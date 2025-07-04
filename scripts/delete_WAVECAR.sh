#!/usr/bin/env bash
# delete_wavecar.sh
#
# Recursively locate every file named “WAVECAR” beneath the
# directory from which the script is launched, print its path,
# and remove it.

set -euo pipefail

echo "🔍 Searching for WAVECAR files under $(pwd)…"
# -print lists each match before removal so you see what’s happening
# -delete removes the file once it’s been printed
find . -type f -name 'WAVECAR' -print -delete

echo "✅ Done."

