#!/bin/bash
set -euo pipefail

# Compila, instala en /Applications, registra el arranque al inicio y relanza.
# Uso:  ./install.sh            (compila + instala)
#       ./install.sh --no-build (solo instala lo ya compilado en build/)

ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/build/NotchUtils.app"
DST="/Applications/NotchUtils.app"

if [[ "${1:-}" != "--no-build" ]]; then
  echo "==> Compilando"
  "$ROOT/build.sh"
fi

if [[ ! -d "$SRC" ]]; then
  echo "ERROR: no existe $SRC (compila primero con ./build.sh)" >&2
  exit 1
fi

echo "==> Cerrando instancia en ejecución"
pkill -f NotchUtils 2>/dev/null || true
sleep 1

echo "==> Instalando en /Applications"
rm -rf "$DST"
cp -R "$SRC" "$DST"

echo "==> Registrando arranque al inicio de sesión"
EXISTS=$(osascript -e 'tell application "System Events" to get name of every login item' 2>/dev/null | tr ',' '\n' | grep -c 'NotchUtils' || true)
if [[ "$EXISTS" -ge 1 ]]; then
  echo "    ya estaba registrado"
else
  osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"$DST\", hidden:true}" >/dev/null
  echo "    añadido a elementos de inicio"
fi

echo "==> Lanzando"
open "$DST"

echo "==> Listo. NotchUtils instalada y en ejecución."
