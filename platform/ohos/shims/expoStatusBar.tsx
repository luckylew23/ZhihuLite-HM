// expo-status-bar → OHOS 兼容垫片（委托给 react-native StatusBar）
import * as React from 'react';
import { StatusBar as RNStatusBar } from 'react-native';

export function StatusBar(props: any) {
  return <RNStatusBar {...props} />;
}

export default StatusBar;
