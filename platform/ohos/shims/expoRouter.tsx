// expo-router → OHOS 兼容垫片（核心）
// ----------------------------------------------------------------------------
// 在 OHOS 模式下，真正的导航树由 ohos/App.tsx 用 React Navigation 直接构建，
// 本垫片提供 expo-router 的 API 表面，使现有 screen 组件无需改动即可运行：
//   useRouter / useLocalSearchParams / useGlobalSearchParams / usePathname /
//   useNavigation / useFocusEffect / Redirect / Link / Stack / Slot / Href
// URL <-> 路由名的解析由 ohos/routeRegistry.ts 提供的 ROUTE_TABLE 完成。
// ----------------------------------------------------------------------------
import * as React from 'react';
import { createContext, useContext } from 'react';
import {
  NavigationContainerRef,
  NavigationContainer,
  useNavigation as useRNNavigation,
  useRoute,
  useFocusEffect as useRNFocusEffect,
  RouteProp,
} from '@react-navigation/native';
import { Linking as RNNLinking, Pressable, Text } from 'react-native';

export const navigationRef = React.createRef<NavigationContainerRef<any>>();

export type Href =
  | string
  | { pathname: string; params?: Record<string, any>; query?: Record<string, any> };

interface RouteEntry {
  pattern: RegExp;
  name: string;
  keys: string[];
}

let routeTable: RouteEntry[] = [];
export function registerRouteTable(table: RouteEntry[]) {
  routeTable = table;
}

export function resolveHref(href: Href): { name: string; params: Record<string, any> } | null {
  let path: string;
  let extra: Record<string, any> = {};
  if (typeof href === 'string') path = href;
  else {
    path = href.pathname;
    extra = { ...(href.params || {}), ...(href.query || {}) };
  }
  const [cleanPath, queryStr] = path.split('?');
  const params: Record<string, any> = { ...extra };
  if (queryStr) {
    queryStr.split('&').forEach((p) => {
      const idx = p.indexOf('=');
      const k = decodeURIComponent(p.slice(0, idx < 0 ? p.length : idx));
      const v = idx < 0 ? '' : decodeURIComponent(p.slice(idx + 1));
      if (k) params[k] = v;
    });
  }
  const p = cleanPath.startsWith('/') ? cleanPath.slice(1) : cleanPath;
  for (const r of routeTable) {
    const m = p.match(r.pattern);
    if (m) {
      const out: Record<string, any> = { ...params };
      r.keys.forEach((k, i) => (out[k] = decodeURIComponent(m[i + 1])));
      return { name: r.name, params: out };
    }
  }
  return null;
}

export function useRouter() {
  return {
    push: (href: Href) => {
      const r = resolveHref(href);
      if (r && navigationRef.current) navigationRef.current.navigate(r.name, r.params);
      else console.warn('[OHOS router] 未找到路由:', typeof href === 'string' ? href : href.pathname);
    },
    replace: (href: Href) => {
      const r = resolveHref(href);
      if (r && navigationRef.current)
        navigationRef.current.reset({ index: 0, routes: [{ name: r.name, params: r.params }] });
      else console.warn('[OHOS router] 未找到路由:', typeof href === 'string' ? href : href.pathname);
    },
    back: () => navigationRef.current?.goBack(),
    canGoBack: () => navigationRef.current?.canGoBack() ?? false,
    dismiss: () => navigationRef.current?.goBack(),
    dismissAll: () => {},
    setParams: (params: Record<string, any>) => navigationRef.current?.setParams(params),
  };
}

export function useLocalSearchParams<T = Record<string, any>>(): T {
  const route = useRoute() as RouteProp<Record<string, any>, string>;
  return (route.params ?? {}) as T;
}

export function useGlobalSearchParams<T = Record<string, any>>(): T {
  return useLocalSearchParams<T>();
}

export function usePathname(): string {
  const route = useRoute();
  return '/' + (route.name ?? '');
}

export function useSegments(): string[] {
  return [];
}

export function useNavigation() {
  return useRNNavigation();
}

export function useFocusEffect(callback: () => void | (() => void)) {
  return useRNFocusEffect(callback);
}

export function Redirect({ href }: { href: Href }) {
  React.useEffect(() => {
    const r = resolveHref(href);
    if (r && navigationRef.current) navigationRef.current.reset({ index: 0, routes: [{ name: r.name, params: r.params }] });
  }, []);
  return null;
}

export function Link(props: { href: Href; children?: React.ReactNode; onPress?: (e: any) => void } & any) {
  const router = useRouter();
  const onPress = (e: any) => {
    if (props.onPress) props.onPress(e);
    router.push(props.href);
  };
  const { href, children, onPress: _o, ...rest } = props;
  return (
    <Pressable onPress={onPress} {...rest}>
      <Text>{children}</Text>
    </Pressable>
  );
}

// 在 OHOS 模式下不参与导航树构建（导航树由 ohos/App 的 React Navigation 构建）。
// 这里提供兼容组件，使直接 import 它们的 screen 可正常渲染（仅渲染子节点）。
export function Stack(props: { children?: React.ReactNode; screenOptions?: any; initialRouteName?: string }) {
  return <>{props.children}</>;
}
(Stack as any).Screen = function StackScreen(props: { children?: React.ReactNode; name?: string; options?: any }) {
  return <>{props.children}</>;
};

export function Slot(props: { children?: React.ReactNode }) {
  return <>{props.children}</>;
}

export const Linking = RNNLinking;

export default {
  useRouter,
  useLocalSearchParams,
  useGlobalSearchParams,
  usePathname,
  useSegments,
  useNavigation,
  useFocusEffect,
  Redirect,
  Link,
  Stack,
  Slot,
  navigationRef,
  registerRouteTable,
  resolveHref,
  Linking,
};
