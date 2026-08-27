# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A collection of Docker images published to `ghcr.io/mk-imagine/` and built via GitHub Actions. All images are multi-arch (linux/amd64 + linux/arm64). Builds are triggered automatically on push to `main` when files under the relevant image directory change.

There is no application code, no test suite, and no lint step. "Building" means building a Docker image; "testing" means running the built image and checking that the thing it exists to do actually works.

## Image hierarchy

```
latex-sidecar          ← standalone TinyTeX init container (populates latex-shared volume)
latex-base             ← standalone minimal Debian runtime that CONSUMES latex-shared

plantuml               ← standalone PlantUML CLI (JRE + Graphviz + pinned plantuml.jar)

py-torch-cuda          ← standalone GPU/PyTorch image (CUDA wheels, amd64-only)

r-stats-base           ← rocker/r-ver:4.5.2, pandoc, radian, core R packages
  └── r-stats-psy      ← base + psychology/stats R packages

py-sci-base            ← python:3.13-slim + numpy, pandas, openpyxl
  └── py-sci-jupyter   ← base + Jupyter infrastructure
        ├── py-manim   ← manim + cairo/pango/ffmpeg; LaTeX via latex-shared volume
        └── py-sci-jupyter-ml    ← jupyter + scikit-learn, optuna
              └── py-sci-jupyter-torch  ← ml + torch stack (CPU wheels)
                    └── py-sci-jupyter-torch-latex  ← LaTeX devcontainer metadata (no packages)
                          └── py-dsml   ← nbclient/nbformat, matplotlib/seaborn, dill, pytest, SVG rendering
```

`latex-sidecar` and `latex-base` are a pair, not a parent/child: the sidecar
*populates* the `latex-shared` volume, `latex-base` is the smallest image that
*runs* LaTeX from it. Neither has a `FROM` relationship to the other or to
anything else in the repo.

`py-torch-cuda` is a separate root rather than a child of `py-sci-base`, and
**it is the one image in this repo that breaks the shared conventions.** Three
deviations, all deliberate and all documented in its Dockerfile and workflow:

| Convention | `py-torch-cuda` | Why |
|---|---|---|
| `platforms: linux/arm64,linux/amd64` | **amd64 only** | PyTorch publishes CUDA wheels for x86_64 alone. Dropping arm64 also means it builds natively instead of under QEMU. |
| `cache-from`/`cache-to: type=gha` | **no GHA cache** | The image measures 8.07GB against GitHub's 10GB per-repo cache cap, which evicts LRU repo-wide — caching it would consume nearly the whole budget and evict every other image's cache. A cold build is 3m50s. |
| `--extra-index-url` (as in `py-sci-jupyter-torch`) | **`--index-url`** | The "extra" form leaves PyPI in the resolver path, which is how a GPU image silently gets CPU-only torch. Replacing the index makes a bad index fail loudly. |

Do not "fix" these to match the other images.

> **Ampere check when bumping the CUDA index.** CUDA 13 already dropped every
> architecture below Turing. After changing the `cu1xx` index in
> `requirements.txt`, confirm the target card's arch is still compiled in rather
> than assuming — `torch.cuda.get_arch_list()` must contain it (`sm_86` for the
> RTX 3070), or Ampere silently falls back to PTX JIT.

Child images are rebuilt automatically via `workflow_dispatch` cascade from the parent workflow's `trigger-children` job.

> **Known cascade gap:** `build-py-sci-jupyter-torch.yml` has no `trigger-children`
> job, so the chain breaks between `py-sci-jupyter-torch` and
> `py-sci-jupyter-torch-latex` — the LaTeX image and everything below it are not
> rebuilt when the torch image changes. Rebuild manually
> (`gh workflow run build-py-sci-jupyter-torch-latex.yml`, which does cascade to
> `py-dsml`) until the matrix is wired.

## Building and verifying locally

Every child Dockerfile pins `FROM ghcr.io/mk-imagine/<parent>:latest` — the
**published** parent, not your working tree. A plain `docker build` of a child
therefore silently tests your change against the last image CI published, not
against the parent you just edited.

To exercise a chain change locally, build each ancestor under the tag its child
expects, bottom-up:

