#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

rm -rf "$ROOT_DIR/build"
mkdir -p "$ROOT_DIR/build"
rm -rf "$ROOT_DIR/DewQRaft.xcodeproj/project.xcworkspace" \
  "$ROOT_DIR/DewQRaft.xcodeproj/xcuserdata"
