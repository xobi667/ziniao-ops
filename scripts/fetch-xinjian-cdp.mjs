#!/usr/bin/env node
import fs from "node:fs/promises";
import path from "node:path";

function argValue(name, fallback = "") {
  const index = process.argv.indexOf(name);
  if (index < 0 || index + 1 >= process.argv.length) return fallback;
  return process.argv[index + 1];
}

function parseJsonArg(name, fallback) {
  const b64 = argValue(`${name}-b64`, "");
  const text = b64 ? Buffer.from(b64, "base64").toString("utf8") : argValue(`${name}-json`, "");
  if (!text) return fallback;
  return JSON.parse(text);
}

function splitStores(values) {
  const raw = Array.isArray(values) ? values : [values];
  return raw
    .flatMap((value) => String(value || "").split(","))
    .map((value) => value.trim())
    .filter(Boolean);
}

function inferLoginState({ pageState, responseCode, method, httpStatus }) {
  const href = String(pageState?.href || "");
  const title = String(pageState?.title || "");
  if (pageState?.hasPasswordInput || /\/login\b|\/auth\b/i.test(href)) {
    return "not_logged_in";
  }
  if (responseCode === 401) {
    if (/首页|心舰|home/i.test(title) && !pageState?.hasPasswordInput) {
      return "page_logged_in_request_unauthorized";
    }
    return "not_logged_in";
  }
  if (method === "app_module" && (responseCode === 0 || responseCode === 200)) {
    return "app_authenticated";
  }
  if (httpStatus && httpStatus >= 200 && httpStatus < 300 && responseCode !== 401) {
    return "endpoint_authenticated";
  }
  if (/首页|心舰|home/i.test(title) && !pageState?.hasPasswordInput) {
    return "page_logged_in";
  }
  return "unknown";
}

const port = Number(argValue("--port", "9339"));
const endpoint = argValue("--endpoint");
const body = parseJsonArg("--body", {});
const stores = splitStores(parseJsonArg("--stores", []));
const out = argValue("--out");
const navigateUrl = argValue("--navigate-url", "");
const navigateWaitMs = Number(argValue("--navigate-wait-ms", "10000"));
const websocketUrl = argValue("--websocket-url", "");
const matchUrl = argValue("--match-url", "");

if (!Number.isFinite(port) || port <= 0) {
  throw new Error("Invalid --port.");
}
if (!endpoint) {
  throw new Error("Missing --endpoint.");
}
if (!out) {
  throw new Error("Missing --out.");
}

const pages = websocketUrl ? [] : await (await fetch(`http://127.0.0.1:${port}/json`)).json();
function parseUrl(value) {
  try {
    return new URL(String(value || ""));
  } catch {
    return null;
  }
}

function comparablePath(value) {
  return String(value || "").replace(/\/+$/g, "") || "/";
}

const targetUrl = parseUrl(matchUrl);
function pageScore(item) {
  const url = String(item.url || "");
  const title = String(item.title || "");
  const currentUrl = parseUrl(url);
  let score = 0;
  if (item.type === "page") score += 10;
  if (url.includes("erp.xinjianerp.com")) score += 20;
  if (title.includes("心舰")) score += 40;
  if (title.includes("首页")) score += 20;
  if (title === "erp.xinjianerp.com/index/home") score -= 30;
  if (url.startsWith("chrome-extension://")) score -= 100;
  if (targetUrl && currentUrl) {
    if (currentUrl.href === targetUrl.href) score += 120;
    if (currentUrl.origin === targetUrl.origin) score += 80;
    if (currentUrl.hostname === targetUrl.hostname) score += 60;
    const currentPath = comparablePath(currentUrl.pathname);
    const targetPath = comparablePath(targetUrl.pathname);
    if (currentPath === targetPath) score += 50;
    else if (currentPath.startsWith(targetPath) || targetPath.startsWith(currentPath)) score += 25;
    if (targetUrl.search && currentUrl.search === targetUrl.search) score += 10;
  } else if (matchUrl && url.includes(matchUrl)) {
    score += 30;
  }
  return score;
}

