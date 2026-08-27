# dev-infra

Shared development infrastructure published to GHCR. All images are multi-arch (arm64 + amd64) and built via GitHub Actions.

## Images

All images live under `ghcr.io/mk-imagine/`:

| Image | Description | Source |
|-------|-------------|--------|
| [`latex-sidecar`](#latex-sidecar) | TinyTeX init container — populates `latex-shared` volume | `latex-sidecar/` |
| [`latex-base`](#latex-base) | Minimal Debian runtime for building LaTeX from `latex-shared` | `latex-base/` |
| [`r-stats-base`](#r-stats-base) | R 4.5.2, pandoc 3.9, radian, core R packages | `r-stats-base/` |
| [`r-stats-psy`](#r-stats-psy) | Base + psychology statistics R packages | `r-stats-psy/` |
| [`py-sci-base`](#py-sci-base) | Python 3.13, numpy, pandas, openpyxl, system essentials | `py-sci-base/` |
| [`py-sci-jupyter`](#py-sci-jupyter) | Base + ipython, ipywidgets, ipykernel | `py-sci-jupyter/` |
| [`py-manim`](#py-manim) | Jupyter + manim, cairo/pango/ffmpeg; LaTeX via `latex-shared` | `py-manim/` |
| [`py-sci-jupyter-ml`](#py-sci-jupyter-ml) | Jupyter + scikit-learn, scikit-optimize, optuna | `py-sci-jupyter-ml/` |
| [`py-sci-jupyter-torch`](#py-sci-jupyter-torch) | ML + torch, torchvision, torchaudio | `py-sci-jupyter-torch/` |
| [`py-sci-jupyter-torch-latex`](#py-sci-jupyter-torch-latex) | Torch + LaTeX devcontainer metadata (no packages) | `py-sci-jupyter-torch-latex/` |
| [`py-dsml`](#py-dsml) | Torch-LaTeX + nbclient/nbformat, matplotlib/seaborn, dill, pytest, SVG rendering | `py-dsml/` |
| [`plantuml`](#plantuml) | PlantUML CLI — JRE + Graphviz + pinned `plantuml.jar` | `plantuml/` |

### Image dependencies

Each image's full dependency list, including packages inherited from parent images. Inherited dependencies are marked with the source image.

#### `latex-sidecar`

> Standalone init container (Debian 12 slim). Populates the `latex-shared` volume with TinyTeX.

**System packages:** wget, perl, ca-certificates, xz-utils, gnupg, libfontconfig1, fontconfig

**LaTeX packages (via tlmgr):**

| Category | Packages |
|----------|----------|
| TeX/LaTeX Core | tex, latex, latex-bin, plain, etex, kpathsea, tex-ini-files, latexconfig, texlive.infra, texlive-scripts, texlive-scripts-extra, metafont, mfware, knuth-lib, latexmk, tools |
| LaTeX3 | l3kernel, l3backend, l3packages |
| PDF/Output Drivers | pdftex, dvipdfmx, dvips, epstopdf, epstopdf-pkg, extractbb |
| Fonts | cm, ec, lm, lm-math, amsfonts, psnfss, doublestroke, inconsolata, helvetic, times, symbol, zapfding, fontspec, latex-fonts, glyphlist, modes |
| Math | amsmath, amscls, cancel, unicode-math, lualatex-math |
| Graphics | graphics, graphics-cfg, graphics-def, xcolor |
| Typesetting/Layout | geometry, booktabs, float, listings, fancyvrb, framed, setspace, mdwtools, enumitem, textpos |
| Bibliography | bibtex, natbib |
| PDF/Hyperlinks | hyperref, bookmark, hycolor, pdfescape, gettitlestring, rerunfilecheck |
| Programming Utilities | etoolbox, etexcmds, ltxcmds, letltxmacro, iftex, infwarerr, filehook, kvoptions, kvsetkeys, kvdefinekeys, xkeyval, intcalc, bigintcalc, refcount, uniquecounter, stringenc, atbegshi, atveryend, auxhook, firstaid, ctablestack, bitset, pdftexcmds |
| Unicode/Language | babel, babel-english, hyph-utf8, hyphen-base, dehyph, unicode-data, euenc, xunicode, tipa, selnolig |
| LuaTeX | luatex, luahbtex, luaotfload, lualibs, luatexbase, lua-uni-algos, lua-alt-getopt |
| XeTeX | xetex, xetexconfig |
| Presentations | beamer, pgf, translator |
| Manim (`py-manim`) | standalone, preview, dvisvgm |
| Misc | url, lipsum |

---

#### `latex-base`

> Standalone runtime image (Debian 12 slim). Minimal companion to `latex-sidecar`: the sidecar **populates** the `latex-shared` volume; `latex-base` is the smallest base that **builds** LaTeX from it. Mount `latex-shared` at `/opt/TinyTeX` — `PATH` already points at `/opt/TinyTeX/bin/current`. Includes a `devuser` (UID 1000) matching the volume's ownership.

**System packages (apt):** perl, libfontconfig1, fontconfig, gnupg, wget, ca-certificates, git, python3

| Package | Why it's needed |
|---------|-----------------|
| perl | `latexmk` is a Perl script |
| libfontconfig1 | XeLaTeX/LuaLaTeX fail to start without it (fontspec / OpenType) |
| fontconfig | `fc-cache` for fonts installed into the volume |
| gnupg | `tlmgr` verified downloads |
| wget, ca-certificates | `tlmgr` package downloads over HTTPS |
| git | devcontainer / source hygiene |
| python3 | utility scripts (e.g. aux-file cleanup) |

> **`tlmgr` lives in the volume, not in this image.** It ships inside TinyTeX, so
> its version is whatever `latex-sidecar` baked in when the volume was first
> populated — nothing in `latex-base` can update it. Because the tlnet repo keeps
> moving while a populated volume does not, a volume that drifts far enough will
> fail every on-demand install with `tlmgr itself needs to be updated ...
> Terminating`. The sidecar runs `tlmgr update --self --all` at build time, so
> freshly populated volumes are current. Recover a drifted volume in place with
> `tlmgr update --self`, or delete it and re-run the sidecar to repopulate.

> **No baked TeX.** TinyTeX lives entirely in the `latex-shared` volume — do not `apt install texlive` here. Projects needing packages beyond the sidecar's list install them on demand with `tlmgr install <pkg>` (into the mounted volume).

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

**System packages (apt):** git, curl, build-essential, poppler-utils

**Python packages:** numpy, pandas, openpyxl

---

#### `py-sci-jupyter`

> Parent: `py-sci-base`. Adds Jupyter notebook infrastructure.

**Inherited from `py-sci-base`:** all system packages and Python packages (numpy, pandas, openpyxl).

**Additional Python packages:** ipython, ipywidgets, ipykernel

---

#### `py-manim`

> Parent: `py-sci-jupyter`. Manim animation rendering. Sits directly on the Jupyter layer rather than deeper in the chain so the `%%manim` cell magic can render a scene and embed the video inline, without pulling in the multi-GB torch stack it would never import.

**Inherited from `py-sci-base`:** git, curl, build-essential, poppler-utils, numpy, pandas, openpyxl

**Inherited from `py-sci-jupyter`:** ipython, ipywidgets, ipykernel

**Additional system packages:** ffmpeg, libcairo2-dev, libpango1.0-dev, pkg-config

**Additional Python packages:** manim (pulls scipy, pycairo, manimpango, moderngl, networkx, pillow, rich, svgelements, skia-pathops, av)

**Image metadata:** `latex-shared` volume at `/opt/TinyTeX`; `/opt/TinyTeX/bin/current` prepended to `PATH`; Python and Jupyter extensions. The LaTeX Workshop extensions carried by `py-sci-jupyter-torch-latex` are omitted — manim invokes `latex` internally, so it needs the binaries but not a `.tex` editing IDE.

**Requires the `latex-shared` volume** for `Tex`/`MathTex`. The pipeline is `latex` → `.dvi` → `dvisvgm` → SVG, which depends on `standalone`, `dvisvgm` and `babel-english` in `latex-sidecar`. Scenes using only geometry render without the volume mounted.

---

#### `py-sci-jupyter-ml`

> Parent: `py-sci-jupyter`. Adds machine learning libraries.

**Inherited from `py-sci-base`:** git, curl, build-essential, poppler-utils, numpy, pandas, openpyxl

**Inherited from `py-sci-jupyter`:** ipython, ipywidgets, ipykernel

**Additional Python packages:** scikit-learn, scikit-optimize, optuna

---

#### `py-sci-jupyter-torch`

> Parent: `py-sci-jupyter-ml`. Adds PyTorch stack (CPU wheels).

**Inherited from `py-sci-base`:** git, curl, build-essential, poppler-utils, numpy, pandas, openpyxl

**Inherited from `py-sci-jupyter`:** ipython, ipywidgets, ipykernel

**Inherited from `py-sci-jupyter-ml`:** scikit-learn, scikit-optimize, optuna

**Additional Python packages:** torch, torchvision, torchaudio

---

#### `py-sci-jupyter-torch-latex`

> Parent: `py-sci-jupyter-torch`. Adds no packages — bakes LaTeX devcontainer configuration into a `devcontainer.metadata` LABEL, inherited by any consuming `devcontainer.json`. Pairs with the `latex-sidecar` volume.

**Inherited:** the full `py-sci-*` chain (see `py-sci-jupyter-torch`)

**Additional Python packages:** none

**Image metadata:** `latex-shared` volume at `/opt/TinyTeX`; `/opt/TinyTeX/bin/current` prepended to `PATH`; LaTeX Workshop extensions and settings

---

#### `py-dsml`

> Parent: `py-sci-jupyter-torch-latex`. Completes the notebook-authoring and headless-execution stack — generate, execute, and verify notebooks without installing anything at container start.

**Inherited from `py-sci-base`:** git, curl, build-essential, poppler-utils, numpy, pandas, openpyxl

**Inherited from `py-sci-jupyter`:** ipython, ipywidgets, ipykernel

**Inherited from `py-sci-jupyter-ml`:** scikit-learn, scikit-optimize, optuna

**Inherited from `py-sci-jupyter-torch`:** torch, torchvision, torchaudio

**Inherited from `py-sci-jupyter-torch-latex`:** the LaTeX `devcontainer.metadata` LABEL

**Additional system packages:** fonts-dejavu, fontconfig, librsvg2-bin

**Additional Python packages:** nbclient, nbformat, matplotlib, seaborn, dill, pytest, pillow, imagehash

**Image metadata:** `/home/devuser/.local/bin` prepended to `PATH` via `ENV`, so console scripts from a `pip install` run inside a live container (which falls back to the user scheme under the non-root default user) are found. It composes with rather than replaces the inherited LaTeX `remoteEnv`, which interpolates `${containerEnv:PATH}`.

**Rendering:** SVG figures are rasterized with `rsvg-convert` (the only SVG renderer in the image, deliberately) against DejaVu Sans. See [`py-dsml/README.md`](py-dsml/README.md) for why `cairosvg` and PyMuPDF were measured and rejected, and for the ink-bounds measurement recipe.

**Not included by design:** project-local editable packages, and course/project-specific Jupyter kernelspecs — this image ships the stock `python3` kernel only. See `py-dsml/README.md`.

---

#### `plantuml`

> Standalone CLI image (Debian 12 slim) for rendering PlantUML diagrams. No parent.

**System packages (apt):** default-jre-headless, graphviz, fonts-dejavu, ca-certificates, curl

**Tools:** `plantuml` wrapper on `PATH` invoking the pinned `plantuml.jar` under `/opt/plantuml/`. Version pinned via `ARG PLANTUML_VERSION` in the Dockerfile — bump to pull a newer release from [plantuml/plantuml releases](https://github.com/plantuml/plantuml/releases).

**Usage:**

```bash
# Render a .puml file from the current directory
docker run --rm -v "$PWD":/work ghcr.io/mk-imagine/plantuml:latest plantuml diagram.puml

# Interactive shell
docker run --rm -it -v "$PWD":/work ghcr.io/mk-imagine/plantuml:latest bash
```

**Local build (while GH Actions is still publishing):**

```bash
docker build -t plantuml:local plantuml/
docker run --rm -v "$PWD":/work plantuml:local plantuml diagram.puml
```

Swap `plantuml:local` for `ghcr.io/mk-imagine/plantuml:latest` once the workflow finishes.

---

### Pulling images

All images are public. No authentication required:

```bash
docker pull ghcr.io/mk-imagine/r-stats-psy:latest
```

### Tags

Each image is tagged with `latest` and the short commit SHA for rollback.

## CI/CD

GitHub Actions workflows in `.github/workflows/`, one per image, build and push
`linux/arm64,linux/amd64` under QEMU. Each triggers on a push to `main` touching
its own directory, and a parent's `trigger-children` job dispatches its children
on completion:

| Workflow | Path trigger | Cascades to |
|----------|--------------|-------------|
| `build-latex-sidecar.yml` | `latex-sidecar/` | — (standalone) |
| `build-latex-base.yml` | `latex-base/` | — (standalone) |
| `build-plantuml.yml` | `plantuml/` | — (standalone) |
| `build-r-stats-base.yml` | `r-stats-base/` | `build-r-stats-psy.yml` |
| `build-r-stats-psy.yml` | `r-stats-psy/` | — |
| `build-py-sci-base.yml` | `py-sci-base/` | `build-py-sci-jupyter.yml` |
| `build-py-sci-jupyter.yml` | `py-sci-jupyter/` | `build-py-sci-jupyter-ml.yml`, `build-py-manim.yml` |
| `build-py-manim.yml` | `py-manim/` | — |
| `build-py-sci-jupyter-ml.yml` | `py-sci-jupyter-ml/` | `build-py-sci-jupyter-torch.yml` |
| `build-py-sci-jupyter-torch.yml` | `py-sci-jupyter-torch/` | **— (gap, see below)** |
| `build-py-sci-jupyter-torch-latex.yml` | `py-sci-jupyter-torch-latex/` | `build-py-dsml.yml` |
| `build-py-dsml.yml` | `py-dsml/` | — |

> **Known cascade gap.** `build-py-sci-jupyter-torch.yml` has no
> `trigger-children` job, so the chain breaks between `py-sci-jupyter-torch` and
> `py-sci-jupyter-torch-latex`: the LaTeX image and `py-dsml` below it are *not*
> rebuilt when the torch image changes. Until the matrix is wired, rebuild by
> hand with `gh workflow run build-py-sci-jupyter-torch-latex.yml`, which does
> cascade on to `py-dsml`.

All workflows also support `workflow_dispatch` for manual rebuilds
(`gh workflow run <name>.yml`, or the Actions UI "Run workflow" button).

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

### Global gitignore

To share a global gitignore across all devcontainers (including remote/Codespaces environments), host the gitignore file at a stable URL (e.g., a GitHub Gist) and add a `postCreateCommand` that fetches it:

```json
{
    "postCreateCommand": "mkdir -p ~/.config/git && curl -fsSL <GITIGNORE_RAW_URL> -o ~/.config/git/ignore && git config --global core.excludesfile ~/.config/git/ignore"
}
```

This approach is portable — it works on any host without requiring a local `~/.config/git/ignore` file.

## Building locally

Every child Dockerfile pins `FROM ghcr.io/mk-imagine/<parent>:latest` — the
**published** parent, not the working tree. A plain `docker build` of a child
therefore tests the change against the last image CI published, not against a
parent edited in the same commit. To exercise a chain change locally, build each
ancestor under the tag its child expects, bottom-up:

```bash
docker build -t ghcr.io/mk-imagine/py-sci-base:latest    py-sci-base/
docker build -t ghcr.io/mk-imagine/py-sci-jupyter:latest py-sci-jupyter/
docker build -t py-dsml:local                            py-dsml/
```

Local builds are single-arch (host only); CI builds both arches under QEMU, so a
local pass on one architecture does not prove the other. Check the other arch
with `docker buildx build --platform linux/amd64 …` before pushing.

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

Step 4 is the one that gets missed: a new image builds fine on its own push and
then silently never rebuilds when its parent changes. Confirm the new filename
appears in the parent workflow's matrix, and add a row to the CI/CD table above.

Any package or image change also means updating the **Image dependencies**
tables above — they list inherited packages per image and nothing generates or
verifies them, so they drift silently.
