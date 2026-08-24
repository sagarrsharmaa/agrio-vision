# ---------------------------------------------------------------------------
# AGRIO Vision — containerised YOLOv8 leaf-disease / trap-insect detector
# Base fork: muqadasejaz/Plant-Detection-using-YOLOv8 (MIT)
# CPU-only image: mirrors the AGRIO field node, which has no discrete GPU.
# ---------------------------------------------------------------------------
FROM python:3.11-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    MODEL_PATH=/app/models/best.pt \
    STREAMLIT_SERVER_PORT=8501 \
    STREAMLIT_SERVER_ADDRESS=0.0.0.0 \
    STREAMLIT_SERVER_HEADLESS=true \
    STREAMLIT_BROWSER_GATHER_USAGE_STATS=false

# OpenCV / ultralytics runtime libs (mirrors upstream packages.txt) + curl for healthcheck
RUN apt-get update && apt-get install -y --no-install-recommends \
        libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# CPU-only torch first, so ultralytics does not drag in the multi-GB CUDA wheels
RUN pip install --no-cache-dir \
        --index-url https://download.pytorch.org/whl/cpu \
        torch torchvision

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Non-root, and a writable Ultralytics config dir
RUN useradd -m -u 10001 agrio && mkdir -p /app/models /home/agrio/.config/Ultralytics \
    && chown -R agrio:agrio /app /home/agrio
ENV YOLO_CONFIG_DIR=/home/agrio/.config/Ultralytics \
    MPLCONFIGDIR=/tmp/mpl

COPY --chown=agrio:agrio app.py track.py ./
USER agrio

EXPOSE 8501
HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
    CMD curl -fsS http://localhost:8501/_stcore/health || exit 1

CMD ["streamlit", "run", "app.py"]
