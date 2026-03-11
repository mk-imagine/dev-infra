# latex-init (TinyTeX Sidecar)

This image is part of the `dev-infra` project. Its purpose is to initialize a 
Docker named volume (`latex-shared`) with a TinyTeX installation.

## Usage

### 1. Initialize/Populate Volume
Run this once to populate the volume. It is idempotent; if the volume is already
populated, it will skip the copy.

```bash
docker build -t latex-init .
docker run --rm -v latex-shared:/opt/TinyTeX latex-init
```

### 2. Use in Dev Container
In your project's `devcontainer.json`:

```json
"mounts": [
    "source=latex-shared,target=/opt/TinyTeX,type=volume"
],
"remoteEnv": {
    "PATH": "/opt/TinyTeX/bin/current:${containerEnv:PATH}"
}
```

Ensure your Dockerfile creates a user with UID 1000:
```dockerfile
RUN useradd -m -u 1000 devuser
```

## Interface Contract
- **Mount Point**: `/opt/TinyTeX`
- **Ownership**: UID 1000 (`devuser`)
- **Binary Path**: `/opt/TinyTeX/bin/current` (architecture-agnostic symlink)
