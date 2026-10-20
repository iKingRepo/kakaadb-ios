#!/usr/bin/env bash
# 取回预编译的 libadb（iOS arm64 静态库 + adb_public.h）
#
# 为什么不在 CI 里现场编译 adb-mobile：
#   那套 make 流程要拉 protobuf v28.3 / abseil / brotli / lz4 / zstd 全套子模块，
#   还要给 CMake 4 打 zstd 补丁，历史上每次都要调 5~10 轮才绿。
#   本仓库直接把已经编好的产物挂在 Release 资产上，构建 2 分钟出 IPA。
set -euo pipefail

ASSET_URL="${LIBADB_ASSET_URL:-https://github.com/iKingRepo/kakaadb-ios/releases/download/libadb/libadb-ios-arm64.zip}"

mkdir -p Vendor/lib Vendor/include

echo "==> 下载预编译 libadb"
echo "    $ASSET_URL"
curl -fSL --retry 3 --retry-delay 2 "$ASSET_URL" -o /tmp/libadb.zip

echo "==> 解包"
rm -rf /tmp/libadb && mkdir -p /tmp/libadb
unzip -q -o /tmp/libadb.zip -d /tmp/libadb

find /tmp/libadb -maxdepth 2 -type f | head -10

LIB=$(find /tmp/libadb -name 'libadb-full.a' -o -name 'libadb.a' | head -1)
if [[ -z "$LIB" ]]; then
  echo "::error::压缩包里没有 libadb-full.a / libadb.a"
  ls -laR /tmp/libadb
  exit 1
fi

cp -v "$LIB" Vendor/lib/libadb.a

INC=$(find /tmp/libadb -name 'adb_public.h' | head -1)
if [[ -z "$INC" ]]; then
  # 兜底：压缩包里 include/ 被拍平的情况
  INC=$(find /tmp/libadb -name 'adb_public.h' -o -name '*.h' | head -1)
fi
if [[ -z "$INC" ]]; then
  echo "::error::找不到 adb_public.h"
  exit 1
fi
cp -v "$INC" Vendor/include/adb_public.h

echo "==> 校验"
test -f Vendor/lib/libadb.a
test -f Vendor/include/adb_public.h
grep -q "adb_commandline_porting" Vendor/include/adb_public.h
ls -lh Vendor/lib/libadb.a Vendor/include/adb_public.h
echo "==> libadb 就绪"
