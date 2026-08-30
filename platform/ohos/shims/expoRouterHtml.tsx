// expo-router/html → OHOS 兼容垫片
// 该模块仅用于 Web 构建（ScrollViewStyleReset），OHOS 下直接透传子节点。
import * as React from 'react';

export function ScrollViewStyleReset(props: { children?: React.ReactNode }) {
  return <>{props.children}</>;
}

export default { ScrollViewStyleReset };
