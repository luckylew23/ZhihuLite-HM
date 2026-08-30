// ohos/index.tsx — HarmonyOS 构建入口（通过 metro.config.js 别名替换 expo-router/entry）
// 由 harmony/ 工程的 ArkTS 层调用 AppRegistry.registerComponent 拉起。
import { AppRegistry } from 'react-native';
import App from './App';

// 应用名需与 harmony/entry 中 ArkTS 注册的名称保持一致。
AppRegistry.registerComponent('zhihu--', () => App);