```bash
docker build -t ghcr.io/mk-imagine/py-sci-base:latest      py-sci-base/
docker build -t ghcr.io/mk-imagine/py-sci-jupyter:latest   py-sci-jupyter/
docker build -t py-dsml:local                              py-dsml/
```

Local builds are single-arch (host only). CI builds both arches under QEMU, so an
arm64-only local pass does not prove the amd64 build. To check the other arch
before pushing:

```bash
docker buildx build --platform linux/amd64 -t py-dsml:amd64 py-dsml/   # --load is single-arch only
```

Smoke tests that match what each image is for:

```bash
# Python chain — imports are the whole contract
docker run --rm py-dsml:local python -c "import torch, nbclient, seaborn, imagehash; print('ok')"

# R chain — install.R already fails the build on a missing package; this checks load
docker run --rm ghcr.io/mk-imagine/r-stats-psy:latest Rscript -e 'library(psych); library(emmeans)'

# LaTeX sidecar — populate a scratch volume, then compile from it
docker run --rm -v latex-test:/opt/TinyTeX latex-sidecar:local
docker run --rm -v latex-test:/opt/TinyTeX latex-base:local latexmk -v
docker volume rm latex-test

# plantuml
docker run --rm -v "$PWD":/work plantuml:local plantuml -version
```

`docker run --rm <img> fc-match DejaVuSans` is the check for `py-dsml`/`py-manim`
font work — fontconfig substitutes silently, so a missing family surfaces as
subtly wrong glyph metrics rather than an error.

## Adding packages

**R images**: Add the package name (with inline comment) to `r-packages.txt` in the relevant image directory. The shared `install.R` script strips comments, skips blanks, and installs only missing packages via CRAN, then re-checks and `stop()`s on any that failed — so a bad package name fails the build rather than shipping a broken image.

**Python images**: Add to `requirements.txt` in the relevant image directory. `#` comments are supported (pip strips them); the existing files use them for per-package rationale.

**LaTeX (latex-sidecar)**: Add to `latex-sidecar/latex_packages.txt`. Comments, blank lines, and `.universal-darwin` entries are stripped at build time by the Dockerfile before passing to `tlmgr install`.

> Note: `tlmgr` lives inside TinyTeX, so it ships in the `latex-shared` volume
> rather than in any image. The sidecar runs `tlmgr update --self --all` in the
> same layer as the package install — keep them together, or a cached
> self-update will let a stale `tlmgr` fail every install. A long-lived volume
> can drift again; recover in place with `tlmgr update --self`.

**System deps**: Add to `apt-packages.txt` in the relevant image directory, one
package per line.

> Unlike `r-packages.txt` and `latex_packages.txt`, **`apt-packages.txt` does not
> support comments**. The Dockerfiles pass it straight through as
> `$(cat /tmp/apt-packages.txt)` with no stripping, so a `#` and its trailing text
> would be handed to `apt-get install` as package names and fail the build. Put
> per-package rationale in the Dockerfile instead.

> Two images opt out of the `apt-packages.txt` convention and inline their apt
> list in the Dockerfile: `latex-sidecar` and `latex-base`. Edit the `RUN
> apt-get install` block there; do not add an `apt-packages.txt` to those
> directories without also changing the Dockerfile to read it.

**Pinned versions** live in Dockerfile `ARG`/`FROM` lines, not in any list file:
`r-stats-base` (`rocker/r-ver:4.5.2`, `ARG PANDOC_VERSION`), `py-sci-base`
(`python:3.13-slim`), `plantuml` (`ARG PLANTUML_VERSION`). Bumping any of these
is a base-image change — expect the whole downstream chain to rebuild.

**After any package or image change, update `README.md`.** It carries the
per-image dependency tables *including inherited packages*, so adding one line to
a base image's `requirements.txt` means editing every descendant's "Inherited
from" list. Nothing generates or verifies those tables — they drift silently.

## Adding a new image

### R child image

