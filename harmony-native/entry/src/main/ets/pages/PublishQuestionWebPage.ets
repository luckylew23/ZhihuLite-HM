/**
 * pages/PublishQuestionWebPage —— 提问题（WebView 官方页兜底）。
 *
 * 仅当原生 API 发布失败时从 PublishQuestionPage 跳入。
 * 交互：加载知乎首页 → 自动点「提问」弹官方表单 → 发布成功后跳原生问题详情页。
 *
 * 关键修复（相对上一版）：
 *   · 首页外壳只在「确认提问弹窗已出现」后才隐藏 —— 弹窗没弹出来时保持首页可见，
 *     不会再出现整页空白；
 *   · hook content/publish 的 XHR/fetch 响应拿新问题 id —— 知乎 web 提交成功后
 *     是 SPA 关弹窗回 feed（URL 不变），pathname 轮询命中不了 /question/{id}。
 */

import { router } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { authStore, hasAuthenticationCookie } from '../store/authStore';
import { ZhihuColors, isDarkNow } from '../utils/theme';

const DOMAIN: number = 0x0002;
const TAG: string = 'ZhihuHttp';

const HOME_URL: string = 'https://www.zhihu.com/';
const DESKTOP_UA: string =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36';

/**
 * 自动点「提问」弹官方表单。
 * 2025 新版首页的快捷入口（提问题/写回答/写文章/发视频）可能：
 *   · 不是 button/a 标签（纯 div 渲染）
 *   · 文本被拆成多个 span（"提"+"问题"）——精确匹配失败
 *   · 渲染在 iframe 里——主文档 querySelectorAll 扫不到
 * 策略：先精确后包含，先主文档后 iframe，每轮带诊断日志。
 * 只有确认弹窗出现后才隐藏首页外壳（否则保持原样，避免空白页）。
 */
const ASK_SCRIPT: string = `(function(){
  function log(m){ try { console.log('ZL_ASK:' + m); } catch(e){} }
  log('inject:pathname=' + location.pathname + ' href=' + location.href.substring(0, 80));
  if (location.pathname !== '/') { log('not-home:' + location.pathname); return; }
  if (window.__zlAskClicked) { log('already-clicked'); return; }

  function matchesAskText(txt) {
    if (!txt) { return false; }
    var t = String(txt).replace(/\\s+/g, '');
    return t === '提问' || t === '我要提问' || t === '提问题' ||
      (t.indexOf('提问题') >= 0 && t.length <= 8) ||
      (t.indexOf('我要提问') >= 0 && t.length <= 10);
  }

  function findHitIn(doc) {
    if (!doc) { return null; }
    // 1) 标准 button/a 精确文本
    var btns = doc.querySelectorAll('button,[role=button],a');
    for (var i = 0; i < btns.length; i++) {
      var txt = ((btns[i].innerText || btns[i].textContent || '')).trim();
      if (matchesAskText(txt)) { return btns[i]; }
    }
    // 2) 叶子元素包含匹配（文本可能拆 span："提"+"问题"）
    var all = doc.querySelectorAll('*');
    for (var j = 0; j < all.length; j++) {
      var el = all[j];
      if (el.childElementCount === 0) {
        var t = (el.textContent || '').trim();
        if (t.length > 0 && t.length <= 12 && matchesAskText(t)) {
          return (el.closest && el.closest('button,[role=button],a')) || el;
        }
      }
    }
    // 3) 非叶子容器整体文本匹配（文本全在子元素里时父级 innerText 命中）
    for (var k = 0; k < all.length; k++) {
      var c = all[k];
      var ct = ((c.innerText || '')).replace(/\\s+/g, '');
      if (ct.length > 0 && ct.length <= 8 && matchesAskText(ct)) {
        return (c.closest && c.closest('button,[role=button],a')) || c;
      }
    }
    return null;
  }

  function findHit() {
    var hit = findHitIn(document);
    if (hit) { log('hit-in-main'); return hit; }
    // iframe 内搜索（同源 iframe 才可访问）
    try {
      var frames = document.querySelectorAll('iframe');
      for (var f = 0; f < frames.length; f++) {
        try {
          var fd = frames[f].contentDocument;
          if (fd) {
            var fh = findHitIn(fd);
            if (fh) { log('hit-in-iframe:' + f); return fh; }
          }
        } catch (e) { /* 跨源跳过 */ }
      }
    } catch (e) {}
    return null;
  }

  function reportDiag() {
    try {
      var bt = document.body ? (document.body.innerText || '') : '';
      log('diag:body-has-ask=' + (bt.indexOf('提问题') >= 0 || bt.indexOf('提问') >= 0) +
        ' iframes=' + document.querySelectorAll('iframe').length +
        ' has-create-center=' + (bt.indexOf('创作中心') >= 0));
    } catch (e) {}
  }

  var tries = 0;
  var t = setInterval(function(){
    tries++;
    var hit = findHit();
    if (hit) {
      clearInterval(t);
      window.__zlAskClicked = true;
      hit.click();
      log('clicked:' + (hit.tagName || 'el'));
      var checks = 0;
      var ct = setInterval(function(){
        checks++;
        var dlg = document.querySelector('[role=dialog],.Modal-wrapper,.Modal-content,.Modal');
        if (dlg) {
          clearInterval(ct);
          var s = document.createElement('style');
          // 弹窗按桌面 680px 定宽，手机屏上小得没法用——强制全屏自适应
          s.textContent = '.AppHeader,.Sticky,.GlobalSideBar,.Topstory-container,' +
            '.FooterExtras,footer{display:none!important}' +
            '[role=dialog],.Modal-wrapper,.Modal-content{max-width:100vw!important;width:100vw!important;min-width:0!important}' +
            '[role=dialog] *,.Modal-wrapper *,.Modal-content *{max-width:100vw!important}' +
            '.Modal-content{margin:0!important;border-radius:0!important;height:100vh!important}' +
            '.Modal-wrapper{align-items:stretch!important;padding:0!important}';
          document.head.appendChild(s);
          log('modal-open');
        } else if (checks > 16) {
          clearInterval(ct);
          log('no-modal');
        }
      }, 500);
    } else if (tries % 10 === 5) {
      reportDiag();
    }
    if (tries > 100) { clearInterval(t); log('button-not-found'); }
  }, 300);
})();`;

