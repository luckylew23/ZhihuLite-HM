// expo-blur → OHOS 兼容垫片
// OHOS 上退化为半透明遮罩（如需真实毛玻璃可接入 @react-native-ohos/blur）。
import * as React from 'react';
import { View, ViewStyle } from 'react-native';

export function BlurView(props: {
  style?: ViewStyle;
  intensity?: number;
  tint?: 'light' | 'dark' | 'default';
  children?: React.ReactNode;
}) {
  const { style, intensity = 50, tint = 'default', children } = props;
  const alpha = Math.max(0.1, Math.min(0.9, (intensity ?? 50) / 100));
  const bg =
    tint === 'light'
      ? `rgba(255,255,255,${alpha})`
      : tint === 'dark'
        ? `rgba(0,0,0,${alpha})`
        : `rgba(255,255,255,${alpha})`;
  return (
    <View style={[style, { backgroundColor: bg }]} pointerEvents="box-none">
      {children}
    </View>
  );
}

export default BlurView;
