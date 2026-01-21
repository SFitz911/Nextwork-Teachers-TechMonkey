"""
Generate teacher avatars using Stable Diffusion
Creates two distinct teacher images for the virtual classroom
"""

import os
from diffusers import StableDiffusionPipeline
import torch
from PIL import Image

# Configuration
OUTPUT_DIR = "../services/animation/avatars"
PROMPTS = {
    "teacher_a": "professional teacher, friendly face, classroom setting, business casual, confident expression, high quality portrait",
    "teacher_b": "professional teacher, warm smile, classroom setting, business casual, approachable expression, high quality portrait"
}


def generate_avatar(prompt: str, output_path: str, seed: int = None):
    """
    Generate a single avatar image using Stable Diffusion
    """
    print(f"Generating avatar with prompt: {prompt}")
    
    # Load model (adjust model name as needed)
    model_id = "runwayml/stable-diffusion-v1-5"
    
    if torch.cuda.is_available():
        pipe = StableDiffusionPipeline.from_pretrained(
            model_id,
            torch_dtype=torch.float16 if torch.cuda.is_available() else torch.float32
        )
        pipe = pipe.to("cuda")
    else:
        print("Warning: CUDA not available, using CPU (will be slow)")
        pipe = StableDiffusionPipeline.from_pretrained(model_id)
    
    # Generate image
    generator = torch.Generator(device="cuda" if torch.cuda.is_available() else "cpu")
    if seed:
        generator.manual_seed(seed)
    
    image = pipe(
        prompt,
        num_inference_steps=50,
        guidance_scale=7.5,
        generator=generator,
        width=512,
        height=512
    ).images[0]
    
    # Save image
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    image.save(output_path)
    print(f"Saved avatar to: {output_path}")
    
    return image


def main():
    """
    Generate both teacher avatars
    """
    print("=" * 60)
    print("AI Teacher Avatar Generation")
    print("=" * 60)
    
    # Check for GPU
    if torch.cuda.is_available():
        print(f"✅ CUDA available: {torch.cuda.get_device_name(0)}")
        print(f"   VRAM: {torch.cuda.get_device_properties(0).total_memory / 1e9:.2f} GB")
    else:
        print("⚠️  CUDA not available - generation will be slow")
    
    # Generate Teacher A
    print("\n" + "-" * 60)
    print("Generating Teacher A avatar...")
    teacher_a_path = os.path.join(OUTPUT_DIR, "teacher_a.jpg")
    generate_avatar(PROMPTS["teacher_a"], teacher_a_path, seed=42)
    
    # Generate Teacher B
    print("\n" + "-" * 60)
    print("Generating Teacher B avatar...")
    teacher_b_path = os.path.join(OUTPUT_DIR, "teacher_b.jpg")
    generate_avatar(PROMPTS["teacher_b"], teacher_b_path, seed=123)
    
    print("\n" + "=" * 60)
    print("✅ Avatar generation complete!")
    print(f"   Teacher A: {teacher_a_path}")
    print(f"   Teacher B: {teacher_b_path}")
    print("=" * 60)


if __name__ == "__main__":
    main()