/**
 * 拦截 content/publish 的 XHR/fetch 响应，拿到新问题 id。
 * 幂等（window.__zlHooked），每次 onPageEnd 重新注入以防 SPA 重载丢 hook。
 */
const PUBLISH_HOOK_SCRIPT: string = `(function(){
  if (window.__zlHooked) { return; }
  window.__zlHooked = true;
  window.__zlPublishedQid = '';
  function pick(text) {
    try {
      var m = text.match(/"question"\\s*:\\s*\\{[\\s\\S]{0,300}?"id"\\s*:\\s*"?([0-9]{8,})"?/);
      if (m) { return m[1]; }
      m = text.match(/"id"\\s*:\\s*"?([0-9]{8,})"?/);
      return m ? m[1] : '';
    } catch (e) { return ''; }
  }
  var of = window.fetch;
  if (of) {
    window.fetch = function() {
      var p = of.apply(this, arguments);
      try {
        var u = arguments[0];
        var url = typeof u === 'string' ? u : ((u && u.url) || '');
        if (url.indexOf('content/publish') >= 0) {
          p.then(function(r) { return r.clone().text(); })
            .then(function(t) { window.__zlPublishedQid = pick(t); })
            .catch(function() {});
        }
      } catch (e) {}
      return p;
    };
  }
  var oo = XMLHttpRequest.prototype.open;
  var os = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.open = function(m, u) {
    this.__zlUrl = u;
    return oo.apply(this, arguments);
  };
  XMLHttpRequest.prototype.send = function() {
    var self = this;
    try {
      if (String(self.__zlUrl || '').indexOf('content/publish') >= 0) {
        self.addEventListener('load', function() {
          try { window.__zlPublishedQid = pick(self.responseText || ''); } catch (e) {}
        });
      }
    } catch (e) {}
    return os.apply(this, arguments);
  };
})();`;

/** 一次轮询同时取 pathname 与 hook 捕获的新问题 id（含弹窗状态，方便诊断） */
const WATCH_SNIPPET: string =
  'JSON.stringify({p:location.pathname,q:(window.__zlPublishedQid||""),' +
  'd:!!document.querySelector("[role=dialog],.Modal-wrapper,.Modal-content,.Modal")})';

/**
 * 把原生表单带来的标题/详情填进官方提问弹窗。
 * 等弹窗出现后：第一个可见输入框填标题；先点「问题描述/添加描述」展开再填详情。
 * React 受控输入用 native setter 触发 input 事件，否则状态不更新。
 */
