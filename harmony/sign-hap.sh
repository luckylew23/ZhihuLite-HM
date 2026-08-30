#!/bin/bash
# zhihu-- 自签调试 HAP（复用 Tydora-HMOS 的本地 CA 链 + hap-sign-tool）
# 用法: ./sign-hap.sh [unsigned.hap] [输出.hap]
# 前置: harmony/signing/ 下已放好 Tydora 的 CA 链 + app-sign.p12/app-cert.cer + profile-sign.p12/profile-cert.cer
#       且 make-profile.py 的 bundle-name 已改为 com.huamu013.ZhihuMinusMinus
set -e
ZROOT=/Users/admin/WorkBuddy/zhihu--/harmony
TD=/Users/admin/WorkBuddy/2026-08-18-22-54-36/Tydora-HMOS
JAVA="$TD/toolchain/jdk-17.0.20+8/Contents/Home/bin/java"
ST="$TD/toolchain/hos-sdk/default/openharmony/20/toolchains/lib/hap-sign-tool.jar"
IN="${1:-$ZROOT/entry/build/default/outputs/default/entry-default-unsigned.hap}"
OUT="${2:-$ZROOT/entry/build/default/outputs/default/zhihu-minusminus-default-signed.hap}"
PWD_=123456

cd "$ZROOT/signing"

if [ ! -f debug.p7b ]; then
  echo "==> [1/2] 生成调试 Provisioning Profile (p7b) for com.huamu013.ZhihuMinusMinus"
  python3 make-profile.py app-cert.cer > debug-profile.json
  "$JAVA" -jar "$ST" sign-profile -mode localSign -keyAlias profile-sign-key -keyPwd "$PWD_" \
    -profileCertFile profile-cert.cer -inFile debug-profile.json -signAlg SHA256withECDSA \
    -keystoreFile profile-sign.p12 -keystorePwd "$PWD_" -outFile debug.p7b
fi

echo "==> [2/2] 签名 hap"
"$JAVA" -jar "$ST" sign-app -mode localSign -keyAlias app-sign-key -keyPwd "$PWD_" \
  -appCertFile app-cert.cer -profileFile debug.p7b -inFile "$IN" \
  -signAlg SHA256withECDSA -keystoreFile app-sign.p12 -keystorePwd "$PWD_" \
  -outFile "$OUT" -compatibleVersion 12

echo "==> 验证签名"
"$JAVA" -jar "$ST" verify-app -inFile "$OUT" -outCertChain verify-cert.cer -outProfile verify-profile.p7b && echo "VERIFY OK"
ls -lh "$OUT"
