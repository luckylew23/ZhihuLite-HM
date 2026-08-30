// react-native-root-siblings → OHOS 兼容垫片
// OHOS 上不再需要 portal 兄弟节点机制，RootSiblingParent 直接渲染子节点。
import * as React from 'react';

export function RootSiblingParent(props: { children?: React.ReactNode }) {
  return <>{props.children}</>;
}

export function RootSiblingPortal(props: { children?: React.ReactNode }) {
  return <>{props.children}</>;
}

export default { RootSiblingParent, RootSiblingPortal };
