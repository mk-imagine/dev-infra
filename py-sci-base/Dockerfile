FROM python:3.13-slim

# 1. Install system dependencies
COPY apt-packages.txt /tmp/
RUN apt-get update && apt-get install -y --no-install-recommends \
    $(cat /tmp/apt-packages.txt) \
    && rm -rf /var/lib/apt/lists/*

# 2. Create devuser with UID 1000
RUN useradd -m -u 1000 devuser

# 3. Install Python packages
COPY requirements.txt /tmp/
RUN pip install --no-cache-dir -r /tmp/requirements.txt

USER devuser
