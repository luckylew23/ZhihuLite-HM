#!/bin/bash
# Tydora-HMOS 自签调试证书生成 + hap 签名
# 用法: ./sign.sh [unsigned.hap] [输出.hap]
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
JAVA="$ROOT/toolchain/jdk-17.0.20+8/Contents/Home/bin/java"
ST="$ROOT/toolchain/hos-sdk/default/openharmony/20/toolchains/lib/hap-sign-tool.jar"
IN="${1:-$ROOT/entry/build/default/outputs/default/entry-default-unsigned.hap}"
OUT="${2:-$ROOT/entry/build/default/outputs/default/Tydora-default-signed.hap}"

mkdir -p "$ROOT/signing"
cd "$ROOT/signing"
PWD_="123456"

if [ ! -f root-ca.cer ]; then
  echo "==> [1/5] 生成 Root CA"
  "$JAVA" -jar "$ST" generate-ca -keyAlias root-ca -keyPwd "$PWD_" -keyAlg ECC -keySize NIST-P-256 \
    -subject "C=CN,O=Tydora,OU=Tydora,CN=Tydora Root CA" -validity 7300 -signAlg SHA256withECDSA \
    -keystoreFile oh-ca.p12 -keystorePwd "$PWD_" -outFile root-ca.cer
fi

if [ ! -f sub-app-ca.cer ] || [ ! -f sub-profile-ca.cer ]; then
  echo "==> [1b/5] 生成二级 CA（App / Profile Signature Service CA）"
  "$JAVA" -jar "$ST" generate-ca -keyAlias sub-app-ca -keyPwd "$PWD_" -keyAlg ECC -keySize NIST-P-256 \
    -issuer "C=CN,O=Tydora,OU=Tydora,CN=Tydora Root CA" -issuerKeyAlias root-ca -issuerKeyPwd "$PWD_" \
    -issuerKeystoreFile oh-ca.p12 -issuerKeystorePwd "$PWD_" \
    -subject "C=CN,O=Tydora,OU=Tydora,CN=Application Signature Service CA" -validity 7300 -signAlg SHA256withECDSA \
    -keystoreFile oh-ca.p12 -keystorePwd "$PWD_" -outFile sub-app-ca.cer
  "$JAVA" -jar "$ST" generate-ca -keyAlias sub-profile-ca -keyPwd "$PWD_" -keyAlg ECC -keySize NIST-P-256 \
    -issuer "C=CN,O=Tydora,OU=Tydora,CN=Tydora Root CA" -issuerKeyAlias root-ca -issuerKeyPwd "$PWD_" \
    -issuerKeystoreFile oh-ca.p12 -issuerKeystorePwd "$PWD_" \
    -subject "C=CN,O=Tydora,OU=Tydora,CN=Profile Signature Service CA" -validity 7300 -signAlg SHA256withECDSA \
    -keystoreFile oh-ca.p12 -keystorePwd "$PWD_" -outFile sub-profile-ca.cer
fi

if [ ! -f app-cert.cer ]; then
  echo "==> [2/5] 生成 App 签名密钥与证书链"
  "$JAVA" -jar "$ST" generate-keypair -keyAlias app-sign-key -keyPwd "$PWD_" -keyAlg ECC -keySize NIST-P-256 \
    -keystoreFile app-sign.p12 -keystorePwd "$PWD_" || true
  "$JAVA" -jar "$ST" generate-app-cert -keyAlias app-sign-key -keyPwd "$PWD_" \
    -issuer "C=CN,O=Tydora,OU=Tydora,CN=Application Signature Service CA" -issuerKeyAlias sub-app-ca -issuerKeyPwd "$PWD_" \
    -issuerKeystoreFile oh-ca.p12 -issuerKeystorePwd "$PWD_" \
    -subject "C=CN,O=Tydora,OU=Tydora,CN=Tydora Debug" -validity 3650 -signAlg SHA256withECDSA \
    -keystoreFile app-sign.p12 -keystorePwd "$PWD_" \
    -outForm certChain -rootCaCertFile root-ca.cer -subCaCertFile sub-app-ca.cer -outFile app-cert.cer
fi

if [ ! -f profile-cert.cer ]; then
  echo "==> [3/5] 生成 Profile 签名密钥与证书"
  "$JAVA" -jar "$ST" generate-keypair -keyAlias profile-sign-key -keyPwd "$PWD_" -keyAlg ECC -keySize NIST-P-256 \
    -keystoreFile profile-sign.p12 -keystorePwd "$PWD_" || true
  "$JAVA" -jar "$ST" generate-profile-cert -keyAlias profile-sign-key -keyPwd "$PWD_" \
    -issuer "C=CN,O=Tydora,OU=Tydora,CN=Profile Signature Service CA" -issuerKeyAlias sub-profile-ca -issuerKeyPwd "$PWD_" \
    -issuerKeystoreFile oh-ca.p12 -issuerKeystorePwd "$PWD_" \
    -subject "C=CN,O=Tydora,OU=Tydora,CN=Tydora Profile Debug" -validity 3650 -signAlg SHA256withECDSA \
    -keystoreFile profile-sign.p12 -keystorePwd "$PWD_" \
    -outForm certChain -rootCaCertFile root-ca.cer -subCaCertFile sub-profile-ca.cer -outFile profile-cert.cer
fi

if [ ! -f debug.p7b ]; then
  echo "==> [4/5] 生成调试 Provisioning Profile (p7b)"
  # 组装 profile JSON（嵌入 app 证书、更新有效期）
  "$ROOT/signing/make-profile.py" app-cert.cer > debug-profile.json
  "$JAVA" -jar "$ST" sign-profile -mode localSign -keyAlias profile-sign-key -keyPwd "$PWD_" \
    -profileCertFile profile-cert.cer -inFile debug-profile.json -signAlg SHA256withECDSA \
    -keystoreFile profile-sign.p12 -keystorePwd "$PWD_" -outFile debug.p7b
fi

echo "==> [5/5] 签名 hap"
"$JAVA" -jar "$ST" sign-app -mode localSign -keyAlias app-sign-key -keyPwd "$PWD_" \
  -appCertFile app-cert.cer -profileFile debug.p7b -inFile "$IN" \
  -signAlg SHA256withECDSA -keystoreFile app-sign.p12 -keystorePwd "$PWD_" \
  -outFile "$OUT" -compatibleVersion 20

echo "==> 验证签名"
"$JAVA" -jar "$ST" verify-app -inFile "$OUT" -outCertChain verify-cert.cer -outProfile verify-profile.p7b && echo "VERIFY OK"
ls -lh "$OUT"
