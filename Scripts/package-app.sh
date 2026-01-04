#!/bin/bash
set -e

# =============================================================================
# Tubify 打包腳本
# 執行測試、建置 Release 版本並打包成 .dmg 檔案
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_NAME="Tubify"
SCHEME_NAME="Tubify"
BUILD_DIR="${PROJECT_DIR}/build"
EXPORT_PATH="${BUILD_DIR}/Export"
DMG_PATH="${BUILD_DIR}/${PROJECT_NAME}.dmg"

# 顏色輸出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[X]${NC} $1"
}

show_help() {
    echo "用法: $0 [選項]"
    echo ""
    echo "選項:"
    echo "  -h, --help       顯示此幫助訊息"
    echo "  --no-clean       跳過清理（預設會清理）"
    echo "  --skip-tests     跳過測試"
    echo "  --no-dmg         不建立 DMG 檔案"
    echo ""
    echo "範例:"
    echo "  $0                    執行測試並打包"
    echo "  $0 --skip-tests       跳過測試直接打包"
    echo "  $0 --no-clean         跳過清理，快速建置"
}

# 預設值
CLEAN_BUILD=true
SKIP_TESTS=false
CREATE_DMG=true

# 解析參數
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --no-clean)
            CLEAN_BUILD=false
            shift
            ;;
        --skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        --no-dmg)
            CREATE_DMG=false
            shift
            ;;
        *)
            print_error "未知選項: $1"
            show_help
            exit 1
            ;;
    esac
done

echo ""
echo "============================================================"
echo "                    Tubify 打包腳本"
echo "============================================================"
echo ""

# 檢查是否在專案目錄
if [ ! -f "${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj/project.pbxproj" ]; then
    print_error "找不到 Xcode 專案！請確認腳本位於正確位置。"
    exit 1
fi

cd "$PROJECT_DIR"

# 清理建置目錄
if [ "$CLEAN_BUILD" = true ]; then
    print_step "清理建置目錄..."
    rm -rf "$BUILD_DIR"
    xcodebuild clean -project "${PROJECT_NAME}.xcodeproj" -scheme "$SCHEME_NAME" -configuration Release 2>/dev/null || true
    print_success "清理完成"
fi

# 執行測試
if [ "$SKIP_TESTS" = false ]; then
    print_step "執行單元測試..."
    echo ""

    # 檢查 scheme 是否有設定測試
    TEST_OUTPUT=$(xcodebuild test \
        -project "${PROJECT_NAME}.xcodeproj" \
        -scheme "$SCHEME_NAME" \
        -configuration Debug \
        -destination 'platform=macOS' \
        2>&1) || true

    if echo "$TEST_OUTPUT" | grep -q "Scheme .* is not currently configured for the test action"; then
        print_warning "Scheme 尚未設定測試 action，跳過測試"
        print_warning "如需測試，請在 Xcode 中將 TubifyTests 加入 Scheme 的 Test action"
        echo ""
    elif echo "$TEST_OUTPUT" | grep -q "TEST SUCCEEDED"; then
        print_success "所有測試通過"
        echo ""
    elif echo "$TEST_OUTPUT" | grep -q "TEST FAILED"; then
        echo "$TEST_OUTPUT" | grep -E "(Test Case|passed|failed|error:)" || true
        print_error "測試失敗！請修復測試後再打包。"
        echo ""
        echo "提示: 使用 --skip-tests 可跳過測試"
        exit 1
    else
        # 其他錯誤
        echo "$TEST_OUTPUT" | tail -20
        print_error "測試執行發生錯誤"
        echo ""
        echo "提示: 使用 --skip-tests 可跳過測試"
        exit 1
    fi
fi

# 建立輸出目錄
mkdir -p "$BUILD_DIR"
mkdir -p "$EXPORT_PATH"

# 建置 Release 版本
print_step "建置 Release 版本..."

xcodebuild build \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "$SCHEME_NAME" \
    -configuration Release \
    -derivedDataPath "${BUILD_DIR}/DerivedData" \
    CONFIGURATION_BUILD_DIR="$EXPORT_PATH" \
    2>&1 | while read line; do
        # 只顯示重要訊息
        if [[ "$line" == *"error:"* ]]; then
            echo -e "${RED}$line${NC}"
        elif [[ "$line" == *"warning:"* ]]; then
            echo -e "${YELLOW}$line${NC}"
        elif [[ "$line" == *"BUILD SUCCEEDED"* ]]; then
            echo -e "${GREEN}$line${NC}"
        elif [[ "$line" == *"BUILD FAILED"* ]]; then
            echo -e "${RED}$line${NC}"
        fi
    done

