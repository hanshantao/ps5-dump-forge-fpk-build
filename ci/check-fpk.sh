#!/usr/bin/env bash
set -euo pipefail
FPK="${1:?用法: check-fpk.sh <package.fpk> <x86_64|arm64>}"
ARCH="${2:?缺少架构}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

tar -xzf "$FPK" -C "$TMP"
[ -f "$TMP/manifest" ] && [ -f "$TMP/app.tgz" ] || { echo "FPK 外层结构不完整" >&2; exit 1; }
tar -xzf "$TMP/app.tgz" -C "$TMP"
# fnpack 将 app/ 的内容作为 app.tgz 根目录，不保留外层 app/ 目录。
BIN="$TMP/bin/ps5-dump-forge"
[ -x "$BIN" ] || { echo "FPK 内缺少可执行文件" >&2; exit 1; }
case "$ARCH" in
  x86_64) EXPECT_MACHINE="Advanced Micro Devices X86-64"; EXPECT_PLATFORM=x86 ;;
  arm64) EXPECT_MACHINE=AArch64; EXPECT_PLATFORM=arm ;;
  *) exit 1 ;;
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
[ "$(elf_machine "$BIN")" = "$EXPECT_MACHINE" ] || { echo "FPK 内 ELF 架构错误" >&2; exit 1; }
grep -Eq "^platform[[:space:]]*=[[:space:]]*$EXPECT_PLATFORM$" "$TMP/manifest" || { echo "manifest platform 不匹配" >&2; exit 1; }
echo "FPK 校验通过: $FPK ($ARCH)"
