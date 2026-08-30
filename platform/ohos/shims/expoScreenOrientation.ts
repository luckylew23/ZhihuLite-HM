// expo-screen-orientation → OHOS 兼容垫片
// OHOS 旋转锁定通过 Ability 配置/Window 控制；此处降级为空操作（默认跟随系统）。
export enum OrientationLock {
  DEFAULT = 'default',
  PORTRAIT_UP = 'portrait_up',
  PORTRAIT_DOWN = 'portrait_down',
  LANDSCAPE_LEFT = 'landscape_left',
  LANDSCAPE_RIGHT = 'landscape_right',
  LANDSCAPE = 'landscape',
  ALL = 'all',
  ALL_BUT_UPSIDE_DOWN = 'all_but_upside_down',
  PORTRAIT = 'portrait',
  UNLOCKED = 'unlocked',
}

export async function lockAsync(_orientation: OrientationLock): Promise<void> {}
export async function unlockAllAsync(): Promise<void> {}
export function addOrientationChangeListener(_cb: (e: any) => void): { remove: () => void } {
  return { remove: () => {} };
}
export function removeOrientationChangeListener(_sub: { remove: () => void }): void {}
export async function getOrientationAsync(): Promise<number> {
  return 0;
}
export async function getPlatformOrientationLockAsync(): Promise<number[]> {
  return [];
}
export async function supportsOrientationLockAsync(_orientation: OrientationLock): Promise<boolean> {
  return true;
}

export default {
  lockAsync,
  unlockAllAsync,
  addOrientationChangeListener,
  removeOrientationChangeListener,
  getOrientationAsync,
  getPlatformOrientationLockAsync,
  supportsOrientationLockAsync,
  OrientationLock,
};
