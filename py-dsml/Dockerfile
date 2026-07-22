# Data-science / curriculum-authoring image.
#
# Parent is py-sci-jupyter-torch-latex, so the LaTeX devcontainer.metadata
# LABEL (sidecar mount, PATH, VS Code extensions/settings) is inherited --
# curriculum sources render to PDF/Beamer as well as .ipynb.
#
# Adds the notebook-authoring and execution stack that the parent chain
# lacks: programmatic notebook execution (nbclient/nbformat), plotting
# (matplotlib/seaborn), extended serialization (dill), and pytest for
# in-notebook verification cells.

FROM ghcr.io/mk-imagine/py-sci-jupyter-torch-latex:latest

USER root
COPY requirements.txt /tmp/
RUN pip install --no-cache-dir -r /tmp/requirements.txt

USER devuser
