#!/bin/bash
# Entrypoint wrapper for the RunPod worker.
# Downloads any missing models from HuggingFace to the Network Volume,
# then hands off to the base image's original /start.sh.

# RunPod serverless mounts the network volume at /runpod-volume.
# The worker-comfyui base image already adds /runpod-volume/models/* as
# extra ComfyUI search paths, so no symlink is needed — just ensure the
# models/ subdirectory exists before download_models.sh writes to it.
mkdir -p /runpod-volume/models
# DiffusionModelLoaderKJ requires models in diffusion_models/ type path.
mkdir -p /runpod-volume/models/diffusion_models

# Safety: ensure diffusion_models is registered even if extra_model_paths.yaml
# was regenerated at runtime by the base image startup scripts.
if [ -f /comfyui/extra_model_paths.yaml ] && ! grep -q "runpod_diffusion_models" /comfyui/extra_model_paths.yaml; then
  printf '\nrunpod_diffusion_models:\n    base_path: /runpod-volume/models\n    diffusion_models: diffusion_models/\n' \
    >> /comfyui/extra_model_paths.yaml
fi

echo "=== Checking/downloading models to network volume ==="
/download_models.sh
echo "=== Starting worker ==="
exec /start.sh
