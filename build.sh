#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="MarkdownEditor"
BUNDLE_NAME="${APP_NAME}.app"
BUILD_DIR="${PROJECT_DIR}/.build"
ARCH="arm64-apple-macosx"
CONFIG="release"

echo "==> Building ${APP_NAME} (${CONFIG})..."
cd "${PROJECT_DIR}"
swift build -c "${CONFIG}" 2>&1

PRODUCTS_DIR="${BUILD_DIR}/${ARCH}/${CONFIG}"
EXECUTABLE="${PRODUCTS_DIR}/${APP_NAME}"

if [ ! -f "${EXECUTABLE}" ]; then
    echo "Error: Executable not found at ${EXECUTABLE}"
    echo "Trying debug config..."
    CONFIG="debug"
    PRODUCTS_DIR="${BUILD_DIR}/${ARCH}/${CONFIG}"
    EXECUTABLE="${PRODUCTS_DIR}/${APP_NAME}"
    if [ ! -f "${EXECUTABLE}" ]; then
        echo "Error: Executable not found. Build may have failed."
        exit 1
    fi
fi

echo "==> Assembling ${BUNDLE_NAME}..."

# Create .app bundle structure
APP_DIR="${PROJECT_DIR}/${BUNDLE_NAME}"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

# Copy executable
cp "${EXECUTABLE}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"

# Copy Info.plist
PLIST_SRC="${PROJECT_DIR}/Sources/${APP_NAME}/Resources/Info.plist"
cp "${PLIST_SRC}" "${APP_DIR}/Contents/Info.plist"

# Write PkgInfo
echo -n "APPL????" > "${APP_DIR}/Contents/PkgInfo"

# Copy resource bundles (SPM creates these)
RESOURCE_BUNDLE="${PRODUCTS_DIR}/${APP_NAME}_${APP_NAME}.bundle"
if [ -d "${RESOURCE_BUNDLE}" ]; then
    cp -R "${RESOURCE_BUNDLE}" "${APP_DIR}/Contents/Resources/"
    echo "    Copied resource bundle"
fi

# Generate a simple app icon (blue circle with "M") if iconutil is available
generate_icon() {
    local ICONSET_DIR="${APP_DIR}/Contents/Resources/AppIcon.iconset"
    mkdir -p "${ICONSET_DIR}"

    for size in 16 32 64 128 256 512; do
        local size2x=$((size * 2))
        # Create icon using sips-compatible approach with a temporary SVG via python
        python3 -c "
import struct, zlib

def create_png(width, height, filename):
    def make_pixel_row(w, cx, cy, r):
        row = []
        for x in range(w):
            dx = x - cx
            dy = 0  # We'll do per-row
            return row
        return row

    # Simple solid blue circle on transparent background
    raw = b''
    cx, cy, radius = width/2, height/2, width/2 - 1
    for y in range(height):
        raw += b'\\x00'  # filter byte
        for x in range(width):
            dx, dy = x - cx, y - cy
            dist = (dx*dx + dy*dy) ** 0.5
            if dist <= radius:
                # Blue gradient
                t = dist / radius
                r_val = int(59 * (1-t) + 37 * t)
                g_val = int(130 * (1-t) + 99 * t)
                b_val = int(246 * (1-t) + 235 * t)
                a_val = 255
                if dist > radius - 1.5:
                    a_val = int(255 * (radius - dist) / 1.5)
                    a_val = max(0, min(255, a_val))
                raw += struct.pack('BBBB', r_val, g_val, b_val, a_val)
            else:
                raw += b'\\x00\\x00\\x00\\x00'

    def chunk(chunk_type, data):
        c = chunk_type + data
        crc = struct.pack('>I', zlib.crc32(c) & 0xffffffff)
        return struct.pack('>I', len(data)) + c + crc

    sig = b'\\x89PNG\\r\\n\\x1a\\n'
    ihdr = struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)
    compressed = zlib.compress(raw)

    with open(filename, 'wb') as f:
        f.write(sig)
        f.write(chunk(b'IHDR', ihdr))
        f.write(chunk(b'IDAT', compressed))
        f.write(chunk(b'IEND', b''))

create_png(${size}, ${size}, '${ICONSET_DIR}/icon_${size}x${size}.png')
if ${size} <= 512:
    create_png(${size2x}, ${size2x}, '${ICONSET_DIR}/icon_${size}x${size}@2x.png')
" 2>/dev/null || true
    done

    # Try to convert iconset to icns
    if command -v iconutil &>/dev/null; then
        iconutil -c icns "${ICONSET_DIR}" -o "${APP_DIR}/Contents/Resources/AppIcon.icns" 2>/dev/null && {
            # Add icon reference to Info.plist
            /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "${APP_DIR}/Contents/Info.plist" 2>/dev/null || true
            echo "    Generated app icon"
        } || echo "    Icon generation skipped (iconutil failed)"
    fi
    rm -rf "${ICONSET_DIR}"
}

generate_icon

# Register the bundle with Launch Services
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "${APP_DIR}" 2>/dev/null || true

echo ""
echo "==> Build complete!"
echo "    ${APP_DIR}"
echo ""
echo "    To launch:  open ${BUNDLE_NAME}"
echo "    To install:  cp -R ${BUNDLE_NAME} /Applications/"
echo ""
