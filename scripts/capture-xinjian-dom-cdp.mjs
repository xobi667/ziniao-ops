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

function isTargetPage(item) {
  const currentUrl = parseUrl(item?.url || "");
  const targetUrl = parseUrl(matchUrl);
  if (!targetUrl) return true;
  if (!currentUrl) return false;
  return currentUrl.origin === targetUrl.origin && comparablePath(currentUrl.pathname) === comparablePath(targetUrl.pathname);
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

async function listPages() {
  return await (await fetch(`http://127.0.0.1:${port}/json`, { signal: AbortSignal.timeout(8000) })).json();
}

async function openTargetPage(url) {
  if (!url) return null;
  const encoded = encodeURIComponent(url);
  for (const endpoint of [
    `http://127.0.0.1:${port}/json/new?${encoded}`,
    `http://127.0.0.1:${port}/json/new?url=${encoded}`
  ]) {
    for (const method of ["PUT", "GET"]) {
      try {
        const response = await fetch(endpoint, { method, signal: AbortSignal.timeout(5000) });
        if (response.ok) return await response.json();
      } catch {
      }
    }
  }
  return null;
}

async function closePage(id) {
  if (!id) return;
  try {
    await fetch(`http://127.0.0.1:${port}/json/close/${encodeURIComponent(id)}`, { signal: AbortSignal.timeout(3000) });
  } catch {
  }
}

async function sleep(ms) {
  await new Promise((resolve) => setTimeout(resolve, ms));
}

let openedByHelper = null;
let pages = await listPages();
let page = pages
  .filter((item) => item.webSocketDebuggerUrl && item.type === "page")
  .sort((a, b) => pageScore(b) - pageScore(a))[0];

if (matchUrl && !isTargetPage(page)) {
  openedByHelper = await openTargetPage(matchUrl);
  if (openedByHelper?.id) {
    await sleep(8000);
    pages = await listPages();
    page = pages
      .filter((item) => item.webSocketDebuggerUrl && item.type === "page")
      .filter(isTargetPage)
      .sort((a, b) => pageScore(b) - pageScore(a))[0] || openedByHelper;
  }
}

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
  const cssPath = (el) => {
    const parts = [];
    let cur = el;
    while (cur && cur.nodeType === 1 && parts.length < 6) {
      let part = cur.tagName.toLowerCase();
      if (cur.id) {
        part += "#" + CSS.escape(cur.id);
        parts.unshift(part);
        break;
      }
      const classes = Array.from(cur.classList || [])
        .filter((name) => !/^is-|^el-icon|^v-/.test(name))
        .slice(0, 3);
      if (classes.length) part += "." + classes.map((name) => CSS.escape(name)).join(".");
      const parent = cur.parentElement;
      if (parent) {
        const same = Array.from(parent.children).filter((item) => item.tagName === cur.tagName);
        if (same.length > 1) part += ":nth-of-type(" + (same.indexOf(cur) + 1) + ")";
      }
      parts.unshift(part);
      cur = parent;
    }
    return parts.join(" > ");
  };
  const controlType = (el) => {
    const tag = el.tagName.toLowerCase();
    const role = el.getAttribute("role") || "";
    const cls = el.className || "";
    if (tag === "button" || role === "button" || /\\bel-button\\b/.test(cls)) return "button";
    if (tag === "input" || tag === "textarea") return "input";
    if (tag === "select" || role === "combobox" || /\\bel-select\\b/.test(cls)) return "select";
    if (role === "tab" || /\\bel-tabs__item\\b/.test(cls)) return "tab";
    if (role === "menuitem" || /\\bel-menu-item\\b|\\bel-submenu__title\\b/.test(cls)) return "menu";
    if (tag === "a") return "link";
    if (role === "checkbox") return "checkbox";
    return role || tag;
  };
  const textOf = (el) => {
    if (el.closest(".avatar-container") || /\\bavatar-wrapper\\b/.test(String(el.className || ""))) {
      return "用户菜单";
    }
    const tag = el.tagName.toLowerCase();
    const type = controlType(el);
    const aria = el.getAttribute("aria-label") || "";
    const title = el.getAttribute("title") || "";
    const placeholder = el.getAttribute("placeholder") || "";
    if (tag === "input" || tag === "textarea") {
      return clean(aria || title || placeholder);
    }
    if (type === "select") {
      const nestedInput = el.querySelector("input[placeholder]");
      const directText = Array.from(el.childNodes || [])
        .filter((node) => node.nodeType === Node.TEXT_NODE)
        .map((node) => node.textContent)
        .join(" ");
      return clean(
        aria ||
        title ||
        placeholder ||
        nestedInput?.getAttribute("placeholder") ||
        directText
      );
    }
    return clean(aria || title || placeholder || el.innerText || el.textContent || "");
  };
  const selectors = [
    "button",
    "a[href]",
    "input",
    "textarea",
    "select",
    "[role='button']",
    "[role='tab']",
    "[role='menuitem']",
    "[role='combobox']",
    "[role='checkbox']",
    ".el-button",
    ".el-input__inner",
    ".el-select",
    ".el-tabs__item",
    ".el-menu-item",
    ".el-submenu__title",
    ".el-dropdown",
    "th",
    "[role='columnheader']"
  ];
  const seen = new Set();
  const controls = [];
  for (const el of Array.from(document.querySelectorAll(selectors.join(",")))) {
    if (!isVisible(el)) continue;
    const type = controlType(el);
    const name = textOf(el);
    const placeholder = clean(el.getAttribute("placeholder") || "");
    const ariaLabel = clean(el.getAttribute("aria-label") || "");
    const title = clean(el.getAttribute("title") || "");
    const href = el.tagName.toLowerCase() === "a" ? redactUrl(el.href || el.getAttribute("href") || "") : "";
    const key = [type, name, placeholder, ariaLabel, title, href, cssPath(el)].join("|");
    if (seen.has(key)) continue;
    seen.add(key);
    const rect = el.getBoundingClientRect();
    controls.push({
      index: controls.length,
      type,
      tag: el.tagName.toLowerCase(),
      name,
      placeholder,
      aria_label: ariaLabel,
      title,
      role: el.getAttribute("role") || "",
      disabled: !!el.disabled || el.getAttribute("aria-disabled") === "true",
      href,
      classes: String(el.className || "").split(/\\s+/).filter(Boolean).slice(0, 8),
      selector: cssPath(el),
      bounds: {
        x: Math.round(rect.x),
        y: Math.round(rect.y),
        width: Math.round(rect.width),
        height: Math.round(rect.height)
      }
    });
  }
  return {
    captured_at: new Date().toISOString(),
    source: "chrome_cdp_dom",
    page: {
      href: redactUrl(location.href),
      title: document.title,
      path: location.pathname,
      has_app_root: !!document.querySelector("#app"),
      has_password_input: !!document.querySelector("input[type='password']")
    },
    counts: {
      controls: controls.length,
      buttons: controls.filter((item) => item.type === "button").length,
      inputs: controls.filter((item) => item.type === "input").length,
      tabs: controls.filter((item) => item.type === "tab").length,
      menus: controls.filter((item) => item.type === "menu").length,
      links: controls.filter((item) => item.type === "link").length
    },
    controls,
    note: "CDP DOM capture only reads element metadata. It does not read cookies, localStorage, sessionStorage, tokens, or input values."
  };
})()`;

const ws = new WebSocket(page.webSocketDebuggerUrl);
let cdpId = 1;
const value = await new Promise((resolve, reject) => {
  const timer = setTimeout(() => {
    try { ws.close(); } catch {}
    reject(new Error("CDP DOM capture timed out."));
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
  throw new Error("CDP DOM capture did not return a structured result.");
}

const payload = {
  ok: true,
  port,
  matched_page: {
    url: page.url,
    title: page.title,
    score: pageScore(page),
    opened_by_helper: !!openedByHelper
  },
  output_path: path.resolve(out),
  ...value,
  controls_count: value.controls?.length || 0
};

await fs.mkdir(path.dirname(out), { recursive: true });
await fs.writeFile(out, JSON.stringify(payload, null, 2), "utf8");
if (openedByHelper?.id) await closePage(openedByHelper.id);
process.stdout.write(JSON.stringify(payload, null, 2));