function buildFillScript(title: string, detail: string): string {
  const safeTitle: string = title.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '\\n');
  const safeDetail: string = detail.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '\\n');
  return `(function(){
  function log(m){ try { console.log('ZL_FILL:' + m); } catch(e){} }
  function setVal(el, text) {
    if (!el || !text) { return; }
    if (el.isContentEditable) {
      el.textContent = text;
      try { el.dispatchEvent(new InputEvent('input', { bubbles: true, data: text })); }
      catch (e) { el.dispatchEvent(new Event('input', { bubbles: true })); }
      return;
    }
    var proto = el.tagName === 'TEXTAREA' ? window.HTMLTextAreaElement.prototype :
      (el.tagName === 'INPUT' ? window.HTMLInputElement.prototype : window.HTMLElement.prototype);
    var setter = Object.getOwnPropertyDescriptor(proto, 'value');
    if (setter && setter.set) { setter.set.call(el, text); }
    else { el.value = text; }
    el.dispatchEvent(new Event('input', { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));
  }
  function visible(el) {
    try {
      var r = el.getBoundingClientRect();
      return r.width > 0 && r.height > 0;
    } catch (e) { return false; }
  }
  var tries = 0;
  var t = setInterval(function(){
    tries++;
    var dlg = document.querySelector('[role=dialog],.Modal-wrapper,.Modal-content,.Modal');
    if (!dlg) { if (tries > 100) { clearInterval(t); log('no-dialog'); } return; }
    clearInterval(t);
    log('dialog-found');
    try {
      var fields = dlg.querySelectorAll('input,textarea,[contenteditable=true]');
      var titleEl = null;
      for (var i = 0; i < fields.length; i++) {
        if (visible(fields[i])) { titleEl = fields[i]; break; }
      }
      if (titleEl) { setVal(titleEl, "${safeTitle}"); log('title-filled:' + titleEl.tagName); }
      else { log('title-not-found'); }
      if ("${safeDetail}") {
        var exps = dlg.querySelectorAll('button,[role=button],a,span,div');
        for (var k = 0; k < exps.length; k++) {
          var et = ((exps[k].innerText || exps[k].textContent || '')).trim();
          if (et === '添加问题描述' || et === '问题描述' || et === '添加描述') {
            exps[k].click();
            log('detail-expander-clicked');
            break;
          }
        }
        setTimeout(function(){
          var fields2 = dlg.querySelectorAll('textarea,[contenteditable=true],input');
          var detailEl = null;
          for (var m = 0; m < fields2.length; m++) {
            if (fields2[m] !== titleEl && visible(fields2[m])) { detailEl = fields2[m]; break; }
          }
          if (detailEl) { setVal(detailEl, "${safeDetail}"); log('detail-filled'); }
          else { log('detail-not-found'); }
        }, 600);
      }
    } catch (e) { log('err:' + (e && e.message)); }
  }, 300);
})();`;
}

@Entry
@Component
struct PublishQuestionWebPage {
  private controller: webview.WebviewController = new webview.WebviewController();
  @State loading: boolean = true;
  @State webError: string = '';
  @State isLoggedIn: boolean = hasAuthenticationCookie(authStore.cookies);
  /** 原生表单带来的草稿（自动填入官方提问弹窗） */
  private draftTitle: string = '';
  private draftDetail: string = '';
  private watchTimer: number = -1;
  private watchTickCount: number = 0;

  aboutToAppear(): void {
    const p = router.getParams() as Record<string, object>;
    if (p) {
      this.draftTitle = p['title'] ? String(p['title']) : '';
      this.draftDetail = p['detail'] ? String(p['detail']) : '';
    }
  }

  aboutToDisappear(): void {
    this.stopPublishWatch();
  }

  /** 轮询：发布成功后知乎 SPA 关弹窗回 feed（URL 不变），
   *  所以同时看 pathname 跳转和 hook 捕获的发布响应 question id */
  private startPublishWatch(): void {
    if (this.watchTimer >= 0) {
      return;
    }
    this.watchTimer = setInterval(() => {
      try {
        this.controller.runJavaScript(WATCH_SNIPPET)
          .then((r: string) => {
            let s: string = r;
            if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
              s = s.substring(1, s.length - 1);
            }
            s = s.replace(/\\"/g, '"').replace(/\\\\/g, '\\');
            let path: string = '';
            let qid: string = '';
            let dlg: string = '';
            try {
              const obj: Record<string, string> = JSON.parse(s) as Record<string, string>;
              path = obj['p'] ?? '';
              qid = obj['q'] ?? '';
              dlg = obj['d'] ?? '';
            } catch (e) {
              return;
            }
            // 诊断：每 5 轮打一次页面状态（pathname/弹窗/hook 结果），定位卡点
            this.watchTickCount = this.watchTickCount + 1;
            if (this.watchTickCount % 5 === 1) {
              hilog.info(DOMAIN, TAG, 'watch tick: path=%{public}s dlg=%{public}s qid=%{public}s raw=%{public}s',
                path, dlg, qid, s.substring(0, 120));
            }
            const m: RegExpMatchArray | null = path.match(/^\/question\/(\d+)/);
            const id: string = m && m.length >= 2 ? m[1] : qid;
            if (id.length > 0) {
              this.stopPublishWatch();
              hilog.info(DOMAIN, TAG, 'publish success qid=%{public}s, jump to detail', id);
              router.replaceUrl({ url: 'pages/QuestionDetailPage', params: { id: id } });
            }
          })
          .catch(() => {
          });
      } catch (e) {
        // controller 未就绪等异常忽略
      }
    }, 1200);
  }

