# py-sci-psy

Psychology-research image: the numpy/pandas modelling stack plus plotly figures
that end up in LaTeX documents. `ghcr.io/mk-imagine/py-sci-psy`.

Consumer: `school/psy-research`.

## What's in it

Inherited from `py-sci-base`: Python 3.13, numpy, pandas, openpyxl, and
git/curl/build-essential/poppler-utils.

Added here:

| Package | Why |
|---------|-----|
| `plotly` | The plotting stack. Figures are explored interactively, then exported. |
| `kaleido` | Static export — PNG/PDF/SVG. Without it `write_image()` fails outright. |
| `chromium` (apt) | kaleido v1 renders through a real browser. |
| `fonts-dejavu`, `fontconfig` (apt) | chromium ships no fonts; without one, labels export as tofu. |

Plus the LaTeX `devcontainer.metadata` LABEL, so a consuming `devcontainer.json`
inherits the `latex-shared` sidecar mount, the `PATH` extension, and the LaTeX
VS Code extensions without repeating them.

## What's deliberately absent

**Jupyter.** The consuming work is script-driven. `ipython`, `ipywidgets`, and
`ipykernel` would be dead weight, which is why the parent is `py-sci-base`
rather than `py-sci-jupyter`.

**matplotlib and seaborn.** This image standardises on plotly. Two plotting
stacks in one image leaves a standing question of which one produced a given
figure, and `py-dsml` already exists for matplotlib-based work.

**torch.** Nothing in the consumer imports it. If that changes, add the CPU
wheels here rather than reparenting under `py-sci-jupyter-torch` — the Jupyter
layer is the unwanted part, not the torch layer.

**Any CUDA.** `py-torch-cuda` is amd64-only, because PyTorch publishes CUDA
wheels for x86_64 alone. A child of it could not run natively on an arm64
workstation and would carry multi-GB `nvidia-*` wheels for a workload whose
heaviest dependency is numpy.

## Notes

**Why Debian's chromium and not `plotly_get_chrome`.** The helper fetches
Chrome for Testing, which Google publishes for `linux64` only. There is no
arm64 build, so it cannot serve half of a multi-arch image. Debian ships
chromium for both architectures.

**Why no `chromium-sandbox`.** kaleido launches the browser with `--no-sandbox`
itself, and the setuid helper cannot acquire user namespaces in a default
container regardless — installing it changes nothing and adds a setuid binary.
Verified: export succeeds with and without it.

**`BROWSER_PATH` is set even though kaleido auto-discovers chromium.** Figure
output depends on which browser draws it. Pinning the path means a second
browser arriving in the image later cannot silently change how figures look.

## Verifying a build

```bash
docker build -t py-sci-psy:local py-sci-psy/
docker run --rm py-sci-psy:local python -c "
import plotly.graph_objects as go
go.Figure(go.Scatter(x=[0,1,2], y=[0,1,4])).write_image('/tmp/probe.png')
print('export OK')"
```

Export is the check that matters. `import plotly` succeeding proves nothing —
the browser dependency only bites at `write_image()`.
