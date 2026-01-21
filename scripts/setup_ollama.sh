#!/bin/bash

# Setup script for Ollama models
# Downloads and configures LLM models for the AI Teacher system

set -e

echo "=========================================="
echo "Ollama Model Setup"
echo "=========================================="

CONTAINER_NAME="ai-teacher-ollama"

# Check if container is running
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    echo "Error: $CONTAINER_NAME container is not running"
    echo "Please start it with: docker compose up -d ollama"
    exit 1
fi

echo "Available models to install:"
echo "1. Mistral 7B (recommended)"
echo "2. Llama 3 8B"
echo "3. Llama 3 70B (requires more VRAM)"
echo "4. Custom model"
echo ""

read -p "Select model (1-4): " choice

case $choice in
    1)
        MODEL="mistral:7b"
        echo "Installing Mistral 7B..."
        ;;
    2)
        MODEL="llama3:8b"
        echo "Installing Llama 3 8B..."
        ;;
    3)
        MODEL="llama3:70b"
        echo "Installing Llama 3 70B (this may take a while)..."
        ;;
    4)
        read -p "Enter model name (e.g., mistral:7b-instruct-q4_0): " MODEL
        echo "Installing $MODEL..."
        ;;
    *)
        echo "Invalid choice, defaulting to Mistral 7B"
        MODEL="mistral:7b"
        ;;
esac

# Pull model
echo "Downloading model (this may take several minutes)..."
docker exec $CONTAINER_NAME ollama pull "$MODEL"

# Verify installation
echo ""
echo "Verifying installation..."
docker exec $CONTAINER_NAME ollama list

echo ""
echo "=========================================="
echo "✅ Model setup complete!"
echo "=========================================="
echo ""
echo "Test the model with:"
echo "  docker exec $CONTAINER_NAME ollama run $MODEL 'Hello, can you introduce yourself?'"
echo ""
echo "Update configs/llm_config.yaml with model name: $MODEL"
