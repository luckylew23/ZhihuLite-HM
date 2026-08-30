// ohos/App.tsx — HarmonyOS 应用根组件
// 用 React Navigation 直接构建导航栈（替代 expo-router 的文件路由）。
//
// 关于底部 Tab：原项目 app/(tabs)/index.tsx 内部已用 PagerView + 自定义底部栏
// 自行管理「关注/推荐/发布/我的」的横向切换，因此这里不再包一层
// BottomTabNavigator（否则会出现两套 Tab 栏），直接把 '(tabs)' 挂到 HomeScreen。
//
// navigationRef 注入给 expo-router 兼容垫片，使 useRouter().push('/question/123') 可解析。
import * as React from 'react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { NavigationContainer } from '@react-navigation/native';
import { createStackNavigator } from '@react-navigation/stack';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { navigationRef, registerRouteTable } from '../platform/ohos/shims/expoRouter';
import { ROUTES, ROUTE_TABLE, TAB_ROUTES } from './routeRegistry';

const Stack = createStackNavigator();
const queryClient = new QueryClient();

registerRouteTable(ROUTE_TABLE);

// 合并为单一扁平数组：嵌套数组会让 Stack.Navigator 的 children 类型推导失败
const SCREENS: [string, React.ComponentType<any>][] = [...TAB_ROUTES, ...ROUTES];

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <SafeAreaProvider>
        <NavigationContainer ref={navigationRef}>
          <Stack.Navigator
            id="root"
            initialRouteName="(tabs)"
            screenOptions={{ headerShown: false }}
          >
            {SCREENS.map(([name, Comp]) => (
              <Stack.Screen key={name} name={name} component={Comp} />
            ))}
          </Stack.Navigator>
        </NavigationContainer>
      </SafeAreaProvider>
    </QueryClientProvider>
  );
}
