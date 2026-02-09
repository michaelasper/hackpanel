#!/usr/bin/env bash
set -euo pipefail

# Simple SPM sanity check for local dev + CI parity.
# Usage: ./Scripts/spm_sanity_check.sh

echo "==> Swift version"
swift --version

echo "==> swift build"
swift build -v

echo "==> swift test"
swift test -v
