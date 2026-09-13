# SDK 命令行构建补丁（sdk-build-patch）

> 2026-09-13 打通 `hvigorw assembleHap` 命令行构建链路（此前 IDE 是唯一出口）。
> 根因：HarmonyOS SDK 的 hvigor 扫描机制与 DevEco 内置 SDK 目录布局不兼容。
> 所有补丁均位于 `/Applications/DevEco-Studio.app/Contents/sdk/default`（IDE SDK）与
> `/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor-ohos-plugin`（hvigor 插件）。

## 背景（为什么命令行会 SDK_COMPONENT_MISSING）

1. `HmosSdkLoader.getHosSdkComponents` → `HosSdkInfoHandler.getLocalSdks("22"/"6.0.2")`
2. `getLocalSdks` 用 `HosVersionMapper.transferVersionIntoHosVersion(version)` 映射版本，
   6.0.2 与 22 均可命中（6.0.2.130 / 6.0.2(22) / 12 不命中）；
3. 命中后 `_getLocalComponents()` 只在 SDK 子目录递归找 **`sdk-pkg.json`**（根目录的不被扫到）；
4. `_parsingPlatforms` 用 `PlatformSdks.getSdks("hms")`，`_additional=["ets","native","previewer","toolchains"]`
   （缺 js → 组件数不足）；
5. 组件 location 原始代码拼 `{sdk}/hms/{comp}`（HarmonyOS 走 hms 目录），
   而 DevEco 内置 SDK 的 hms 组件**不完整**（缺 @kit.ArkUI/@kit.ArkTS，这两个在 openharmony/ets/kits）→
   编译期必挂；把 location 指向 **openharmony** 则所有 Kit 齐全（本工程代码所需 Kit 全部在 openharmony）。

## 补丁清单（构建前逐项执行）

```bash
SDK=/Applications/DevEco-Studio.app/Contents/sdk/default
BASE=/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor-ohos-plugin/node_modules/@ohos/hos-sdkmanager-common/build/src/hos

# P1: sdk-pkg.json 放到扫描预期位置（{sdk}/HarmonyOS-6.0.2/）
mkdir -p "$SDK/HarmonyOS-6.0.2" && cp "$SDK/sdk-pkg.json" "$SDK/HarmonyOS-6.0.2/"

# P2: platform-sdks.js _additional 补 js（5 组件）
# 原: _additional = ["ets","native","previewer","toolchains"]
# 改: _additional = ["ets","native","previewer","toolchains","js"]
# 文件: $BASE/mapper/platform-sdks.js（备份 .bak-0922b）

# P3: hos-sdk-info-handler.js 组件 location 指向 openharmony
# 原: s.location=path.join(getLocation(),"hms",t)
# 改: s.location=path.join(this._sdkSettings.getLocation(),"openharmony",t)
# 文件: $BASE/api/hos-sdk-info-handler.js（备份 .bak-0922b）

# P4: openharmony/{ets,native,toolchains}/uni-package.json（getHmsSdkComponents 检查 HMS 定义文件）
# 从 hms 对应组件复制（若缺则占位 {"name":comp,"version":"6.0.2.130","metaVersion":"3.1.0"}）

# P5: openharmony/toolchains/lib 补 hms 独有 dylib/jar（资源编译/签名工具链）
# hms/toolchains/lib 下 openharmony 缺失的全部软链过去：
# libastc_encoder_shared.dylib libastcCustomizedEncode.dylib libimage_transcoder_shared.dylib
# liblz4_shared.dylib libtextureSuperCompress.dylib Provisionsigntool.jar sdk-sign-tool-full.jar

# P6: openharmony/toolchains/id_defined.json 置空 record（restool 对非空 record 有解析 bug，报"同名重复"）
# 写: {"startId":"0x07800000","record":[]}
# 注意: 本工程不引用 sys.* 资源，空 record 无影响；restool 警告可忽略
```

## 构建命令

```bash
cd ~/workbuddy/zhihu--HMOS/harmony-native
/Applications/DevEco-Studio.app/Contents/tools/node/bin/node \
  /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw.js \
  assembleHap --mode module -p product=default --no-daemon
# 产物: entry/build/default/outputs/default/entry-default-signed.hap（华为签名，真机可装）
```

## 回滚

- P2/P3: 用 `.bak-0922b` 恢复 platform-sdks.js / hos-sdk-info-handler.js
- P1/P4: 删除 `HarmonyOS-6.0.2/` 与 openharmony 下的 uni-package.json
- P5: 删除 openharmony/toolchains/lib 下 7 个软链
- P6: id_defined.json 原始 7166 条已被覆盖（无法恢复），如需还原请重装/更新 SDK；
  空 record 对 IDE 构建无影响（IDE 构建不使用该文件的内容做 sys 资源分配）

## 经验教训（防重踩）

1. **不要改坏 SDK 原始文件再依赖 IDE**：hvigor daemon 缓存插件，改插件文件必须重启 daemon。
2. **先单测 `getLocalSdks(version)`**（node -e require hos-sdkmanager-common）确认扫描，再跑完整构建，
   每个版本字符串都测（6.0.2 ✓ / 22 ✓ / 6.0.2.130 ✗ / 6.0.2(22) ✗ / 12 ✗）。
3. **restool 的 id_defined.json 解析**：非空 record 数组必报"同名重复"（工具 bug），空 record 可过。
4. **命令行编译真正报错点**：SDK 检查通过后还会挂在 restool 工具链（dylib 缺失）→ 资源编译 → ArkTS 编译，
   逐层解（P4→P5→P6→Kit/语法），每层错误都指向明确的 SDK 目录文件。
5. **AppStorage（V1）**：SDK 6.0.2 起为全局 API，不要 `import { AppStorage } from '@kit.ArkUI'`。
6. **Stack 内自定义组件链式**（.width/.visibility 等）可能报 "does not meet UI component syntax"，
   包一层 Column 即可。
