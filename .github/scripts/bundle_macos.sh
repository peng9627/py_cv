#!/bin/bash
# -----------------------------------------------------------------------------
# macOS 依赖项递归打包脚本 (v7 - 符号链接修复版)
# -----------------------------------------------------------------------------
set -e

RELEASE_DIR="release"
SCANNER_EXE="$RELEASE_DIR/wechat_scanner"

echo "--- Starting recursive dependency bundling for $SCANNER_EXE ---"

# --- 步骤 1: 递归查找所有非系统依赖 ---
ALL_LIBS=()
LIBS_TO_PROCESS=()
PROCESSED_LIBS=() # 用于防止重复处理

# 首先找到主程序的直接依赖
INITIAL_DEPS=$(otool -L "$SCANNER_EXE" | grep -v -E '/usr/lib/|/System/Library/' | tail -n +2 | awk '{print $1}')
LIBS_TO_PROCESS+=($INITIAL_DEPS)

while [ ${#LIBS_TO_PROCESS[@]} -gt 0 ]; do
  CURRENT_LIB=${LIBS_TO_PROCESS[0]}
  LIBS_TO_PROCESS=("${LIBS_TO_PROCESS[@]:1}")

  if [[ " ${PROCESSED_LIBS[@]} " =~ " ${CURRENT_LIB} " ]]; then
    continue
  fi
  PROCESSED_LIBS+=("$CURRENT_LIB")

  echo "Found dependency: $CURRENT_LIB"
  ALL_LIBS+=("$CURRENT_LIB")

  # 查找当前库自身的依赖，并将它们也加入“待处理”列表
  NEW_DEPS=$(otool -L "$CURRENT_LIB" | grep -v -E '/usr/lib/|/System/Library/' | tail -n +2 | awk '{print $1}' || true)
  if [ -n "$NEW_DEPS" ]; then
    LIBS_TO_PROCESS+=($NEW_DEPS)
  fi
done

# --- 步骤 1.5: 针对 webp 的特殊处理 (保留，以防万一) ---
echo "--- Force-adding all libraries from webp package as a workaround (if not already found) ---"
WEBP_LIB_DIR=$(brew --prefix webp)/lib
if [ -d "$WEBP_LIB_DIR" ]; then
  for lib_full_path in "$WEBP_LIB_DIR"/*.dylib; do
    lib_name=$(basename "$lib_full_path")
    # 检查是否已经存在于 ALL_LIBS 中 (通过 basename 比较)
    found_in_all_libs=0
    for existing_lib_path in "${ALL_LIBS[@]}"; do
      if [ "$(basename "$existing_lib_path")" == "$lib_name" ]; then
        found_in_all_libs=1
        break
      fi
    done

    if [ $found_in_all_libs -eq 0 ]; then
      echo "Adding webp dependency: $lib_full_path"
      ALL_LIBS+=("$lib_full_path")
    fi
  done
fi

echo "--- Full list of libraries to bundle ---"
printf '%s\n' "${ALL_LIBS[@]}"

# --- 步骤 2: 拷贝所有找到的库并处理符号链接 ---
echo "--- Copying all found libraries and recreating necessary symlinks in $RELEASE_DIR ---"
for lib_path in "${ALL_LIBS[@]}"; do
  if [ -e "$lib_path" ]; then
    # 获取实际文件路径 (如果 lib_path 是符号链接，则获取其目标)
    actual_file_path=$(readlink -f "$lib_path" || echo "$lib_path")
    actual_filename=$(basename "$actual_file_path")

    # 复制实际文件到 release 目录
    cp -f "$actual_file_path" "$RELEASE_DIR/$actual_filename"
    echo "Copied: $actual_file_path -> $RELEASE_DIR/$actual_filename"

    # 如果原始 lib_path 是一个符号链接，则在 release 目录中重新创建它
    if [ "$lib_path" != "$actual_file_path" ]; then
      symlink_name=$(basename "$lib_path")
      # 确保符号链接指向我们刚刚复制的实际文件
      ln -sf "$actual_filename" "$RELEASE_DIR/$symlink_name"
      echo "Recreated symlink: $RELEASE_DIR/$symlink_name -> $actual_filename"
    fi
  else
    echo "Warning: Library path does not exist, skipping copy: $lib_path"
  fi
done

# --- 步骤 3: 修复所有文件中的引用路径 ---
echo "--- Fixing library reference paths (Optimized) ---"

FILES_TO_PATCH=("$SCANNER_EXE")
# 遍历 release 目录中的所有 .dylib 文件和可执行文件，加入到待修补列表
for file in "$RELEASE_DIR"/*.dylib "$SCANNER_EXE"; do
  if [ -f "$file" ]; then
    FILES_TO_PATCH+=("$file")
  fi
done

for file_to_patch in "${FILES_TO_PATCH[@]}"; do
  if [ ! -f "$file_to_patch" ]; then continue; fi

  echo "--- Patching dependencies for: $(basename "$file_to_patch") ---"
  chmod +w "$file_to_patch"

  # 获取当前文件引用的所有非系统依赖
  DEPS_TO_REMAP=$(otool -L "$file_to_patch" | grep -v -E '/usr/lib/|/System/Library/' | tail -n +2 | awk '{print $1}' || true)
  if [ -z "$DEPS_TO_REMAP" ]; then
    echo "No external dependencies to patch."
    continue
  fi

  for dep_path in $DEPS_TO_REMAP; do
    dep_name=$(basename "$dep_path")
    # 检查 release 目录中是否存在这个 dep_name (可能是实际文件或符号链接)
    if [ -e "$RELEASE_DIR/$dep_name" ]; then
      echo "Remapping '$dep_path' -> '@executable_path/$dep_name'"
      install_name_tool -change "$dep_path" "@executable_path/$dep_name" "$file_to_patch"
    else
      echo "Warning: Referenced dependency '$dep_name' not found in $RELEASE_DIR. Skipping remapping for this dependency in $file_to_patch."
    fi
  done
done

echo "--- Final dependencies of wechat_scanner ---"
otool -L "$SCANNER_EXE"
echo "--- Bundle process complete. ---"
