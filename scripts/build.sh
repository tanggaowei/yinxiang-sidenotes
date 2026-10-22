#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$( dirname "$SCRIPT_DIR" )"
DIST_DIR="$PROJECT_DIR/dist"
APP_NAME="YinxiangSideNotes"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"

echo "🚀 开始构建 macOS 原生轻量版印象笔记 SideNotes..."

# 1. 清理并准备输出目录
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources/worker"

# 2. 收集 Swift 源文件
SWIFT_FILES=$(find "$PROJECT_DIR/src" -name "*.swift")
echo "📦 正在编译 Swift 源代码..."
echo "$SWIFT_FILES"

# 3. 编译 Swift 可执行文件
SDK_PATH=$(xcrun --show-sdk-path 2>/dev/null || echo "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk")
swiftc \
    -O \
    -target arm64-apple-macos14.0 \
    -sdk "$SDK_PATH" \
    -parse-as-library \
    -framework Cocoa \
    -framework SwiftUI \
    -framework Carbon \
    -framework Combine \
    $SWIFT_FILES \
    -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

echo "✅ 编译成功！"

# 4. 生成 Info.plist
cat << 'EOF' > "$APP_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>YinxiangSideNotes</string>
    <key>CFBundleIdentifier</key>
    <string>com.yinxiang.sidenotes</string>
    <key>CFBundleName</key>
    <string>印象笔记 SideNotes</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

# 5. 复制同步核心组件与依赖
echo "📦 打包同步轻量核心模块..."
cp -R "$PROJECT_DIR/worker/sync_worker.js" "$APP_BUNDLE/Contents/Resources/worker/"
cp -R "$PROJECT_DIR/worker/package.json" "$APP_BUNDLE/Contents/Resources/worker/"
if [ -d "$PROJECT_DIR/worker/node_modules" ]; then
    cp -R "$PROJECT_DIR/worker/node_modules" "$APP_BUNDLE/Contents/Resources/worker/"
fi

# 6. 对 App Bundle 执行本地 ad-hoc 签名
echo "🔏 正在对应用进行本地签名..."
codesign --force --deep -s - "$APP_BUNDLE"

# 7. 计算体积与产物详情
APP_SIZE=$(du -sh "$APP_BUNDLE" | cut -f1)
BIN_SIZE=$(du -sh "$APP_BUNDLE/Contents/MacOS/$APP_NAME" | cut -f1)

echo "🎉 构建完成！"
echo "📍 产物路径: $APP_BUNDLE"
echo "📊 原生二进制体积: $BIN_SIZE"
echo "📊 应用总包体积: $APP_SIZE (真正原生轻量，告别 Electron 臃肿！)"