1. Create `r-stats-<name>/` with `Dockerfile`, `r-packages.txt`, and `install.R`
2. `FROM ghcr.io/mk-imagine/r-stats-base:latest` in the Dockerfile
3. Copy `install.R` verbatim from an existing R child image (it's identical across all R images)
4. Add `.github/workflows/build-r-stats-<name>.yml` (copy an existing child workflow)
5. Add `build-r-stats-<name>.yml` to the `trigger-children` matrix in `build-r-stats-base.yml`

### Python child image

1. Create `py-sci-<name>/` with `Dockerfile` and `requirements.txt`
2. `FROM` the appropriate parent image
3. Add `.github/workflows/build-py-sci-<name>.yml`
4. Add the workflow filename to the `trigger-children` matrix in the parent's workflow

Step 4/5 is the one that gets forgotten — a new image builds fine on its own push
and then never rebuilds when its parent changes. Grep the parent's workflow for
`trigger-children` and confirm the new filename is in the matrix.

## CI/CD

Workflows live in `.github/workflows/`, one per image. All are structurally identical except `build-py-torch-cuda.yml` (see the table above). Each:
- Triggers on `push` to `main` scoped to its image directory, plus `workflow_dispatch`
- Builds `linux/arm64,linux/amd64` via QEMU and pushes with tags `latest` and short SHA
- Uses GitHub Actions cache (`type=gha`, `mode=max`) for layer caching

The only per-workflow variables are `env.IMAGE`, the `paths:` filter, the build
`context:`, and the presence/contents of `trigger-children`. When copying a
workflow for a new image, those four are what must change.

Manual rebuild: `gh workflow run build-<name>.yml`, or the GitHub Actions UI "Run workflow" button.

## LaTeX sidecar design

TinyTeX is baked into the image at `/opt/staging/TinyTeX` during build. The entrypoint copies it to the mounted volume (`/opt/TinyTeX`) on first run, then creates a `bin/current` symlink pointing at the arch-specific binary dir, and `chown`s the volume to UID 1000. The copy is idempotent — skipped if `/opt/TinyTeX/bin` already exists, which also means **a sidecar rebuild does not update an already-populated volume**; delete the volume and re-run to pick up new packages.

Consuming devcontainers must mount `latex-shared` at `/opt/TinyTeX` and prepend `/opt/TinyTeX/bin/current` to `PATH`. Do not call `tinytex::install_tinytex()` or install system `texlive` in consuming images.

## Devcontainer metadata

`py-sci-jupyter-torch-latex` and `py-manim` carry a `devcontainer.metadata`
LABEL so consuming `devcontainer.json` files inherit the volume mount, `PATH`,
and VS Code extensions without duplicating them per-repo. Those images also set
`ENV PATH` directly, because the LABEL only applies under a devcontainer — a
plain `docker run` would otherwise not find the TinyTeX binaries.

The LaTeX `remoteEnv` interpolates `${containerEnv:PATH}`, so it composes with a
descendant's `ENV PATH` rather than overwriting it (see `py-dsml`, which prepends
`~/.local/bin` this way).

### New devcontainer checklist

1. Add a `postCreateCommand` that curls the global gitignore from the gist and configures git to use it:
   ```
   "postCreateCommand": "mkdir -p ~/.config/git && curl -fsSL https://gist.githubusercontent.com/mk-imagine/cf71d040d468af090a7fe65568470a09/raw/ignore -o ~/.config/git/ignore && git config --global core.excludesfile ~/.config/git/ignore"
   ```
2. If the project uses LaTeX, add the `latex-shared` volume mount and `PATH` entry (see "LaTeX sidecar design" above).
3. Set `"remoteUser": "devuser"`.

## User inside containers

All images create `devuser` with UID 1000, matching the ownership the sidecar
sets on `latex-shared`. R package installs run as `devuser` (site-library is
chowned to it). Python installs run as root (pip into system site-packages),
then the image switches to `devuser` as the default user — so a `pip install`
inside a *running* container falls back to the user scheme and lands console
scripts in `~/.local/bin`.

## Repo notes

`.history/` directories are local VS Code Local History artifacts, ignored via
the user's global gitignore rather than this repo's. They are not source — do not
read them for current state or add them to the tree.

`.gitignore` here exists solely to negate a global `CLAUDE.md` ignore rule so
this file stays in version control.
