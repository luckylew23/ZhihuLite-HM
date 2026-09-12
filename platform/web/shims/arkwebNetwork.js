/**
 * arkwebNetwork.js —— ArkWeb 原生网络桥的 Web 侧垫片
 * ---------------------------------------------------------------------------
 * 由 scripts/inline-single-file.mjs 注入到 <head>（在业务脚本之前执行）。
 *
 * 背景：页面源是 resource://rawfile（opaque origin），知乎接口不返回
 * Access-Control-Allow-Origin → 页面里的 XHR/fetch 全被浏览器 CORS 拦死
 * → 表现为「界面出来了但永远空态 + NetworkError」。
 *
 * 本垫片把**知乎域名**的请求改道到 ArkTS 注册的 window.__zhihuBridge
 * （见 harmony/entry/src/main/ets/bridge/ZhihuBridge.ets），由 @ohos.net.http
 * 在原生侧发出 —— 不受 CORS 约束，且原生统一维护 Cookie Jar。
 *
 * 设计约束：
 *   1) 桥**调用时**惰性解析，绝不在安装时一次性判定是否可用。
 *      ArkWeb 的 javaScriptProxy 在首屏 <head> 脚本执行时往往尚未绑定，
 *      若安装时直接 return，垫片不会安装 → 后续 XHR 走原生被 CORS 拦死
 *      （这正是「unhandledrejection networkerror」的根因）。
 *   2) 非 ArkWeb 环境（本地 Chrome 复现，location 非 resource:）→ 不等待桥，
 *      直接回退原生 XHR/fetch，保持原生网络行为，复现结果可信。
 *   3) 非知乎域名的请求（Sentry、GitHub 更新检查等）**回退原生 XHR/fetch**，
 *      不做任何改动。
 *   4) 完整实现 XHR 语义（readyState/status/responseText/getAllResponseHeaders/
 *      upload/abort 等），因为 axios 走的是 XHR adapter。
 * ---------------------------------------------------------------------------
 */
