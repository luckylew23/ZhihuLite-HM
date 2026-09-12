#!/bin/bash
# Zhihu--HMOS 本地自签调试证书生成 + hap 签名
# ---------------------------------------------------------------------------
# 用法: ./sign.sh [unsigned.hap] [输出.hap]
#
# 完全离线自签（不依赖华为开发者帐号）：
#   Root CA → 二级 CA(App/Profile) → App 证书 → Profile 证书 → p7b → sign-app
#
# 前置：DevEco Studio（提供 jbr/JDK 与 hap-sign-tool.jar）
# ---------------------------------------------------------------------------
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

DEVECO_HOME="${DEVECO_HOME:-/Applications/DevEco-Studio.app/Contents}"
if [ ! -d "$DEVECO_HOME" ]; then
  echo "❌ 未找到 DevEco Studio（$DEVECO_HOME）。请设置 DEVECO_HOME。" >&2
  exit 1
fi

# hap-sign-tool.jar：优先用 local.properties 里记录的 SDK 根，再从常见路径兜底
SDK_BASE="$(sed -n 's#^sdk\.dir=##p' "$ROOT/local.properties" 2>/dev/null | tr -d '\r')"
if [ -z "$SDK_BASE" ]; then
  SDK_BASE="$DEVECO_HOME/sdk/default/openharmony"
fi

ST=""
for cand in \
  "$SDK_BASE/20/toolchains/lib/hap-sign-tool.jar" \
  "$DEVECO_HOME/sdk/default/openharmony/20/toolchains/lib/hap-sign-tool.jar" \
  "$DEVECO_HOME/sdk/default/openharmony/toolchains/lib/hap-sign-tool.jar"
do
  if [ -f "$cand" ]; then ST="$cand"; break; fi
done
if [ -z "$ST" ]; then
  # 兜底：全盘搜一次（只在上面都落空时执行）
  ST="$(find "$DEVECO_HOME/sdk" -name 'hap-sign-tool.jar' 2>/dev/null | head -1 || true)"
fi
if [ -z "$ST" ] || [ ! -f "$ST" ]; then
  echo "❌ 找不到 hap-sign-tool.jar（SDK 根目录：$SDK_BASE）。" >&2
  echo "   请在 DevEco Studio → Settings → SDK 中确认已下载 OpenHarmony SDK。" >&2
  exit 1
fi

JAVA=""
for cand in \
  "${JAVA_HOME:-}/bin/java" \
  "$DEVECO_HOME/jbr/Contents/Home/bin/java" \
  "/usr/bin/java"
do
  if [ -n "$cand" ] && [ -x "$cand" ]; then JAVA="$cand"; break; fi
done
if [ -z "$JAVA" ]; then
  echo "❌ 找不到 java。请设置 JAVA_HOME。" >&2
  exit 1
fi

IN="${1:-$ROOT/entry/build/default/outputs/default/entry-default-unsigned.hap}"
OUT="${2:-$ROOT/entry/build/default/outputs/default/zhihu--default-signed.hap}"

