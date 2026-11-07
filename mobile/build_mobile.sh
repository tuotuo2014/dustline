#!/bin/bash
# Build only this independent mobile copy. All tool settings and keys stay here.
set -euo pipefail
MOBILE_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$MOBILE_DIR/project"
TOOLS_DIR="$MOBILE_DIR/tools"
GODOT_BIN="$TOOLS_DIR/godot/Godot.app/Contents/MacOS/Godot"
JDK_DIR="$TOOLS_DIR/jdk/jdk-17.0.20.1+1/Contents/Home"
SDK_DIR="$TOOLS_DIR/android-sdk"
TEMPLATE_DIR="$TOOLS_DIR/templates/4.7.2.stable"
MODE="${1:-check}"
RUN_ID="$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$MOBILE_DIR/builds/logs"

fail() { printf '%s\n' "$*" >&2; exit 1; }
require_file() { [[ -f "$1" ]] || fail "缺少：$1。请参阅 mobile/BUILDING.md。"; }
require_file "$GODOT_BIN"
ENGINE_VERSION="$("$GODOT_BIN" --version)"
[[ "$ENGINE_VERSION" == 4.7.2.stable.* ]] || fail "需要 Godot 4.7.2 stable；当前为 $ENGINE_VERSION。"

# This is the private self-contained editor, never the desktop editor's settings.
mkdir -p "$TOOLS_DIR/godot/editor_data"
touch "$TOOLS_DIR/godot/_sc_"
cat > "$TOOLS_DIR/godot/editor_data/editor_settings-4.7.tres" <<EOF
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/java_sdk_path = "$JDK_DIR"
export/android/android_sdk_path = "$SDK_DIR"
export/android/debug_keystore = "$TOOLS_DIR/keys/debug.keystore"
EOF
export JAVA_HOME="$JDK_DIR"
export ANDROID_HOME="$SDK_DIR"
export PATH="$JDK_DIR/bin:$SDK_DIR/platform-tools:$PATH"
cd "$PROJECT_DIR"

import_project() {
    "$GODOT_BIN" --headless --path "$PROJECT_DIR" --import \
        --log-file "$MOBILE_DIR/builds/logs/import-$RUN_ID.log"
}

build_android() {
    require_file "$TEMPLATE_DIR/android_debug.apk"
    require_file "$JDK_DIR/bin/java"
    require_file "$SDK_DIR/build-tools/36.0.0/apksigner"
    mkdir -p "$TOOLS_DIR/keys" "$MOBILE_DIR/builds/android"
    if [[ ! -f "$TOOLS_DIR/keys/debug.keystore" ]]; then
        "$JDK_DIR/bin/keytool" -genkeypair -keystore "$TOOLS_DIR/keys/debug.keystore" \
            -storepass android -alias androiddebugkey -keypass android \
            -keyalg RSA -keysize 2048 -validity 10000 \
            -dname "CN=Android Debug,O=Android,C=US" >/dev/null
    fi
    export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$TOOLS_DIR/keys/debug.keystore"
    export GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey
    export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=android
    "$GODOT_BIN" --headless --path "$PROJECT_DIR" \
        --export-debug "Android Mobile" "$MOBILE_DIR/builds/android/Dustline-Mobile.apk" \
        --log-file "$MOBILE_DIR/builds/logs/android-$RUN_ID.log"
    "$SDK_DIR/build-tools/36.0.0/apksigner" verify --verbose \
        "$MOBILE_DIR/builds/android/Dustline-Mobile.apk"
    printf '\n安卓安装包：%s\n' "$MOBILE_DIR/builds/android/Dustline-Mobile.apk"
}

build_web() {
    require_file "$TEMPLATE_DIR/web_nothreads_release.zip"
    mkdir -p "$MOBILE_DIR/builds/web"
    "$GODOT_BIN" --headless --path "$PROJECT_DIR" \
        --export-release "Mobile Web" "$MOBILE_DIR/builds/web/index.html" \
        --log-file "$MOBILE_DIR/builds/logs/web-$RUN_ID.log"
    require_file "$MOBILE_DIR/builds/web/index.wasm"
    require_file "$MOBILE_DIR/builds/web/index.pck"
    printf '\n手机网页版已生成。启动方式：%s\n' "$MOBILE_DIR/打开手机版.command"
}

build_ios() {
    require_file "$TEMPLATE_DIR/ios.zip"
    if ! /usr/bin/xcodebuild -version >/dev/null 2>&1; then
        fail "iPhone 原生导出需要完整 Xcode；本机目前仅有 Command Line Tools。可先使用已生成的手机网页版。"
    fi
    if [[ -z "${IOS_TEAM_ID:-}" ]]; then
        fail "请用 IOS_TEAM_ID=你的真实AppleTeamID ./build_mobile.sh ios。Godot 即使只导出 Xcode 工程也要求真实 Team ID；未填写或伪造身份。"
    fi
    [[ "$IOS_TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || fail "IOS_TEAM_ID 应为 10 位大写字母或数字。"
    mkdir -p "$MOBILE_DIR/builds/ios"
    PRESET_BACKUP="$MOBILE_DIR/builds/logs/presets-$RUN_ID.cfg"
    cp "$PROJECT_DIR/export_presets.cfg" "$PRESET_BACKUP"
    trap 'cp "$PRESET_BACKUP" "$PROJECT_DIR/export_presets.cfg"; rm -f "$PRESET_BACKUP"' EXIT
    /usr/bin/sed -i '' "s/application\/app_store_team_id=\"\"/application\/app_store_team_id=\"$IOS_TEAM_ID\"/" "$PROJECT_DIR/export_presets.cfg"
    "$GODOT_BIN" --headless --path "$PROJECT_DIR" \
        --export-debug "iPhone Mobile" "$MOBILE_DIR/builds/ios/DustlineMobile.zip" \
        --log-file "$MOBILE_DIR/builds/logs/ios-$RUN_ID.log"
    printf '\niPhone Xcode 工程已导出；仍需在 Xcode 中选择自己的签名和真机运行。\n'
}

case "$MODE" in
    check)
        printf 'Godot：%s\n独立项目：%s\n' "$ENGINE_VERSION" "$PROJECT_DIR"
        for template in android_debug.apk android_release.apk ios.zip web_nothreads_release.zip; do
            if [[ -f "$TEMPLATE_DIR/$template" ]]; then printf '模板就绪：%s\n' "$template"; else printf '模板缺失：%s\n' "$template"; fi
        done
        if [[ -x "$JDK_DIR/bin/java" ]]; then "$JDK_DIR/bin/java" -version; fi
        if [[ -x "$SDK_DIR/platform-tools/adb" ]]; then "$SDK_DIR/platform-tools/adb" version; fi
        if ! /usr/bin/xcodebuild -version; then printf '尚无完整 Xcode；iPhone 原生包暂不能编译签名。\n'; fi
        ;;
    android) import_project; build_android ;;
    web) import_project; build_web ;;
    ios) build_ios ;;
    all) import_project; build_android; build_web ;;
    *) fail "用法：./build_mobile.sh [check|android|web|ios|all]。all 生成安卓 APK 和跨平台手机版网页。" ;;
esac
