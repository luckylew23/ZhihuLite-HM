// expo-splash-screen → OHOS 兼容垫片
// OHOS 启动页由 EntryAbility / splash 资源控制，JS 层无需干预，降级为空操作。
export async function preventAutoHideAsync(): Promise<void> {}
export async function hideAsync(): Promise<void> {}
export async function hide(): Promise<void> {}
export async function setOptionsAsync(_options: { duration?: number; fade?: boolean }): Promise<void> {}

export default { preventAutoHideAsync, hideAsync, hide, setOptionsAsync };
