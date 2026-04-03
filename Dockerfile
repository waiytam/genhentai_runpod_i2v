# Base image: ComfyUI + comfy-cli + ComfyUI-Manager
FROM runpod/worker-comfyui:5.5.1-base

# Increase WebSocket polling interval so the worker waits 60 s between
# "Still waiting..." log lines instead of the default ~10 s.
ENV COMFY_POLLING_INTERVAL_MS=60000

# Disable torch.compile (dynamo) to prevent compilation errors on non-H100 GPUs.
ENV TORCHDYNAMO_DISABLE=1

# ── Custom nodes ──────────────────────────────────────────────────────────────

# ComfyUI-VideoHelperSuite (provides VHS_VideoCombine for MP4 video output)
RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git && \
    pip install -r /comfyui/custom_nodes/ComfyUI-VideoHelperSuite/requirements.txt

# ComfyUI-WanVideoWrapper (provides WanImageToVideoSVIPro, DiffusionModelLoaderKJ,
# ScheduledCFGGuidance, ImageBatchExtendWithOverlap)
RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git && \
    pip install -r /comfyui/custom_nodes/ComfyUI-WanVideoWrapper/requirements.txt

# ComfyUI-KJNodes (provides ImageResizeKJv2)
RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/kijai/ComfyUI-KJNodes.git && \
    pip install -r /comfyui/custom_nodes/ComfyUI-KJNodes/requirements.txt

# ComfyUI-GGUF (provides UnetLoaderGGUF for .gguf model files)
RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/city96/ComfyUI-GGUF.git && \
    pip install -r /comfyui/custom_nodes/ComfyUI-GGUF/requirements.txt

# rgthree-comfy (provides Power Lora Loader (rgthree))
RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/rgthree/rgthree-comfy.git && \
    pip install -r /comfyui/custom_nodes/rgthree-comfy/requirements.txt

# Register /runpod-volume/models/diffusion_models as a ComfyUI search path.
# worker-comfyui:5.5.1-base has a hardcoded whitelist of volume subdirectories
# {checkpoints, clip, clip_vision, configs, controlnet, embeddings, loras,
# upscale_models, vae, unet} — diffusion_models is NOT in this list.
# DiffusionModelLoaderKJ (ComfyUI-WanVideoWrapper) scans ONLY the
# "diffusion_models" folder type, so without this entry it always returns [].
RUN printf '\nrunpod_diffusion_models:\n    base_path: /runpod-volume/models\n    diffusion_models: diffusion_models/\n' \
    >> /comfyui/extra_model_paths.yaml || true

# Patch the worker handler to also return VHS video (gifs) output alongside images.
COPY patch_handler.py /tmp/patch_handler.py
RUN python3 /tmp/patch_handler.py

# ── Model download startup script ────────────────────────────────────────────
# Models are NOT baked into the image. They live on a RunPod Network Volume
# mounted at /runpod-volume. The download script checks for each file and
# only downloads what is missing (idempotent — fast no-op on warm starts).

COPY download_models.sh /download_models.sh
RUN chmod +x /download_models.sh

# Entrypoint wrapper: download missing models first, then start the worker.
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]
