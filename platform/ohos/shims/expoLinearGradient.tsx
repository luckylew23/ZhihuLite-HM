// expo-linear-gradient → OHOS 兼容垫片（基于 react-native-svg，OHOS 原生支持）
import * as React from 'react';
import { View, ViewStyle } from 'react-native';
import Svg, {
  Defs,
  LinearGradient as SvgLinearGradient,
  Stop,
  Rect,
} from 'react-native-svg';

export function LinearGradient(props: {
  colors: (string | number)[];
  start?: { x: number; y: number };
  end?: { x: number; y: number };
  locations?: number[];
  style?: ViewStyle;
  children?: React.ReactNode;
}) {
  const {
    colors,
    start = { x: 0, y: 0 },
    end = { x: 1, y: 1 },
    locations,
    style,
    children,
  } = props;

  return (
    <View style={[style, { overflow: 'hidden' }]}>
      <Svg
        height="100%"
        width="100%"
        viewBox="0 0 1 1"
        preserveAspectRatio="none"
        style={{ position: 'absolute', left: 0, top: 0 }}
      >
        <Defs>
          <SvgLinearGradient id="ohos-lg" x1={start.x} y1={start.y} x2={end.x} y2={end.y}>
            {colors.map((c, i) => (
              <Stop
                key={i}
                offset={(locations ? locations[i] : i / Math.max(1, colors.length - 1)).toString()}
                stopColor={c as string}
              />
            ))}
          </SvgLinearGradient>
        </Defs>
        <Rect x="0" y="0" width={1} height={1} fill="url(#ohos-lg)" />
      </Svg>
      {children}
    </View>
  );
}

export default LinearGradient;
