#!/bin/bash
# Download models to the RunPod Network Volume if they are not already present.
# Idempotent: re-running on an already-populated volume is a fast no-op.
set -e

MODELS_DIR="/runpod-volume/models"
DIFF_DIR="$MODELS_DIR/diffusion_models"
UNET_DIR="$MODELS_DIR/unet"
LORA_DIR="$MODELS_DIR/loras"
CLIP_DIR="$MODELS_DIR/clip"
VAE_DIR="$MODELS_DIR/vae"
CLIP_VIS_DIR="$MODELS_DIR/clip_vision"

HF_BASE="https://huggingface.co"
LORA_REPO="waiytam/genhentai-lora-wan/resolve/main"

download_if_missing() {
  local dest="$1"
  local url="$2"
  if [ ! -f "$dest" ]; then
    echo "Downloading $(basename "$dest")..."
    mkdir -p "$(dirname "$dest")"
    # Pass HF token if set (required for private HuggingFace repos)
    if [ -n "$HF_TOKEN" ]; then
      wget -q --show-progress --header="Authorization: Bearer $HF_TOKEN" -O "$dest" "$url" \
        || { echo "FAILED: $url"; rm -f "$dest"; }
    else
      wget -q --show-progress -O "$dest" "$url" || { echo "FAILED: $url"; rm -f "$dest"; }
    fi
  else
    echo "Already present: $(basename "$dest")"
  fi
}

# ── GGUF models (UnetLoaderGGUF, used by 10s SVI-Pro GGUF workflow) ───────────
# UnetLoaderGGUF scans the "unet" folder type.
download_if_missing "$UNET_DIR/smoothMixWan22I2VT2V_i2vHigh-Q8_0.gguf" \
  "$HF_BASE/$LORA_REPO/smoothMixWan22I2VT2V_i2vHigh-Q8_0.gguf"

download_if_missing "$UNET_DIR/smoothMixWan22I2VT2V_i2vLow-Q8_0.gguf" \
  "$HF_BASE/$LORA_REPO/smoothMixWan22I2VT2V_i2vLow-Q8_0.gguf"

# ── Main models (SVI-Pro smoothMix dual checkpoint, fp16) ─────────────────────
# DiffusionModelLoaderKJ (ComfyUI-WanVideoWrapper) scans the "diffusion_models"
# folder type — NOT "checkpoints". Models must live in diffusion_models/ so that
# ComfyUI auto-adds /runpod-volume/models/diffusion_models as a search path.

download_if_missing "$DIFF_DIR/smoothMixWan2214BI2V_i2vV20High.safetensors" \
  "$HF_BASE/$LORA_REPO/smoothMixWan2214BI2V_i2vV20High.safetensors"

download_if_missing "$DIFF_DIR/smoothMixWan2214BI2V_i2vV20Low.safetensors" \
  "$HF_BASE/$LORA_REPO/smoothMixWan2214BI2V_i2vV20Low.safetensors"

# v2test workflow: smoothMixWan22I2VT2V (non-quantized variant)
download_if_missing "$DIFF_DIR/smoothMixWan22I2VT2V_i2vHigh.safetensors" \
  "$HF_BASE/$LORA_REPO/smoothMixWan22I2VT2V_i2vHigh.safetensors"

download_if_missing "$DIFF_DIR/smoothMixWan22I2VT2V_i2vLow.safetensors" \
  "$HF_BASE/$LORA_REPO/smoothMixWan22I2VT2V_i2vLow.safetensors"

# ── CLIP text encoder (fp16) ───────────────────────────────────────────────────
# SVI-Pro uses fp16 CLIP (different from GGUF endpoint which uses fp8)
download_if_missing "$CLIP_DIR/umt5_xxl_fp16.safetensors" \
  "$HF_BASE/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp16.safetensors"

# ── VAE ───────────────────────────────────────────────────────────────────────
download_if_missing "$VAE_DIR/wan_2.1_vae.safetensors" \
  "$HF_BASE/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors"

# ── CLIP Vision ───────────────────────────────────────────────────────────────
download_if_missing "$CLIP_VIS_DIR/clip_vision_vit_h.safetensors" \
  "$HF_BASE/lllyasviel/misc/resolve/main/clip_vision_vit_h.safetensors"

# ── SVI-Pro LoRAs ─────────────────────────────────────────────────────────────
# SVI Pro v2.0 rank-128 fp16 (Kijai fork, used by svi-pro-10s-v2test.json)
SVI_REPO="Kijai/WanVideo_comfy/resolve/main/LoRAs/Stable-Video-Infinity/v2.0"
download_if_missing "$LORA_DIR/SVI_v2_PRO_Wan2.2-I2V-A14B_HIGH_lora_rank_128_fp16.safetensors" \
  "$HF_BASE/$SVI_REPO/SVI_v2_PRO_Wan2.2-I2V-A14B_HIGH_lora_rank_128_fp16.safetensors"
