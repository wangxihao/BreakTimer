#!/bin/zsh
# 构建 BreakTimer.app 应用包（含图标），产物在 build/BreakTimer.app
set -e
cd "$(dirname "$0")"

echo "==> swift build -c release"
swift build -c release

APP="build/BreakTimer.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/BreakTimer "$APP/Contents/MacOS/BreakTimer"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>BreakTimer</string>
    <key>CFBundleDisplayName</key>
    <string>BreakTimer</string>
    <key>CFBundleIdentifier</key>
    <string>com.breaktimer.app</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>BreakTimer</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "==> 生成图标"
ICONSET="/tmp/BreakTimer.iconset"
rm -rf "$ICONSET"
if swift scripts/gen_icon.swift "$ICONSET" >/dev/null 2>&1 && [ -f "$ICONSET/icon_512x512@2x.png" ]; then
    sips -z 512 512 "$ICONSET/icon_512x512@2x.png" --out "$ICONSET/icon_512x512.png" >/dev/null
    sips -z 256 256 "$ICONSET/icon_512x512@2x.png" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
    sips -z 256 256 "$ICONSET/icon_512x512.png"     --out "$ICONSET/icon_256x256.png"   >/dev/null
    sips -z 128 128 "$ICONSET/icon_512x512.png"     --out "$ICONSET/icon_128x128@2x.png" >/dev/null
    sips -z 128 128 "$ICONSET/icon_256x256.png"     --out "$ICONSET/icon_128x128.png"   >/dev/null
    sips -z 64 64   "$ICONSET/icon_128x128.png"     --out "$ICONSET/icon_64x64.png"     >/dev/null 2>&1 || true
    sips -z 32 32   "$ICONSET/icon_128x128.png"     --out "$ICONSET/icon_32x32@2x.png"  >/dev/null
    sips -z 32 32   "$ICONSET/icon_64x64.png"       --out "$ICONSET/icon_32x32.png"     >/dev/null 2>&1 || true
    sips -z 16 16   "$ICONSET/icon_32x32.png"       --out "$ICONSET/icon_16x16.png"     >/dev/null
    sips -z 16 16   "$ICONSET/icon_32x32.png"       --out "$ICONSET/icon_16x16@2x.png"  >/dev/null
    rm -f "$ICONSET/icon_64x64.png"
    if iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns" 2>/dev/null; then
        echo "    图标 OK"
    else
        echo "    iconutil 失败，跳过图标（不影响功能）"
    fi
else
    echo "    图标生成失败，跳过（不影响功能）"
fi

codesign --force -s - "$APP" 2>/dev/null || true

echo "==> 完成: $APP"
echo "    运行: open $APP"
