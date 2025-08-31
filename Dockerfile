# Base: CUDA runtime with Python on Ubuntu 22.04
FROM nvidia/cuda:12.4.1-cudnn-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    PYTHONUNBUFFERED=1 \
    UV_ICU_DATA_DIR=/usr/share/icu

# System deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv python3-dev \
    git curl ca-certificates ffmpeg \
    build-essential pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user (optional but safer)
RUN useradd -m -u 1000 app && mkdir -p /workspace && chown -R app:app /workspace
USER app
WORKDIR /workspace

# Clone ComfyUI into /comfyui (container copy)
RUN git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git /comfyui

# Python deps: Torch + ComfyUI reqs (CUDA 12.4 wheels)
RUN python3 -m pip install --upgrade pip && \
    python3 -m pip install --extra-index-url https://download.pytorch.org/whl/cu124 \
        torch==2.5.1+cu124 torchvision==0.20.1+cu124 torchaudio==2.5.1+cu124 && \
    python3 -m pip install -r /comfyui/requirements.txt && \
    # Nice-to-have: ComfyUI-Manager (optional)
    python3 -m pip install git+https://github.com/ltdrdata/ComfyUI-Manager.git@v2.51.9

# Copy entrypoint
COPY --chown=app:app entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 8188
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=10 \
  CMD curl -fsS http://127.0.0.1:8188/ || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
