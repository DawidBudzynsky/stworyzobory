#!/bin/sh
# Pakuje grę do dist/stwory.love (archiwum zip z main.lua w korzeniu).
set -e
cd "$(dirname "$0")"
mkdir -p dist
rm -f dist/stwory.love
zip -q -r dist/stwory.love main.lua conf.lua src assets README.md docs -x "*.pyc"
echo "Gotowe: dist/stwory.love ($(du -h dist/stwory.love | cut -f1))"
