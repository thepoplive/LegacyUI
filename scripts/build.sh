#!/bin/bash
# LegacyUI build script — no Theos, plain clang + ldid + dpkg-deb.
#
# Toolchain notes (iOS 8.4.1 / ARMv7):
#  - Compile with the iPhoneOS10.3.sdk for linking.
#  - Deployment target 8.4.1 makes ld64 emit LC_VERSION_MIN_IPHONEOS.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TWEAK_NAME="LegacyUI"
ARCH="armv7"
MIN_OS="8.4.1"
LEGACY_SDK="$ROOT/third_party/theos-sdks/iPhoneOS10.3.sdk"
BUILD="$ROOT/build"
OBJ="$BUILD/obj"
STAGE="$ROOT/stage"
CONTROL="$ROOT/layout/DEBIAN/control"
FRAMEWORKS="-framework UIKit -framework Foundation -framework CoreGraphics -framework QuartzCore -framework AVFoundation -framework MediaPlayer"

die() { echo "build.sh: ERROR: $*" >&2; exit 1; }

require_macos() {
    [ "$(uname -s)" = "Darwin" ] || die "iOS build requires macOS (Xcode)."
    command -v xcrun >/dev/null 2>&1 || die "xcrun not found (install Xcode)"
}

VERSION="$(sed -n 's/^Version: *//p' "$CONTROL" | tr -d '[:space:]')"
[ -n "$VERSION" ] || die "cannot read Version from $CONTROL"

include_flags() {
    local dirs="" d
    while IFS= read -r d; do
        dirs="$dirs -I$d"
    done < <(find "$ROOT/Core" "$ROOT/Dock" "$ROOT/VolumeHUD" -name '*.h' 2>/dev/null | xargs -n1 dirname | sort -u)
    echo "$dirs"
}

compile_all() {
    local compile_sysroot src obj incs
    compile_sysroot="$LEGACY_SDK"
    [ -d "$compile_sysroot" ] || die "legacy SDK missing at $LEGACY_SDK (CI clones theos/sdks sparse)"
    incs="$(include_flags)"
    mkdir -p "$OBJ"

    echo "  Compiling Tweak.xm..."
    xcrun clang -arch "$ARCH" -miphoneos-version-min="$MIN_OS" \
        -isysroot "$compile_sysroot" -fobjc-arc -Os -Wall \
        -Wunguarded-availability $incs -c "$ROOT/Tweak.xm" -o "$OBJ/Tweak.o" \
        || die "compile failed: Tweak.xm"

    for src in "$ROOT/Core/"*.m "$ROOT/Dock/"*.m "$ROOT/VolumeHUD/"*.m; do
        [ -f "$src" ] || continue
        obj="$OBJ/$(basename "$src" .m).o"
        echo "  CC $(basename "$src")"
        xcrun clang -arch "$ARCH" -miphoneos-version-min="$MIN_OS" \
            -isysroot "$compile_sysroot" -fobjc-arc -Os -Wall \
            -Wunguarded-availability $incs -c "$src" -o "$obj" \
            || die "compile failed: $src"
    done

    [ -n "$(ls -A "$OBJ" 2>/dev/null)" ] || die "no object files produced"
}

link_binary() {
    [ -d "$LEGACY_SDK" ] || die "legacy SDK missing at $LEGACY_SDK"
    echo "  LD $TWEAK_NAME (sysroot: $(basename "$LEGACY_SDK"))"
    xcrun clang -arch "$ARCH" -miphoneos-version-min="$MIN_OS" \
        -dynamiclib -install_name /Library/MobileSubstrate/DynamicLibraries/${TWEAK_NAME}.dylib \
        -isysroot "$LEGACY_SDK" -Wl,-U,_objc_msgSend_stret \
        -o "$BUILD/${TWEAK_NAME}.dylib" "$OBJ"/*.o $FRAMEWORKS \
        || die "link failed"
    command -v ldid >/dev/null 2>&1 || die "ldid not found (brew install ldid)"
    ldid -S "$BUILD/${TWEAK_NAME}.dylib" || die "ldid signing failed"
}

stage_tweak() {
    rm -rf "$STAGE"
    mkdir -p "$STAGE/Library/MobileSubstrate/DynamicLibraries"
    mkdir -p "$STAGE/Library/PreferenceBundles/LegacyUI.bundle"
    mkdir -p "$STAGE/Library/PreferenceLoader/Preferences"
    mkdir -p "$STAGE/DEBIAN"

    cp "$BUILD/${TWEAK_NAME}.dylib" "$STAGE/Library/MobileSubstrate/DynamicLibraries/"
    chmod 755 "$STAGE/Library/MobileSubstrate/DynamicLibraries/${TWEAK_NAME}.dylib"

    if [ -d "$ROOT/Preferences" ]; then
        cp -r "$ROOT/Preferences/"*.plist "$STAGE/Library/PreferenceBundles/LegacyUI.bundle/" 2>/dev/null || true
        cp -r "$ROOT/Preferences/"*.m "$STAGE/Library/PreferenceBundles/LegacyUI.bundle/" 2>/dev/null || true
    fi

    if [ -f "$ROOT/Preferences/Entry.plist" ]; then
        cp "$ROOT/Preferences/Entry.plist" "$STAGE/Library/PreferenceLoader/Preferences/"
    fi

    cp "$CONTROL" "$STAGE/DEBIAN/control"
    chmod 644 "$STAGE/DEBIAN/control"

    if [ -f "$ROOT/layout/DEBIAN/postinst" ]; then
        cp "$ROOT/layout/DEBIAN/postinst" "$STAGE/DEBIAN/postinst"
        chmod 755 "$STAGE/DEBIAN/postinst"
    fi
}

make_deb() {
    command -v dpkg-deb >/dev/null 2>&1 || die "dpkg-deb not found (brew install dpkg)"
    local deb="$BUILD/${TWEAK_NAME}_${VERSION}_iphoneos-arm.deb"
    dpkg-deb -Zgzip --root-owner-group -b "$STAGE" "$deb" || die "dpkg-deb failed"
    echo "  OK $deb"
}

validate_deb() {
    local deb
    deb="$(ls "$BUILD/${TWEAK_NAME}_"*.deb 2>/dev/null | head -1)"
    [ -n "$deb" ] || die "no .deb in build/ — run ./scripts/build.sh package first"
    echo "== dpkg-deb -I =="
    dpkg-deb -I "$deb"
    echo "== validation OK =="
}

cmd="${1:-package}"
case "$cmd" in
    build)    require_macos; compile_all; link_binary ;;
    package)  require_macos; compile_all; link_binary; stage_tweak; make_deb ;;
    validate) validate_deb ;;
    clean)    rm -rf "$BUILD" "$STAGE" ;;
    *) die "unknown command: $cmd (build|package|validate|clean)" ;;
esac