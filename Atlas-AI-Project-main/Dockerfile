FROM python:3.11-slim

WORKDIR /app/Atlas-AI-Project-main

RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN mkdir -p data sessions logs && useradd -m -u 1000 appuser && chown -R appuser:appuser /app

EXPOSE 5000
USER appuser
CMD ["python", "app-lite.py"]
