#!/usr/bin/env node
import path from "node:path";
import fs from "node:fs/promises";

function argValue(name, fallback = "") {
  const index = process.argv.indexOf(name);
  if (index < 0 || index + 1 >= process.argv.length) return fallback;
  return process.argv[index + 1];
}

const port = Number(argValue("--port", "9342"));
const matchUrl = argValue("--match-url", "");
const out = argValue("--out", "");
const maxRoutes = Number(argValue("--max-routes", "300"));

if (!Number.isFinite(port) || port <= 0) throw new Error("Invalid --port.");
if (!out) throw new Error("Missing --out.");

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

function pageScore(item) {
  const url = String(item.url || "");
  const title = String(item.title || "");
  const currentUrl = parseUrl(url);
  const targetUrl = parseUrl(matchUrl);
  let score = 0;
  if (item.type === "page") score += 10;
  if (url.includes("erp.xinjianerp.com")) score += 50;
  if (title.includes("心舰")) score += 40;
  if (url.startsWith("chrome-extension://")) score -= 100;
  if (targetUrl && currentUrl) {
    if (currentUrl.href === targetUrl.href) score += 120;
    if (currentUrl.origin === targetUrl.origin) score += 80;
    const currentPath = comparablePath(currentUrl.pathname);
    const targetPath = comparablePath(targetUrl.pathname);
    if (currentPath === targetPath) score += 80;
    else if (currentPath.startsWith(targetPath) || targetPath.startsWith(currentPath)) score += 25;
  }
  return score;
}

const pages = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
const page = pages
  .filter((item) => item.webSocketDebuggerUrl && item.type === "page")
  .sort((a, b) => pageScore(b) - pageScore(a))[0];

if (!page?.webSocketDebuggerUrl) {
  throw new Error(`No debuggable page was found on port ${port}.`);
}

