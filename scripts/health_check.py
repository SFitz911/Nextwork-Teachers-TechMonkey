#!/usr/bin/env python3
"""
Health check script for AI Teacher services
Checks all services and reports status
"""

import requests
import sys
import os
from typing import Dict, Tuple

# Service endpoints
SERVICES = {
    "n8n": os.getenv("N8N_URL", "http://localhost:5678"),
    "TTS": os.getenv("TTS_API_URL", "http://localhost:8001"),
    "Animation": os.getenv("ANIMATION_API_URL", "http://localhost:8002"),
    "Ollama": os.getenv("OLLAMA_URL", "http://localhost:11434"),
    "Frontend": os.getenv("FRONTEND_URL", "http://localhost:8501"),
}


def check_service(name: str, url: str) -> Tuple[bool, str]:
    """
    Check if a service is healthy
    Returns (is_healthy, message)
    """
    try:
        # Adjust endpoint based on service
        if name == "Ollama":
            check_url = f"{url}/api/tags"
        elif name == "Frontend":
            check_url = url
        else:
            check_url = url
        
        response = requests.get(check_url, timeout=5)
        
        if response.status_code == 200:
            return True, "✅ Online"
        else:
            return False, f"❌ Status: {response.status_code}"
    
    except requests.exceptions.ConnectionError:
        return False, "❌ Connection refused"
    except requests.exceptions.Timeout:
        return False, "❌ Timeout"
    except Exception as e:
        return False, f"❌ Error: {str(e)}"


def check_gpu() -> Tuple[bool, str]:
    """
    Check GPU availability (if nvidia-smi is available)
    """
    import subprocess
    try:
        result = subprocess.run(
            ["nvidia-smi", "--query-gpu=name,memory.used,memory.total", "--format=csv,noheader"],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            gpu_info = result.stdout.strip().split("\n")[0]
            return True, f"✅ {gpu_info}"
        else:
            return False, "❌ nvidia-smi failed"
    except FileNotFoundError:
        return False, "⚠️  nvidia-smi not found (may be normal)"
    except Exception as e:
        return False, f"❌ Error: {str(e)}"


def main():
    """
    Run health checks and print report
    """
    print("=" * 60)
    print("AI Virtual Classroom - Health Check")
    print("=" * 60)
    print()
    
    all_healthy = True
    
    # Check GPU
    print("GPU:")
    gpu_healthy, gpu_msg = check_gpu()
    print(f"  {gpu_msg}")
    print()
    
    # Check services
    print("Services:")
    for name, url in SERVICES.items():
        healthy, msg = check_service(name, url)
        print(f"  {name:12} {msg}")
        if not healthy:
            all_healthy = False
    
    print()
    print("=" * 60)
    
    if all_healthy:
        print("✅ All services are healthy!")
        return 0
    else:
        print("⚠️  Some services are unhealthy. Please check logs.")
        return 1


if __name__ == "__main__":
    sys.exit(main())
