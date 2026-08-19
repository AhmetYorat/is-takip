#!/usr/bin/env bash
# Release APK build edip Firebase App Distribution ile testerlara dağıtır.
#
# Kullanım:
#   ./scripts/distribute.sh ["release notes"] [tester-grubu]
#
# Varsayılan grup: testers

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

APP_ID="1:192386661850:android:107e0fcc9fbe19bfd2d4e3"
NOTES="${1:-$(date '+%Y-%m-%d %H:%M') build}"
GROUP="${2:-testers}"

echo "==> Release APK build ediliyor..."
flutter build apk --release

echo "==> Firebase App Distribution'a yükleniyor (grup: $GROUP)..."
firebase appdistribution:distribute \
  build/app/outputs/flutter-apk/app-release.apk \
  --app "$APP_ID" \
  --groups "$GROUP" \
  --release-notes "$NOTES"
