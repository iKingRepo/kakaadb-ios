#!/usr/bin/env bash
# 从 iKingRepo/libadb-ios 的 Actions artifact 取回 libadb（iOS arm64 静态库 + adb_public.h）
#
# 为什么不在 CI 里现场编译 adb-mobile：
#   那套 make 要拉 protobuf v28.3 / abseil / brotli / lz4 / zstd 全套子模块，
#   还要给 CMake 4 打 zstd 补丁，历史上每次都要调 5~10 轮才绿。
# 为什么不用本地 zip：
#   本机留存的 dist 包与 CI artifact 可能不是同一次构建（protobuf 运行时是否打进去会有差异），
#   直接取 Actions artifact 才是「我们线上验证过能链接成功」的那一份。
set -euo pipefail

REPO="iKingRepo/libadb-ios"
ARTIFACT="libadb-ios-arm64"
DEST_LIB="Vendor/lib"
DEST_INC="Vendor/include"

mkdir -p "$DEST_LIB" "$DEST_INC"

GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
if [[ -z "${GH_TOKEN}" ]]; then
  echo "::error::缺少 token（secrets.LIBADB_TOKEN 未配置）"
  exit 1
fi

echo "==> 查询 artifact"
ARTIFACT_ID=$(curl -sL \
  -H "Authorization: token ${GH_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${REPO}/actions/artifacts?per_page=30" \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
for a in d.get('artifacts', []):
    if a.get('name') == '${ARTIFACT}' and not a.get('expired'):
        print(a['id']); break
")

if [[ -z "${ARTIFACT_ID}" ]]; then
  echo "::error::找不到有效的 ${ARTIFACT} 产物"
  exit 1
fi
echo "    artifact id = ${ARTIFACT_ID}"

echo "==> 下载"
# artifact zip 会 302 到 Azure Blob，重定向后的 URL 自带签名，不能再带 Authorization
curl -sL -H "Authorization: token ${GH_TOKEN}" \
  "https://api.github.com/repos/${REPO}/actions/artifacts/${ARTIFACT_ID}/zip" \
  -o /tmp/libadb.zip
ls -lh /tmp/libadb.zip

echo "==> 解包"
rm -rf /tmp/libadb && mkdir -p /tmp/libadb
unzip -q -o /tmp/libadb.zip -d /tmp/libadb

LIB=$(find /tmp/libadb -name 'libadb-full.a' | head -1)
if [[ -z "$LIB" ]]; then
  echo "::error::压缩包内没有 libadb-full.a"; ls -laR /tmp/libadb; exit 1
fi
cp -v "$LIB" "$DEST_LIB/libadb.a"

if [[ -d /tmp/libadb/include ]]; then
  cp -Rv /tmp/libadb/include/. "$DEST_INC/"
fi

echo "==> 校验"
test -f "$DEST_LIB/libadb.a"
test -f "$DEST_INC/adb_public.h"
grep -q "adb_commandline_porting" "$DEST_INC/adb_public.h"
# protobuf 运行时必须在库里，否则链接期会报 MessageLite 未定义
if ! grep -qa "message_lite.cc.o" "$DEST_LIB/libadb.a"; then
  echo "::warning::该 libadb 产物不含 protobuf 运行时对象（message_lite.cc.o），链接可能失败"
fi
ls -lh "$DEST_LIB/libadb.a" "$DEST_INC/adb_public.h"
echo "==> libadb 就绪"
