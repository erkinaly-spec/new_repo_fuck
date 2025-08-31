# =========================
# ComfyUI on CUDA 12.4 (Ubuntu 22.04)
# =========================
FROM nvidia/cuda:12.4.1-cudnn-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    PYTHONUNBUFFERED=1 \
    PIP_PREFER_BINARY=1

# --- System deps ---
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv python3-dev \
    git curl ca-certificates ffmpeg \
    build-essential pkg-config \
    libsndfile1 libsndfile1-dev gfortran \
 && rm -rf /var/lib/apt/lists/*

# --- Non-root user + workspace ---
RUN useradd -m -u 1000 app \
 && mkdir -p /workspace \
 && chown -R app:app /workspace

WORKDIR /workspace
USER app

# --- Clone ComfyUI ---
RUN git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git /workspace/ComfyUI

# --- Python venv ---
RUN python3 -m venv /workspace/.venv
ENV PATH="/workspace/.venv/bin:${PATH}"

# --- PyTorch CUDA 12.4 ---
RUN python -m pip install --upgrade pip \
 && python -m pip install --extra-index-url https://download.pytorch.org/whl/cu124 \
      torch==2.5.1+cu124 torchvision==0.20.1+cu124 torchaudio==2.5.1+cu124 \
 && rm -rf ~/.cache/pip

# --- Heavy deps (только бинарники) ---
RUN python -m pip install --only-binary=:all: scipy soundfile psutil \
 && rm -rf ~/.cache/pip

# --- ComfyUI requirements + Manager ---
RUN python -m pip install -r /workspace/ComfyUI/requirements.txt \
 && python -m pip install git+https://github.com/ltdrdata/ComfyUI-Manager.git@v2.51.9 \
 && rm -rf ~/.cache/pip

# --- Network / health ---
EXPOSE 8188
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=10 \
  CMD curl -fsS http://127.0.0.1:8188/ || exit 1

# --- Start ComfyUI ---
WORKDIR /workspace/ComfyUI
CMD ["bash", "-lc", "python main.py --listen 0.0.0.0 --port 8188"]
