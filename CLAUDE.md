# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A collection of Docker images published to `ghcr.io/mk-imagine/` and built via GitHub Actions. All images are multi-arch (linux/amd64 + linux/arm64). Builds are triggered automatically on push to `main` when files under the relevant image directory change.

## Image hierarchy

```
latex-sidecar          ← standalone TinyTeX init container (populates latex-shared volume)

plantuml               ← standalone PlantUML CLI (JRE + Graphviz + pinned plantuml.jar)

r-stats-base           ← rocker/r-ver:4.5.2, pandoc, radian, core R packages
  └── r-stats-psy      ← base + psychology/stats R packages

py-sci-base            ← python:3.13-slim + numpy, pandas
  └── py-sci-jupyter   ← base + Jupyter infrastructure
        ├── py-manim   ← manim + cairo/pango/ffmpeg; LaTeX via latex-shared volume
        └── py-sci-jupyter-ml    ← jupyter + scikit-learn, optuna
              └── py-sci-jupyter-torch  ← ml + torch stack
                    └── py-sci-jupyter-torch-latex  ← LaTeX devcontainer metadata (no packages)
                          └── py-dsml   ← nbclient/nbformat, matplotlib/seaborn, dill, pytest
```

Child images are rebuilt automatically via `workflow_dispatch` cascade from the parent workflow's `trigger-children` job.

> **Known cascade gap:** `build-py-sci-jupyter-torch.yml` has no `trigger-children`
> job, so the chain breaks between `py-sci-jupyter-torch` and
> `py-sci-jupyter-torch-latex` — the LaTeX image and everything below it are not
> rebuilt when the torch image changes. Rebuild manually
> (`gh workflow run build-py-sci-jupyter-torch-latex.yml`, which now cascades to
> `py-dsml`) until the matrix is wired.

## Adding packages

**R images**: Add the package name (with inline comment) to `r-packages.txt` in the relevant image directory. The shared `install.R` script strips comments, skips blanks, and installs only missing packages via CRAN.

**Python images**: Add to `requirements.txt` in the relevant image directory.

**LaTeX (latex-sidecar)**: Add to `latex-sidecar/latex_packages.txt`. Comments and blank lines are stripped at build time by the Dockerfile before passing to `tlmgr install`.

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

## CI/CD

Workflows live in `.github/workflows/`. Each workflow:
- Triggers on `push` to `main` scoped to its image directory, plus `workflow_dispatch`
- Builds and pushes with tags `latest` and short SHA
- Uses GitHub Actions cache (`type=gha`) for layer caching

Manual rebuild: use the GitHub Actions UI "Run workflow" button, or `gh workflow run <name>.yml`.

## LaTeX sidecar design

TinyTeX is baked into the image at `/opt/staging/TinyTeX` during build. The entrypoint copies it to the mounted volume (`/opt/TinyTeX`) on first run, then creates a `bin/current` symlink pointing at the arch-specific binary dir. The copy is idempotent — skipped if `/opt/TinyTeX/bin` already exists.

Consuming devcontainers must mount `latex-shared` at `/opt/TinyTeX` and prepend `/opt/TinyTeX/bin/current` to `PATH`. Do not call `tinytex::install_tinytex()` or install system `texlive` in consuming images.

## New devcontainer checklist

When creating a new devcontainer that uses any image from this repo:

1. Add a `postCreateCommand` that curls the global gitignore from the gist and configures git to use it:
   ```
   "postCreateCommand": "mkdir -p ~/.config/git && curl -fsSL https://gist.githubusercontent.com/mk-imagine/cf71d040d468af090a7fe65568470a09/raw/ignore -o ~/.config/git/ignore && git config --global core.excludesfile ~/.config/git/ignore"
   ```
2. If the project uses LaTeX, add the `latex-shared` volume mount and `PATH` entry (see "LaTeX sidecar design" above).
3. Set `"remoteUser": "devuser"`.

## User inside containers

All images create `devuser` with UID 1000. R package installs run as `devuser`. Python base installs run as root (pip into system site-packages), then switch to `devuser` as the default user.
