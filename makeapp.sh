#!/bin/zsh
# 构建 BreakTimer 可分发版本：
#   build/BreakTimer.app           通用二进制应用包（arm64 + x86_64，含图标）
#   build/BreakTimer-<ver>.zip     应用压缩包
#   build/BreakTimer-<ver>.dmg     拖拽安装镜像
set -e
cd "$(dirname "$0")"

VERSION="1.0.1"
APP="build/BreakTimer.app"

echo "==> swift build -c release（arm64 + x86_64 分架构构建，lipo 合并）"
swift build -c release --arch arm64
swift build -c release --arch x86_64

find_binary() {
    for p in ".build/$1/release/BreakTimer" ".build/release/BreakTimer"; do
        [ -f "$p" ] && { echo "$p"; return; }
    done
}
ARM_BIN="$(find_binary arm64-apple-macosx)"
X64_BIN="$(find_binary x86_64-apple-macosx)"
[ -n "$ARM_BIN" ] && [ -n "$X64_BIN" ] || { echo "分架构构建产物缺失"; exit 1; }

UNIVERSAL="build/.universal/BreakTimer"
mkdir -p "$(dirname "$UNIVERSAL")"
lipo -create -output "$UNIVERSAL" "$ARM_BIN" "$X64_BIN"
BIN="$UNIVERSAL"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/BreakTimer"

cat > "$APP/Contents/Info.plist" <<PLIST
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
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
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

# Ad-hoc 签名：本机可正常运行；发给他人时首次打开需「右键 → 打开」（未公证）
codesign --force -s - --deep "$APP" 2>/dev/null || true

echo "==> 打包 ZIP"
rm -f "build/BreakTimer-$VERSION.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "build/BreakTimer-$VERSION.zip"

echo "==> 打包 DMG"
STAGING="build/.dmg-staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
rm -f "build/BreakTimer-$VERSION.dmg"
hdiutil create -volname "BreakTimer $VERSION" -srcfolder "$STAGING" -ov -format UDZO \
    "build/BreakTimer-$VERSION.dmg" >/dev/null
rm -rf "$STAGING"

echo "==> 架构: $(lipo -info "$APP/Contents/MacOS/BreakTimer")"
echo "==> 完成，产物:"
ls -lh build/ | grep -E "BreakTimer" | awk '{print "    " $5 "  " $9}'
echo "    运行: open $APP"
