# dev-infra

Shared development infrastructure published to GHCR. All images are multi-arch (arm64 + amd64) and built via GitHub Actions.

## Images

All images live under `ghcr.io/mk-imagine/`:

| Image | Description | Source |
|-------|-------------|--------|
| `latex-sidecar` | TinyTeX init container — populates `latex-shared` volume | `latex-sidecar/` |
| `r-stats-base` | R 4.5.2, pandoc 3.9, radian, core R packages | `r-stats-base/` |
| `r-stats-psy772` | Base + psy772-specific R packages | `r-stats-psy772/` |

### Image hierarchy

```
ghcr.io/mk-imagine/latex-sidecar:latest        ← standalone, populates latex-shared volume

ghcr.io/mk-imagine/r-stats-base:latest          ← R, pandoc, system deps, radian, core R packages
       ↓ FROM
ghcr.io/mk-imagine/r-stats-psy772:latest        ← base + psy772-specific packages
```

### Pulling images

All images are public. No authentication required:

```bash
docker pull ghcr.io/mk-imagine/r-stats-psy772:latest
```

### Tags

Each image is tagged with `latest` and the short commit SHA for rollback.

## CI/CD

GitHub Actions workflows in `.github/workflows/` build and push each image:

- **build-latex-sidecar.yml** — triggers on changes to `latex-sidecar/`
- **build-r-stats-base.yml** — triggers on changes to `r-stats-base/`; on completion, dispatches child image rebuilds
- **build-r-stats-psy772.yml** — triggers on changes to `r-stats-psy772/` or when base image rebuilds

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
    "image": "ghcr.io/mk-imagine/r-stats-psy772:latest",
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

1. Create `r-stats-<name>/` with `Dockerfile`, `r-packages.txt`, and `install.R`
2. The Dockerfile should `FROM ghcr.io/mk-imagine/r-stats-base:latest`
3. Add a workflow in `.github/workflows/build-r-stats-<name>.yml`
4. Add the workflow filename to the `trigger-children` matrix in `build-r-stats-base.yml`
