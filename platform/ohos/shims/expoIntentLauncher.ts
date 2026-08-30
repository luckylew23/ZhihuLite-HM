// expo-intent-launcher → OHOS 兼容垫片
// Android 专属能力，OHOS 无直接等价；APK 安装等能力需改走 OHOS Ability，
// 此处降级为空操作，避免打包/运行报错。详见 EXPO_OHOS_MAPPING.md。
export async function startActivityAsync(_activity: string, _params?: any): Promise<void> {
  console.warn('[OHOS] expo-intent-launcher 无对应能力，已降级为空操作');
}

export const IntentLauncher = {
  startActivityAsync,
  startActivity: startActivityAsync,
};

export default IntentLauncher;
