"""
LongCat-Video-Avatar API Service
Wraps LongCat-Video-Avatar pipeline for HTTP API access
"""

from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.responses import FileResponse, JSONResponse
from pydantic import BaseModel
import os
import json
import uuid
import subprocess
import tempfile
from pathlib import Path
from typing import Optional
import asyncio
import logging

app = FastAPI(title="LongCat-Video-Avatar Service")

# Configuration
LONGCAT_VIDEO_DIR = os.getenv("LONGCAT_VIDEO_DIR", "/app/longcat-video")
CHECKPOINT_DIR = os.getenv("CHECKPOINT_DIR", f"{LONGCAT_VIDEO_DIR}/weights/LongCat-Video-Avatar")
AVATAR_IMAGES_DIR = os.getenv("AVATAR_IMAGES_DIR", f"{LONGCAT_VIDEO_DIR}/assets/avatars")
OUTPUT_DIR = os.getenv("OUTPUT_DIR", "/app/output")
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


@app.get("/")
async def root():
    return {
        "service": "LongCat-Video-Avatar",
        "status": "ready",
        "checkpoint_dir": CHECKPOINT_DIR,
        "resolution": RESOLUTION
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
        "active_jobs": len([j for j in jobs.values() if j["status"] == "processing"])
    }


@app.post("/generate", response_model=GenerateResponse)
async def generate_video(request: GenerateRequest, background_tasks: BackgroundTasks):
    """
    Generate video from image + audio + prompt using LongCat-Video-Avatar
    """
    try:
        # Validate avatar_id
        if request.avatar_id not in TEACHER_IMAGES:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid avatar_id: {request.avatar_id}. Must be one of: {list(TEACHER_IMAGES.keys())}"
            )
        
        # Get avatar image path
        avatar_image = TEACHER_IMAGES[request.avatar_id]
        avatar_path = os.path.join(AVATAR_IMAGES_DIR, avatar_image)
        
        if not os.path.exists(avatar_path):
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
        
        # Start generation in background
        background_tasks.add_task(
            generate_video_background,
            job_id,
            input_json_path,
            audio_path,
            request.resolution,
            request.num_segments
        )
        
        return GenerateResponse(
            video_url=f"/video/{job_id}",
            video_path=f"{OUTPUT_DIR}/video_{job_id}.mp4",
            job_id=job_id,
            status="processing"
        )
    
    except Exception as e:
        logger.error(f"Error generating video: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


async def generate_video_background(
    job_id: str,
    input_json_path: str,
    audio_path: str,
    resolution: str,
    num_segments: int
):
    """
    Background task to generate video using LongCat-Video-Avatar
    """
    try:
        logger.info(f"Starting video generation for job {job_id}")
        
        # Prepare output directory
        job_output_dir = os.path.join(OUTPUT_DIR, f"job_{job_id}")
        os.makedirs(job_output_dir, exist_ok=True)
        
        # Build command
        script_path = os.path.join(LONGCAT_VIDEO_DIR, "run_demo_avatar_single_audio_to_video.py")
        
        cmd = [
            "torchrun",
            f"--nproc_per_node={CONTEXT_PARALLEL_SIZE}",
            script_path,
            f"--context_parallel_size={CONTEXT_PARALLEL_SIZE}",
            f"--checkpoint_dir={CHECKPOINT_DIR}",
            "--stage_1=ai2v",  # Audio-Image-to-Video
            f"--input_json={input_json_path}",
            f"--output_dir={job_output_dir}",
            f"--resolution={resolution}",
            f"--num_segments={num_segments}",
            "--enable_compile"  # Faster inference
        ]
        
        # Set environment
        env = os.environ.copy()
        env["PYTHONPATH"] = f"{LONGCAT_VIDEO_DIR}:{env.get('PYTHONPATH', '')}"
        
        # Run generation
        logger.info(f"Running command: {' '.join(cmd)}")
        result = subprocess.run(
            cmd,
            cwd=LONGCAT_VIDEO_DIR,
            env=env,
            capture_output=True,
            text=True,
            timeout=3600  # 1 hour timeout
        )
        
        if result.returncode != 0:
            logger.error(f"Generation failed: {result.stderr}")
            jobs[job_id]["status"] = "failed"
            jobs[job_id]["error"] = result.stderr
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
    
    except subprocess.TimeoutExpired:
        logger.error(f"Generation timeout for job {job_id}")
        jobs[job_id]["status"] = "failed"
        jobs[job_id]["error"] = "Generation timeout"
    
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
