/**
 * debugOverlay.js —— 屏上诊断面板（仅 HMOS_DEBUG=1 注入）
 * ---------------------------------------------------------------------------
 * ArkWeb 里看不到 devtools，所有状态只能糊在页面上。本面板把关键运行时信号
 * 实时打印到页面顶部，便于把"暂无内容 / 点击没反应"这样的模糊反馈定位到：
 *   - 桥是否就绪（window.__zhihuBridge.request）
 *   - 游客态是否解锁（globalThis.__guestReady）
 *   - 每个 zhihu 请求最终走到桥没有、返回 status/body 前 200 字/错误信息
 * 用户装好后截图顶部面板即可，无需抓 log。
 * ---------------------------------------------------------------------------
 */
(function () {
  'use strict';
  var last = [];
  var reqCount = 0;

  function panel() {
    var el = document.getElementById('__hmos_diag__');
    if (!el) {
      el = document.createElement('pre');
      el.id = '__hmos_diag__';
      el.style.cssText =
        'position:fixed;left:0;top:0;right:0;z-index:2147483646;' +
        'max-height:55%;overflow:auto;margin:0;padding:8px 10px;white-space:pre-wrap;' +
        'word-break:break-all;background:rgba(0,20,40,.85);color:#9fe7ff;' +
        'font:11px/1.45 monospace;border-bottom:1px solid #2af;';
      (document.body || document.documentElement).appendChild(el);
    }
    return el;
  }

  function proto() {
    try { return location.protocol; } catch (e) { return '?'; }
  }

  // 包装桥 request：记录每一次调用的结果
  function hookBridge() {
    var b = window.__zhihuBridge;
    if (!b || typeof b.request !== 'function') return;
    if (b.__hooked) return;
    b.__hooked = true;
    var orig = b.request.bind(b);
    b.request = function () {
      var args = Array.prototype.slice.call(arguments);
      var url = String(args[0] || '');
      var host = '';
      try { host = new URL(url, location.href).host; } catch (e) {}
      reqCount++;
      var seq = reqCount;
      return Promise.resolve(orig.apply(null, args)).then(function (raw) {
        var status = '?', err = '', body = '';
        try {
          var r = JSON.parse(raw);
          status = r.status; err = r.error || ''; body = (r.body || '').slice(0, 200);
        } catch (e) { body = String(raw).slice(0, 200); }
        last.unshift(
          '#' + seq + ' ' + (args[1] || 'GET') + ' ' + host +
          ' -> s=' + status + (err ? ' ERR=' + err.slice(0, 160) : '') +
          (body ? '\n   body: ' + body : '')
        );
        if (last.length > 5) last.pop();
        render();
        return raw;
      }).catch(function (e) {
        last.unshift('#' + seq + ' ' + (args[1] || 'GET') + ' ' + host + ' -> REJECT ' + String(e).slice(0, 160));
        if (last.length > 5) last.pop();
        render();
        throw e;
      });
    };
  }

  function render() {
    try {
      var bridge = window.__zhihuBridge;
      var hasReq = bridge && typeof bridge.request === 'function';
      var lines = [
        'HMOS-DIAG  proto=' + proto() +
          '  shim=' + (window.__hmosNetworkProxyReady ? 'Y' : 'n') +
          '  bridge=' + (hasReq ? 'Y' : 'n') +
          '  guest=' + (window.__guestReady ? 'Y' : 'n') +
          '  reqs=' + reqCount,
      ];
      for (var i = 0; i < last.length; i++) lines.push(last[i]);
      panel().textContent = lines.join('\n');
    } catch (e) {}
  }

  hookBridge();
  setInterval(function () { hookBridge(); render(); }, 700);
})();