const page = websocketUrl
  ? { webSocketDebuggerUrl: websocketUrl, url: "", title: "" }
  : pages
    .filter((item) => item.webSocketDebuggerUrl && item.type === "page")
    .sort((a, b) => pageScore(b) - pageScore(a))[0];

if (!page?.webSocketDebuggerUrl) {
  throw new Error(`No debuggable page was found on port ${port}.`);
}

const expression = `(() => {
  return (async () => {
    const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
    for (let index = 0; index < 40; index += 1) {
      const text = (document.body && document.body.innerText) || "";
      if (document.querySelector("#app") || /首页|心舰|home/i.test(document.title) || /登录|登陆|login/i.test(text)) {
        break;
      }
      await sleep(250);
    }
    const endpoint = ${JSON.stringify(endpoint)};
    const baseBody = ${JSON.stringify(body)};
    const requestedStores = ${JSON.stringify(stores)};
    const pageState = {
      href: location.href,
      title: document.title,
      hasPasswordInput: !!document.querySelector('input[type="password"]'),
      hasLoginButtonText: /登录|登陆|login/i.test((document.body && document.body.innerText) || ""),
      hasAppRoot: !!document.querySelector("#app")
    };

    const clone = (value) => JSON.parse(JSON.stringify(value));
    const withTimeout = (promise, ms, label) => Promise.race([
      promise,
      new Promise((_, reject) => setTimeout(() => reject(new Error(label || "timeout")), ms))
    ]);
    const normalize = (value) => String(value || "")
      .toLowerCase()
      .replace(/\\s+/g, "")
      .replace(/自营/g, "");
    const shopText = (shop) => [
      shop.shopName,
      shop.alias,
      shop.name,
      shop.fullPinyin,
      shop.shortPinyin,
      shop.region,
      shop.platform,
      shop.platformShopId,
      shop.id
    ].filter(Boolean).join(" | ");
    const compactShop = (shop) => ({
      id: shop.id,
      shopName: shop.shopName || shop.alias || shop.name || String(shop.id),
      alias: shop.alias || null,
      name: shop.name || null,
      region: shop.region || null,
      platform: shop.platform || null,
      platformShopId: shop.platformShopId || null
    });
    const collectShops = (value, rows = []) => {
      if (Array.isArray(value)) {
        value.forEach((item) => collectShops(item, rows));
      } else if (value && typeof value === "object") {
        const keys = Object.keys(value);
        const hasId = Object.prototype.hasOwnProperty.call(value, "id");
        const hasShopName = keys.some((key) => /shop|alias|name|region|platform/i.test(key));
        if (hasId && hasShopName && (value.shopName || value.alias || value.name || value.platformShopId)) {
          rows.push(value);
        }
        keys.forEach((key) => collectShops(value[key], rows));
      }
      return rows;
    };
    const uniqueShops = (rows) => {
      const seen = new Set();
      const result = [];
      rows.forEach((shop) => {
        const key = String(shop.id || shop.shopName || shop.alias || shop.name || "");
        if (!key || seen.has(key)) return;
        seen.add(key);
        result.push(shop);
      });
      return result;
    };
    const matchShop = (requested, rows) => {
      const target = normalize(requested);
      const exact = rows.find((shop) => normalize(shopText(shop)).includes(target));
      if (exact) return exact;
      return null;
    };
    const suggestShops = (requested, rows) => {
      const raw = normalize(requested);
      const base = raw.split("-")[0].replace(/(th|my|sg|ph|vn|id|sp)$/i, "");
      if (!base || base.length < 3) return [];
      return rows
        .filter((shop) => normalize(shopText(shop)).includes(base))
        .slice(0, 5)
        .map(compactShop);
    };
    const attachStore = (record, matched, requested) => ({
      ...record,
      store: matched.shopName || matched.alias || matched.name || requested,
      shopName: matched.shopName || matched.alias || matched.name || requested,
      shopId: matched.id,
      sourceShopRequested: requested
    });
    const ensureWebpackRequire = () => {
      if (!window.__codex_wp_req && window.webpackJsonp && window.webpackJsonp.push) {
        const id = "codex_" + Math.random().toString(36).slice(2);
        window.webpackJsonp.push([[id], {
          [id]: function(module, exports, __webpack_require__) {
            window.__codex_wp_req = __webpack_require__;
          }
        }, [[id]]]);
      }
      return window.__codex_wp_req;
    };

    let appModuleError = null;
    try {
      const req = ensureWebpackRequire();
      if (req) {
        const bi = req("./src/api/bi.js");
        if (bi && typeof bi.summaryByDate_v2 === "function") {
          if (requestedStores.length > 0) {
            let shopRows = [];
            try {
              const shopApi = req("./src/api/erp/shop.js");
              const shopCalls = [];
              if (shopApi && typeof shopApi.getShopPage === "function") {
                shopCalls.push(shopApi.getShopPage({ pageNo: 1, pageSize: 500 }));
              }
              if (shopApi && typeof shopApi.getShops === "function") {
                shopCalls.push(shopApi.getShops({}));
              }
              const shopResults = await Promise.allSettled(shopCalls);
              shopRows = uniqueShops(shopResults.flatMap((item) => (
                item.status === "fulfilled" ? collectShops(item.value) : []
              )));
            } catch (error) {
              appModuleError = "shop_lookup_failed: " + String(error && (error.message || error));
            }

            const matched = [];
            const notFound = [];
            const suggestions = {};
            requestedStores.forEach((requested) => {
              const row = matchShop(requested, shopRows);
              if (row) {
                matched.push({ requested, shop: compactShop(row) });
              } else {
                notFound.push(requested);
                suggestions[requested] = suggestShops(requested, shopRows);
              }
            });

            const currentData = [];
            const preData = [];
            const perStore = [];
            let responseCode = 0;
            let responseMsg = "";
            for (const item of matched) {
              const requestBody = { ...baseBody, shopIds: [item.shop.id] };
              const response = clone(await withTimeout(
                bi.summaryByDate_v2(requestBody),
                20000,
                "summaryByDate_v2_timeout"
              ));
              responseCode = response.code ?? responseCode;
              responseMsg = response.msg ?? responseMsg;
              const data = response.data || {};
              const currentRows = Array.isArray(data.currentData) ? data.currentData : [];
              const previousRows = Array.isArray(data.preData) ? data.preData : [];
              currentRows.forEach((record) => currentData.push(attachStore(record, item.shop, item.requested)));
              previousRows.forEach((record) => preData.push(attachStore(record, item.shop, item.requested)));
              perStore.push({
                requested: item.requested,
                shop: item.shop,
                code: response.code ?? null,
                msg: response.msg ?? "",
                current_rows: currentRows.length,
                previous_rows: previousRows.length
              });
            }

            return {
              method: "app_module",
              pageState,
              appModuleError,
              result: {
                code: matched.length > 0 ? responseCode : 0,
                msg: responseMsg,
                data: { currentData, preData },
                codexMeta: {
                  stores_requested: requestedStores,
                  stores_matched: matched,
                  stores_not_found: notFound,
                  store_suggestions: suggestions,
                  per_store: perStore,
                  shop_lookup_rows: shopRows.length
                }
              }
            };
          }

          const result = clone(await withTimeout(
            bi.summaryByDate_v2(baseBody),
            20000,
            "summaryByDate_v2_timeout"
          ));
          return { method: "app_module", pageState, result, appModuleError };
        }
        appModuleError = "summaryByDate_v2_unavailable";
      } else {
        appModuleError = "webpack_require_unavailable";
      }
    } catch (error) {
      appModuleError = String(error && (error.message || error));
    }

    let response = null;
    let text = "";
    let parsed = null;
    try {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), 15000);
      response = await fetch(endpoint, {
        method: "POST",
        headers: { "content-type": "application/json;charset=UTF-8" },
        body: JSON.stringify(baseBody),
        credentials: "include",
        signal: controller.signal
      });
      clearTimeout(timer);
      text = await response.text();
      try { parsed = JSON.parse(text); } catch (error) {}
    } catch (error) {
      parsed = {
        code: pageState.hasPasswordInput ? 401 : null,
        msg: String(error && (error.message || error))
      };
      text = JSON.stringify(parsed);
    }
    return {
      method: "native_fetch",
      pageState,
      status: response ? response.status : null,
      text,
      parsed,
      appModuleError
    };
  })();
})()`;