const expression = `(() => {
  const clean = (value) => String(value || "")
    .replace(/[\\uE000-\\uF8FF]/g, " ")
    .replace(/\\s+/g, " ")
    .trim();
  const redactUrl = (value) => String(value || "").replace(
    /([?&][^=]*(token|secret|password|passwd|pwd|cookie|session|auth|key|code)[^=]*=)[^&#]*/ig,
    "$1[redacted]"
  );
  const isVisible = (el) => {
    const style = window.getComputedStyle(el);
    const rect = el.getBoundingClientRect();
    return style && style.display !== "none" && style.visibility !== "hidden" && rect.width > 0 && rect.height > 0;
  };
  const normalizeRoutePath = (value) => {
    const text = clean(value);
    if (!text) return "";
    if (text === "/") return "/";
    return text.replace(/\\/+/g, "/").replace(/\\/$/, "");
  };
  const joinRoutePath = (parent, child) => {
    const parentPath = normalizeRoutePath(parent);
    const childPath = clean(child);
    if (!childPath) return parentPath || "/";
    if (childPath.startsWith("/")) return normalizeRoutePath(childPath);
    if (!parentPath || parentPath === "/") return normalizeRoutePath("/" + childPath);
    return normalizeRoutePath(parentPath + "/" + childPath);
  };
  const paramsOf = (value) => Array.from(String(value || "").matchAll(/:([A-Za-z0-9_]+)/g)).map((match) => match[1]);
  const routeRows = [];
  const collectRoute = (route, source, parentFullPath = "") => {
    if (!route || typeof route !== "object") return;
    const meta = route.meta || {};
    const fullPath = joinRoutePath(parentFullPath, route.path);
    const rawPath = clean(route.path);
    routeRows.push({
      source,
      path: rawPath,
      full_path: fullPath,
      name: clean(route.name),
      meta_title: clean(meta.title || meta.name || meta.label),
      redirect: clean(route.redirect),
      hidden: !!route.hidden,
      always_show: !!route.alwaysShow,
      dynamic: /[:()*]/.test(fullPath),
      params: paramsOf(fullPath),
      navigable_without_params: fullPath && !/[:()*]/.test(fullPath) && clean(route.redirect) !== "noredirect"
    });
    for (const child of Array.from(route.children || [])) {
      collectRoute(child, source, fullPath);
    }
  };
  const dedupe = (rows, keyFn) => {
    const seen = new Set();
    const result = [];
    for (const row of rows) {
      const key = keyFn(row);
      if (!key || seen.has(key)) continue;
      seen.add(key);
      result.push(row);
    }
    return result;
  };

  let routeSource = "none";
  let routeError = "";
  try {
    const app = document.querySelector("#app");
    const vue = app && app.__vue__;
    const router = vue && (vue.$router || (vue._routerRoot && vue._routerRoot._router));
    if (router?.options?.routes) {
      routeSource = "vue_router_options";
      for (const route of Array.from(router.options.routes || [])) {
        collectRoute(route, routeSource, "");
      }
    } else if (router?.matcher?.getRoutes) {
      routeSource = "vue_router_matcher";
      for (const route of Array.from(router.matcher.getRoutes() || [])) {
        collectRoute(route, routeSource, "");
      }
    }
  } catch (error) {
    routeError = String(error && (error.message || error));
  }

  const visibleLinks = dedupe(Array.from(document.querySelectorAll("a[href]"))
    .filter(isVisible)
    .map((el) => {
      const href = redactUrl(el.href || el.getAttribute("href") || "");
      let url = null;
      try { url = new URL(href, location.href); } catch {}
      return {
        text: clean(el.innerText || el.textContent || el.getAttribute("title") || ""),
        href,
        path: url && url.hostname === "erp.xinjianerp.com" ? url.pathname : "",
        title: clean(el.getAttribute("title") || ""),
        active: /is-active|router-link-active/.test(String(el.className || ""))
      };
    })
    .filter((item) => item.href && item.href.includes("erp.xinjianerp.com")), (item) => item.href + "|" + item.text);

  const visibleMenus = dedupe(Array.from(document.querySelectorAll(".el-menu-item,.el-submenu__title,[role='menuitem']"))
    .filter(isVisible)
    .map((el) => {
      const link = el.closest("a[href]") || el.querySelector("a[href]");
      const href = link ? redactUrl(link.href || link.getAttribute("href") || "") : "";
      let url = null;
      try { url = new URL(href, location.href); } catch {}
      return {
        text: clean(el.innerText || el.textContent || el.getAttribute("title") || ""),
        href,
        path: url && url.hostname === "erp.xinjianerp.com" ? url.pathname : "",
        active: /is-active/.test(String(el.className || "")),
        opened: /is-opened/.test(String(el.className || ""))
      };
    })
    .filter((item) => item.text), (item) => item.text + "|" + item.href);

  const routes = dedupe(routeRows, (item) => [item.full_path, item.name, item.meta_title].join("|"));
  const navigableRoutes = routes.filter((item) => item.navigable_without_params);
  return {
    captured_at: new Date().toISOString(),
    source: "chrome_cdp_vue_router",
    page: {
      href: redactUrl(location.href),
      title: document.title,
      path: location.pathname,
      has_app_root: !!document.querySelector("#app"),
      has_password_input: !!document.querySelector("input[type='password']")
    },
    route_source: routeSource,
    route_error: routeError,
    counts: {
      routes: routes.length,
      navigable_routes: navigableRoutes.length,
      dynamic_routes: routes.filter((item) => item.dynamic).length,
      visible_links: visibleLinks.length,
      visible_menus: visibleMenus.length
    },
    routes,
    visible_links: visibleLinks,
    visible_menus: visibleMenus,
    note: "CDP route discovery reads Vue Router metadata and visible link/menu labels only. It does not read cookies, localStorage, sessionStorage, tokens, input values, or table row data."
  };
})()`;

const ws = new WebSocket(page.webSocketDebuggerUrl);
let cdpId = 1;
const value = await new Promise((resolve, reject) => {
  const timer = setTimeout(() => {
    try { ws.close(); } catch {}
    reject(new Error("CDP route discovery timed out."));
  }, 30000);
  let evaluateId = null;
  const send = (method, params = {}) => {
    const id = cdpId++;
    ws.send(JSON.stringify({ id, method, params }));
    return id;
  };
  ws.onopen = () => {
    evaluateId = send("Runtime.evaluate", { expression, returnByValue: true });
  };
  ws.onmessage = (event) => {
    const message = JSON.parse(event.data);
    if (message.id !== evaluateId) return;
    clearTimeout(timer);
    try { ws.close(); } catch {}
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
    try { ws.close(); } catch {}
    reject(new Error("CDP websocket error."));
  };
});

if (!value || typeof value !== "object") {
  throw new Error("CDP route discovery did not return a structured result.");
}

const routeLimit = Number.isFinite(maxRoutes) && maxRoutes > 0 ? maxRoutes : 300;
const payload = {
  ok: true,
  port,
  matched_page: {
    url: page.url,
    title: page.title,
    score: pageScore(page)
  },
  output_path: path.resolve(out),
  ...value,
  routes: Array.isArray(value.routes) ? value.routes.slice(0, routeLimit) : [],
  routes_truncated: Array.isArray(value.routes) && value.routes.length > routeLimit
};

await fs.mkdir(path.dirname(out), { recursive: true });
await fs.writeFile(out, JSON.stringify(payload, null, 2), "utf8");
process.stdout.write(JSON.stringify(payload, null, 2));
