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
const maxTriggers = Number(argValue("--max-triggers", "20"));

if (!Number.isFinite(port) || port <= 0) throw new Error("Invalid --port.");
if (!out) throw new Error("Missing --out.");

function parseUrl(value) {
  try { return new URL(String(value || "")); } catch { return null; }
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

const expression = `(async () => {
  const maxTriggers = ${JSON.stringify(Number.isFinite(maxTriggers) && maxTriggers > 0 ? maxTriggers : 20)};
  const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
  const clean = (value) => String(value || "")
    .replace(/[\\uE000-\\uF8FF]/g, " ")
    .replace(/\\s+/g, " ")
    .trim();
  const redactUrl = (value) => String(value || "").replace(
    /([?&][^=]*(token|secret|password|passwd|pwd|cookie|session|auth|key|code)[^=]*=)[^&#]*/ig,
    "$1[redacted]"
  );
  const isVisible = (el) => {
    if (!el || el.nodeType !== 1) return false;
    const style = window.getComputedStyle(el);
    const rect = el.getBoundingClientRect();
    return style && style.display !== "none" && style.visibility !== "hidden" && rect.width > 0 && rect.height > 0;
  };
  const isPrivateLike = (value) => {
    const text = clean(value);
    if (!text) return false;
    return (
      /@/.test(text) ||
      /\\b\\d{7,}\\b/.test(text) ||
      /[A-Za-z][A-Za-z0-9 ._-]{1,50}-(?:my|th|id|sg|ph|vn)-(?:sp|tt|la)\\b/i.test(text) ||
      /(?:token|secret|password|passwd|cookie|session|auth)\\s*[:=]/i.test(text)
    );
  };
  const isGenericUiText = (value) => {
    const text = clean(value);
    if (!text || text.length > 60 || isPrivateLike(text)) return false;
    return true;
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
  const controlName = (el) => {
    if (el.closest(".avatar-container") || /\\bavatar-wrapper\\b/.test(String(el.className || ""))) return "用户菜单";
    return clean(el.getAttribute("aria-label") || el.getAttribute("title") || el.innerText || el.textContent || "");
  };
  const isSafeDialogOpener = (name) => {
    const text = clean(name);
    if (!text || text === "用户菜单" || text.length > 24) return false;
    if (/搜索|查询|重置|刷新|取消|关闭|返回|上一页|下一页|跳至|导出|下载|保存|提交|确定|确认|删除|恢复|分配|认领|转移|授权|同步|清除|移除|审核|审批|发货|作废|标记|批量|启用|禁用|启动|停止|推送|发送|更新|支付|充值|购买/.test(text)) return false;
    return /新增|添加|创建|详情|查看|编辑|修改|设置|配置|打开|自定义/.test(text);
  };
  const dialogContainers = () => Array.from(document.querySelectorAll([
    ".el-dialog",
    ".el-drawer",
    ".el-message-box"
  ].join(","))).filter(isVisible);
  const uniqueTexts = (values) => {
    const seen = new Set();
    const result = [];
    for (const value of values) {
      const text = clean(value);
      const key = text.toLowerCase();
      if (!text || seen.has(key) || !isGenericUiText(text)) continue;
      seen.add(key);
      result.push(text);
    }
    return result;
  };
  const snapshotDialog = (dialog) => {
    const title = clean(
      dialog.querySelector(".el-dialog__title, .el-drawer__title, .el-message-box__title, [class*='title']")?.innerText || ""
    );
    const buttons = uniqueTexts(Array.from(dialog.querySelectorAll("button, .el-button, [role='button']"))
      .filter(isVisible)
      .map((node) => controlName(node)));
    const fieldLabels = uniqueTexts(Array.from(dialog.querySelectorAll(".el-form-item__label, label"))
      .filter(isVisible)
      .map((node) => node.innerText || node.textContent || ""));
    const placeholders = uniqueTexts(Array.from(dialog.querySelectorAll("input[placeholder], textarea[placeholder]"))
      .filter(isVisible)
      .map((node) => node.getAttribute("placeholder") || ""));
    return {
      type: dialog.classList.contains("el-drawer") ? "drawer" : (dialog.classList.contains("el-message-box") ? "message_box" : "dialog"),
      title: isGenericUiText(title) ? title : "",
      selector: cssPath(dialog),
      buttons,
      field_labels: fieldLabels,
      placeholders
    };
  };
  const closeDialogs = async () => {
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }));
    document.body.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }));
    await sleep(100);
    for (const closeButton of Array.from(document.querySelectorAll(".el-dialog__close, .el-drawer__close, .el-message-box__close")).filter(isVisible)) {
      try { closeButton.click(); await sleep(80); } catch {}
    }
    for (const button of Array.from(document.querySelectorAll(".el-dialog button, .el-drawer button, .el-message-box button")).filter(isVisible)) {
      const name = controlName(button);
      if (/^(取消|关闭)$/.test(name)) {
        try { button.click(); await sleep(80); } catch {}
      }
    }
  };

  await closeDialogs();
  const initialPage = {
    href: redactUrl(location.href),
    title: document.title,
    path: location.pathname,
    has_app_root: !!document.querySelector("#app"),
    has_password_input: !!document.querySelector("input[type='password']")
  };
  const seen = new Set();
  const triggers = Array.from(document.querySelectorAll("button, .el-button, [role='button']"))
    .filter(isVisible)
    .filter((el) => !el.closest(".el-dialog,.el-drawer,.el-message-box,.avatar-container"))
    .map((el) => {
      const name = controlName(el);
      const rect = el.getBoundingClientRect();
      return { el, name, selector: cssPath(el), rect };
    })
    .filter((item) => isSafeDialogOpener(item.name))
    .filter((item) => {
      const key = item.name + "|" + item.selector;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    })
    .slice(0, maxTriggers);

  const results = [];
  for (let index = 0; index < triggers.length; index += 1) {
    const item = triggers[index];
    await closeDialogs();
    const beforeHref = location.href;
    const beforePath = location.pathname;
    try {
      item.el.scrollIntoView({ block: "center", inline: "center" });
      await sleep(80);
      item.el.click();
      await sleep(650);
      const afterHref = location.href;
      const afterPath = location.pathname;
      const dialogs = dialogContainers().map(snapshotDialog);
      const result = {
        index,
        trigger_text: item.name,
        trigger_selector: item.selector,
        bounds: {
          x: Math.round(item.rect.x),
          y: Math.round(item.rect.y),
          width: Math.round(item.rect.width),
          height: Math.round(item.rect.height)
        },
        before_path: beforePath,
        after_path: afterPath,
        navigated: afterHref !== beforeHref,
        dialog_count: dialogs.length,
        dialogs
      };
      results.push(result);
      if (afterHref !== beforeHref) {
        try { history.back(); await sleep(700); } catch {}
      } else {
        await closeDialogs();
      }
    } catch (error) {
      results.push({
        index,
        trigger_text: item.name,
        trigger_selector: item.selector,
        error: String(error && (error.message || error))
      });
      await closeDialogs();
    }
  }
  await closeDialogs();
  const finalPage = {
    href: redactUrl(location.href),
    title: document.title,
    path: location.pathname,
    has_app_root: !!document.querySelector("#app"),
    has_password_input: !!document.querySelector("input[type='password']")
  };

  return {
    captured_at: new Date().toISOString(),
    source: "chrome_cdp_dialog_probe",
    page: initialPage,
    final_page: finalPage,
    counts: {
      triggers: results.length,
      triggers_with_dialogs: results.filter((item) => item.dialog_count > 0).length,
      dialogs: results.reduce((sum, item) => sum + (item.dialog_count || 0), 0),
      dialog_buttons: results.reduce((sum, item) => sum + (item.dialogs || []).reduce((n, dialog) => n + (dialog.buttons || []).length, 0), 0),
      field_labels: results.reduce((sum, item) => sum + (item.dialogs || []).reduce((n, dialog) => n + (dialog.field_labels || []).length, 0), 0)
    },
    dialog_triggers: results,
    note: "CDP dialog probe clicks only safe dialog-opening controls and records sanitized dialog/drawer button labels, field labels, and placeholders. It does not click submit/confirm/write buttons, type, submit forms, read cookies, read storage, read tokens, or read input values."
  };
})()`;

const ws = new WebSocket(page.webSocketDebuggerUrl);
let cdpId = 1;
const value = await new Promise((resolve, reject) => {
  const timer = setTimeout(() => {
    try { ws.close(); } catch {}
    reject(new Error("CDP dialog capture timed out."));
  }, 60000);
  let evaluateId = null;
  const send = (method, params = {}) => {
    const id = cdpId++;
    ws.send(JSON.stringify({ id, method, params }));
    return id;
  };
  ws.onopen = () => {
    evaluateId = send("Runtime.evaluate", { expression, awaitPromise: true, returnByValue: true });
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

if (!value || typeof value !== "object" || !value.page || !value.counts) {
  throw new Error("CDP dialog capture did not return a structured result.");
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
  ...value
};

await fs.mkdir(path.dirname(out), { recursive: true });
await fs.writeFile(out, JSON.stringify(payload, null, 2), "utf8");
if (openedByHelper?.id) await closePage(openedByHelper.id);
process.stdout.write(JSON.stringify(payload, null, 2));
