#!/bin/bash
set -e

echo "🔨 Building MacConverter..."
swift build -c release

APP_NAME="MacConverter.app"
BIN_NAME="MacConverter"
BUILD_BIN=".build/release/${BIN_NAME}"
CONTENTS_DIR="${APP_NAME}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "📦 Packaging ${APP_NAME}..."
rm -rf "${APP_NAME}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

cp "${BUILD_BIN}" "${MACOS_DIR}/${BIN_NAME}"
cp "Info.plist" "${CONTENTS_DIR}/Info.plist"
if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
fi

# Ad-hoc code signing for local execution
codesign --force --deep --sign - "${APP_NAME}"
touch "${APP_NAME}"

# Copy to /Applications so it is immediately available in Applications & Launchpad
if [ -w "/Applications" ]; then
    echo "🚀 Installing ${APP_NAME} to /Applications..."
    rm -rf "/Applications/${APP_NAME}"
    cp -R "${APP_NAME}" "/Applications/${APP_NAME}"
    touch "/Applications/${APP_NAME}"
    echo "✅ Installed to /Applications/${APP_NAME}"
fi

echo "✅ Build and packaging complete: ${APP_NAME}"
