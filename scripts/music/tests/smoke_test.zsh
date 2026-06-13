#!/usr/bin/env zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h:h}"

echo "Checking script syntax..."

for script in "$SCRIPT_DIR"/*.zsh; do
    echo "  $(basename "$script")"
    zsh -n "$script"
done

echo ""
echo "PASS: syntax validation complete"
