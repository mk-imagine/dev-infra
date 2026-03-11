# dev-infra: Shared Development Infrastructure

## Purpose

This repository manages shared tooling infrastructure for local development
environments across all projects. The goal is a single installation of each
major tool (LaTeX, etc.) that any dev container — regardless of its base image
(R, Python, Manim, Jupyter) — can mount and use without maintaining its own copy.

---

## Problem Statement

LaTeX installations (TinyTeX/TeX Live) are 500MB+. Duplicating them across
every project's Docker image wastes disk space, slows builds, and creates
divergent package states. The same tool is needed in fundamentally different
container stacks (R for coursework, Manim for animation, Jupyter for notebooks,
standalone for thesis writing). A shared base image cannot solve this because
these stacks have incompatible base images.

---

## Architecture: Named Volume + Init Container

```
┌─────────────────────────────────────────────────────┐
│                  Docker Named Volume                │
│                   latex-shared                      │
│            mounted at /opt/TinyTeX                  │
└────────┬──────────┬──────────┬──────────┬───────────┘
         │          │          │          │
    ┌────▼───┐ ┌────▼───┐ ┌───▼────┐ ┌───▼──────┐
    │ psy772 │ │ psy771 │ │  Manim │ │ Jupyter  │
    │   R    │ │   R    │ │ Python │ │  Python  │
    └────────┘ └────────┘ └────────┘ └──────────┘
```

### Components

**1. `latex-init` (this repo — `latex-sidecar/`)**
A dedicated Docker image whose sole purpose is to install TinyTeX into the
`latex-shared` named volume. Run once. Never runs as part of normal dev workflow.

**2. `latex-shared` (Docker named volume)**
A persistent named volume containing a single TinyTeX installation at
`/opt/TinyTeX`. Managed independently of any project container.

**3. Consuming devcontainers (all other projects)**
Mount `latex-shared` read-write at `/opt/TinyTeX`. Add TinyTeX binaries to
`PATH`. No LaTeX installation of their own.

---

## Init Container Design

### Build
TinyTeX is installed into the init image at build time at `~/.TinyTeX` (its
default location), baked in as a regular image layer. Volumes do not exist
during `docker build`, so this is purely a staging step inside the image.

### Runtime copy into the volume
When the init container runs, `latex-shared` is mounted at `/opt/TinyTeX`. The
entrypoint script copies TinyTeX from `~/.TinyTeX` (inside the image) into
`/opt/TinyTeX` (the volume). After this copy, `~/.TinyTeX` inside the init
image is irrelevant — it was only ever a staging area.

This two-phase approach avoids the "device or resource busy" error that occurs
when `tinytex::install_tinytex()` attempts to `unlink()` a volume mount point
— the exact bug encountered during psy772 devcontainer development.

### Runtime
At container start, the entrypoint script checks whether the volume is already
populated. If empty, it copies TinyTeX from the image into the volume. If
already populated, it exits immediately (idempotent).

### Populating the volume (one-time setup)
```bash
docker build -t latex-init ./latex-sidecar
docker run --rm -v latex-shared:/opt/TinyTeX latex-init
```

### Adding LaTeX packages globally
From any running devcontainer that has the volume mounted:
```bash
tlmgr install <package>
```
The package is immediately available to all other containers.

---

## Volume Lifecycle

| Operation | Command |
|-----------|---------|
| First-time setup | `docker run --rm -v latex-shared:/opt/TinyTeX latex-init` |
| Repopulate after accidental deletion | Same as above |
| Upgrade TinyTeX | Rebuild `latex-init`, delete volume, repopulate |
| Install a new package | `tlmgr install <pkg>` from any running container |
| List installed packages | `tlmgr list --only-installed` from any running container |
| Inspect volume | `docker volume inspect latex-shared` |

---

## Interface Contract

Every project that consumes the shared LaTeX volume **must** conform to the
following. This is non-negotiable for permissions and PATH to work correctly.

### 1. User: `devuser` at UID 1000

All consuming containers must create a user with UID exactly 1000:

```dockerfile
RUN useradd -m -u 1000 devuser
```

The volume files are owned by UID 1000. Containers using a different UID will
not have write access and cannot install new packages.

### 2. Volume mount in `devcontainer.json`

```json
"mounts": [
    "source=latex-shared,target=/opt/TinyTeX,type=volume"
]
```

The mount target **must** be `/opt/TinyTeX`. This is the canonical path.
Do not change it per-project.

### 3. PATH in `devcontainer.json`

```json
"remoteEnv": {
    "PATH": "/opt/TinyTeX/bin/current:${containerEnv:PATH}"
}
```

The `current` symlink is architecture-agnostic (created by the init container).
It resolves to the correct binary directory for the host architecture
(`aarch64-linux` on Apple Silicon, `x86_64-linux` on Intel/AMD).

### 4. No local LaTeX installation

Consuming containers **must not** call `tinytex::install_tinytex()` or install
TeX Live via apt. These would create a parallel, project-local LaTeX installation
that conflicts with the shared volume and wastes disk space.

If a `postCreateCommand` previously called `install_tinytex()`, remove it.

---

## New Project Integration Checklist

When setting up a new devcontainer that needs LaTeX:

- [ ] Ensure the `latex-shared` volume exists and is populated
      (`docker volume ls | grep latex-shared`)
- [ ] Add `useradd -m -u 1000 devuser` to the Dockerfile
- [ ] Add the volume mount to `devcontainer.json`
- [ ] Add the PATH entry to `devcontainer.json`
- [ ] Confirm no `tinytex::install_tinytex()` or `apt install texlive` calls exist
- [ ] Test: open a terminal in the container and run `pdflatex --version`

---

## Architecture Decisions

### Why `/opt/TinyTeX` and not `~/.TinyTeX`?

`~/.TinyTeX` is user-home-relative. Different containers may have different home
directories for `devuser` depending on their base image. `/opt/TinyTeX` is an
absolute, home-independent path consistent across all containers.

### Why an init container and not an "attach script"?

An attach script (checking at container startup whether LaTeX is installed and
installing if not) has two failure modes:

1. **Race condition**: Two containers starting simultaneously against an empty
   volume both attempt installation, corrupting the TinyTeX state.
2. **Heterogeneous dependencies**: Non-R containers would need R (or a separate
   shell-script-based TinyTeX installer) to run the attach script — coupling
   unrelated toolchains.

The init container runs once, is idempotent, and imposes no dependency on
consuming containers.

### Why a named volume and not a shared base image?

A shared base image (`FROM mark-latex-base`) only achieves deduplication within
a single language stack. R containers, Manim containers, and Jupyter containers
have incompatible base images. A named volume is the only mechanism that works
across all of them at runtime.

### Why not a full TeX Live installation instead of TinyTeX?

Full TeX Live is 4–8GB. TinyTeX installs on-demand via `tlmgr` and covers all
packages needed for academic PDF output. Package additions are recorded in the
shared volume, so the installation grows only as needed.
