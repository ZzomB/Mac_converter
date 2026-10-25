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

# Ad-hoc code signing for local execution
codesign --force --deep --sign - "${APP_NAME}"

echo "✅ Build and packaging complete: ${APP_NAME}"
