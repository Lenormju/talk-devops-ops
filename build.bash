#!/bin/bash
set -euo pipefail

mkdir -p public
uv tool run --offline 'mkslides' \
    build \
    --config-file 'mkslides_config.yml' \
    --site-dir 'public' \
    --strict

#xdg-open "file://$(pwd)/public/index.html"
