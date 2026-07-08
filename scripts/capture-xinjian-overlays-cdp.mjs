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
const maxTriggers = Number(argValue("--max-triggers", "40"));
const includeSelects = process.argv.includes("--include-selects");
const includeDatePickers = process.argv.includes("--include-date-pickers");

if (!Number.isFinite(port) || port <= 0) throw new Error("Invalid --port.");
if (!out) throw new Error("Missing --out.");

function parseUrl(value) {
  try { return new URL(String(value || "")); } catch { return null; }
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

const pages = await (await fetch(`http://127.0.0.1:${port}/json`, { signal: AbortSignal.timeout(8000) })).json();
const page = pages
  .filter((item) => item.webSocketDebuggerUrl && item.type === "page")
  .sort((a, b) => pageScore(b) - pageScore(a))[0];

if (!page?.webSocketDebuggerUrl) {
  throw new Error(`No debuggable page was found on port ${port}.`);
}

const expression = `(async () => {
  const maxTriggers = ${JSON.stringify(Number.isFinite(maxTriggers) && maxTriggers > 0 ? maxTriggers : 40)};
  const includeSelects = ${JSON.stringify(includeSelects)};
  const includeDatePickers = ${JSON.stringify(includeDatePickers)};
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
  const isGenericOption = (value) => {
    const text = clean(value);
    if (!text || text.length > 40 || isPrivateLike(text)) return false;
    return /^(全部|请选择|启用|禁用|是|否|成功|失败|已处理|未处理|今天|昨天|近7天|近30天|Shopee|Lazada|Tiktok|TikTok|视频|直播|商品|店铺|订单|利润|费用|导出|下载|删除|编辑|修改|新增|添加|恢复|转移|分配|认领|标记已处理|标记未处理|批量删除|批量导入|信息更新|应用|重置|搜索|详情|查看|达人ID|达人昵称|达人名称|视频ID号|视频名称|Tiktok账号|TikTok账号|店铺名称|店铺名|负责人|人员|商务)$/i.test(text) ||
      /^(按|选择|切换|批量|标记|导出|下载|删除|编辑|修改|新增|添加|恢复|转移|分配|认领)/.test(text);
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
  const triggerType = (el) => {
    const cls = String(el.className || "");
    const role = el.getAttribute("role") || "";
    if (/\\bel-cascader\\b/.test(cls)) return "cascader";
    if (/\\bel-select\\b/.test(cls) || role === "combobox") return "select";
    if (/\\bel-date-editor\\b/.test(cls)) return "date_picker";
    if (/\\bel-dropdown\\b/.test(cls) || /\\bel-dropdown-selfdefine\\b/.test(cls)) return "dropdown";
    return "overlay_trigger";
  };
  const triggerName = (el) => {
    if (el.closest(".avatar-container") || /\\bavatar-wrapper\\b/.test(String(el.className || ""))) return "用户菜单";
    const input = el.querySelector("input[placeholder]") || (el.matches("input[placeholder]") ? el : null);
    const placeholder = input?.getAttribute("placeholder") || el.getAttribute("placeholder") || "";
    const aria = el.getAttribute("aria-label") || "";
    const title = el.getAttribute("title") || "";
    const directText = Array.from(el.childNodes || [])
      .filter((node) => node.nodeType === Node.TEXT_NODE)
      .map((node) => node.textContent)
      .join(" ");
    return clean(aria || title || placeholder || directText || el.innerText || el.textContent || "");
  };
  const closeOverlays = async () => {
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }));
    document.body.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }));
    await sleep(80);
    document.body.click();
    await sleep(120);
  };
  const overlayContainers = () => Array.from(document.querySelectorAll([
    ".el-select-dropdown",
    ".el-cascader__dropdown",
    ".el-dropdown-menu",
    ".el-picker-panel",
    ".el-popover",
    ".el-tooltip__popper"
  ].join(","))).filter(isVisible);
  const overlayItems = (containers, kind) => {
    const rows = [];
    for (const overlay of containers) {
      const nodes = Array.from(overlay.querySelectorAll([
        ".el-select-dropdown__item",
        ".el-cascader-node",
        ".el-dropdown-menu__item",
        ".el-picker-panel__shortcut",
        "[role='option']",
        "[role='menuitem']",
        "button"
      ].join(","))).filter(isVisible);
      for (const node of nodes) {
        const name = clean(node.innerText || node.textContent || node.getAttribute("title") || node.getAttribute("aria-label") || "");
        if (!name) continue;
        const generic = isGenericOption(name);
        const privateLike = isPrivateLike(name);
        if (!generic) {
          rows.push({ filtered: true, reason: privateLike ? "private_like" : "non_generic_overlay_option" });
          continue;
        }
        if (privateLike) {
          rows.push({ filtered: true, reason: "private_like" });
          continue;
        }
        rows.push({
          name,
          type: node.getAttribute("role") || node.tagName.toLowerCase(),
          disabled: !!node.disabled || /is-disabled/.test(String(node.className || "")),
          classes: String(node.className || "").split(/\\s+/).filter(Boolean).slice(0, 8)
        });
      }
    }
    const seen = new Set();
    return rows.filter((item) => {
      if (item.filtered) return true;
      const key = item.name + "|" + item.type;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
  };

  await closeOverlays();
  const triggerSelectors = [".el-dropdown"];
  if (includeSelects) triggerSelectors.push(".el-select", ".el-cascader", "[role='combobox']");
  if (includeDatePickers) triggerSelectors.push(".el-date-editor");
  const triggerSelector = triggerSelectors.join(",");
  const seenTriggers = new Set();
  const triggers = Array.from(document.querySelectorAll(triggerSelector))
    .filter(isVisible)
    .filter((el) => !el.closest(".avatar-container"))
    .map((el) => {
      const name = triggerName(el);
      const kind = triggerType(el);
      const rect = el.getBoundingClientRect();
      return { el, name, kind, selector: cssPath(el), rect };
    })
    .filter((item) => item.name !== "用户菜单")
    .filter((item) => {
      const key = item.kind + "|" + item.name + "|" + item.selector;
      if (seenTriggers.has(key)) return false;
      seenTriggers.add(key);
      return true;
    })
    .slice(0, maxTriggers);

  const results = [];
  for (let index = 0; index < triggers.length; index += 1) {
    const item = triggers[index];
    await closeOverlays();
    try {
      item.el.scrollIntoView({ block: "center", inline: "center" });
      await sleep(80);
      const beforeOverlays = new Set(overlayContainers());
      const clickTarget = item.el.querySelector(".el-dropdown-selfdefine, .el-input, input, button") || item.el;
      if (item.kind === "dropdown") {
        clickTarget.dispatchEvent(new MouseEvent("mouseenter", { bubbles: true, cancelable: true, view: window }));
        clickTarget.dispatchEvent(new MouseEvent("mouseover", { bubbles: true, cancelable: true, view: window }));
        item.el.dispatchEvent(new MouseEvent("mouseenter", { bubbles: true, cancelable: true, view: window }));
        await sleep(250);
      }
      clickTarget.click();
      await sleep(350);
      let overlays = overlayContainers().filter((overlay) => !beforeOverlays.has(overlay));
      if (overlays.length === 0) overlays = overlayContainers();
      const rawItems = overlayItems(overlays, item.kind);
      const filteredCount = rawItems.filter((row) => row.filtered).length;
      const visibleItems = rawItems.filter((row) => !row.filtered);
      results.push({
        index,
        trigger_type: item.kind,
        name: item.name || item.kind,
        selector: item.selector,
        bounds: {
          x: Math.round(item.rect.x),
          y: Math.round(item.rect.y),
          width: Math.round(item.rect.width),
          height: Math.round(item.rect.height)
        },
        overlay_count: overlays.length,
        item_count: visibleItems.length,
        filtered_item_count: filteredCount,
        items: visibleItems
      });
    } catch (error) {
      results.push({
        index,
        trigger_type: item.kind,
        name: item.name || item.kind,
        selector: item.selector,
        error: String(error && (error.message || error))
      });
    }
  }
  await closeOverlays();

  return {
    captured_at: new Date().toISOString(),
    source: "chrome_cdp_overlay_probe",
    page: {
      href: redactUrl(location.href),
      title: document.title,
      path: location.pathname,
      has_app_root: !!document.querySelector("#app"),
      has_password_input: !!document.querySelector("input[type='password']")
    },
    counts: {
      triggers: results.length,
      overlays_with_items: results.filter((item) => item.item_count > 0).length,
      items: results.reduce((sum, item) => sum + (item.item_count || 0), 0),
      filtered_items: results.reduce((sum, item) => sum + (item.filtered_item_count || 0), 0)
    },
    overlay_triggers: results,
    note: "CDP overlay probe opens dropdown/select/date/cascader panels and records sanitized generic item labels only. It does not click overlay items, submit forms, read cookies, read storage, read tokens, or read input values."
  };
})()`;

const ws = new WebSocket(page.webSocketDebuggerUrl);
let cdpId = 1;
const value = await new Promise((resolve, reject) => {
  const timer = setTimeout(() => {
    try { ws.close(); } catch {}
    reject(new Error("CDP overlay capture timed out."));
  }, 45000);
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
  throw new Error("CDP overlay capture did not return a structured result.");
}

const payload = {
  ok: true,
  port,
  matched_page: {
    url: page.url,
    title: page.title,
    score: pageScore(page)
  },
  output_path: path.resolve(out),
  ...value
};

await fs.mkdir(path.dirname(out), { recursive: true });
await fs.writeFile(out, JSON.stringify(payload, null, 2), "utf8");
process.stdout.write(JSON.stringify(payload, null, 2));
