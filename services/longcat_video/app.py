"""
LongCat-Video-Avatar API Service
Wraps LongCat-Video-Avatar pipeline for HTTP API access

Memory Management:
- Queue system: Only 1 video generation at a time (prevents concurrent model loads)
- Process monitoring: Track and kill stuck processes
- Explicit cleanup: Clear GPU memory after each job
"""

from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.responses import FileResponse, JSONResponse
from pydantic import BaseModel
import os
import sys
import json
import uuid
import subprocess
import tempfile
import signal
import psutil
from pathlib import Path
from typing import Optional
import asyncio
import logging
from collections import deque
import threading
import time

app = FastAPI(title="LongCat-Video-Avatar Service")

# Configuration
LONGCAT_VIDEO_DIR = os.getenv("LONGCAT_VIDEO_DIR", os.path.expanduser("~/Nextwork-Teachers-TechMonkey/LongCat-Video"))
CHECKPOINT_DIR = os.getenv("CHECKPOINT_DIR", f"{LONGCAT_VIDEO_DIR}/weights/LongCat-Video-Avatar")
AVATAR_IMAGES_DIR = os.getenv("AVATAR_IMAGES_DIR", f"{LONGCAT_VIDEO_DIR}/assets/avatars")
# Use storage volume if available, otherwise fallback to local output
VAST_STORAGE = os.getenv("VAST_STORAGE_PATH", os.getenv("VAST_STORAGE", ""))
if VAST_STORAGE and os.path.exists(VAST_STORAGE):
    OUTPUT_DIR = os.getenv("VIDEO_OUTPUT_DIR", os.path.join(VAST_STORAGE, "data/videos"))
else:
    OUTPUT_DIR = os.getenv("OUTPUT_DIR", os.path.expanduser("~/Nextwork-Teachers-TechMonkey/outputs/longcat"))
CONTEXT_PARALLEL_SIZE = int(os.getenv("CONTEXT_PARALLEL_SIZE", "1"))
RESOLUTION = os.getenv("RESOLUTION", "480p")
NUM_SEGMENTS = int(os.getenv("NUM_SEGMENTS", "1"))

# Teacher mapping
TEACHER_IMAGES = {
    "teacher_a": "maya.png",
    "teacher_b": "maximus.png",
    "teacher_c": "krishna.png",
    "teacher_d": "techmonkey_steve.png",
    "teacher_e": "pano_bieber.png"
}

# Teacher prompts (from configs/teacher_prompts.yaml)
TEACHER_PROMPTS = {
    "teacher_a": "A warm and approachable educator with expertise in making complex topics relatable. Speaking naturally and conversationally.",
    "teacher_b": "A technical expert with deep knowledge in advanced topics. Speaking precisely and analytically.",
    "teacher_c": "An enthusiastic and knowledgeable educator with extensive teaching experience. Speaking clearly and engagingly.",
    "teacher_d": "An innovative and creative educator who makes learning fun. Speaking energetically and creatively.",
    "teacher_e": "A knowledgeable and adaptable educator. Speaking clearly and supportively."
}

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class GenerateRequest(BaseModel):
    avatar_id: str  # "teacher_a", "teacher_b", etc.
    audio_url: str  # URL to audio file (from TTS service)
    text_prompt: Optional[str] = None  # Optional text prompt override
    resolution: Optional[str] = "480p"  # "480p" or "720p"
    num_segments: Optional[int] = 1  # Number of video segments


class GenerateResponse(BaseModel):
    video_url: str
    video_path: str
    job_id: str
    status: str = "processing"


# Job tracking
jobs = {}

# Queue system: Only allow 1 video generation at a time
generation_queue = deque()
generation_lock = threading.Lock()
current_generation = None  # Track current generation process
current_generation_pid = None  # Track PID for cleanup


