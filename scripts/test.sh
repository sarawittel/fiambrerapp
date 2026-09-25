#!/bin/sh
# Ejecuta los tests de GK2Core. Funciona con Xcode o solo con las Command Line Tools.
set -e
cd "$(dirname "$0")/../Packages/GK2Core"
F=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
if xcodebuild -version >/dev/null 2>&1 || [ ! -d "$F" ]; then
  exec swift test "$@"
fi
L=/Library/Developer/CommandLineTools/Library/Developer/usr/lib
exec swift test -Xswiftc -F"$F" -Xlinker -F"$F" -Xlinker -rpath -Xlinker "$F" -Xlinker -rpath -Xlinker "$L" "$@"
