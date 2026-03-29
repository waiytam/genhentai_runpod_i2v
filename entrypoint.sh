#!/bin/bash
# Entrypoint wrapper for the RunPod worker.
# Downloads any missing models from HuggingFace to the Network Volume,
# then hands off to the base image's original /start.sh.

# RunPod serverless mounts the network volume at /runpod-volume.
# The worker-comfyui base image already adds /runpod-volume/models/* as
# extra ComfyUI search paths, so no symlink is needed — just ensure the
# models/ subdirectory exists before download_models.sh writes to it.
mkdir -p /runpod-volume/models

echo "=== Checking/downloading models to network volume ==="
/download_models.sh
echo "=== Starting worker ==="
exec /start.sh