def cleanup_gpu_memory():
    """Explicitly clear GPU memory"""
    try:
        # Try to clear via Python if torch is available
        import torch
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
            torch.cuda.ipc_collect()
            logger.info("✅ GPU memory cache cleared")
    except ImportError:
        # torch not available in this process, that's okay
        pass
    except Exception as e:
        logger.warning(f"Failed to clear GPU memory: {e}")


def kill_stuck_processes():
    """Kill any stuck video generation processes"""
    try:
        # Find processes related to video generation
        for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
            try:
                cmdline = proc.info.get('cmdline', [])
                if cmdline:
                    cmdline_str = ' '.join(cmdline)
                    # Look for torch.distributed.run or run_demo_avatar processes
                    if 'torch.distributed.run' in cmdline_str and 'avatar' in cmdline_str:
                        pid = proc.info['pid']
                        logger.warning(f"Found stuck process {pid}, killing it...")
                        try:
                            proc.kill()
                            proc.wait(timeout=5)
                            logger.info(f"✅ Killed stuck process {pid}")
                        except (psutil.NoSuchProcess, psutil.TimeoutExpired):
                            pass
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
    except Exception as e:
        logger.warning(f"Error killing stuck processes: {e}")


def process_generation_queue():
    """Process the generation queue (runs in background thread)"""
    global current_generation, current_generation_pid
    
    while True:
        try:
            with generation_lock:
                if not generation_queue or current_generation is not None:
                    time.sleep(1)
                    continue
                
                # Get next job from queue
                job_data = generation_queue.popleft()
                current_generation = job_data
                current_generation_pid = None
            
            # Process the job
            job_id = job_data['job_id']
            logger.info(f"Processing queued job {job_id}")
            
            try:
                # Run generation
                generate_video_background_sync(
                    job_id,
                    job_data['input_json_path'],
                    job_data['audio_path'],
                    job_data['resolution'],
                    job_data['num_segments']
                )
            finally:
                # Cleanup after job completes
                with generation_lock:
                    current_generation = None
                    current_generation_pid = None
                
                # Clear GPU memory
                cleanup_gpu_memory()
                
                # Kill any stuck processes
                kill_stuck_processes()
                
                logger.info(f"Job {job_id} completed, queue has {len(generation_queue)} items remaining")
        
        except Exception as e:
            logger.error(f"Error in queue processor: {e}", exc_info=True)
            with generation_lock:
                current_generation = None
                current_generation_pid = None
            time.sleep(1)


# Start queue processor thread
queue_thread = threading.Thread(target=process_generation_queue, daemon=True)
queue_thread.start()


@app.get("/")
async def root():
    return {
        "service": "LongCat-Video-Avatar",
        "status": "ready",
        "checkpoint_dir": CHECKPOINT_DIR,
        "resolution": RESOLUTION,
        "queue_size": len(generation_queue),
        "current_generation": current_generation['job_id'] if current_generation else None
    }


@app.get("/status")
async def status():
    """Check service status and model availability"""
    model_exists = os.path.exists(CHECKPOINT_DIR)
    return {
        "status": "ready" if model_exists else "models_not_found",
        "model_path": CHECKPOINT_DIR,
        "model_exists": model_exists,
        "output_dir": OUTPUT_DIR,
        "active_jobs": len([j for j in jobs.values() if j["status"] == "processing"]),
        "queue_size": len(generation_queue),
        "current_generation": current_generation['job_id'] if current_generation else None
    }


