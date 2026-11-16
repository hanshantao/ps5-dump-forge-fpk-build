#!/usr/bin/env bash
# 用法: FNPACK_BIN=/path/fnpack ci/build-fpk.sh <binary> <x86_64|arm64> <upstream-build-version> <out-dir>
set -euo pipefail

BIN="${1:?缺少二进制路径}"
ARCH="${2:?缺少架构}"
BUILD_VER="${3:?缺少构建版本，例如 0.5.5-23}"
OUT_DIR="${4:?缺少输出目录}"
FNPACK_BIN="${FNPACK_BIN:?缺少 FNPACK_BIN}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

[ -x "$FNPACK_BIN" ] || { echo "fnpack 不可执行: $FNPACK_BIN" >&2; exit 1; }
[ -f "$BIN" ] || { echo "二进制不存在: $BIN" >&2; exit 1; }
case "$ARCH" in
  x86_64) PLATFORM=x86; EXPECT_MACHINE="Advanced Micro Devices X86-64" ;;
  arm64) PLATFORM=arm; EXPECT_MACHINE=AArch64 ;;
  *) echo "不支持的架构: $ARCH" >&2; exit 1 ;;
esac
elf_machine() {
  if command -v readelf >/dev/null 2>&1; then
    readelf -h "$1" | sed -n 's/^ *Machine: *//p'
  else
    case "$(file -b "$1")" in
      *x86-64*) echo "Advanced Micro Devices X86-64" ;;
      *aarch64*|*arm64*) echo AArch64 ;;
    esac
  fi
}
MACHINE=$(elf_machine "$BIN")
[ "$MACHINE" = "$EXPECT_MACHINE" ] || { echo "二进制架构不匹配: $MACHINE" >&2; exit 1; }

# FPK 版本只能可靠比较前三段：0.5.5-23 -> 0.5.523。
if [[ "$BUILD_VER" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)-([0-9]+)$ ]]; then
  FPK_VERSION="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.$((10#${BASH_REMATCH[3]} * 100 + 10#${BASH_REMATCH[4]}))"
else
  echo "非法构建版本: $BUILD_VER" >&2; exit 1
fi

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -a "$ROOT/fpk/." "$STAGE/"
mkdir -p "$STAGE/app/bin" "$STAGE/app/ui/images"
cp "$BIN" "$STAGE/app/bin/ps5-dump-forge"
chmod 755 "$STAGE/app/bin/ps5-dump-forge" "$STAGE/cmd/main"
sed "s/__FPK_VERSION__/$FPK_VERSION/; s/__PLATFORM__/$PLATFORM/" "$STAGE/manifest" > "$STAGE/manifest.tmp"
mv "$STAGE/manifest.tmp" "$STAGE/manifest"

mkdir -p "$OUT_DIR"
( cd "$STAGE" && "$FNPACK_BIN" build )
PACKAGE="$STAGE/ps5dumpforge.fpk"
[ -f "$PACKAGE" ] || { echo "fnpack 未生成 ps5dumpforge.fpk" >&2; exit 1; }
DEST="$OUT_DIR/ps5-dump-forge-fnos-${ARCH}.${BUILD_VER}.fpk"
mv "$PACKAGE" "$DEST"
echo "$DEST"