  private stopPublishWatch(): void {
    if (this.watchTimer >= 0) {
      clearInterval(this.watchTimer);
      this.watchTimer = -1;
    }
  }

  private reload(): void {
    this.webError = '';
    this.loading = true;
    try {
      this.controller.refresh();
    } catch (e) {
      // ignore
    }
  }

  build() {
    Column({ space: 0 }) {
      Row() {
        Text('‹')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(ZhihuColors.text)
          .onClick(() => {
            router.back();
          })
          .padding({ left: 8, right: 12 })
        Text('提问题（网页版）')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor(ZhihuColors.text)
        Blank()
      }
      .width('100%')
      .height(52)
      .padding({ left: 4, right: 16 })
      .alignItems(VerticalAlign.Center)
      .backgroundColor(isDarkNow() ? '#111111' : '#FFFFFF')

      if (!this.isLoggedIn) {
        Column({ space: 12 }) {
          Text('请先登录')
            .fontSize(18)
            .fontColor(ZhihuColors.text)
          Text('提问题需要知乎登录态，登录后自动返回本页。')
            .fontSize(14)
            .fontColor(ZhihuColors.textSecondary)
          Button('去登录')
            .backgroundColor(ZhihuColors.primary)
            .fontColor(Color.White)
            .onClick(() => {
              router.pushUrl({ url: 'pages/LoginPage' });
            })
        }
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)
        .width('100%')
      } else if (this.webError.length > 0) {
        Column({ space: 12 }) {
          Text('加载失败')
            .fontSize(16)
            .fontColor(ZhihuColors.text)
          Text(this.webError)
            .fontSize(13)
            .fontColor(ZhihuColors.textSecondary)
            .maxLines(3)
          Button('重试')
            .backgroundColor(ZhihuColors.primary)
            .fontColor(Color.White)
            .onClick(() => {
              this.reload();
            })
        }
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)
        .width('100%')
      } else {
        Stack() {
          Web({ src: HOME_URL, controller: this.controller })
            .javaScriptAccess(true)
            .domStorageAccess(true)
            .databaseAccess(true)
            .imageAccess(true)
            .onlineImageAccess(true)
            .mixedMode(MixedMode.All)
            .cacheMode(CacheMode.Default)
            .onControllerAttached(() => {
              try {
                this.controller.setCustomUserAgent(DESKTOP_UA);
              } catch (e) {
                hilog.warn(DOMAIN, TAG, 'setUA failed: %{public}s', String(e));
              }
            })
            .onPageEnd(() => {
              this.loading = false;
              hilog.info(DOMAIN, TAG, 'onPageEnd: inject scripts (draft t=%{public}d d=%{public}d)',
                this.draftTitle.length, this.draftDetail.length);
              try {
                this.controller.runJavaScript(PUBLISH_HOOK_SCRIPT);
                this.controller.runJavaScript(ASK_SCRIPT);
                // 原生表单带来的草稿 → 自动填入官方提问弹窗
                if (this.draftTitle.length > 0 || this.draftDetail.length > 0) {
                  this.controller.runJavaScript(buildFillScript(this.draftTitle, this.draftDetail));
                }
              } catch (e) {
                hilog.warn(DOMAIN, TAG, 'ask script failed: %{public}s', String(e));
              }
              this.startPublishWatch();
            })
            .onConsole((event): boolean => {
              try {
                hilog.info(DOMAIN, TAG, 'web console: %{public}s', event.message.getMessage());
              } catch (e) {
                // ignore
              }
              return true;
            })
            .onErrorReceive((event) => {
              if (event && event.request && event.request.isMainFrame()) {
                const desc: string =
                  (event.error && event.error.getErrorInfo()) ? event.error.getErrorInfo() : '网络错误';
                this.webError = desc;
              }
            })
          if (this.loading) {
            Column({ space: 10 }) {
              LoadingProgress().width(36).height(36)
              Text('正在打开知乎提问…')
                .fontSize(13)
                .fontColor(ZhihuColors.textSecondary)
            }
            .justifyContent(FlexAlign.Center)
            .width('100%')
            .layoutWeight(1)
            .backgroundColor(isDarkNow() ? '#111111' : '#FFFFFF')
          }
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(isDarkNow() ? '#111111' : '#FFFFFF')
  }
}
