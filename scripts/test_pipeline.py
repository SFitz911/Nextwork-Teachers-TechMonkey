#!/usr/bin/env python3
"""
Test pipeline script
Tests the end-to-end flow: LLM → TTS → Animation
"""

import requests
import json
import sys
import os
import time

# Configuration
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://localhost:11434")
TTS_URL = os.getenv("TTS_API_URL", "http://localhost:8001")
ANIMATION_URL = os.getenv("ANIMATION_API_URL", "http://localhost:8002")
MODEL = "mistral:7b"
TEST_TEXT = "Hello, I am an AI teacher. I'm here to help you learn new things today."


def test_llm(text: str) -> str:
    """
    Test LLM generation
    """
    print("Step 1: Testing LLM...")
    try:
        response = requests.post(
            f"{OLLAMA_URL}/api/generate",
            json={
                "model": MODEL,
                "prompt": f"Respond as a friendly teacher: {text}",
                "stream": False
            },
            timeout=60
        )
        response.raise_for_status()
        result = response.json()
        generated_text = result.get("response", "")
        print(f"  ✅ LLM generated: {generated_text[:100]}...")
        return generated_text
    except Exception as e:
        print(f"  ❌ LLM error: {e}")
        return None


def test_tts(text: str) -> str:
    """
    Test TTS generation
    """
    print("\nStep 2: Testing TTS...")
    try:
        response = requests.post(
            f"{TTS_URL}/tts",
            json={
                "text": text,
                "voice": "en_US-lessac-medium",
                "chunk": False
            },
            timeout=30
        )
        response.raise_for_status()
        result = response.json()
        audio_base64 = result.get("audio_base64", "")
        if audio_base64:
            print(f"  ✅ TTS generated ({len(audio_base64)} bytes)")
            return audio_base64
        else:
            print("  ⚠️  TTS returned empty audio")
            return None
    except Exception as e:
        print(f"  ❌ TTS error: {e}")
        return None


def test_animation(audio_base64: str, avatar_id: str = "teacher_a") -> str:
    """
    Test animation generation
    """
    print("\nStep 3: Testing Animation...")
    try:
        response = requests.post(
            f"{ANIMATION_URL}/animate",
            json={
                "audio_base64": audio_base64,
                "avatar_id": avatar_id,
                "style": "default"
            },
            timeout=120
        )
        response.raise_for_status()
        result = response.json()
        video_url = result.get("video_url", "")
        job_id = result.get("job_id", "")
        print(f"  ✅ Animation generated (Job ID: {job_id})")
        print(f"     Video URL: {video_url}")
        return job_id
    except Exception as e:
        print(f"  ❌ Animation error: {e}")
        return None


def main():
    """
    Run end-to-end pipeline test
    """
    print("=" * 60)
    print("AI Virtual Classroom - Pipeline Test")
    print("=" * 60)
    print()
    
    start_time = time.time()
    
    # Step 1: LLM
    generated_text = test_llm(TEST_TEXT)
    if not generated_text:
        print("\n❌ Pipeline test failed at LLM stage")
        return 1
    
    # Step 2: TTS
    audio_base64 = test_tts(generated_text)
    if not audio_base64:
        print("\n❌ Pipeline test failed at TTS stage")
        return 1
    
    # Step 3: Animation
    job_id = test_animation(audio_base64)
    if not job_id:
        print("\n❌ Pipeline test failed at Animation stage")
        return 1
    
    elapsed = time.time() - start_time
    
    print("\n" + "=" * 60)
    print(f"✅ Pipeline test completed successfully!")
    print(f"   Total time: {elapsed:.2f} seconds")
    print("=" * 60)
    
    return 0


if __name__ == "__main__":
    sys.exit(main())
