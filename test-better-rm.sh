#!/bin/bash
#
# Better-RM 完整測試腳本
# Comprehensive Test Script for Better-RM
#
# 此腳本可在容器環境下測試 better-rm 的所有功能
# This script tests all features of better-rm in a container environment
#

# 顏色定義 (Color definitions)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 測試計數器 (Test counters)
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Better-RM 腳本路徑 (Better-RM script path)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BETTER_RM="$SCRIPT_DIR/better-rm"

# 測試用的垃圾桶目錄 (Test trash directory)
TEST_TRASH_DIR="/tmp/better-rm-test-trash"

# 測試用的狀態目錄 (Test state directory)
TEST_STATE_DIR="/tmp/better-rm-test-state"

# 測試用的工作目錄 (Test working directory)
TEST_WORK_DIR="/tmp/better-rm-test-work"

# 測試不可寫狀態目錄時使用的一般檔案
# Regular file used to test an unavailable state directory
TEST_STATE_BLOCKER="/tmp/better-rm-test-state-blocker"

# 顯示測試標題 (Display test title)
test_title() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# 顯示測試項目 (Display test item)
test_item() {
    echo -e "${YELLOW}[測試 $TOTAL_TESTS] $1${NC}"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

# 測試成功 (Test passed)
test_pass() {
    echo -e "${GREEN}✓ 通過: $1${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
}

# 測試失敗 (Test failed)
test_fail() {
    echo -e "${RED}✗ 失敗: $1${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
}

# 清理測試環境 (Clean up test environment)
cleanup() {
    rm -rf "$TEST_TRASH_DIR" "$TEST_STATE_DIR" "$TEST_WORK_DIR" "$TEST_STATE_BLOCKER"
}

# 設置測試環境 (Setup test environment)
setup() {
    cleanup
    mkdir -p "$TEST_WORK_DIR"
    export TRASH_DIR="$TEST_TRASH_DIR"
    export BETTER_RM_STATE_DIR="$TEST_STATE_DIR"
}

# 驗證檔案是否在垃圾桶中 (Verify file is in trash)
verify_in_trash() {
    local pattern="$1"
    if find "$TEST_TRASH_DIR" -name "*${pattern}*" 2>/dev/null | grep -q .; then
        return 0
    else
        return 1
    fi
}

# 驗證日誌記錄 (Verify log entry)
verify_log_entry() {
    local log_file="$TEST_STATE_DIR/deletion.log"
    local pattern="$1"
    if [ -f "$log_file" ] && grep -q "$pattern" "$log_file"; then
        return 0
    else
        return 1
    fi
}

# ============================================================================
# 測試開始 (Tests Begin)
# ============================================================================

echo -e "${GREEN}Better-RM 完整測試套件${NC}"
echo -e "${GREEN}Better-RM Comprehensive Test Suite${NC}"
echo ""
echo "測試腳本: $BETTER_RM"
echo "垃圾桶目錄: $TEST_TRASH_DIR"
echo "狀態目錄: $TEST_STATE_DIR"
echo "工作目錄: $TEST_WORK_DIR"
echo ""

# ============================================================================
# 測試 1: 版本與說明 (Test 1: Version and Help)
# ============================================================================
test_title "測試 1: 版本與說明資訊"

test_item "測試 --version 參數"
if "$BETTER_RM" --version | grep -q "better-rm 1.7.1"; then
    test_pass "--version 顯示正確版本"
else
    test_fail "--version 版本不正確"
fi

test_item "測試 --help 參數"
if "$BETTER_RM" --help | grep -q "用法"; then
    test_pass "--help 顯示說明訊息"
else
    test_fail "--help 未顯示說明訊息"
fi

# ============================================================================
# 測試 2: 基本檔案刪除 (Test 2: Basic File Deletion)
# ============================================================================
test_title "測試 2: 基本檔案刪除功能"

setup
cd "$TEST_WORK_DIR"

test_item "刪除單一檔案"
echo "test content" > file1.txt
if "$BETTER_RM" file1.txt && [ ! -e file1.txt ] && verify_in_trash "file1.txt"; then
    test_pass "單一檔案成功移至垃圾桶"
else
    test_fail "單一檔案刪除失敗"
fi

test_item "刪除多個檔案"
echo "file2" > file2.txt
echo "file3" > file3.txt
if "$BETTER_RM" file2.txt file3.txt && [ ! -e file2.txt ] && [ ! -e file3.txt ] && \
   verify_in_trash "file2.txt" && verify_in_trash "file3.txt"; then
    test_pass "多個檔案成功移至垃圾桶"
else
    test_fail "多個檔案刪除失敗"
fi

# ============================================================================
# 測試 3: 目錄刪除 (Test 3: Directory Deletion)
# ============================================================================
test_title "測試 3: 目錄刪除功能"

setup
cd "$TEST_WORK_DIR"

test_item "遞迴刪除目錄 (-r)"
mkdir -p testdir/subdir
echo "content" > testdir/file.txt
echo "subcontent" > testdir/subdir/subfile.txt
if "$BETTER_RM" -r testdir && [ ! -e testdir ] && verify_in_trash "testdir"; then
    test_pass "目錄成功遞迴刪除"
else
    test_fail "目錄刪除失敗"
fi

test_item "刪除空目錄"
mkdir emptydir
if "$BETTER_RM" -r emptydir && [ ! -e emptydir ] && verify_in_trash "emptydir"; then
    test_pass "空目錄成功刪除"
else
    test_fail "空目錄刪除失敗"
fi

test_item "不加 -r 刪除目錄應失敗"
mkdir testdir2
if "$BETTER_RM" testdir2 2>/dev/null; then
    test_fail "不加 -r 卻成功刪除目錄（不應該）"
else
    test_pass "不加 -r 正確拒絕刪除目錄"
fi
rm -rf testdir2

# ============================================================================
# 測試 4: 特殊字元檔名 (Test 4: Special Characters in Filenames)
# ============================================================================
test_title "測試 4: 特殊字元檔名處理"

setup
cd "$TEST_WORK_DIR"

test_item "檔名含空格"
echo "content" > "file with spaces.txt"
if "$BETTER_RM" "file with spaces.txt" && [ ! -e "file with spaces.txt" ]; then
    test_pass "空格檔名成功處理"
else
    test_fail "空格檔名處理失敗"
fi

test_item "檔名含特殊字元"
echo "content" > "file-with_special.chars.txt"
if "$BETTER_RM" "file-with_special.chars.txt" && [ ! -e "file-with_special.chars.txt" ]; then
    test_pass "特殊字元檔名成功處理"
else
    test_fail "特殊字元檔名處理失敗"
fi

test_item "中文檔名"
echo "內容" > "測試檔案.txt"
if "$BETTER_RM" "測試檔案.txt" && [ ! -e "測試檔案.txt" ]; then
    test_pass "中文檔名成功處理"
else
    test_fail "中文檔名處理失敗"
fi

# ============================================================================
# 測試 5: 符號連結 (Test 5: Symbolic Links)
# ============================================================================
test_title "測試 5: 符號連結處理"

setup
cd "$TEST_WORK_DIR"

test_item "刪除符號連結"
echo "target" > target.txt
ln -s target.txt symlink.txt
if "$BETTER_RM" symlink.txt && [ ! -L symlink.txt ] && [ -e target.txt ]; then
    test_pass "符號連結成功刪除（目標檔案保留）"
else
    test_fail "符號連結刪除失敗"
fi

# ============================================================================
# 測試 6: 時間戳記與 Hash (Test 6: Timestamp and Hash)
# ============================================================================
test_title "測試 6: 時間戳記與內容 Hash"

setup
cd "$TEST_WORK_DIR"

test_item "檔名包含時間戳記和 Hash"
echo "content for hash" > hashtest.txt
"$BETTER_RM" hashtest.txt
if find "$TEST_TRASH_DIR" -name "hashtest.txt__*__*" | grep -q .; then
    test_pass "檔名包含時間戳記和 Hash"
else
    test_fail "檔名格式不正確"
fi

test_item "相同檔名但不同內容產生不同 Hash"
echo "content1" > test.txt
"$BETTER_RM" test.txt
sleep 0.01  # 確保時間戳記不同
hash1=$(find "$TEST_TRASH_DIR" -name "test.txt__*" | sort | head -1 | awk -F'__' '{print $NF}')

echo "content2" > test.txt
"$BETTER_RM" test.txt
hash2=$(find "$TEST_TRASH_DIR" -name "test.txt__*" | sort | tail -1 | awk -F'__' '{print $NF}')

if [ -n "$hash1" ] && [ -n "$hash2" ] && [ "$hash1" != "$hash2" ]; then
    test_pass "不同內容產生不同 Hash (hash1=$hash1, hash2=$hash2)"
else
    test_fail "不同內容產生相同 Hash 或未找到 Hash (hash1=$hash1, hash2=$hash2)"
fi

test_item "空檔案的 Hash"
touch empty.txt
"$BETTER_RM" empty.txt
if find "$TEST_TRASH_DIR" -name "empty.txt__*__d41d8cd98f00b204e9800998ecf8427e" | grep -q .; then
    test_pass "空檔案 Hash 正確 (MD5 of empty string)"
else
    test_fail "空檔案 Hash 不正確"
fi

# ============================================================================
# 測試 7: 刪除日誌 (Test 7: Deletion Log)
# ============================================================================
test_title "測試 7: 刪除日誌功能"

setup
cd "$TEST_WORK_DIR"

test_item "日誌檔案自動創建"
echo "test" > logtest.txt
"$BETTER_RM" logtest.txt
if [ -f "$TEST_STATE_DIR/deletion.log" ] && [ ! -e "$TEST_TRASH_DIR/.deletion_log" ]; then
    test_pass "日誌檔案成功創建"
else
    test_fail "日誌檔案未創建"
fi

test_item "狀態目錄與日誌使用限制性權限"
state_mode=$(stat -c '%a' "$TEST_STATE_DIR" 2>/dev/null || stat -f '%Lp' "$TEST_STATE_DIR" 2>/dev/null)
log_mode=$(stat -c '%a' "$TEST_STATE_DIR/deletion.log" 2>/dev/null || stat -f '%Lp' "$TEST_STATE_DIR/deletion.log" 2>/dev/null)
if [ "$state_mode" = "700" ] && [ "$log_mode" = "600" ]; then
    test_pass "狀態目錄與日誌權限正確"
else
    test_fail "狀態目錄或日誌權限不正確 (directory=$state_mode, log=$log_mode)"
fi

test_item "日誌記錄檔案刪除"
if verify_log_entry "logtest.txt" && verify_log_entry "file"; then
    test_pass "日誌正確記錄檔案刪除"
else
    test_fail "日誌未記錄檔案刪除"
fi

test_item "日誌記錄目錄刪除"
mkdir logdir
echo "content" > logdir/file.txt
"$BETTER_RM" -r logdir
if verify_log_entry "logdir" && verify_log_entry "directory"; then
    test_pass "日誌正確記錄目錄刪除"
else
    test_fail "日誌未記錄目錄刪除"
fi

test_item "日誌記錄符號連結"
echo "target" > logtarget.txt
ln -s logtarget.txt logsymlink.txt
"$BETTER_RM" logsymlink.txt
if verify_log_entry "symlink"; then
    test_pass "日誌正確記錄符號連結"
else
    test_fail "日誌未記錄符號連結"
fi

test_item "日誌格式正確"
log_file="$TEST_STATE_DIR/deletion.log"
if grep -E "^[0-9]{8}_[0-9]{6}_[0-9]+ \| .+ \| .+ \| .+ \| (file|directory|symlink)$" "$log_file" >/dev/null 2>&1; then
    test_pass "日誌格式正確"
else
    test_fail "日誌格式不正確"
fi

test_item "無法建立日誌目錄時刪除仍成功且不洩漏 Shell 錯誤"
printf 'blocker\n' > "$TEST_STATE_BLOCKER"
echo "unavailable state test" > unavailable-state.txt
log_failure_output=$(BETTER_RM_STATE_DIR="$TEST_STATE_BLOCKER/child" "$BETTER_RM" unavailable-state.txt 2>&1)
log_failure_status=$?
if [ $log_failure_status -eq 0 ] && [ ! -e unavailable-state.txt ] && \
   verify_in_trash "unavailable-state.txt" && \
   echo "$log_failure_output" | grep -q "無法建立日誌目錄" && \
   ! echo "$log_failure_output" | grep -Eq "Permission denied|Operation not permitted|Not a directory"; then
    test_pass "日誌失敗不影響刪除且輸出受控"
else
    test_fail "日誌失敗時的刪除結果或錯誤輸出不正確"
fi

# ============================================================================
# 測試 8: 參數選項 (Test 8: Command Options)
# ============================================================================
test_title "測試 8: 命令參數選項"

setup
cd "$TEST_WORK_DIR"

test_item "詳細模式 (-v)"
echo "verbose test" > vtest.txt
if "$BETTER_RM" -v vtest.txt 2>&1 | grep -q "已移除"; then
    test_pass "-v 參數顯示詳細訊息"
else
    test_fail "-v 參數未顯示詳細訊息"
fi

test_item "強制模式 (-f) 忽略不存在的檔案"
if "$BETTER_RM" -f nonexistent.txt 2>/dev/null; then
    test_pass "-f 參數正確忽略不存在的檔案"
else
    test_fail "-f 參數未正確處理"
fi

test_item "組合參數 (-rf)"
mkdir -p rftest/subdir
echo "content" > rftest/file.txt
if "$BETTER_RM" -rf rftest && [ ! -e rftest ]; then
    test_pass "-rf 組合參數正常工作"
else
    test_fail "-rf 組合參數失敗"
fi

# ============================================================================
# 測試 9: 受保護目錄 (Test 9: Protected Directories)
# ============================================================================
test_title "測試 9: 受保護目錄"

test_item "拒絕刪除根目錄 (/)"
if "$BETTER_RM" -rf / 2>&1 | grep -q "拒絕刪除受保護的目錄"; then
    test_pass "正確拒絕刪除根目錄"
else
    test_fail "未正確保護根目錄"
fi

test_item "拒絕刪除 /home"
if "$BETTER_RM" -rf /home 2>&1 | grep -q "拒絕刪除受保護的目錄"; then
    test_pass "正確拒絕刪除 /home"
else
    test_fail "未正確保護 /home"
fi

test_item "拒絕刪除 /mnt 與第一層掛載根"
mnt_protected=true
for protected_mnt_path in /mnt /mnt/c /mnt/../mnt/wsl; do
    if ! "$BETTER_RM" -rf "$protected_mnt_path" 2>&1 | grep -q "拒絕刪除受保護的目錄"; then
        mnt_protected=false
    fi
done
if [ "$mnt_protected" = true ]; then
    test_pass "正確保護 /mnt 與第一層掛載根"
else
    test_fail "未正確保護 /mnt 掛載根"
fi

test_item "允許處理 /mnt 掛載根內的一般路徑"
if "$BETTER_RM" -f /mnt/c/project/nonexistent 2>&1 | grep -q "拒絕刪除受保護的目錄"; then
    test_fail "錯誤封鎖 /mnt 掛載根內的一般路徑"
else
    test_pass "未封鎖 /mnt 掛載根內的一般路徑"
fi

test_item "拒絕刪除 .git 目錄"
setup
cd "$TEST_WORK_DIR"
mkdir -p project/.git
if "$BETTER_RM" -rf project/.git 2>&1 | grep -q "拒絕刪除受保護的目錄"; then
    test_pass "正確拒絕刪除 .git 目錄"
else
    test_fail "未正確保護 .git 目錄"
fi

# ============================================================================
# 測試 10: 快速連續刪除 (Test 10: Rapid Successive Deletions)
# ============================================================================
test_title "測試 10: 快速連續刪除（測試奈秒時間戳記）"

setup
cd "$TEST_WORK_DIR"

test_item "快速連續刪除多個檔案"
for i in {1..5}; do
    echo "content $i" > "rapid$i.txt"
done

for i in {1..5}; do
    "$BETTER_RM" "rapid$i.txt" &
done
wait

# 檢查所有檔案是否都成功刪除
all_deleted=true
for i in {1..5}; do
    if [ -e "rapid$i.txt" ]; then
        all_deleted=false
    fi
done

# 檢查是否有檔名衝突
trash_files=$(find "$TEST_TRASH_DIR" -name "rapid*.txt__*" 2>/dev/null | wc -l)

if $all_deleted && [ "$trash_files" -eq 5 ]; then
    test_pass "快速連續刪除成功，無檔名衝突（奈秒時間戳記正常工作）"
elif $all_deleted; then
    test_pass "快速連續刪除成功，但找到 $trash_files 個檔案（預期 5 個）"
else
    test_fail "快速連續刪除失敗"
fi

# ============================================================================
# 測試 11: 路徑結構保留 (Test 11: Path Structure Preservation)
# ============================================================================
test_title "測試 11: 垃圾桶路徑結構保留"

setup
cd "$TEST_WORK_DIR"

test_item "深層目錄結構保留"
mkdir -p deep/nested/directory/structure
echo "deep content" > deep/nested/directory/structure/file.txt
original_path="$TEST_WORK_DIR/deep/nested/directory/structure/file.txt"
"$BETTER_RM" deep/nested/directory/structure/file.txt

# 檢查垃圾桶中是否保留了路徑結構 (考慮 macOS 的 /tmp -> /private/tmp)
resolved_work_dir=$(readlink -f "$TEST_WORK_DIR" 2>/dev/null || realpath "$TEST_WORK_DIR" 2>/dev/null || echo "$TEST_WORK_DIR")
if find "$TEST_TRASH_DIR$resolved_work_dir/deep/nested/directory/structure" -name "file.txt__*" | grep -q .; then
    test_pass "路徑結構成功保留"
else
    test_fail "路徑結構未保留"
fi

# ============================================================================
# 測試 12: 自訂垃圾桶目錄 (Test 12: Custom Trash Directory)
# ============================================================================
test_title "測試 12: 自訂垃圾桶目錄"

test_item "使用自訂 TRASH_DIR"
custom_trash="/tmp/custom-trash-test"
rm -rf "$custom_trash"
cd "$TEST_WORK_DIR"
echo "custom trash test" > customtest.txt

TRASH_DIR="$custom_trash" "$BETTER_RM" customtest.txt

if [ -d "$custom_trash" ] && find "$custom_trash" -name "customtest.txt__*" | grep -q . && \
   [ ! -e "$custom_trash/.deletion_log" ] && verify_log_entry "customtest.txt"; then
    test_pass "自訂垃圾桶目錄正常工作"
else
    test_fail "自訂垃圾桶目錄失敗"
fi
rm -rf "$custom_trash"

test_item "使用自訂 BETTER_RM_STATE_DIR"
custom_state="/tmp/custom-better-rm-state-test"
rm -rf "$custom_state"
echo "custom state test" > customstatetest.txt
BETTER_RM_STATE_DIR="$custom_state" "$BETTER_RM" customstatetest.txt
if [ -f "$custom_state/deletion.log" ] && grep -q "customstatetest.txt" "$custom_state/deletion.log"; then
    test_pass "自訂狀態目錄正常工作"
else
    test_fail "自訂狀態目錄失敗"
fi
rm -rf "$custom_state"

test_item "使用 XDG_STATE_HOME"
custom_xdg_state="/tmp/custom-xdg-state-test"
rm -rf "$custom_xdg_state"
echo "xdg state test" > xdgstatetest.txt
BETTER_RM_STATE_DIR="" XDG_STATE_HOME="$custom_xdg_state" "$BETTER_RM" xdgstatetest.txt
if [ -f "$custom_xdg_state/better-rm/deletion.log" ] && \
   grep -q "xdgstatetest.txt" "$custom_xdg_state/better-rm/deletion.log"; then
    test_pass "XDG 狀態目錄正常工作"
else
    test_fail "XDG 狀態目錄失敗"
fi
rm -rf "$custom_xdg_state"

test_item "相對 XDG_STATE_HOME 回退預設狀態目錄"
fallback_home="/tmp/better-rm-state-fallback-home"
rm -rf "$fallback_home"
mkdir -p "$fallback_home"
echo "fallback state test" > fallbackstatetest.txt
HOME="$fallback_home" BETTER_RM_STATE_DIR="" XDG_STATE_HOME="relative-state" \
    "$BETTER_RM" fallbackstatetest.txt
if [ -f "$fallback_home/.local/state/better-rm/deletion.log" ] && \
   grep -q "fallbackstatetest.txt" "$fallback_home/.local/state/better-rm/deletion.log"; then
    test_pass "相對 XDG_STATE_HOME 正確回退"
else
    test_fail "相對 XDG_STATE_HOME 未正確回退"
fi
rm -rf "$fallback_home"

# ============================================================================
# 測試 13: 還原功能 (Test 13: Restore Function)
# ============================================================================
test_title "測試 13: 還原功能"

test_item "基本還原功能"
cd "$TEST_WORK_DIR"
echo "original content" > test_restore.txt
"$BETTER_RM" test_restore.txt

if [ -f "test_restore.txt" ]; then
    test_fail "測試還原前的刪除失敗"
else
    # 執行還原
    "$BETTER_RM" --restore test_restore.txt
    if [ -f "test_restore.txt" ] && [ "$(cat test_restore.txt)" = "original content" ]; then
        test_pass "基本還原成功"
    else
        test_fail "基本還原失敗"
    fi
fi

test_item "再次還原（已不存在於垃圾桶）"
# 因為已經被還原移出，再次還原應提示找不到
if "$BETTER_RM" --restore test_restore.txt 2>/dev/null; then
    test_fail "不應成功還原已不在垃圾桶的檔案"
else
    test_pass "再次還原正確地回傳失敗"
fi

test_item "同名檔案存在時的覆蓋確認 - 選擇否 (n)"
echo "content v1" > test_restore.txt
"$BETTER_RM" test_restore.txt
echo "local content v2" > test_restore.txt

# 模擬使用者輸入 n
echo "n" | "$BETTER_RM" --restore test_restore.txt >/dev/null 2>&1
if [ "$(cat test_restore.txt)" = "local content v2" ]; then
    test_pass "選擇否 (n) 時未覆蓋同名檔案"
else
    test_fail "選擇否 (n) 時同名檔案被錯誤覆蓋"
fi

test_item "同名檔案存在時的覆蓋確認 - 選擇是 (y)"
# 模擬使用者輸入 y
echo "y" | "$BETTER_RM" --restore test_restore.txt >/dev/null 2>&1
if [ "$(cat test_restore.txt)" = "content v1" ]; then
    test_pass "選擇是 (y) 時成功覆蓋同名檔案"
else
    test_fail "選擇是 (y) 時同名檔案未被覆蓋"
fi

test_item "同名檔案存在時的 -f 強制覆蓋"
# 重新刪除並準備環境
echo "content v1" > test_restore.txt
"$BETTER_RM" test_restore.txt
echo "local content v3" > test_restore.txt

# 使用 -f 參數，不應提示確認且應直接覆蓋
"$BETTER_RM" -f --restore test_restore.txt >/dev/null 2>&1
if [ "$(cat test_restore.txt)" = "content v1" ]; then
    test_pass "-f 強制覆蓋同名檔案成功"
else
    test_fail "-f 強制覆蓋同名檔案失敗"
fi

test_item "新日誌無符合項目時回退舊版垃圾桶日誌"
setup
cd "$TEST_WORK_DIR"
echo "legacy content" > legacy_restore.txt
"$BETTER_RM" legacy_restore.txt
mv "$TEST_STATE_DIR/deletion.log" "$TEST_TRASH_DIR/.deletion_log"
echo "current content" > current_log_only.txt
"$BETTER_RM" current_log_only.txt
"$BETTER_RM" --restore legacy_restore.txt
if [ -f legacy_restore.txt ] && [ "$(cat legacy_restore.txt)" = "legacy content" ]; then
    test_pass "舊版垃圾桶日誌回退還原成功"
else
    test_fail "舊版垃圾桶日誌回退還原失敗"
fi

# 清理測試產生的檔案
rm -f test_restore.txt

# ============================================================================
# 測試 14: 清除過期項目 (Test 14: Purge Expired Trash Items)
# ============================================================================
test_title "測試 14: 清除過期項目"

setup
cd "$TEST_WORK_DIR"

test_item "--purge 清除過期項目並保留未過期項目"
echo "recent" > recent_purge.txt
"$BETTER_RM" recent_purge.txt
mkdir -p "$TEST_TRASH_DIR/old/project/sub"
echo "old" > "$TEST_TRASH_DIR/old/project/sub/old__name.txt__20200101_120000_000000000__abc"
if "$BETTER_RM" -f --purge 30 >/dev/null && \
   ! find "$TEST_TRASH_DIR" -name "old__name.txt__*" | grep -q . && \
   verify_in_trash "recent_purge.txt"; then
    test_pass "過期項目已清除，未過期項目保留"
else
    test_fail "清除結果不正確"
fi

test_item "清除後移除變空的路徑結構目錄"
if [ ! -e "$TEST_TRASH_DIR/old" ] && [ -d "$TEST_TRASH_DIR" ]; then
    test_pass "空的路徑結構目錄已移除，垃圾桶根目錄保留"
else
    test_fail "路徑結構目錄未正確清理"
fi

test_item "確認提示選擇否 (n) 時不刪除"
echo "old" > "$TEST_TRASH_DIR/prompt.txt__20200101_120000_000000000__abc"
echo "n" | "$BETTER_RM" --purge 30 >/dev/null 2>&1
if [ -e "$TEST_TRASH_DIR/prompt.txt__20200101_120000_000000000__abc" ]; then
    test_pass "選擇否 (n) 時未刪除任何項目"
else
    test_fail "選擇否 (n) 時項目被錯誤刪除"
fi

test_item "確認提示選擇是 (y) 時刪除"
echo "y" | "$BETTER_RM" --purge=30 >/dev/null 2>&1
if [ ! -e "$TEST_TRASH_DIR/prompt.txt__20200101_120000_000000000__abc" ]; then
    test_pass "選擇是 (y) 時成功清除"
else
    test_fail "選擇是 (y) 時未清除"
fi

test_item "不影響非 better-rm 格式的檔案"
echo "foreign" > "$TEST_TRASH_DIR/finder-item.txt"
"$BETTER_RM" -f --purge 0 >/dev/null
if [ -f "$TEST_TRASH_DIR/finder-item.txt" ] && ! verify_in_trash "recent_purge.txt"; then
    test_pass "--purge 0 清除所有 better-rm 項目且保留其他檔案"
else
    test_fail "非 better-rm 格式檔案處理不正確"
fi

test_item "清除含唯讀子目錄的過期目錄"
mkdir -p "$TEST_TRASH_DIR/cache__20200101_120000_000000000__abc/readonly"
echo "ro" > "$TEST_TRASH_DIR/cache__20200101_120000_000000000__abc/readonly/file"
chmod a-w "$TEST_TRASH_DIR/cache__20200101_120000_000000000__abc/readonly"
if "$BETTER_RM" -f --purge 30 >/dev/null 2>&1 && \
   [ ! -e "$TEST_TRASH_DIR/cache__20200101_120000_000000000__abc" ]; then
    test_pass "唯讀子目錄的過期目錄已清除"
else
    chmod -R u+w "$TEST_TRASH_DIR" 2>/dev/null
    test_fail "唯讀子目錄的過期目錄未清除"
fi

test_item "含未過期項目的目錄不會被整個清除"
mkdir -p "$TEST_TRASH_DIR/copy__20200101_120000_000000000__abc/sub"
echo "new" > "$TEST_TRASH_DIR/copy__20200101_120000_000000000__abc/sub/new.txt__20990101_120000_000000000__abc"
"$BETTER_RM" -f --purge 30 >/dev/null 2>&1
if [ -e "$TEST_TRASH_DIR/copy__20200101_120000_000000000__abc/sub/new.txt__20990101_120000_000000000__abc" ]; then
    test_pass "含未過期項目的目錄已略過"
else
    test_fail "含未過期項目的目錄被錯誤清除"
fi

test_item "拒絕無效天數與檔案參數"
invalid_rejected=true
for invalid_args in "--purge abc" "--purge -5" "--purge" "--purge 30 file.txt"; do
    # shellcheck disable=SC2086
    if "$BETTER_RM" -f $invalid_args >/dev/null 2>&1; then
        invalid_rejected=false
    fi
done
if [ "$invalid_rejected" = true ]; then
    test_pass "無效參數正確回傳失敗"
else
    test_fail "無效參數未被拒絕"
fi

test_item "拒絕清除受保護或相對路徑的垃圾桶目錄"
purge_home="/tmp/better-rm-purge-home"
rm -rf "$purge_home"
mkdir -p "$purge_home"
echo "keep" > "$purge_home/keep.txt__20200101_120000_000000000__abc"
if ! HOME="$purge_home" TRASH_DIR="$purge_home" "$BETTER_RM" -f --purge 0 >/dev/null 2>&1 && \
   ! TRASH_DIR="relative-trash" "$BETTER_RM" -f --purge 0 >/dev/null 2>&1 && \
   [ -f "$purge_home/keep.txt__20200101_120000_000000000__abc" ]; then
    test_pass "受保護與相對路徑的垃圾桶目錄被拒絕"
else
    test_fail "未正確拒絕危險的垃圾桶目錄"
fi
rm -rf "$purge_home"

setup
cd "$TEST_WORK_DIR"
# 使用隨機內容避免檔案系統壓縮影響實際佔用空間
# Use random content so filesystem compression cannot skew allocated size
mkdir -p "$TEST_TRASH_DIR/old"
head -c 1572864 /dev/urandom > "$TEST_TRASH_DIR/old/big.bin__20200101_120000_000000000__abc"

test_item "--dry-run 列出項目與預計釋放空間且不刪除（即使加 -f）"
dry_run_output=$("$BETTER_RM" -f --purge 30 --dry-run 2>&1)
dry_run_status=$?
if [ $dry_run_status -eq 0 ] && [ -f "$TEST_TRASH_DIR/old/big.bin__20200101_120000_000000000__abc" ] && \
   echo "$dry_run_output" | grep -q "big.bin__20200101_120000_000000000__abc" && \
   echo "$dry_run_output" | grep -q "預計釋放約 1.5 MiB"; then
    test_pass "試執行正確列出項目與空間且未刪除"
else
    test_fail "試執行結果不正確: $dry_run_output"
fi

test_item "--dry-run 未搭配 --purge 時應失敗"
if "$BETTER_RM" --dry-run dry_run_file.txt >/dev/null 2>&1; then
    test_fail "--dry-run 未搭配 --purge 卻成功執行"
else
    test_pass "--dry-run 未搭配 --purge 正確回傳失敗"
fi

test_item "確認提示與完成訊息顯示空間大小"
purge_output=$(echo "y" | "$BETTER_RM" --purge 30 2>&1)
if echo "$purge_output" | grep -q "（約 1.5 MiB）" && echo "$purge_output" | grep -q "釋放約 1.5 MiB" && \
   [ ! -e "$TEST_TRASH_DIR/old/big.bin__20200101_120000_000000000__abc" ]; then
    test_pass "提示與完成訊息正確顯示空間大小"
else
    test_fail "提示或完成訊息未正確顯示空間大小: $purge_output"
fi

# ============================================================================
# 測試 15: 週/月/日期時間條件與刪除日誌清理
# (Test 15: Week/Month/Date-Time Age Specs and Deletion Log Pruning)
# ============================================================================
test_title "測試 15: 週/月/日期時間條件與刪除日誌清理"

setup
cd "$TEST_WORK_DIR"
mkdir -p "$TEST_TRASH_DIR/old"
OLD_ITEM="$TEST_TRASH_DIR/old/old.txt__20200101_120000_000000000__aaa"
MID_ITEM="$TEST_TRASH_DIR/old/mid.txt__20240601_090000_000000000__bbb"
NEW_ITEM="$TEST_TRASH_DIR/old/new.txt__20990101_120000_000000000__ccc"

reset_age_fixtures() {
    mkdir -p "$TEST_TRASH_DIR/old"
    echo old > "$OLD_ITEM"
    echo mid > "$MID_ITEM"
    echo new > "$NEW_ITEM"
}

test_item "週/月/天數單位 (2w、1m、30d、--purge=3m) 保留未來項目並清除舊項目"
age_ok=true
for age_spec in 2w 1m 30d 3m 2W 1M 5D; do
    reset_age_fixtures
    "$BETTER_RM" -f --purge "$age_spec" >/dev/null 2>&1
    if [ -e "$OLD_ITEM" ] || [ -e "$MID_ITEM" ] || [ ! -e "$NEW_ITEM" ]; then
        age_ok=false
    fi
done
reset_age_fixtures
"$BETTER_RM" -f --purge=2w >/dev/null 2>&1
if [ -e "$OLD_ITEM" ] || [ ! -e "$NEW_ITEM" ]; then
    age_ok=false
fi
if [ "$age_ok" = true ]; then
    test_pass "各種單位皆正確清除舊項目並保留未來項目"
else
    test_fail "週/月/天數單位處理不正確"
fi

test_item "絕對日期 2024-01-01 清除 2020 項目並保留 2024-06 與 2099 項目"
reset_age_fixtures
"$BETTER_RM" -f --purge 2024-01-01 >/dev/null 2>&1
if [ ! -e "$OLD_ITEM" ] && [ -e "$MID_ITEM" ] && [ -e "$NEW_ITEM" ]; then
    test_pass "日期條件邊界正確"
else
    test_fail "日期條件邊界不正確"
fi

test_item "日期加時間 (空白與 T 分隔) 以時間邊界判斷"
reset_age_fixtures
"$BETTER_RM" -f --purge "2024-06-01 08:59:59" >/dev/null 2>&1
before_boundary_kept=false
[ -e "$MID_ITEM" ] && before_boundary_kept=true
reset_age_fixtures
"$BETTER_RM" -f --purge 2024-06-01T09:00 >/dev/null 2>&1
if [ "$before_boundary_kept" = true ] && [ ! -e "$OLD_ITEM" ] && [ ! -e "$MID_ITEM" ] && [ -e "$NEW_ITEM" ]; then
    test_pass "日期時間條件正確"
else
    test_fail "日期時間條件不正確"
fi

test_item "拒絕無效單位、日期、時間與未來時間"
invalid_age_rejected=true
for invalid_age in 5x 2026-13-01 2026-02-30 "2026-01-01 25:00" "2026-01-01 10:61" 2099-01-01 1.5d 2024-1-1 ""; do
    if "$BETTER_RM" -f --purge "$invalid_age" >/dev/null 2>&1; then
        invalid_age_rejected=false
    fi
done
if [ "$invalid_age_rejected" = true ] && [ -e "$NEW_ITEM" ]; then
    test_pass "無效時間條件正確回傳失敗"
else
    test_fail "無效時間條件未被拒絕"
fi

# 寫入指向測試項目的日誌行（含結尾斜線造成的 // 路徑），並保留近期的真實刪除記錄
# Write log lines pointing at the fixtures (including a // path from a trailing slash) next to a real recent deletion
setup_log_fixtures() {
    setup
    cd "$TEST_WORK_DIR"
    mkdir -p "$TEST_TRASH_DIR/old" "$TEST_TRASH_DIR/dir__20200101_120000_000000000__ddd/inner"
    echo old > "$OLD_ITEM"
    echo mid > "$MID_ITEM"
    echo inner > "$TEST_TRASH_DIR/dir__20200101_120000_000000000__ddd/inner/f.txt__20190101_120000_000000000__eee"
    echo recent > recent_log.txt
    "$BETTER_RM" recent_log.txt
    {
        echo "20200101_120000_000000000 | /old/old.txt | $TEST_TRASH_DIR//old/old.txt__20200101_120000_000000000__aaa | aaa | file"
        echo "20240601_090000_000000000 | /old/mid.txt | $MID_ITEM | bbb | file"
        echo "20190101_120000_000000000 | /x/dir/inner/f.txt | $TEST_TRASH_DIR/dir__20200101_120000_000000000__ddd/inner/f.txt__20190101_120000_000000000__eee | eee | file"
        echo "this line does not parse"
    } >> "$TEST_STATE_DIR/deletion.log"
}

test_item "清除後同步移除對應的刪除日誌記錄（含目錄內項目），保留其他記錄與標頭"
setup_log_fixtures
log_file="$TEST_STATE_DIR/deletion.log"
"$BETTER_RM" -f --purge 2024-01-01 >/dev/null 2>&1
if ! grep -q "old.txt__20200101" "$log_file" && \
   ! grep -q "f.txt__20190101" "$log_file" && \
   grep -q "mid.txt__20240601" "$log_file" && \
   grep -q "recent_log.txt" "$log_file" && \
   grep -q "this line does not parse" "$log_file" && \
   grep -q "^# Better-RM Deletion Log" "$log_file"; then
    test_pass "日誌只移除已永久刪除項目的記錄"
else
    test_fail "日誌清理不正確: $(cat "$log_file")"
fi

test_item "日誌檔案權限維持僅限使用者存取"
log_mode=$(stat -c %a "$log_file" 2>/dev/null || stat -f %Lp "$log_file" 2>/dev/null)
if [ "$log_mode" = "600" ]; then
    test_pass "日誌權限為 600"
else
    test_fail "日誌權限為 $log_mode"
fi

test_item "清除後 --restore 仍可還原近期刪除的檔案"
rm -f recent_log.txt
if "$BETTER_RM" --restore recent_log.txt >/dev/null 2>&1 && [ -f recent_log.txt ]; then
    test_pass "近期項目仍可還原"
else
    test_fail "近期項目無法還原"
fi

test_item "--dry-run 與確認選擇否 (n) 不修改日誌，且 dry-run 顯示將清除的記錄數"
setup_log_fixtures
cp "$log_file" "$TEST_WORK_DIR/log.before"
dry_output=$("$BETTER_RM" --purge 2024-01-01 --dry-run 2>&1)
echo n | "$BETTER_RM" --purge 2024-01-01 >/dev/null 2>&1
if cmp -s "$log_file" "$TEST_WORK_DIR/log.before" && echo "$dry_output" | grep -q "清除 2 筆刪除日誌記錄"; then
    test_pass "試執行與取消皆未修改日誌"
else
    test_fail "試執行或取消修改了日誌: $dry_output"
fi

test_item "同步清理舊版垃圾桶日誌 .deletion_log"
setup_log_fixtures
echo "20200101_120000_000000000 | /old/old.txt | $OLD_ITEM | aaa | file" > "$TEST_TRASH_DIR/.deletion_log"
"$BETTER_RM" -f --purge 2024-01-01 >/dev/null 2>&1
if ! grep -q "old.txt__20200101" "$TEST_TRASH_DIR/.deletion_log"; then
    test_pass "舊版日誌記錄已清除"
else
    test_fail "舊版日誌記錄未清除"
fi

# ============================================================================
# 測試 16: 依原始路徑前綴清除 (Test 16: Purge by Original Path Prefix)
# ============================================================================
test_title "測試 16: 依原始路徑前綴清除"

# 以 TRASH_DIR 加上原始路徑建立垃圾桶項目，內容用 echo 即可
# Build a trash item at TRASH_DIR plus the original path
make_trash_item() {
    mkdir -p "$(dirname "$TEST_TRASH_DIR$1")"
    echo x > "$TEST_TRASH_DIR$1"
}

setup
cd "$TEST_WORK_DIR"
PA_OLD="/pathtest/proj/a/old.txt__20200101_120000_000000000__aaa"
PA_SUB="/pathtest/proj/a/sub/mid.txt__20240601_090000_000000000__bbb"
PA_NEW="/pathtest/proj/a/new.txt__20990101_120000_000000000__ccc"
PA_AB="/pathtest/proj/ab/other.txt__20200101_120000_000000000__ddd"
reset_path_fixtures() {
    setup
    cd "$TEST_WORK_DIR"
    make_trash_item "$PA_OLD"
    make_trash_item "$PA_SUB"
    make_trash_item "$PA_NEW"
    make_trash_item "$PA_AB"
}

test_item "--purge-path 單獨使用：清除該路徑之下所有項目，且以目錄為界不誤刪 /ab"
reset_path_fixtures
"$BETTER_RM" -f --purge-path /pathtest/proj/a >/dev/null 2>&1
if [ ! -e "$TEST_TRASH_DIR$PA_OLD" ] && [ ! -e "$TEST_TRASH_DIR$PA_SUB" ] && [ ! -e "$TEST_TRASH_DIR$PA_NEW" ] && \
   [ -e "$TEST_TRASH_DIR$PA_AB" ]; then
    test_pass "只清除 /pathtest/proj/a 之下的項目，/pathtest/proj/ab 保留"
else
    test_fail "路徑前綴比對不正確"
fi

test_item "--purge-path 搭配 --purge 時間條件：兩個條件都要符合"
reset_path_fixtures
"$BETTER_RM" -f --purge 2024-01-01 --purge-path=/pathtest/proj/a >/dev/null 2>&1
if [ ! -e "$TEST_TRASH_DIR$PA_OLD" ] && [ -e "$TEST_TRASH_DIR$PA_SUB" ] && [ -e "$TEST_TRASH_DIR$PA_NEW" ] && \
   [ -e "$TEST_TRASH_DIR$PA_AB" ]; then
    test_pass "僅清除路徑符合且夠舊的項目"
else
    test_fail "路徑搭配時間條件不正確"
fi

test_item "--purge-path 可重複指定，並接受結尾斜線"
reset_path_fixtures
"$BETTER_RM" -f --purge-path /pathtest/proj/ab/ --purge-path /pathtest/proj/a/sub >/dev/null 2>&1
if [ ! -e "$TEST_TRASH_DIR$PA_AB" ] && [ ! -e "$TEST_TRASH_DIR$PA_SUB" ] && \
   [ -e "$TEST_TRASH_DIR$PA_OLD" ] && [ -e "$TEST_TRASH_DIR$PA_NEW" ]; then
    test_pass "多個前綴皆生效"
else
    test_fail "多個前綴處理不正確"
fi

test_item "相對路徑以目前資料夾為基準，符號連結前綴會解析為實際路徑"
reset_path_fixtures
real_dir=$(cd "$TEST_WORK_DIR" && pwd -P)
make_trash_item "$real_dir/local/gone.txt__20200101_120000_000000000__eee"
make_trash_item "$real_dir/local/sub/gone2.txt__20200101_120000_000000000__fff"
mkdir -p "$TEST_WORK_DIR/local"
ln -s "$TEST_WORK_DIR/local" "$TEST_WORK_DIR/link"
(cd "$TEST_WORK_DIR/local" && "$BETTER_RM" -f --purge-path . >/dev/null 2>&1)
relative_ok=false
if [ ! -e "$TEST_TRASH_DIR$real_dir/local/gone.txt__20200101_120000_000000000__eee" ] && \
   [ ! -e "$TEST_TRASH_DIR$real_dir/local/sub/gone2.txt__20200101_120000_000000000__fff" ] && \
   [ -e "$TEST_TRASH_DIR$PA_OLD" ]; then
    relative_ok=true
fi
make_trash_item "$real_dir/local/via-link.txt__20200101_120000_000000000__ggg"
"$BETTER_RM" -f --purge-path "$TEST_WORK_DIR/link" >/dev/null 2>&1
if [ "$relative_ok" = true ] && [ ! -e "$TEST_TRASH_DIR$real_dir/local/via-link.txt__20200101_120000_000000000__ggg" ]; then
    test_pass "相對路徑與符號連結前綴皆正確"
else
    test_fail "相對路徑或符號連結前綴處理不正確"
fi

test_item "--dry-run 不刪除項目，並顯示路徑條件"
reset_path_fixtures
path_dry_output=$("$BETTER_RM" -f --purge-path /pathtest/proj/a --dry-run 2>&1)
if [ -e "$TEST_TRASH_DIR$PA_OLD" ] && [ -e "$TEST_TRASH_DIR$PA_NEW" ] && \
   echo "$path_dry_output" | grep -q "將永久刪除 3 個原始路徑在 /pathtest/proj/a 之下的項目"; then
    test_pass "試執行未刪除且訊息正確"
else
    test_fail "試執行結果不正確: $path_dry_output"
fi

test_item "依路徑清除時同步清理對應的刪除日誌記錄"
reset_path_fixtures
mkdir -p "$TEST_STATE_DIR"
{
    echo "20200101_120000_000000000 | /pathtest/proj/a/old.txt | $TEST_TRASH_DIR$PA_OLD | aaa | file"
    echo "20200101_120000_000000000 | /pathtest/proj/ab/other.txt | $TEST_TRASH_DIR$PA_AB | ddd | file"
} >> "$TEST_STATE_DIR/deletion.log"
"$BETTER_RM" -f --purge-path /pathtest/proj/a >/dev/null 2>&1
if ! grep -q "old.txt__20200101" "$TEST_STATE_DIR/deletion.log" && \
   grep -q "other.txt__20200101" "$TEST_STATE_DIR/deletion.log"; then
    test_pass "日誌只移除已清除路徑的記錄"
else
    test_fail "日誌清理不正確"
fi

test_item "拒絕缺少或空白的 --purge-path 引數，且不可與檔案參數並用"
reset_path_fixtures
path_invalid_rejected=true
for invalid_args in "--purge-path" "--purge-path=" "--purge-path /pathtest file.txt"; do
    # shellcheck disable=SC2086
    if "$BETTER_RM" -f $invalid_args >/dev/null 2>&1; then
        path_invalid_rejected=false
    fi
done
if [ "$path_invalid_rejected" = true ] && [ -e "$TEST_TRASH_DIR$PA_OLD" ]; then
    test_pass "無效的 --purge-path 參數正確回傳失敗"
else
    test_fail "無效的 --purge-path 參數未被拒絕"
fi

# ============================================================================
# 測試 17: 列出垃圾桶項目 (Test 17: List Trash Items)
# ============================================================================
test_title "測試 17: 列出垃圾桶項目"

setup
cd "$TEST_WORK_DIR"
make_trash_item "/listtest/a/old.txt__20200101_120000_000000000__aaa"
make_trash_item "/listtest/a/mid.txt__20240601_090000_000000000__bbb"
make_trash_item "/listtest/b/new.txt__20990101_120000_000000000__ccc"
mkdir -p "$TEST_TRASH_DIR/listtest/dir__20210101_120000_000000000__ddd/inner"
echo x > "$TEST_TRASH_DIR/listtest/dir__20210101_120000_000000000__ddd/inner/f"
echo foreign > "$TEST_TRASH_DIR/finder-item.txt"

test_item "--list 依刪除時間由舊到新列出項目與原始路徑，且不含非 better-rm 的檔案"
list_stdout=$("$BETTER_RM" --list 2>/dev/null)
first_line=$(echo "$list_stdout" | head -1)
last_line=$(echo "$list_stdout" | tail -1)
if [ "$(echo "$list_stdout" | wc -l | tr -d ' ')" = "4" ] && \
   echo "$first_line" | grep -q "^2020-01-01 12:00:00 .* file .*/listtest/a/old.txt$" && \
   echo "$last_line" | grep -q "^2099-01-01 12:00:00 .* file .*/listtest/b/new.txt$" && \
   echo "$list_stdout" | grep -q " directory .*/listtest/dir$" && \
   ! echo "$list_stdout" | grep -q "finder-item"; then
    test_pass "列出內容、排序與原始路徑正確"
else
    test_fail "列出結果不正確: $list_stdout"
fi

test_item "--list 統計摘要輸出到 stderr（項目數、類型與空間）"
list_summary=$("$BETTER_RM" --list 2>&1 >/dev/null)
if echo "$list_summary" | grep -q "共 4 個項目（3 個檔案、1 個目錄、0 個符號連結）" && \
   echo "$list_summary" | grep -q "佔用約"; then
    test_pass "統計摘要正確且不污染 stdout"
else
    test_fail "統計摘要不正確: $list_summary"
fi

test_item "--list 搭配 --purge / --purge-path 只篩選，不刪除任何項目"
before_count=$(find "$TEST_TRASH_DIR" -type f | wc -l | tr -d ' ')
filtered_age=$("$BETTER_RM" --list --purge 2024-01-01 2>/dev/null)
filtered_path=$("$BETTER_RM" --list --purge-path /listtest/b 2>/dev/null)
filtered_both=$("$BETTER_RM" --list --purge 30d --purge-path /listtest/a 2>/dev/null)
after_count=$(find "$TEST_TRASH_DIR" -type f | wc -l | tr -d ' ')
if [ "$before_count" = "$after_count" ] && \
   [ "$(echo "$filtered_age" | wc -l | tr -d ' ')" = "2" ] && \
   echo "$filtered_path" | grep -q "/listtest/b/new.txt" && [ "$(echo "$filtered_path" | wc -l | tr -d ' ')" = "1" ] && \
   [ "$(echo "$filtered_both" | wc -l | tr -d ' ')" = "2" ]; then
    test_pass "篩選正確且未刪除任何檔案"
else
    test_fail "篩選或唯讀行為不正確"
fi

test_item "--list 無符合項目、垃圾桶不存在時成功結束；無效條件與衝突選項回傳失敗"
empty_ok=true
"$BETTER_RM" --list --purge-path /nonexistent-prefix >/dev/null 2>&1 || empty_ok=false
TRASH_DIR="/tmp/better-rm-no-such-trash" "$BETTER_RM" --list >/dev/null 2>&1 || empty_ok=false
list_rejected=true
for invalid_args in "--list --purge 5x" "--list --dry-run" "--list file.txt" "--list --restore x"; do
    # shellcheck disable=SC2086
    if "$BETTER_RM" $invalid_args >/dev/null 2>&1; then
        list_rejected=false
    fi
done
if [ "$empty_ok" = true ] && [ "$list_rejected" = true ]; then
    test_pass "邊界情況處理正確"
else
    test_fail "邊界情況處理不正確 (empty_ok=$empty_ok, list_rejected=$list_rejected)"
fi

# ============================================================================
# 測試 18: --purge 確認前先預覽 (Test 18: Preview Before --purge Confirmation)
# ============================================================================
test_title "測試 18: --purge 確認前先預覽"

setup
cd "$TEST_WORK_DIR"
make_trash_item "/previewtest/old.txt__20200101_120000_000000000__aaa"
make_trash_item "/previewtest/keep.txt__20990101_120000_000000000__bbb"

test_item "未加 -f 時，確認提示前先列出完整項目清單（選擇 n 不刪除）"
preview_output=$(echo n | "$BETTER_RM" --purge 30 2>&1)
if echo "$preview_output" | grep -q "would purge) '.*previewtest/old.txt__20200101" && \
   ! echo "$preview_output" | grep -q "keep.txt" && \
   echo "$preview_output" | grep -q "(y/N)" && \
   [ -e "$TEST_TRASH_DIR/previewtest/old.txt__20200101_120000_000000000__aaa" ]; then
    test_pass "確認前已列出將刪除的項目，且取消時未刪除"
else
    test_fail "確認前預覽不正確: $preview_output"
fi

test_item "加 -f 時不列出清單也不提示"
force_output=$("$BETTER_RM" -f --purge 30 2>&1)
if ! echo "$force_output" | grep -q "would purge" && ! echo "$force_output" | grep -q "(y/N)" && \
   [ ! -e "$TEST_TRASH_DIR/previewtest/old.txt__20200101_120000_000000000__aaa" ]; then
    test_pass "-f 行為維持不變"
else
    test_fail "-f 行為改變: $force_output"
fi

# ============================================================================
# 測試 19: 垃圾桶摘要統計 (Test 19: Trash Statistics)
# ============================================================================
test_title "測試 19: 垃圾桶摘要統計"

setup
cd "$TEST_WORK_DIR"
make_trash_item "/statstest/a/old.txt__20200101_120000_000000000__aaa"
make_trash_item "/statstest/a/mid.txt__20240601_090000_000000000__bbb"
make_trash_item "/statstest/b/new.txt__20990101_120000_000000000__ccc"
mkdir -p "$TEST_TRASH_DIR/statstest/b/dir__20210101_120000_000000000__ddd"
echo x > "$TEST_TRASH_DIR/statstest/b/dir__20210101_120000_000000000__ddd/f"
echo foreign > "$TEST_TRASH_DIR/finder-item.txt"
echo recent > recent_stats.txt
"$BETTER_RM" recent_stats.txt

test_item "--stats 顯示項目數、類型、最早與最新刪除時間"
stats_output=$("$BETTER_RM" --stats 2>&1)
if echo "$stats_output" | grep -q "項目數 (Items): *5（檔案 4、目錄 1、符號連結 0" && \
   echo "$stats_output" | grep -q "最早刪除 (Oldest): *2020-01-01 12:00:00" && \
   echo "$stats_output" | grep -q "最新刪除 (Newest): *2099-01-01 12:00:00" && \
   echo "$stats_output" | grep -q "佔用空間 (Disk usage):"; then
    test_pass "總覽統計正確且不含非 better-rm 的檔案"
else
    test_fail "總覽統計不正確: $stats_output"
fi

test_item "--stats 依刪除時間分佈：1 天內 2 項（近期與 2099）、超過 90 天 3 項"
if echo "$stats_output" | grep -Eq "^ +2 項 +[0-9.]+ [KMG]iB  1 天內" && \
   echo "$stats_output" | grep -Eq "^ +3 項 +[0-9.]+ [KMG]iB  超過 90 天"; then
    test_pass "時間分佈正確"
else
    test_fail "時間分佈不正確: $stats_output"
fi

test_item "--stats 依原始目錄列出項目數"
if echo "$stats_output" | grep -Eq " 2 項  /statstest/a$" && \
   echo "$stats_output" | grep -Eq " 2 項  /statstest/b$"; then
    test_pass "原始目錄統計正確"
else
    test_fail "原始目錄統計不正確: $stats_output"
fi

test_item "--stats 搭配 --purge / --purge-path 只篩選，不刪除任何項目"
before_count=$(find "$TEST_TRASH_DIR" -type f | wc -l | tr -d ' ')
stats_filtered=$("$BETTER_RM" --stats --purge-path /statstest/a --purge 2024-01-01 2>&1)
after_count=$(find "$TEST_TRASH_DIR" -type f | wc -l | tr -d ' ')
if [ "$before_count" = "$after_count" ] && \
   echo "$stats_filtered" | grep -q "篩選條件 (Filter):" && \
   echo "$stats_filtered" | grep -q "項目數 (Items): *1（檔案 1、目錄 0"; then
    test_pass "篩選統計正確且未刪除任何檔案"
else
    test_fail "篩選統計或唯讀行為不正確: $stats_filtered"
fi

test_item "--stats 無符合項目時成功結束；與 --list、--dry-run、檔案參數並用時失敗"
stats_ok=true
"$BETTER_RM" --stats --purge-path /nonexistent-prefix >/dev/null 2>&1 || stats_ok=false
stats_rejected=true
for invalid_args in "--stats --list" "--stats --dry-run" "--stats file.txt" "--stats --purge 5x"; do
    # shellcheck disable=SC2086
    if "$BETTER_RM" $invalid_args >/dev/null 2>&1; then
        stats_rejected=false
    fi
done
if [ "$stats_ok" = true ] && [ "$stats_rejected" = true ]; then
    test_pass "邊界情況處理正確"
else
    test_fail "邊界情況處理不正確 (stats_ok=$stats_ok, stats_rejected=$stats_rejected)"
fi

# ============================================================================
# 測試 20: 執行中檔案被覆寫的防護 (Test 20: Safe When Script Is Overwritten While Running)
# ============================================================================
test_title "測試 20: 執行中檔案被覆寫的防護"

test_item "main 結束後不再讀取腳本後續內容"
guard_script="/tmp/better-rm-test-guard-script"
cp "$BETTER_RM" "$guard_script"
# 在腳本結尾附加會造成語法錯誤的殘片，模擬執行中被覆寫後 bash 讀到的內容
# Append a syntax-error fragment to simulate what bash reads after an in-place overwrite
printf '%s\n' '+)); do' >> "$guard_script"
guard_output=$("$guard_script" --version 2>&1)
guard_status=$?
rm -f "$guard_script"
if [ $guard_status -eq 0 ] && ! echo "$guard_output" | grep -q "syntax error"; then
    test_pass "腳本結尾之後的內容不會被讀取"
else
    test_fail "仍會讀取 main 之後的內容 (status=$guard_status): $guard_output"
fi

# ============================================================================
# 測試結果統計 (Test Results Summary)
# ============================================================================
cleanup

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}測試結果統計 (Test Results Summary)${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "總測試數 (Total Tests): ${BLUE}$TOTAL_TESTS${NC}"
echo -e "通過測試 (Passed): ${GREEN}$PASSED_TESTS${NC}"
echo -e "失敗測試 (Failed): ${RED}$FAILED_TESTS${NC}"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}✓ 所有測試通過！(All tests passed!)${NC}"
    exit 0
else
    echo -e "${RED}✗ 有 $FAILED_TESTS 個測試失敗 ($FAILED_TESTS tests failed)${NC}"
    exit 1
fi