APP_PATH="${EXPORT_PATH}/${PROJECT_NAME}.app"

# 檢查 .app 是否存在
if [ ! -d "$APP_PATH" ]; then
    print_error "建置失敗！找不到 .app"
    exit 1
fi

print_success ".app 建置完成: $APP_PATH"

# Ad-hoc 程式碼簽署
print_step "程式碼簽署（ad-hoc）..."
print_warning "使用 ad-hoc 簽名，首次開啟需右鍵點擊 -> 開啟"

# 對內部的 dylib 和執行檔簽署
find "$APP_PATH" -type f \( -name "*.dylib" -o -name "*.framework" -o -perm +111 \) -print0 2>/dev/null | while IFS= read -r -d '' file; do
    if file "$file" | grep -q "Mach-O"; then
        codesign --force --sign - "$file" 2>/dev/null || true
    fi
done

# 簽署整個 .app
codesign --force --deep --sign - "$APP_PATH"

print_success "程式碼簽署完成"

# 驗證簽署
print_step "驗證簽署..."
if codesign --verify --verbose "$APP_PATH" 2>/dev/null; then
    print_success "簽署驗證通過"
else
    print_warning "簽署驗證失敗"
fi

# 建立 DMG
if [ "$CREATE_DMG" = true ]; then
    print_step "建立 DMG 檔案..."

    # 移除舊的 DMG
    rm -f "$DMG_PATH"

    # 建立臨時目錄
    DMG_TEMP="${BUILD_DIR}/dmg_temp"
    rm -rf "$DMG_TEMP"
    mkdir -p "$DMG_TEMP"

    # 複製 .app 到臨時目錄
    cp -R "$APP_PATH" "$DMG_TEMP/"

    # 建立 Applications 資料夾的捷徑
    ln -s /Applications "$DMG_TEMP/Applications"

    # 建立 DMG
    hdiutil create \
        -volname "$PROJECT_NAME" \
        -srcfolder "$DMG_TEMP" \
        -ov \
        -format UDZO \
        "$DMG_PATH"

    # 清理臨時目錄
    rm -rf "$DMG_TEMP"

    # 設定 DMG 圖示
    print_step "設定 DMG 圖示..."
    ICNS_PATH="${APP_PATH}/Contents/Resources/AppIcon.icns"
    if [ -f "$ICNS_PATH" ]; then
        ICON_TEMP="${BUILD_DIR}/icon_temp"
        mkdir -p "$ICON_TEMP"

        # 從 icns 提取圖片
        sips -s format png "$ICNS_PATH" --out "$ICON_TEMP/icon.png" >/dev/null 2>&1

        # 使用 osascript 設定 DMG 圖示
        osascript << ASEOF
use framework "AppKit"
use scripting additions

set iconPath to "$ICON_TEMP/icon.png"
set dmgPath to "$DMG_PATH"

set theImage to current application's NSImage's alloc()'s initWithContentsOfFile:iconPath
if theImage is not missing value then
    set theWorkspace to current application's NSWorkspace's sharedWorkspace()
    theWorkspace's setIcon:theImage forFile:dmgPath options:0
end if
ASEOF

        # 清理臨時圖示目錄
        rm -rf "$ICON_TEMP"

        print_success "DMG 圖示設定完成"
    else
        print_warning "找不到 AppIcon.icns，跳過 DMG 圖示設定"
    fi

    print_success "DMG 建立完成: $DMG_PATH"
fi

# 顯示結果
echo ""
echo "============================================================"
echo "                       打包完成！"
echo "============================================================"
echo ""
print_success "輸出目錄: $EXPORT_PATH"
echo ""
echo "產出檔案:"
APP_SIZE=$(du -sh "$APP_PATH" 2>/dev/null | awk '{print $1}')
echo "  [APP] ${APP_PATH} (${APP_SIZE})"
if [ "$CREATE_DMG" = true ] && [ -f "$DMG_PATH" ]; then
    DMG_SIZE=$(ls -lh "$DMG_PATH" | awk '{print $5}')
    echo "  [DMG] ${DMG_PATH} (${DMG_SIZE})"
fi
echo ""
echo "安裝說明:"
echo "  由於使用 ad-hoc 簽名，首次開啟需執行以下步驟之一："
echo ""
echo "  方法 A：右鍵點擊 Tubify.app -> 開啟 -> 再點「開啟」"
echo ""
echo "  方法 B：在終端機執行："
echo "    xattr -cr /Applications/Tubify.app"
echo ""

# 開啟輸出目錄
if command -v open &> /dev/null; then
    print_step "在 Finder 中開啟輸出目錄..."
    open "$EXPORT_PATH"
fi
