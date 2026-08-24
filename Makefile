.PHONY: build up down logs shell dev
build:  ; docker compose build
up:     ; docker compose up -d && echo "http://localhost:8501"
down:   ; docker compose down
logs:   ; docker compose logs -f agrio-vision
shell:  ; docker compose run --rm --entrypoint bash agrio-vision
dev:    ; .venv/bin/streamlit run app.py