@app.post("/generate", response_model=GenerateResponse)
async def generate_video(request: GenerateRequest, background_tasks: BackgroundTasks):
    """
    Generate video from image + audio + prompt using LongCat-Video-Avatar
    """
    try:
        logger.info(f"Received generate request: avatar_id={request.avatar_id}, audio_url={request.audio_url}")
        logger.info(f"AVATAR_IMAGES_DIR: {AVATAR_IMAGES_DIR}")
        logger.info(f"Available images in directory: {os.listdir(AVATAR_IMAGES_DIR) if os.path.exists(AVATAR_IMAGES_DIR) else 'DIRECTORY NOT FOUND'}")
        
        # Validate avatar_id
        if request.avatar_id not in TEACHER_IMAGES:
            logger.error(f"Invalid avatar_id: {request.avatar_id}. Valid options: {list(TEACHER_IMAGES.keys())}")
            raise HTTPException(
                status_code=400,
                detail=f"Invalid avatar_id: {request.avatar_id}. Must be one of: {list(TEACHER_IMAGES.keys())}"
            )
        
        # Get avatar image path
        avatar_image = TEACHER_IMAGES[request.avatar_id]
        avatar_path = os.path.join(AVATAR_IMAGES_DIR, avatar_image)
        logger.info(f"Looking for avatar image at: {avatar_path}")
        
        if not os.path.exists(avatar_path):
            logger.error(f"Avatar image not found: {avatar_path}")
            logger.error(f"AVATAR_IMAGES_DIR exists: {os.path.exists(AVATAR_IMAGES_DIR)}")
            if os.path.exists(AVATAR_IMAGES_DIR):
                logger.error(f"Files in AVATAR_IMAGES_DIR: {os.listdir(AVATAR_IMAGES_DIR)}")
            raise HTTPException(
                status_code=404,
                detail=f"Avatar image not found: {avatar_path}. Please ensure teacher images are in {AVATAR_IMAGES_DIR}"
            )
        
        # Get text prompt (use teacher-specific or provided)
        text_prompt = request.text_prompt or TEACHER_PROMPTS.get(request.avatar_id, "A person speaking naturally")
        
        # Generate job ID
        job_id = str(uuid.uuid4())
        
        # Create output directory
        os.makedirs(OUTPUT_DIR, exist_ok=True)
        
        # Download audio file
        import requests
        audio_response = requests.get(request.audio_url)
        if audio_response.status_code != 200:
            raise HTTPException(status_code=400, detail=f"Failed to download audio from {request.audio_url}")
        
        # Save audio to temp file
        audio_temp = tempfile.NamedTemporaryFile(delete=False, suffix=".wav")
        audio_temp.write(audio_response.content)
        audio_temp.close()
        audio_path = audio_temp.name
        
        # Create input JSON for LongCat-Video
        input_json_path = os.path.join(OUTPUT_DIR, f"input_{job_id}.json")
        input_data = {
            "prompt": text_prompt,
            "cond_image": avatar_path,
            "cond_audio": {
                "person1": audio_path
            }
        }
        
        with open(input_json_path, 'w') as f:
            json.dump(input_data, f)
        
        # Track job
        jobs[job_id] = {
            "status": "processing",
            "avatar_id": request.avatar_id,
            "output_path": None
        }
        
        # Add to queue instead of starting immediately
        with generation_lock:
            generation_queue.append({
                "job_id": job_id,
                "input_json_path": input_json_path,
                "audio_path": audio_path,
                "resolution": request.resolution,
                "num_segments": request.num_segments
            })
            logger.info(f"Job {job_id} added to queue (queue size: {len(generation_queue)})")
        
        return GenerateResponse(
            video_url=f"/video/{job_id}",
            video_path=f"{OUTPUT_DIR}/video_{job_id}.mp4",
            job_id=job_id,
            status="processing"
        )
    
    except HTTPException:
        # Re-raise HTTP exceptions as-is (they already have proper status codes)
        raise
    except Exception as e:
        logger.error(f"Error generating video: {e}", exc_info=True)
        logger.error(f"AVATAR_IMAGES_DIR: {AVATAR_IMAGES_DIR}")
        logger.error(f"CHECKPOINT_DIR: {CHECKPOINT_DIR}")
        logger.error(f"OUTPUT_DIR: {OUTPUT_DIR}")
        raise HTTPException(status_code=500, detail=f"Video generation failed: {str(e)}")


