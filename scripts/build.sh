#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "$DIR"

echo "🔨 Building RemoteCommander (Release)..."
swift build -c release

echo "📦 Assembling RemoteCommander.app..."
mkdir -p RemoteCommander.app/Contents/MacOS
mkdir -p RemoteCommander.app/Contents/Resources

cp .build/release/RemoteCommander RemoteCommander.app/Contents/MacOS/

# Bundle Cloudflare Tunnel binary
if [ ! -f bin/cloudflared ]; then
    echo "⬇️ Downloading standalone cloudflared binary..."
    mkdir -p bin
    curl -sL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-darwin-arm64.tgz | tar -xz -C bin/
    chmod +x bin/cloudflared
fi

cp bin/cloudflared RemoteCommander.app/Contents/Resources/
chmod +x RemoteCommander.app/Contents/Resources/cloudflared

# Bundle App Icon
if [ -f Resources/AppIcon.icns ]; then
    cp Resources/AppIcon.icns RemoteCommander.app/Contents/Resources/
fi

cat << 'EOF' > RemoteCommander.app/Contents/Info.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>RemoteCommander</string>
    <key>CFBundleDisplayName</key>
    <string>RemoteCommander</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.RemoteCommander</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>RemoteCommander</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

# Touch app bundle so macOS LaunchServices refreshes icon cache
touch RemoteCommander.app

echo "✅ Build complete with AppIcon! You can open the app with:"
echo "   open RemoteCommander.app"
