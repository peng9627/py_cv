#!/bin/bash
# -----------------------------------------------------------------------------
# macOS 依赖项递归打包脚本 (v5 - 终极健壮版)
# -----------------------------------------------------------------------------
set -e

RELEASE_DIR="release"
SCANNER_EXE="$RELEASE_DIR/wechat_scanner"

echo "--- Starting recursive dependency bundling for $SCANNER_EXE ---"

# --- 步骤 1: 递归查找所有非系统依赖 ---
ALL_LIBS=()
LIBS_TO_PROCESS=()

# 【修复】使用“排除法”来查找所有非系统库，更健壮
# 首先找到主程序的直接依赖
INITIAL_DEPS=$(otool -L "$SCANNER_EXE" | grep -v -E '/usr/lib/|/System/Library/' | tail -n +2 | awk '{print $1}')
LIBS_TO_PROCESS+=($INITIAL_DEPS)

while [ ${#LIBS_TO_PROCESS[@]} -gt 0 ]; do
  CURRENT_LIB=${LIBS_TO_PROCESS[0]}
  LIBS_TO_PROCESS=("${LIBS_TO_PROCESS[@]:1}")

  if [[ " ${ALL_LIBS[@]} " =~ " ${CURRENT_LIB} " ]]; then
    continue
  fi

  echo "Found dependency: $CURRENT_LIB"
  ALL_LIBS+=("$CURRENT_LIB")

  # 查找当前库自身的依赖，并将它们也加入“待处理”列表
  NEW_DEPS=$(otool -L "$CURRENT_LIB" | grep -v -E '/usr/lib/|/System/Library/' | tail -n +2 | awk '{print $1}' || true)
  if [ -n "$NEW_DEPS" ]; then
    LIBS_TO_PROCESS+=($NEW_DEPS)
  fi
done

echo "--- Full list of libraries to bundle ---"
printf '%s\n' "${ALL_LIBS[@]}"

# --- 步骤 2: 拷贝所有找到的库 ---
for lib_path in "${ALL_LIBS[@]}"; do
  if [ -e "$lib_path" ]; then
    cp -fL "$lib_path" "$RELEASE_DIR/"
  else
    echo "Warning: Library path does not exist, skipping copy: $lib_path"
  fi
done

# --- 步骤 3: 修复所有文件中的引用路径 ---
echo "--- Fixing library reference paths (Optimized) ---"

FILES_TO_PATCH=("$SCANNER_EXE")
for lib_path in "${ALL_LIBS[@]}"; do
  lib_name=$(basename "$lib_path")
  FILES_TO_PATCH+=("$RELEASE_DIR/$lib_name")
done

for file_to_patch in "${FILES_TO_PATCH[@]}"; do
  if [ ! -f "$file_to_patch" ]; then continue; fi

  echo "--- Patching dependencies for: $(basename "$file_to_patch") ---"
  chmod +w "$file_to_patch"

  DEPS_TO_REMAP=$(otool -L "$file_to_patch" | grep -v -E '/usr/lib/|/System/Library/' | tail -n +2 | awk '{print $1}' || true)
  if [ -z "$DEPS_TO_REMAP" ]; then
    echo "No external dependencies to patch."
    continue
  fi

  for dep_path in $DEPS_TO_REMAP; do
    dep_name=$(basename "$dep_path")
    echo "Remapping '$dep_path' -> '@executable_path/$dep_name'"
    install_name_tool -change "$dep_path" "@executable_path/$dep_name" "$file_to_patch"
  done
done

echo "--- Final dependencies of wechat_scanner ---"
otool -L "$SCANNER_EXE"
echo "--- Bundle process complete. ---"
