#!/usr/bin/env python3
"""从 app 证书链提取叶子证书，生成 OpenHarmony 调试 provisioning profile JSON。"""
import json
import subprocess
import sys
import time

cert_file = sys.argv[1] if len(sys.argv) > 1 else "app-cert.cer"
chain = open(cert_file).read()
# certChain 文件包含多张证书，取第一张（叶子）
# hap-sign-tool 的 DigestUtils.decodeBase64ToX509Certifate 用 Base64.getUrlDecoder()
# 解码该字段，因此必须是 URL-safe base64（'+'→'-'，'/'→'_'），不能含 PEM 头尾
import base64
begin = chain.index("-----BEGIN CERTIFICATE-----")
end = chain.index("-----END CERTIFICATE-----")
b64_body = "".join(chain[begin:end].split("-----BEGIN CERTIFICATE-----")[-1].split())
der = base64.b64decode(b64_body)
leaf_cert = base64.urlsafe_b64encode(der).decode()

now = int(time.time())
profile = {
    "version-name": "2.0.0",
    "version-code": 2,
    "uuid": "a7f3d2c1-8b90-4e5f-b2a1-3c4d5e6f7081",
    "validity": {
        "not-before": now - 86400,
        "not-after": now + 10 * 365 * 86400,
    },
    "type": "debug",
    "bundle-info": {
        "developer-id": "ZhihuMinusMinus",
        "development-certificate": leaf_cert,
        "bundle-name": "com.huamu013.ZhihuMinusMinus",
        "apl": "normal",
        "app-feature": "hos_normal_app",
    },
    "acls": {"allowed-acls": [""]},
    "permissions": {"allowed-acls": [""], "restricted-permissions": [""]},
    "debug-info": {
        "device-ids": [],
        "device-id-type": "udid",
    },
    "issuer": "pki_internal",
}
print(json.dumps(profile, indent=2, ensure_ascii=False))
