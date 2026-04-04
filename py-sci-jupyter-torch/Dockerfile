FROM ghcr.io/mk-imagine/py-sci-jupyter-ml:latest

USER root
COPY requirements.txt /tmp/
RUN pip install --no-cache-dir -r /tmp/requirements.txt

USER devuser
