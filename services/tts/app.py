"""
TTS Service - Piper or Coqui TTS
Handles text-to-speech conversion with chunking support
"""

from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse, FileResponse
from pydantic import BaseModel
import io
import os
import uuid
import base64
from typing import Optional
from pathlib import Path

app = FastAPI(title="AI Teacher TTS Service")

# Model selection: "piper" or "coqui"
TTS_MODEL = os.getenv("TTS_MODEL", "piper")
TTS_VOICE = os.getenv("TTS_VOICE", "en_US-lessac-medium")

# Audio storage directory
AUDIO_DIR = os.getenv("AUDIO_DIR", os.path.join(os.path.dirname(__file__), "..", "..", "outputs", "tts"))
os.makedirs(AUDIO_DIR, exist_ok=True)


class TTSRequest(BaseModel):
    text: str
    voice: Optional[str] = None
    speed: Optional[float] = 1.0
    chunk: Optional[bool] = False  # Return chunks for streaming


class TTSResponse(BaseModel):
    audio_url: Optional[str] = None
    audio_base64: Optional[str] = None
    chunks: Optional[list] = None


@app.get("/")
async def root():
    return {
        "service": "TTS",
        "model": TTS_MODEL,
        "status": "ready"
    }


@app.post("/tts", response_model=TTSResponse)
async def generate_speech(request: TTSRequest):
    """
    Generate speech from text
    """
    try:
        voice = request.voice or TTS_VOICE
        text = request.text
        
        if TTS_MODEL == "piper":
            # Piper TTS implementation
            audio_data = await generate_piper_tts(text, voice, request.speed)
        elif TTS_MODEL == "coqui":
            # Coqui TTS implementation
            audio_data = await generate_coqui_tts(text, voice, request.speed)
        else:
            raise HTTPException(status_code=400, detail=f"Unknown TTS model: {TTS_MODEL}")
        
        # If chunking requested, split audio
        if request.chunk:
            chunks = chunk_audio(audio_data)
            return TTSResponse(chunks=chunks)
        
        # Save audio to file and return URL
        audio_id = str(uuid.uuid4())
        audio_filename = f"{audio_id}.wav"
        audio_path = os.path.join(AUDIO_DIR, audio_filename)
        
        # If audio_data is base64, decode it
        if isinstance(audio_data, str) and not audio_data.startswith("piper_") and not audio_data.startswith("coqui_"):
            try:
                audio_bytes = base64.b64decode(audio_data)
            except:
                # If not base64, treat as placeholder and create empty file for now
                audio_bytes = b""  # Placeholder - will be replaced when TTS is implemented
        else:
            # Placeholder - create empty file
            audio_bytes = b""  # Will be replaced when actual TTS is implemented
        
        # Save audio file
        with open(audio_path, 'wb') as f:
            f.write(audio_bytes)
        
        # Return URL (prioritize audio_url for LongCat-Video compatibility)
        audio_url = f"http://localhost:8001/audio/{audio_filename}"
        
        return TTSResponse(audio_url=audio_url, audio_base64=audio_data)
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


async def generate_piper_tts(text: str, voice: str, speed: float) -> str:
    """
    Generate TTS using Piper
    TODO: Implement Piper TTS
    """
    # Placeholder - implement actual Piper TTS
    # See: https://github.com/rhasspy/piper
    return "piper_audio_base64_placeholder"


async def generate_coqui_tts(text: str, voice: str, speed: float) -> str:
    """
    Generate TTS using Coqui TTS
    TODO: Implement Coqui TTS
    """
    # Placeholder - implement actual Coqui TTS
    # See: https://github.com/coqui-ai/TTS
    return "coqui_audio_base64_placeholder"


def chunk_audio(audio_data: str, chunk_duration: float = 2.0) -> list:
    """
    Split audio into chunks for streaming
    """
    # TODO: Implement audio chunking
    return [audio_data]  # Placeholder


@app.get("/audio/{filename}")
async def get_audio(filename: str):
    """
    Serve audio files
    """
    audio_path = os.path.join(AUDIO_DIR, filename)
    if not os.path.exists(audio_path):
        raise HTTPException(status_code=404, detail="Audio file not found")
    return FileResponse(audio_path, media_type="audio/wav")


@app.get("/voices")
async def list_voices():
    """
    List available voices
    """
    return {
        "voices": [
            "en_US-lessac-medium",
            "en_US-lessac-high",
            "en_GB-alba-medium",
            # Add more voices
        ]
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