def generate_video_background_sync(
    job_id: str,
    input_json_path: str,
    audio_path: str,
    resolution: str,
    num_segments: int
):
    """
    Synchronous video generation (called from queue processor)
    """
    global current_generation_pid
    
    try:
        logger.info(f"Starting video generation for job {job_id}")
        
        # Prepare output directory
        job_output_dir = os.path.join(OUTPUT_DIR, f"job_{job_id}")
        os.makedirs(job_output_dir, exist_ok=True)
        
        # Build command - use python -m torch.distributed.run to ensure correct environment
        script_path = os.path.join(LONGCAT_VIDEO_DIR, "run_demo_avatar_single_audio_to_video.py")
        
        # Verify script file exists
        if not os.path.exists(script_path):
            error_msg = f"LongCat-Video script not found: {script_path}\n"
            error_msg += f"LONGCAT_VIDEO_DIR: {LONGCAT_VIDEO_DIR}\n"
            error_msg += f"Directory exists: {os.path.exists(LONGCAT_VIDEO_DIR)}\n"
            if os.path.exists(LONGCAT_VIDEO_DIR):
                error_msg += f"Files in directory: {', '.join(os.listdir(LONGCAT_VIDEO_DIR)[:10])}\n"
            error_msg += "\nTo fix this, run:\n"
            error_msg += "  bash scripts/clone_longcat_video.sh"
            logger.error(error_msg)
            jobs[job_id]["status"] = "failed"
            jobs[job_id]["error"] = error_msg
            return
        
        # CRITICAL: Use conda Python explicitly, not venv Python
        # Check if we're in conda environment
        python_exe = sys.executable
        conda_prefix = os.getenv("CONDA_PREFIX", "")
        
        # If we're in conda, use conda Python explicitly
        if conda_prefix and "longcat-video" in conda_prefix:
            # We're in conda environment, use it
            conda_python = os.path.join(conda_prefix, "bin", "python")
            if os.path.exists(conda_python):
                python_exe = conda_python
                logger.info(f"Using conda Python: {python_exe}")
            else:
                logger.warning(f"Conda Python not found at {conda_python}, using {python_exe}")
        else:
            # Try to find conda Python from CONDA_DEFAULT_ENV
            conda_env = os.getenv("CONDA_DEFAULT_ENV", "")
            if conda_env == "longcat-video":
                conda_base = os.getenv("CONDA_BASE", os.path.expanduser("~/.conda"))
                conda_python = os.path.join(conda_base, "envs", "longcat-video", "bin", "python")
                if os.path.exists(conda_python):
                    python_exe = conda_python
                    logger.info(f"Found conda Python via CONDA_DEFAULT_ENV: {python_exe}")
                else:
                    logger.warning(f"Conda Python not found, using {python_exe}")
            else:
                logger.warning(f"Not in conda longcat-video environment (CONDA_DEFAULT_ENV={conda_env}), using {python_exe}")
        
        cmd = [
            python_exe,
            "-m", "torch.distributed.run",
            f"--nproc_per_node={CONTEXT_PARALLEL_SIZE}",
            script_path,
            f"--context_parallel_size={CONTEXT_PARALLEL_SIZE}",
            f"--checkpoint_dir={CHECKPOINT_DIR}",
            "--stage_1=ai2v",  # Audio-Image-to-Video
            f"--input_json={input_json_path}",
            f"--output_dir={job_output_dir}",
            f"--resolution={resolution}",
            f"--num_segments={num_segments}"
        ]
        
        # Set environment
        env = os.environ.copy()
        env["PYTHONPATH"] = f"{LONGCAT_VIDEO_DIR}:{env.get('PYTHONPATH', '')}"
        # Set CUDA device to GPU 1 (which is empty) and memory optimization
        env["CUDA_VISIBLE_DEVICES"] = "1"  # Use GPU 1 instead of GPU 0
        env["PYTORCH_CUDA_ALLOC_CONF"] = "expandable_segments:True"  # Help with memory fragmentation
        
        # Run generation
        logger.info(f"Running command: {' '.join(cmd)}")
        logger.info(f"Working directory: {LONGCAT_VIDEO_DIR}")
        logger.info(f"Python executable: {python_exe}")
        logger.info(f"CONDA_PREFIX: {os.getenv('CONDA_PREFIX', 'not set')}")
        logger.info(f"CONDA_DEFAULT_ENV: {os.getenv('CONDA_DEFAULT_ENV', 'not set')}")
        
        # Start process and track PID
        process = subprocess.Popen(
            cmd,
            cwd=LONGCAT_VIDEO_DIR,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        
        current_generation_pid = process.pid
        logger.info(f"Started generation process with PID: {current_generation_pid}")
        
        # Wait for completion with timeout
        try:
            stdout, stderr = process.communicate(timeout=3600)  # 1 hour timeout
            returncode = process.returncode
        except subprocess.TimeoutExpired:
            logger.error(f"Generation timeout for job {job_id}, killing process {process.pid}")
            process.kill()
            process.wait()
            jobs[job_id]["status"] = "failed"
            jobs[job_id]["error"] = "Generation timeout"
            return
        
        if returncode != 0:
            error_msg = f"Generation failed with exit code {returncode}"
            if stdout:
                logger.error(f"STDOUT: {stdout}")
                error_msg += f"\nSTDOUT: {stdout[-2000:]}"  # Last 2000 chars
            if stderr:
                logger.error(f"STDERR: {stderr}")
                error_msg += f"\nSTDERR: {stderr[-2000:]}"  # Last 2000 chars
            logger.error(f"Full error: {error_msg}")
            jobs[job_id]["status"] = "failed"
            jobs[job_id]["error"] = error_msg
            return
        
        # Find output video
        output_video = None
        for file in os.listdir(job_output_dir):
            if file.endswith(".mp4"):
                output_video = os.path.join(job_output_dir, file)
                break
        
        if not output_video:
            # Try to find in subdirectories
            for root, dirs, files in os.walk(job_output_dir):
                for file in files:
                    if file.endswith(".mp4"):
                        output_video = os.path.join(root, file)
                        break
                if output_video:
                    break
        
        if output_video:
            # Copy to final location
            final_video = os.path.join(OUTPUT_DIR, f"video_{job_id}.mp4")
            import shutil
            shutil.copy2(output_video, final_video)
            
            jobs[job_id]["status"] = "completed"
            jobs[job_id]["output_path"] = final_video
            logger.info(f"Video generation completed: {final_video}")
        else:
            logger.error(f"No output video found in {job_output_dir}")
            jobs[job_id]["status"] = "failed"
            jobs[job_id]["error"] = "No output video generated"
        
        # Cleanup temp files
        try:
            os.remove(input_json_path)
            os.remove(audio_path)
        except:
            pass
    
    except Exception as e:
        logger.error(f"Error in background generation: {e}", exc_info=True)
        jobs[job_id]["status"] = "failed"
        jobs[job_id]["error"] = str(e)


@app.get("/video/{job_id}")
async def get_video(job_id: str):
    """Stream generated video"""
    if job_id not in jobs:
        raise HTTPException(status_code=404, detail="Job not found")
    
    job = jobs[job_id]
    
    if job["status"] == "processing":
        return JSONResponse(
            status_code=202,
            content={"status": "processing", "message": "Video generation in progress"}
        )
    
    if job["status"] == "failed":
        raise HTTPException(status_code=500, detail=job.get("error", "Generation failed"))
    
    video_path = job.get("output_path")
    if not video_path or not os.path.exists(video_path):
        raise HTTPException(status_code=404, detail="Video not found")
    
    return FileResponse(video_path, media_type="video/mp4")


@app.get("/job/{job_id}")
async def get_job_status(job_id: str):
    """Get job status"""
    if job_id not in jobs:
        raise HTTPException(status_code=404, detail="Job not found")
    
    return jobs[job_id]


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8003)
