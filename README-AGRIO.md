# AGRIO Vision — containerised detection service

Prototype vision service for **AGRIO** (SIH 2026 · PS **SIH26180** · Qualcomm Inc. · Disaster Management · Hardware).

---

## Attribution

This repository is a **fork of [muqadasejaz/Plant-Detection-using-YOLOv8](https://github.com/muqadasejaz/Plant-Detection-using-YOLOv8)**, used under its **MIT licence** (retained verbatim in [LICENSE](LICENSE)).

We forked it as a **reference implementation to build on, not to submit as our own work**. Upstream is preserved as the `upstream` git remote, so every change we make stays visible as a diff:

```bash
git remote -v          # origin = our fork, upstream = original
git diff upstream/main # exactly what we changed
```

### Why this base, of everything on `github.com/topics/plant-disease-detection`

| Criterion | Why it mattered | This repo |
|---|---|---|
| Licence | We must be free to modify and publish | **MIT** (most alternatives had *no licence at all*) |
| Model family | AGRIO counts insects on a trap card — that needs **detection**, not whole-image classification | **YOLOv8** (Ultralytics), same family as our planned YOLOv8n |
| Export path | Must reach the Qualcomm Hexagon NPU via ONNX → AI Hub → INT8 | Ultralytics exports ONNX natively |
| Deployability | Needs to run as a service, not only a notebook | ships a Streamlit `app.py` |
| Maintenance | Not abandoned | last pushed 2026 |

The most-starred option (`manthan89-py/Plant-Disease-Detection`, 376★) was rejected: it carries **no licence**, and it is a whole-image classifier, so it cannot localise or count.

---

## What we changed

| Change | Reason |
|---|---|
| `app.py` — weights source now reads `MODEL_PATH` / `GDRIVE_FILE_ID` from the environment, falling back to `st.secrets` | Upstream hard-required a Streamlit secrets file, so the container could not boot. It now runs from a mounted `./models/best.pt`. |
| `Dockerfile` | CPU-only image (`--index-url .../whl/cpu`) — the AGRIO field node has no discrete GPU, so the container should mirror it. Non-root user, healthcheck, pinned OpenCV system libs from upstream `packages.txt`. |
| `docker-compose.yml`, `.env.example` | One-command run; weights mounted read-only rather than baked into the image. |
| `.dockerignore` | Keeps the 24 MB demo video and the 5.5 MB notebook out of the build context. |
| `.streamlit/config.toml` | Headless server defaults for container/CI use. |
| `Makefile` | `make build / up / logs / dev`. |

---

## Run it

```bash
cp .env.example .env            # optional
cp /path/to/best.pt models/     # trained YOLOv8 weights
docker compose up -d            # → http://localhost:8501
```

Local dev without Docker:

```bash
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
.venv/bin/streamlit run app.py
```

---

## Where this fits in the AGRIO architecture

This service is the **bench-side stand-in for the edge node's vision stage** — the box labelled *VISION MODELS* on slide 3 of the deck. It lets us iterate on detection quality on a laptop before the model is quantised and moved onto the Hexagon NPU.

```
 trap / canopy image
        │
        ▼
 YOLOv8 detection  ← this repo (float32, x86, Streamlit)
        │
        ▼
 ONNX export → Qualcomm AI Hub (AIMET INT8) → QAIRT / AI Engine Direct
        │
        ▼
 Hexagon NPU on QCS6490  ← the actual field node (~18 ms/frame target)
        │
        ▼
 count per species → compare against Economic Threshold Level (ETL)
        │
        ▼
 spray / don't spray  → voice alert + field beacon
```

### Planned retarget (not yet done)

Upstream detects **10 leaf-disease classes**. AGRIO needs the same detector head pointed at a second task:

1. **Insect counting** — retrain on **IP102** (102 pest classes) + our own sticky-trap imagery, so the output is *insects per species per night* rather than a disease label.
2. **ETL decision layer** — a thin wrapper turning that count into `spray` / `no spray`, which is where the 30–50% pesticide reduction comes from. Detection alone does not save anything.
3. **INT8 export** — `model.export(format="onnx")` → AI Hub quantize job → on-device latency measurement on real QCS6490 hardware.
4. **Field data** — upstream's accuracy is reported on curated imagery. We will report ours on field images only, per the lab-to-field discipline in the deck.

> Honest status: items 1–4 are **not implemented yet**. Today this fork is upstream's disease detector, containerised and made runnable without secrets.
