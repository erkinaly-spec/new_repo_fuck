#!/usr/bin/env bash
set -euo pipefail

log() { echo "[entrypoint] $*"; }

# 1) Ждём, пока примонтируется Storage
for i in {1..60}; do
  if [ -d /runpod-volume ]; then break; fi
  log "waiting for /runpod-volume mount ($i)"; sleep 1
done

WS="/runpod-volume/workspace/ComfyUI"
CN="$WS/custom_nodes"
MD1="$WS/models"                 # модели рядом с ComfyUI
MD2="/runpod-volume/models"      # модели отдельно в корне Storage

# 2) Создаём минимальные папки, чтобы extra-paths не падали
mkdir -p "$CN"
mkdir -p "$MD1" "$MD1"/{checkpoints,clip,clip_vision,configs,controlnet,embeddings,loras,unet,upscale_models,vae}
mkdir -p "$MD2" "$MD2"/{checkpoints,clip,clip_vision,configs,controlnet,embeddings,loras,unet,upscale_models,vae}

# 3) Ставим зависимости кастом-нодов
if [ -d "$CN" ]; then
  while IFS= read -r req; do
    log "Installing deps: ${req}"
    pip install -U -r "${req}" || log "(warn) deps install failed for ${req}"
  done < <(find "$CN" -maxdepth 2 -name requirements.txt -type f || true)
fi

# 4) Обновляем контейнерный ComfyUI (опционально, без падения)
if [ -d /comfyui/.git ]; then
  log "Updating container ComfyUI (git pull + requirements)"
  (cd /comfyui && git pull || true)
  pip install -U -r /comfyui/requirements.txt || log "(warn) comfy deps update failed"
fi

# 5) Готовим аргументы для ComfyUI
EXTRA_ARGS=(
  --extra-node-paths "$CN"
  --extra-model-paths "$MD1"
  --extra-model-paths "$MD2"
)
log "EXTRA_ARGS=${EXTRA_ARGS[*]}"

# 6) Запускаем: либо ваш ComfyUI из Storage, либо контейнерный
if [ -f "$WS/main.py" ]; then
  log "Launching YOUR ComfyUI from Storage: $WS"
  exec python3 "$WS/main.py" "${EXTRA_ARGS[@]}"
else
  log "Launching CONTAINER ComfyUI: /comfyui"
  exec python3 /comfyui/main.py "${EXTRA_ARGS[@]}"
fi
