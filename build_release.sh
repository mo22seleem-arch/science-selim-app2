#!/usr/bin/env bash
# usage: SUPABASE_URL=... SUPABASE_ANON_KEY=... GCP_PROJECT_NUMBER=... ./build_release.sh
set -euo pipefail
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=GCP_PROJECT_NUMBER="${GCP_PROJECT_NUMBER:-}"
echo "AAB: build/app/outputs/bundle/release/app-release.aab   (keep build/symbols to de-obfuscate crash traces)"
