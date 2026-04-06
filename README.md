# dev-infra

Shared development infrastructure published to GHCR. All images are multi-arch (arm64 + amd64) and built via GitHub Actions.

## Images

All images live under `ghcr.io/mk-imagine/`:

| Image | Description | Source |
|-------|-------------|--------|
| [`latex-sidecar`](#latex-sidecar) | TinyTeX init container — populates `latex-shared` volume | `latex-sidecar/` |
| [`r-stats-base`](#r-stats-base) | R 4.5.2, pandoc 3.9, radian, core R packages | `r-stats-base/` |
| [`r-stats-psy`](#r-stats-psy) | Base + psychology statistics R packages | `r-stats-psy/` |
| [`py-sci-base`](#py-sci-base) | Python 3.13, numpy, pandas, system essentials | `py-sci-base/` |
| [`py-sci-jupyter`](#py-sci-jupyter) | Base + ipython, ipywidgets, ipykernel | `py-sci-jupyter/` |
| [`py-sci-jupyter-ml`](#py-sci-jupyter-ml) | Jupyter + scikit-learn, scikit-optimize, optuna | `py-sci-jupyter-ml/` |
| [`py-sci-jupyter-torch`](#py-sci-jupyter-torch) | ML + torch, torchvision, torchaudio | `py-sci-jupyter-torch/` |

### Image dependencies

Each image's full dependency list, including packages inherited from parent images. Inherited dependencies are marked with the source image.

#### `latex-sidecar`

> Standalone init container (Debian 12 slim). Populates the `latex-shared` volume with TinyTeX.

**System packages:** wget, perl, ca-certificates, xz-utils

**LaTeX packages (via tlmgr):**

| Category | Packages |
|----------|----------|
| TeX/LaTeX Core | tex, latex, latex-bin, plain, etex, kpathsea, tex-ini-files, latexconfig, texlive.infra, texlive-scripts, texlive-scripts-extra, metafont, mfware, knuth-lib, latexmk, tools |
| LaTeX3 | l3kernel, l3backend, l3packages |
| PDF/Output Drivers | pdftex, dvipdfmx, dvips, epstopdf, epstopdf-pkg, extractbb |
| Fonts | cm, ec, lm, lm-math, amsfonts, psnfss, doublestroke, inconsolata, helvetic, times, symbol, zapfding, fontspec, latex-fonts, glyphlist, modes |
| Math | amsmath, amscls, cancel, unicode-math, lualatex-math |
| Graphics | graphics, graphics-cfg, graphics-def, xcolor |
| Typesetting/Layout | geometry, booktabs, float, listings, fancyvrb, framed, setspace, mdwtools |
| Bibliography | bibtex, natbib |
| PDF/Hyperlinks | hyperref, bookmark, hycolor, pdfescape, gettitlestring, rerunfilecheck |
| Programming Utilities | etoolbox, etexcmds, ltxcmds, letltxmacro, iftex, infwarerr, filehook, kvoptions, kvsetkeys, kvdefinekeys, xkeyval, intcalc, bigintcalc, refcount, uniquecounter, stringenc, atbegshi, atveryend, auxhook, firstaid, ctablestack, bitset, pdftexcmds |
| Unicode/Language | babel, hyph-utf8, hyphen-base, dehyph, unicode-data, euenc, xunicode, tipa, selnolig |
| LuaTeX | luatex, luahbtex, luaotfload, lualibs, luatexbase, lua-uni-algos, lua-alt-getopt |
| XeTeX | xetex, xetexconfig |
| Misc | url |

---

#### `r-stats-base`

> Base image: `rocker/r-ver:4.5.2` (R 4.5.2). Includes Pandoc 3.9, radian console, and core R packages.

**System packages (apt):** git, tmux, wget, perl, curl, jq, htop, tree, python3-pip, libxml2-dev, libssl-dev, libcurl4-openssl-dev, zlib1g-dev, libfontconfig1-dev, libharfbuzz-dev, libfribidi-dev, libfreetype6-dev, libpng-dev, libtiff5-dev, libjpeg-dev, libxt6t64, cmake

**Tools:** Pandoc 3.9, radian (Python-based R console), APA CSL style

**R packages:**

| Category | Packages |
|----------|----------|
| Data wrangling | dplyr, tidyverse, readxl, reshape2 |
| Visualization | ggplot2, latex2exp |
| Reporting | rmarkdown, knitr, formatR |
| Machine learning | caret |
| IDE support | languageserver, httpgd |

---

#### `r-stats-psy`

> Parent: `r-stats-base`. Adds psychology and statistics R packages.
>
> **Volume dependency:** Consuming devcontainers should mount the `latex-shared` volume (from `latex-sidecar`) for LaTeX/PDF rendering.

**Inherited from `r-stats-base`:** all system packages, tools (Pandoc, radian), and R packages listed above.

**Additional R packages:**

| Category | Packages |
|----------|----------|
| Core psychology statistics | psych, emmeans, car, effectsize |
| Specialized analyses | heplots, ppcor, lm.beta, agricolae, mvoutlier, interactions |

---

#### `py-sci-base`

> Base image: `python:3.13-slim`. Core scientific Python stack.

**System packages (apt):** git, curl, build-essential

**Python packages:** numpy, pandas

---

#### `py-sci-jupyter`

> Parent: `py-sci-base`. Adds Jupyter notebook infrastructure.

**Inherited from `py-sci-base`:** all system packages and Python packages (numpy, pandas).

**Additional Python packages:** ipython, ipywidgets, ipykernel

---

#### `py-sci-jupyter-ml`

> Parent: `py-sci-jupyter`. Adds machine learning libraries.

**Inherited from `py-sci-base`:** git, curl, build-essential, numpy, pandas

**Inherited from `py-sci-jupyter`:** ipython, ipywidgets, ipykernel

**Additional Python packages:** scikit-learn, scikit-optimize, optuna

---

#### `py-sci-jupyter-torch`

> Parent: `py-sci-jupyter-ml`. Adds PyTorch stack (CPU wheels).

**Inherited from `py-sci-base`:** git, curl, build-essential, numpy, pandas

**Inherited from `py-sci-jupyter`:** ipython, ipywidgets, ipykernel

**Inherited from `py-sci-jupyter-ml`:** scikit-learn, scikit-optimize, optuna

**Additional Python packages:** torch, torchvision, torchaudio

---

### Pulling images

All images are public. No authentication required:

```bash
docker pull ghcr.io/mk-imagine/r-stats-psy:latest
```

### Tags

Each image is tagged with `latest` and the short commit SHA for rollback.

## CI/CD

GitHub Actions workflows in `.github/workflows/` build and push each image:

- **build-latex-sidecar.yml** — triggers on changes to `latex-sidecar/`
- **build-r-stats-base.yml** — triggers on changes to `r-stats-base/`; on completion, dispatches child image rebuilds
- **build-r-stats-psy.yml** — triggers on changes to `r-stats-psy/` or when base rebuilds
- **build-py-sci-base.yml** — triggers on changes to `py-sci-base/`; cascades to jupyter
- **build-py-sci-jupyter.yml** — triggers on changes to `py-sci-jupyter/` or when base rebuilds; cascades to jupyter-ml
- **build-py-sci-jupyter-ml.yml** — triggers on changes to `py-sci-jupyter-ml/` or when jupyter rebuilds; cascades to jupyter-torch
- **build-py-sci-jupyter-torch.yml** — triggers on changes to `py-sci-jupyter-torch/` or when jupyter-ml rebuilds

All workflows also support `workflow_dispatch` for manual rebuilds.

## LaTeX Sidecar

LaTeX installations (TinyTeX/TeX Live) are 500MB+. Instead of duplicating them in every image, a sidecar init container populates a shared Docker named volume.

```
                    Docker Named Volume: latex-shared
                         mounted at /opt/TinyTeX
                ┌──────────┬──────────┬──────────┐
           ┌────▼───┐ ┌────▼───┐ ┌───▼────┐ ┌───▼──────┐
           │ psy772 │ │ psy771 │ │  Manim │ │ Jupyter  │
           │   R    │ │   R    │ │ Python │ │  Python  │
           └────────┘ └────────┘ └────────┘ └──────────┘
```

### One-time setup (local)

```bash
docker pull ghcr.io/mk-imagine/latex-sidecar:latest
docker run --rm -v latex-shared:/opt/TinyTeX ghcr.io/mk-imagine/latex-sidecar:latest
```

The init container is idempotent — safe to re-run if the volume is already populated.

### Volume lifecycle

| Operation | Command |
|-----------|---------|
| First-time setup | `docker run --rm -v latex-shared:/opt/TinyTeX ghcr.io/mk-imagine/latex-sidecar:latest` |
| Repopulate after deletion | Same as above |
| Upgrade TinyTeX | Pull latest sidecar, delete volume, repopulate |
| Install a package | `tlmgr install <pkg>` from any running container |
| List installed packages | `tlmgr list --only-installed` |
| Inspect volume | `docker volume inspect latex-shared` |

## Interface contract for consuming devcontainers

Projects using these images need the following in `devcontainer.json`:

```json
{
    "image": "ghcr.io/mk-imagine/r-stats-psy:latest",
    "mounts": [
        "source=latex-shared,target=/opt/TinyTeX,type=volume"
    ],
    "remoteEnv": {
        "PATH": "/opt/TinyTeX/bin/current:${containerEnv:PATH}"
    },
    "remoteUser": "devuser"
}
```

The `current` symlink is architecture-agnostic — resolves to the correct binary directory for the host architecture.

**Do not** call `tinytex::install_tinytex()` or `apt install texlive` in consuming containers.

## Adding a new child image

### R ecosystem

1. Create `r-stats-<name>/` with `Dockerfile`, `r-packages.txt`, and `install.R`
2. The Dockerfile should `FROM ghcr.io/mk-imagine/r-stats-base:latest`
3. Add a workflow in `.github/workflows/build-r-stats-<name>.yml`
4. Add the workflow filename to the `trigger-children` matrix in `build-r-stats-base.yml`

### Python ecosystem

1. Create `py-sci-<name>/` with `Dockerfile` and `requirements.txt`
2. The Dockerfile should `FROM` the appropriate parent image (e.g., `ghcr.io/mk-imagine/py-sci-base:latest` or `py-sci-jupyter:latest`)
3. Add a workflow in `.github/workflows/build-py-sci-<name>.yml`
4. Add the workflow filename to the `trigger-children` matrix in the parent's workflow
