# -------- Stage 1: Builder --------
FROM python:3.11-slim AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements first for caching
COPY requirements.txt .

RUN pip install --upgrade pip \
    && pip install --prefix=/install -r requirements.txt

# Copy application code
COPY src/ ./src
COPY run.py .

# -------- Stage 2: Runtime --------
FROM python:3.11-slim

# Create non-root user
RUN useradd -m appuser

WORKDIR /app

# Copy dependencies
COPY --from=builder /install /usr/local
COPY --from=builder /app /app

# Set ownership to non-root
RUN chown -R appuser:appuser /app
USER appuser

# Expose port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s \
    CMD curl -f http://localhost:5000/health || exit 1

# Environment argument to switch dev/prod
ARG ENV=production
ENV ENV=${ENV}

# Start command
CMD if [ "$ENV" = "development" ]; then \
        python -m flask --app src.app run --host=0.0.0.0 --port=5000 --reload; \
    else \
        python run.py; \
    fi