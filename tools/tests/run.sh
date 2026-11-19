#!/bin/sh
# Compiles the pure model files plus tools/tests/main.swift and runs the checks.
# Usage (from the repo root): tools/tests/run.sh
set -e
OUT="${TMPDIR:-/tmp}/kathalu-tests"
xcrun swiftc -O -o "$OUT" \
  Kathalu/Models/Syllables.swift \
  Kathalu/Models/Akshara.swift \
  Kathalu/Models/VocabCard.swift \
  tools/tests/main.swift
"$OUT"
