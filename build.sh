#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/build/NotchUtils.app"
MACOS="$APP/Contents/MacOS"
RES="$APP/Contents/Resources"

echo "==> Limpiando build anterior"
rm -rf "$APP"
mkdir -p "$MACOS" "$RES"

echo "==> Compilando"
swiftc -O \
  -o "$MACOS/NotchUtils" \
  "$ROOT"/Sources/*.swift \
  -framework AppKit -framework SwiftUI

echo "==> Copiando Info.plist"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

echo "==> Firmando (ad-hoc) con entitlements"
codesign --force --sign - \
  --entitlements "$ROOT/Resources/NotchUtils.entitlements" \
  "$APP"

echo "==> Listo: $APP"
echo "    Ejecuta:  open \"$APP\"    (o)    \"$MACOS/NotchUtils\" para ver logs"
