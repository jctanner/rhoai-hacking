FROM registry.tannerjc.net/python:3.11-slim

USER root

# Set working directory
WORKDIR /app

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV FLASK_APP=app.py
ENV FLASK_ENV=production

# Install system dependencies
#RUN apt-get update && apt-get install -y --no-install-recommends \
#    curl \
#    && rm -rf /var/lib/apt/lists/*
RUN which curl || dnf -y install curl

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

USER 65532:65532

# Create non-root user
#RUN adduser --disabled-password --gecos '' appuser && \
#    chown -R 65532:65532 /app
#USER appuser

# Expose port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

USER 65532:65532

# Run with gunicorn
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--timeout", "120", "app:app"] 