const ws = new WebSocket(page.webSocketDebuggerUrl);
let cdpId = 1;
const value = await new Promise((resolve, reject) => {
  const cleanup = () => {
    if (loadTimer) clearTimeout(loadTimer);
    try { ws.close(); } catch {}
  };
  const timer = setTimeout(() => {
    cleanup();
    reject(new Error("CDP evaluation timed out."));
  }, 60000);
  let loadTimer = null;
  let evaluateSent = false;
  let evaluateId = null;
  const send = (method, params = {}) => {
    const id = cdpId++;
    ws.send(JSON.stringify({ id, method, params }));
    return id;
  };
  const sendEvaluate = () => {
    if (evaluateSent) return;
    evaluateSent = true;
    if (loadTimer) clearTimeout(loadTimer);
    evaluateId = send("Runtime.evaluate", { expression, awaitPromise: true, returnByValue: true });
  };
  ws.onopen = () => {
    if (navigateUrl) {
      send("Page.enable");
      send("Runtime.enable");
      send("Page.navigate", { url: navigateUrl });
      loadTimer = setTimeout(sendEvaluate, Number.isFinite(navigateWaitMs) ? navigateWaitMs : 10000);
    } else {
      sendEvaluate();
    }
  };
  ws.onmessage = (event) => {
    const message = JSON.parse(event.data);
    if (message.method === "Page.loadEventFired" && navigateUrl) {
      setTimeout(sendEvaluate, 1000);
      return;
    }
    if (!evaluateSent || message.id !== evaluateId) return;
    clearTimeout(timer);
    cleanup();
    if (message.error) {
      reject(new Error(JSON.stringify(message.error)));
      return;
    }
    if (message.result?.exceptionDetails) {
      reject(new Error(JSON.stringify(message.result.exceptionDetails)));
      return;
    }
    resolve(message.result?.result?.value);
  };
  ws.onerror = () => {
    clearTimeout(timer);
    cleanup();
    reject(new Error("CDP websocket error."));
  };
});