# 把 IN/OUT 解析成绝对路径：本脚本后续会 cd 到 $ROOT/signing，
# 若调用方传入相对路径，cd 后相对基准会错位导致 sign-app 读不到输入。
_resolve() {
  local p="$1"
  case "$p" in
    /*) echo "$p" ;;
    *)  local d; d="$(cd "$(dirname "$p")" 2>/dev/null && pwd)"; echo "${d:+$d/}$(basename "$p")" ;;
  esac
}
IN="$(_resolve "$IN")"
OUT="$(_resolve "$OUT")"

if [ ! -f "$IN" ]; then
  echo "❌ 未找到待签名包：$IN" >&2
  exit 1
fi

mkdir -p "$ROOT/signing"
cd "$ROOT/signing"
PWD_="123456"

echo "🔧 java : $("$JAVA" -version 2>&1 | head -1)"
echo "🔧 tool : $ST"

# 用 .p12（而非 .cer）判断是否需要重建：.p12 才是密钥载体，
# 只有 .cer 而没有 .p12 时后续签发会直接失败。
if [ ! -f oh-ca.p12 ]; then
  echo "==> [1/5] 生成 Root CA"
  "$JAVA" -jar "$ST" generate-ca -keyAlias root-ca -keyPwd "$PWD_" -keyAlg ECC -keySize NIST-P-256 \
    -subject "C=CN,O=ZhihuMinusMinus,OU=ZhihuMinusMinus,CN=ZhihuMinusMinus Root CA" -validity 7300 -signAlg SHA256withECDSA \
    -keystoreFile oh-ca.p12 -keystorePwd "$PWD_" -outFile root-ca.cer
fi

# 三个条件：证书缺失，或根 CA 是刚重建的（旧二级 CA 就成了孤儿证书，必须跟着重建）
if [ ! -f sub-app-ca.cer ] || [ ! -f sub-profile-ca.cer ] || [ oh-ca.p12 -nt sub-app-ca.cer ]; then
  echo "==> [1b/5] 生成二级 CA（App / Profile Signature Service CA）"
  "$JAVA" -jar "$ST" generate-ca -keyAlias sub-app-ca -keyPwd "$PWD_" -keyAlg ECC -keySize NIST-P-256 \
    -issuer "C=CN,O=ZhihuMinusMinus,OU=ZhihuMinusMinus,CN=ZhihuMinusMinus Root CA" -issuerKeyAlias root-ca -issuerKeyPwd "$PWD_" \
    -issuerKeystoreFile oh-ca.p12 -issuerKeystorePwd "$PWD_" \
    -subject "C=CN,O=ZhihuMinusMinus,OU=ZhihuMinusMinus,CN=Application Signature Service CA" -validity 7300 -signAlg SHA256withECDSA \
    -keystoreFile oh-ca.p12 -keystorePwd "$PWD_" -outFile sub-app-ca.cer
  "$JAVA" -jar "$ST" generate-ca -keyAlias sub-profile-ca -keyPwd "$PWD_" -keyAlg ECC -keySize NIST-P-256 \
    -issuer "C=CN,O=ZhihuMinusMinus,OU=ZhihuMinusMinus,CN=ZhihuMinusMinus Root CA" -issuerKeyAlias root-ca -issuerKeyPwd "$PWD_" \
    -issuerKeystoreFile oh-ca.p12 -issuerKeystorePwd "$PWD_" \
    -subject "C=CN,O=ZhihuMinusMinus,OU=ZhihuMinusMinus,CN=Profile Signature Service CA" -validity 7300 -signAlg SHA256withECDSA \
    -keystoreFile oh-ca.p12 -keystorePwd "$PWD_" -outFile sub-profile-ca.cer
fi

if [ ! -f app-sign.p12 ] || [ ! -f app-cert.cer ] || [ oh-ca.p12 -nt app-cert.cer ]; then
  echo "==> [2/5] 生成 App 签名密钥与证书链"
  "$JAVA" -jar "$ST" generate-keypair -keyAlias app-sign-key -keyPwd "$PWD_" -keyAlg ECC -keySize NIST-P-256 \
    -keystoreFile app-sign.p12 -keystorePwd "$PWD_" || true
  "$JAVA" -jar "$ST" generate-app-cert -keyAlias app-sign-key -keyPwd "$PWD_" \
    -issuer "C=CN,O=ZhihuMinusMinus,OU=ZhihuMinusMinus,CN=Application Signature Service CA" -issuerKeyAlias sub-app-ca -issuerKeyPwd "$PWD_" \
    -issuerKeystoreFile oh-ca.p12 -issuerKeystorePwd "$PWD_" \
    -subject "C=CN,O=ZhihuMinusMinus,OU=ZhihuMinusMinus,CN=ZhihuMinusMinus Debug" -validity 3650 -signAlg SHA256withECDSA \
    -keystoreFile app-sign.p12 -keystorePwd "$PWD_" \
    -outForm certChain -rootCaCertFile root-ca.cer -subCaCertFile sub-app-ca.cer -outFile app-cert.cer
fi

if [ ! -f profile-sign.p12 ] || [ ! -f profile-cert.cer ] || [ oh-ca.p12 -nt profile-cert.cer ]; then
  echo "==> [3/5] 生成 Profile 签名密钥与证书"
  "$JAVA" -jar "$ST" generate-keypair -keyAlias profile-sign-key -keyPwd "$PWD_" -keyAlg ECC -keySize NIST-P-256 \
    -keystoreFile profile-sign.p12 -keystorePwd "$PWD_" || true
  "$JAVA" -jar "$ST" generate-profile-cert -keyAlias profile-sign-key -keyPwd "$PWD_" \
    -issuer "C=CN,O=ZhihuMinusMinus,OU=ZhihuMinusMinus,CN=Profile Signature Service CA" -issuerKeyAlias sub-profile-ca -issuerKeyPwd "$PWD_" \
    -issuerKeystoreFile oh-ca.p12 -issuerKeystorePwd "$PWD_" \
    -subject "C=CN,O=ZhihuMinusMinus,OU=ZhihuMinusMinus,CN=ZhihuMinusMinus Profile Debug" -validity 3650 -signAlg SHA256withECDSA \
    -keystoreFile profile-sign.p12 -keystorePwd "$PWD_" \
    -outForm certChain -rootCaCertFile root-ca.cer -subCaCertFile sub-profile-ca.cer -outFile profile-cert.cer
fi

if [ ! -f debug.p7b ] || [ app-cert.cer -nt debug.p7b ]; then
  echo "==> [4/5] 生成调试 Provisioning Profile (p7b)"
  python3 "$ROOT/signing/make-profile.py" app-cert.cer > debug-profile.json
  "$JAVA" -jar "$ST" sign-profile -mode localSign -keyAlias profile-sign-key -keyPwd "$PWD_" \
    -profileCertFile profile-cert.cer -inFile debug-profile.json -signAlg SHA256withECDSA \
    -keystoreFile profile-sign.p12 -keystorePwd "$PWD_" -outFile debug.p7b
fi

echo "==> [5/5] 签名 hap"
"$JAVA" -jar "$ST" sign-app -mode localSign -keyAlias app-sign-key -keyPwd "$PWD_" \
  -appCertFile app-cert.cer -profileFile debug.p7b -inFile "$IN" \
  -signAlg SHA256withECDSA -keystoreFile app-sign.p12 -keystorePwd "$PWD_" \
  -outFile "$OUT" -compatibleVersion 22

echo "==> 验证签名"
"$JAVA" -jar "$ST" verify-app -inFile "$OUT" -outCertChain verify-cert.cer -outProfile verify-profile.p7b && echo "VERIFY OK"
ls -lh "$OUT"
