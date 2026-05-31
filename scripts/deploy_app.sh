#!/bin/bash
set -e

cd "$(dirname "$0")/../flutter-app"

PLATFORM=${1:-android}

echo "=== Flutter 앱 빌드: $PLATFORM ==="

case $PLATFORM in
  android)
    flutter build apk --release
    echo ""
    echo "APK 위치: build/app/outputs/flutter-apk/app-release.apk"
    echo "Nginx 서버에 업로드:"
    echo "  docker cp build/app/outputs/flutter-apk/app-release.apk \\"
    echo "    gemma4-nginx-1:/var/www/download/agent-report.apk"
    ;;
  ios)
    flutter build ios --release --no-codesign
    echo "Xcode에서 Archive → Enterprise Distribution으로 서명하세요."
    ;;
  macos)
    flutter build macos --release
    echo "빌드 완료: build/macos/Build/Products/Release/"
    ;;
  windows)
    flutter build windows --release
    echo "빌드 완료: build/windows/x64/runner/Release/"
    ;;
  *)
    echo "사용법: $0 [android|ios|macos|windows]"
    exit 1
    ;;
esac