if (!value || typeof value !== "object") {
  throw new Error("CDP evaluation did not return a structured result.");
}

let parsed = null;
let bodyText = "";
if (value.method === "app_module" && value.result) {
  parsed = value.result;
  bodyText = JSON.stringify(value.result, null, 2);
} else if (typeof value.text === "string") {
  bodyText = value.text;
  parsed = value.parsed;
  if (!parsed) {
    try {
      parsed = JSON.parse(value.text);
    } catch {
      parsed = {};
    }
  }
} else {
  throw new Error("CDP evaluation did not return a response body.");
}

await fs.mkdir(path.dirname(out), { recursive: true });
await fs.writeFile(out, bodyText, "utf8");

const responseCode = parsed?.code ?? null;
const responseMsg = parsed?.msg ?? null;
const meta = parsed?.codexMeta || {};
const loginState = inferLoginState({
  pageState: value.pageState,
  responseCode,
  method: value.method,
  httpStatus: value.status,
});

process.stdout.write(
  JSON.stringify(
    {
      ok: true,
      method: value.method,
      login_state: loginState,
      page_url: value.pageState?.href || page.url || null,
      page_match_url: matchUrl || null,
      page_title: value.pageState?.title || page.title || null,
      has_password_input: !!value.pageState?.hasPasswordInput,
      has_login_button_text: !!value.pageState?.hasLoginButtonText,
      has_app_root: !!value.pageState?.hasAppRoot,
      http_status: value.status ?? null,
      response_code: responseCode,
      response_msg: responseMsg,
      app_module_error: value.appModuleError || null,
      stores_requested: meta.stores_requested || stores,
      stores_matched: meta.stores_matched || [],
      stores_not_found: meta.stores_not_found || [],
      store_suggestions: meta.store_suggestions || {},
      per_store: meta.per_store || [],
      response_path: path.resolve(out),
    },
    null,
    2,
  ),
);
