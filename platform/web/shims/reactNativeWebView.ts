/**
 * react-native-webview 的 Web 垫片
 * ---------------------------------------------------------------------------
 * 背景：react-native-webview 在 Web 平台只渲染一行红字占位
 *   "React Native WebView does not support this platform."
 * 且 **不会** 触发 onMessage。而首页用它做游客 cookie 引导：
 *   1×1 隐藏 WebView 加载 https://www.zhihu.com/，injectedJavaScript 轮询到
 *   d_c0 后 postMessage('ready') → onMessage → setGuestCookieReady(true)
 *   → 才解锁 feed 查询（门禁 `(!!cookies || guestCookieReady)`）。
 * 在 Web/ArkWeb 下这条链路永远不通 → 一条数据请求都不发 → 永远空态。
 *
 * 策略：**只**针对游客引导这种用法（injectedJavaScript 含
 * `postMessage('ready')` 且传了 onMessage）延迟触发一次 onMessage。
 * 登录页 / 验证码 / LaTeX 等其他 WebView 不含该哨兵，保持不触发，
 * 以免误触发登录流程。
 *
 * 说明：游客 feed 接口（api/v3/explore/guest/feeds）匿名即可读，
 * 所以无需真的拿到 d_c0，这里只负责解锁门禁。
 *
 * 注意：本垫片**不 import react**（返回 null 即可），因为它在上游
 * projectRoot 之外，Metro 解析不到 react 依赖。
 * ---------------------------------------------------------------------------
 */

const READY_SENTINEL = "postMessage('ready')";
const READY_SENTINEL_DQ = 'postMessage("ready")';

interface WebViewMessageEvent {
  nativeEvent: {
    data: string;
    url?: string;
  };
}

interface WebViewProps {
  source?: { uri?: string; html?: string } | number;
  injectedJavaScript?: string;
  onMessage?: (event: WebViewMessageEvent) => void;
  [k: string]: unknown;
}

/** 诊断计数（便于本地验证时确认垫片是否挂载/触发） */
function bump(name: string): void {
  try {
    const g = globalThis as unknown as Record<string, unknown>;
    g[name] = ((g[name] as number) ?? 0) + 1;
  } catch (e) {
    /* ignore */
  }
}

export function WebView(props: WebViewProps): null {
  bump('__wvShimMounts');
  const onMessage = props.onMessage;
  const injected = String(props.injectedJavaScript ?? '');
  const source = props.source;
  const uri =
    source && typeof source === 'object' ? String(source.uri ?? '') : '';

  if (typeof onMessage === 'function') {
    bump('__wvShimHasOnMessage');
    const isGuestBootstrap =
      injected.indexOf(READY_SENTINEL) >= 0 ||
      injected.indexOf(READY_SENTINEL_DQ) >= 0;
    if (isGuestBootstrap) {
      bump('__wvShimReadyScheduled');
      setTimeout(() => {
        bump('__wvShimReadyFired');
        try { (globalThis as unknown as Record<string, unknown>).__guestReady = true; } catch (e) {}
        onMessage({ nativeEvent: { data: 'ready', url: uri } });
      }, 1200);
    }
  }

  return null;
}

export default WebView;