(function () {
  'use strict';

  // 只在 ArkWeb（rawfile 源）下等待桥就绪；本地复现协议是 http: → 不等待。
  var IS_ARKWEB = (function () {
    try { return location.protocol === 'resource:'; } catch (e) { return false; }
  })();

  function getBridge() {
    var b = window.__zhihuBridge;
    return b && typeof b.request === 'function' ? b : null;
  }

  // 给桥最多 waitMs 时间就绪（首屏 onPageEnd 后才会注册并完成 bootstrap）。
  // 判定"是否需要等待桥"不再依赖 location.protocol 的字符串比较（设备上该值未必是
  // 精确的 'resource:'，一旦误判为"非 ArkWeb"就会立即放弃、请求直接失败）。
  // 改为：只要是 http:/https:（本地浏览器，从不注册桥）就立即回退原生；
  // 其余协议（resource: / about: 等 —— 即 ArkWeb）一律轮询等待桥就绪。
  function waitForBridge(waitMs) {
    return new Promise(function (resolve) {
      var b = getBridge();
      if (b) return resolve(b);
      var proto = '';
      try { proto = location.protocol; } catch (e) { proto = ''; }
      var isLocal = proto === 'http:' || proto === 'https:';
      if (isLocal) return resolve(null);
      var waited = 0;
      var step = 80;
      var timer = setInterval(function () {
        waited += step;
        var bb = getBridge();
        if (bb || waited >= waitMs) {
          clearInterval(timer);
          resolve(bb || null);
        }
      }, step);
    });
  }

  var PROXY_HOST_SUFFIXES = ['zhihu.com', 'zhimg.com', 'zhihu-pics.com'];

  function endsWith(s, suffix) {
    return s.length >= suffix.length && s.lastIndexOf(suffix) === s.length - suffix.length;
  }

  function shouldProxy(url) {
    if (!url) return false;
    var u;
    try {
      u = new URL(String(url), location.href);
    } catch (e) {
      return false;
    }
    if (u.protocol !== 'https:' && u.protocol !== 'http:') return false;
    var h = u.hostname.toLowerCase();
    for (var i = 0; i < PROXY_HOST_SUFFIXES.length; i++) {
      var s = PROXY_HOST_SUFFIXES[i];
      if (h === s || endsWith(h, '.' + s)) return true;
    }
    return false;
  }

  function headersToObject(h) {
    var out = {};
    if (!h) return out;
    if (typeof Headers !== 'undefined' && h instanceof Headers) {
      h.forEach(function (v, k) {
        out[k] = v;
      });
      return out;
    }
    if (Array.isArray(h)) {
      for (var i = 0; i < h.length; i++) {
        if (h[i] && h[i].length >= 2) out[h[i][0]] = h[i][1];
      }
      return out;
    }
    if (typeof h === 'object') {
      for (var k2 in h) {
        if (Object.prototype.hasOwnProperty.call(h, k2)) out[k2] = h[k2];
      }
    }
    return out;
  }

  // ---------------------------------------------------------------- XHR ----
  var NativeXHR = window.XMLHttpRequest;

  function ProxyXHR() {
    this.readyState = 0;
    this.status = 0;
    this.statusText = '';
    this.responseText = '';
    this.response = null;
    this.responseType = '';
    this.responseURL = '';
    this.timeout = 0;
    this.withCredentials = false;
    this.onreadystatechange = null;
    this.onloadstart = null;
    this.onprogress = null;
    this.onload = null;
    this.onerror = null;
    this.ontimeout = null;
    this.onabort = null;
    this.onloadend = null;

    var noopTarget = {
      addEventListener: function () {},
      removeEventListener: function () {},
      dispatchEvent: function () {
        return true;
      },
    };
    this.upload = noopTarget;

    this._method = 'GET';
    this._url = '';
    this._headers = {};
    this._respHeaders = {};
    this._listeners = {};
    this._aborted = false;
    this._fallback = null;
  }

  ProxyXHR.UNSENT = 0;
  ProxyXHR.OPENED = 1;
  ProxyXHR.HEADERS_RECEIVED = 2;
  ProxyXHR.LOADING = 3;
  ProxyXHR.DONE = 4;

  ProxyXHR.prototype.addEventListener = function (type, fn) {
    if (!this._listeners[type]) this._listeners[type] = [];
    this._listeners[type].push(fn);
  };
  ProxyXHR.prototype.removeEventListener = function (type, fn) {
    var arr = this._listeners[type];
    if (!arr) return;
    var idx = arr.indexOf(fn);
    if (idx >= 0) arr.splice(idx, 1);
  };
  ProxyXHR.prototype.dispatchEvent = function (ev) {
    this._emit(ev && ev.type ? ev.type : '', ev);
    return true;
  };
  ProxyXHR.prototype._emit = function (type, ev) {
    var self = this;
    var handler = this['on' + type];
    if (typeof handler === 'function') {
      try {
        handler.call(this, ev || { type: type, target: this });
      } catch (e) {
        /* 业务回调抛错不应中断分发 */
      }
    }
    var arr = this._listeners[type];
    if (arr) {
      arr.slice().forEach(function (fn) {
        try {
          fn.call(self, ev || { type: type, target: self });
        } catch (e) {}
      });
    }
  };

  ProxyXHR.prototype.open = function (method, url) {
    this._method = String(method || 'GET').toUpperCase();
    this._url = String(url);
    this.readyState = 1;
    if (shouldProxy(this._url)) {
      this._fallback = null;
    } else if (NativeXHR) {
      this._fallback = new NativeXHR();
      try {
        this._fallback.open(this._method, this._url, true);
      } catch (e) {
        this._fallback = null;
      }
    }
    this._emit('readystatechange');
  };

  ProxyXHR.prototype.setRequestHeader = function (k, v) {
    this._headers[String(k)] = String(v);
    if (this._fallback) {
      try {
        this._fallback.setRequestHeader(k, v);
      } catch (e) {}
    }
  };

  ProxyXHR.prototype.getResponseHeader = function (k) {
    if (this._fallback) {
      try {
        return this._fallback.getResponseHeader(k);
      } catch (e) {
        return null;
      }
    }
    var key = String(k).toLowerCase();
    return Object.prototype.hasOwnProperty.call(this._respHeaders, key) ? this._respHeaders[key] : null;
  };

  ProxyXHR.prototype.getAllResponseHeaders = function () {
    if (this._fallback) {
      try {
        return this._fallback.getAllResponseHeaders();
      } catch (e) {
        return '';
      }
    }
    var out = [];
    for (var k in this._respHeaders) {
      if (Object.prototype.hasOwnProperty.call(this._respHeaders, k)) {
        out.push(k + ': ' + this._respHeaders[k]);
      }
    }
    return out.join('\r\n');
  };

  ProxyXHR.prototype.overrideMimeType = function () {};
  ProxyXHR.prototype.abort = function () {
    this._aborted = true;
    if (this._fallback) {
      try {
        this._fallback.abort();
      } catch (e) {}
    }
    this._emit('abort');
  };

  ProxyXHR.prototype._fail = function (msg) {
    this.status = 0;
    this.responseText = '';
    this.response = '';
    this.readyState = 4;
    this._emit('readystatechange');
    this._emit('error');
    this._emit('loadend');
  };

  ProxyXHR.prototype.send = function (body) {
    var self = this;
    this._emit('loadstart');

    // 非知乎域名 → 原样走原生 XHR
    if (this._fallback) {
      var fb = this._fallback;
      fb.onreadystatechange = function () {
        self.readyState = fb.readyState;
        if (fb.readyState === 4) {
          self.status = fb.status;
          self.statusText = fb.statusText;
          try {
            self.responseText = fb.responseText;
          } catch (e) {
            self.responseText = '';
          }
          self.response = fb.response !== undefined ? fb.response : self.responseText;
          self.responseURL = fb.responseURL || self._url;
        }
        self._emit('readystatechange');
      };
      fb.onload = function () { self._emit('load'); };
      fb.onerror = function () { self._emit('error'); };
      fb.ontimeout = function () { self._emit('timeout'); };
      fb.onloadend = function () { self._emit('loadend'); };
      try {
        fb.send(body);
      } catch (e) {
        self._emit('error');
        self._emit('loadend');
      }
      return;
    }

    // 知乎域名 → 必须经原生桥；调用时惰性等待桥就绪
    var payload = '';
    if (body !== undefined && body !== null) {
      payload = typeof body === 'string' ? body : String(body);
    }

    waitForBridge(4000).then(function (bridge) {
      if (self._aborted) return;
      if (!bridge) {
        // 非 ArkWeb 环境：桥永不就绪，回退原生（本地复现用；知乎仍会被 CORS 拦，属预期）
        self._fail('zhihu bridge unavailable (not ArkWeb?)');
        return;
      }
      bridge
        .request(self._url, self._method, JSON.stringify(self._headers), payload)
        .then(function (raw) {
          if (self._aborted) return;
          var res;
          try {
            res = JSON.parse(raw);
          } catch (e) {
            res = { status: 0, statusText: '', headers: {}, body: '', error: String(e) };
          }

          self._respHeaders = res.headers || {};
          // 让业务侧读到 CORS 头，避免任何二次校验逻辑误判
          if (!self._respHeaders['access-control-allow-origin']) {
            self._respHeaders['access-control-allow-origin'] = '*';
          }
          self.status = res.status || 0;
          self.statusText = res.statusText || '';
          self.responseText = res.body || '';
          self.response = self.responseText;
          self.responseURL = self._url;
          self.readyState = 4;

          if (res.error) {
            self._emit('readystatechange');
            self._emit('error');
            self._emit('loadend');
            return;
          }
          self._emit('readystatechange');
          self._emit('load');
          self._emit('loadend');
        })
        .catch(function (e) {
          if (self._aborted) return;
          self.status = 0;
          self.responseText = '';
          self.response = '';
          self.readyState = 4;
          self._emit('readystatechange');
          self._emit('error');
          self._emit('loadend');
        });
    });
  };

  window.XMLHttpRequest = ProxyXHR;
  window.__nativeXMLHttpRequest = NativeXHR;

  // -------------------------------------------------------------- fetch ----
  var nativeFetch = typeof window.fetch === 'function' ? window.fetch.bind(window) : null;

  window.fetch = function (input, init) {
    var url = typeof input === 'string' ? input : input && input.url ? String(input.url) : '';
    var opts = init || (typeof input !== 'string' && input ? input : {});

    // 非知乎域名 → 原样走原生
    if (!shouldProxy(url)) {
      if (!nativeFetch) return Promise.reject(new Error('fetch unavailable'));
      return nativeFetch(input, init);
    }

    var method = (opts && opts.method) || 'GET';
    var headers = headersToObject(opts && opts.headers);
    var body = '';
    if (opts && opts.body !== undefined && opts.body !== null) {
      body = typeof opts.body === 'string' ? opts.body : String(opts.body);
    }

    return waitForBridge(4000).then(function (bridge) {
      // 非 ArkWeb：桥永不就绪，回退原生 fetch（本地复现；知乎仍会被 CORS 拦，属预期）
      if (!bridge) {
        if (!nativeFetch) return Promise.reject(new Error('fetch unavailable'));
        return nativeFetch(input, init);
      }
      return bridge.request(url, method, JSON.stringify(headers), body).then(function (raw) {
        var res;
        try {
          res = JSON.parse(raw);
        } catch (e) {
          res = { status: 0, headers: {}, body: '', error: String(e) };
        }
        if (res.error) {
          throw new Error(res.error);
        }
        var status = res.status && res.status > 0 ? res.status : 200;
        return new Response(res.body || '', {
          status: status,
          statusText: res.statusText || '',
          headers: res.headers || {},
        });
      });
    });
  };

  window.__hmosNetworkProxyReady = true;
})();
