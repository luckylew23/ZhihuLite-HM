// expo-router/entry → OHOS 兼容垫片（安全网）
// ----------------------------------------------------------------------------
// 标准 Expo 工程通过 package.json 的 "main": "expo-router/entry" 启动根组件。
// 在 OHOS 构建里，真正的入口由 harmony/ 工程的 ArkTS 层指定为 ohos/index.tsx
// （它调用 AppRegistry.registerComponent('zhihu--', ...)）。因此正常情况下不会有人
// import 'expo-router/entry'。但若某些工具链仍按 package main 解析，本垫片提供等价行为：
// 注册并导出根组件，避免解析失败。
// ----------------------------------------------------------------------------
import { AppRegistry } from 'react-native';
import App from '../../../ohos/App';

AppRegistry.registerComponent('zhihu--', () => App);

export default App;