download_if_missing "$LORA_DIR/SVI_v2_PRO_Wan2.2-I2V-A14B_LOW_lora_rank_128_fp16.safetensors" \
  "$HF_BASE/$SVI_REPO/SVI_v2_PRO_Wan2.2-I2V-A14B_LOW_lora_rank_128_fp16.safetensors"

# v2.0 (original format, kept for reference)
for f in \
  "SVI_Wan2.2-I2V-A14B_high_noise_lora_v2.0.safetensors" \
  "SVI_Wan2.2-I2V-A14B_low_noise_lora_v2.0.safetensors" \
  "SVI_Wan2.2-I2V-A14B_high_noise_lora_v2.0_pro.safetensors" \
  "SVI_Wan2.2-I2V-A14B_low_noise_lora_v2.0_pro.safetensors"; do
  download_if_missing "$LORA_DIR/$f" "$HF_BASE/$LORA_REPO/$f"
done

# ── lightx2v LoRAs (hardcoded in v2test workflow nodes 301/306) ───────────────
for f in \
  "wan2.2_i2v_A14b_high_noise_lora_rank64_lightx2v_4step_1022.safetensors" \
  "wan2.2_i2v_A14b_low_noise_lora_rank64_lightx2v_4step_1022.safetensors"; do
  download_if_missing "$LORA_DIR/$f" "$HF_BASE/$LORA_REPO/$f"
done

# ── Default LoRAs (hardcoded in workflow nodes 300/304/505/506/507/508) ────────
for f in \
  "SmoothXXXAnimation_High.safetensors" \
  "SmoothXXXAnimation_Low.safetensors" \
  "wan22-k3nk4llinon3-16epoc-full-high-k3nk.safetensors" \
  "wan22-k3nk4llinon3-15epoc-full-low-k3nk.safetensors" \
  "bounce_test_HighNoise-000005.safetensors" \
  "bounce_test_LowNoise-000005.safetensors" \
  "2D_animation_effects_high_noise.safetensors" \
  "2D_animation_effects_low_noise.safetensors" \
  "wan2.2_i2v_animestyle_v2_high.safetensors" \
  "wan2.2_i2v_animestyle_v2_low.safetensors"; do
  download_if_missing "$LORA_DIR/$f" "$HF_BASE/$LORA_REPO/$f"
done

# ── Dynamic LoRAs (selected per-generation by keyword scanning) ───────────────

for f in \
  "PENISLORA_22_i2v_HIGH_e320.safetensors" \
  "PENISLORA_22_i2v_LOW_e496.safetensors" \
  "PenInsert_high_noise.safetensors" \
  "PenInsert_low_noise.safetensors" \
  "wan2.2-i2v-high-breast-insertion-v1.0.safetensors" \
  "wan2.2-i2v-low-breast-insertion-v1.0.safetensors" \
  "wan2.2-i2v-high-pov-insertion-v1.0.safetensors" \
  "wan2.2-i2v-low-pov-insertion-v1.0.safetensors" \
  "pussyjob_v1.0_wan2.1_14b.safetensors" \
  "DR34MJOB_I2V_14b_HighNoise.safetensors" \
  "DR34MJOB_I2V_14b_LowNoise.safetensors" \
  "wan22-fullnelson-i2v-108epoc-high-k3nk.safetensors" \
  "wan22-fullnelson-i2v-368epoc-low-k3nk.safetensors" \
  "Wan2.2_dp_v2_HighNoise-000020.safetensors" \
  "Wan2.2_dp_v2_LowNoise-000018.safetensors" \
  "wan22-ultimatedeepthroat-i2v-102epoc-high-k3nk.safetensors" \
  "wan22-ultimatedeepthroat-I2V-101epoc-low-k3nk.safetensors" \
  "23High-Cumshot-Aesthetics.safetensors" \
  "56Low-Cumshot-Aesthetics.safetensors" \
  "wan22-mouthfull-140epoc-high-k3nk.safetensors" \
  "wan22-mouthfull-152epoc-low-k3nk.safetensors" \
  "sh00tz_HN_75.safetensors" \
  "sh00tz_LN_75.safetensors" \
  "X-ray_creampie_high.safetensors" \
  "X-ray_creampie_low.safetensors" \
  "maleejac_000004625_high_noise.safetensors" \
  "maleejac_000004625_low_noise.safetensors" \
  "CRM-FULL-EPOCH-80-HIGH.safetensors" \
  "CRM-FULL-EPOCH-80-LOW.safetensors" \
  "TWERKI2VHIGH.safetensors" \
  "TWERKI2VLOW.safetensors"; do
  download_if_missing "$LORA_DIR/$f" "$HF_BASE/$LORA_REPO/$f"
done

echo "Model check complete."
