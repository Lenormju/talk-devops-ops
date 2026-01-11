#!/bin/bash
set -euo pipefail

mkdir -p public
uv tool run 'mkslides' \
    serve \
    --config-file 'mkslides_config.yml' \
    --strict \
    --open \
    'slides/slides.md'
