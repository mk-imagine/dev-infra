#!/bin/bash
set -e

STAGING_DIR="/opt/staging/TinyTeX"
TARGET_DIR="/opt/TinyTeX"

# Check if the volume is empty (or missing the bin directory)
if [ ! -d "$TARGET_DIR/bin" ]; then
    echo "Info: $TARGET_DIR is empty or unpopulated. Copying TinyTeX from staging..."
    
    # Copy all files from staging to the volume
    # Use -a to preserve permissions/links
    cp -a "$STAGING_DIR/." "$TARGET_DIR/"
    
    # Determine the architecture-specific binary directory
    # TinyTeX uses paths like bin/x86_64-linux or bin/aarch64-linux
    ARCH_DIR=$(ls "$TARGET_DIR/bin" | head -n 1)
    
    if [ -n "$ARCH_DIR" ]; then
        echo "Info: Creating 'current' symlink for architecture: $ARCH_DIR"
        ln -sfn "$ARCH_DIR" "$TARGET_DIR/bin/current"
    else
        echo "Error: Could not find architecture-specific binary directory in $TARGET_DIR/bin"
        exit 1
    fi

    echo "Success: TinyTeX volume populated."
else
    echo "Info: $TARGET_DIR is already populated. Skipping copy."
fi

# Ensure UID 1000 owns the volume content
echo "Info: Ensuring UID 1000 owns $TARGET_DIR"
chown -R 1000:1000 "$TARGET_DIR"
