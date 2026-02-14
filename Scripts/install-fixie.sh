#!/bin/zsh
set -euo pipefail

cd ~/Sources/swift-fixie/
swift build -c release

# warning: assumes macOS / Apple Silicon
mv .build/arm64-apple-macosx/release/fixie ~/.local/bin/fixie
