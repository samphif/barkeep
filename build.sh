#!/usr/bin/env bash
set -euo pipefail

echo "Building Barkeep (Release)..."
xcodebuild \
  -project Barkeep.xcodeproj \
  -scheme Barkeep \
  -configuration Release \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

if [[ "${1:-}" == "--install" ]]; then
  echo "Installing Barkeep.app to /Applications..."
  rm -rf /Applications/Barkeep.app
  cp -R build/Build/Products/Release/Barkeep.app /Applications/
  echo "Installed /Applications/Barkeep.app"
else
  echo "Built build/Build/Products/Release/Barkeep.app (pass --install to copy to /Applications)"
fi
