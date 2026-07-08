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
const maxTables = Number(argValue("--max-tables", "12"));
const maxRowsPerTable = Number(argValue("--max-rows-per-table", "20"));

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

const expression = `(() => {
  const maxTables = ${JSON.stringify(Number.isFinite(maxTables) && maxTables > 0 ? maxTables : 12)};
  const maxRowsPerTable = ${JSON.stringify(Number.isFinite(maxRowsPerTable) && maxRowsPerTable > 0 ? maxRowsPerTable : 20)};
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
  const isPublicUiText = (value, maxLen = 60) => {
    const text = clean(value);
    return !!text && text.length <= maxLen && !isPrivateLike(text);
  };
  const isActionText = (value) => {
    const text = clean(value).replace(/\\s+/g, "");
    if (!text || text.length > 24 || isPrivateLike(text)) return false;
    if (/^(搜索|查询|重置|取消|确定|关闭|上一页|下一页|跳至|更多)$/.test(text)) return false;
    return /详情|查看|编辑|修改|删除|恢复|设置|配置|预警|打开|进入|下载|导出|复制|更新|转移|分配|认领|加入|移除|拉黑|黑名单|关注|取消关注|审核|审批|作废|同步|启用|禁用|重新|执行|日志|授权|续费|开通/.test(text);
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
  const controlName = (el) => clean(el.getAttribute("aria-label") || el.getAttribute("title") || el.innerText || el.textContent || "");
  const columnClass = (el) => {
    const cls = String(el.className || "");
    const match = cls.match(/el-table_\\d+_column_\\d+/);
    return match ? match[0] : "";
  };
  const tableTitle = (table) => {
    const previous = table.previousElementSibling;
    const text = previous && isVisible(previous) ? clean(previous.innerText || previous.textContent || "") : "";
    return isPublicUiText(text, 40) ? text : "";
  };
  const tableHeaders = (table) => {
    const headers = [];
    for (const th of Array.from(table.querySelectorAll("thead th")).filter(isVisible)) {
      const name = clean(th.innerText || th.textContent || "");
      const cls = columnClass(th);
      if (!isPublicUiText(name, 40) && !cls) continue;
      headers.push({ name: isPublicUiText(name, 40) ? name : "", column_class: cls });
    }
    return headers;
  };
  const headerForCell = (td, headers, cellIndex) => {
    const cls = columnClass(td);
    if (cls) {
      const byClass = headers.find((item) => item.column_class === cls);
      if (byClass?.name) return byClass.name;
    }
    const byIndex = headers[cellIndex];
    return byIndex?.name || "";
  };
  const tables = Array.from(document.querySelectorAll(".el-table, table"))
    .filter((item) => item.matches(".el-table") || !item.closest(".el-table"))
    .filter(isVisible)
    .slice(0, maxTables);
  const results = [];
  for (let tableIndex = 0; tableIndex < tables.length; tableIndex += 1) {
    const table = tables[tableIndex];
    const headers = tableHeaders(table);
    const rows = Array.from(table.querySelectorAll("tbody tr")).filter(isVisible).slice(0, maxRowsPerTable);
    const actions = [];
    for (let rowIndex = 0; rowIndex < rows.length; rowIndex += 1) {
      const row = rows[rowIndex];
      const cells = Array.from(row.querySelectorAll("td")).filter(isVisible);
      for (let cellIndex = 0; cellIndex < cells.length; cellIndex += 1) {
        const cell = cells[cellIndex];
        const columnHeader = headerForCell(cell, headers, cellIndex);
        const controls = Array.from(cell.querySelectorAll("button, a[href], [role='button'], .el-button")).filter(isVisible);
        for (const control of controls) {
          const name = controlName(control);
          if (!isActionText(name)) continue;
          actions.push({
            name,
            column_header: isPublicUiText(columnHeader, 40) ? columnHeader : "",
            column_class: columnClass(cell),
            row_index: rowIndex,
            selector: cssPath(control),
            disabled: !!control.disabled || control.getAttribute("aria-disabled") === "true"
          });
        }
      }
    }
    const seen = new Map();
    for (const action of actions) {
      const key = [action.name, action.column_header, action.column_class].join("|");
      const existing = seen.get(key);
      if (existing) {
        if (existing.disabled && !action.disabled) {
          existing.selector = action.selector;
          existing.row_index = action.row_index;
        }
        existing.disabled = existing.disabled && action.disabled;
      } else {
        seen.set(key, action);
      }
    }
    const dedupedActions = Array.from(seen.values());
    if (headers.length || dedupedActions.length) {
      results.push({
        index: tableIndex,
        title: tableTitle(table),
        selector: cssPath(table),
        headers: headers.map((item) => item.name).filter(Boolean),
        row_count_sampled: rows.length,
        action_count: dedupedActions.length,
        actions: dedupedActions
      });
    }
  }
  return {
    captured_at: new Date().toISOString(),
    source: "chrome_cdp_row_action_probe",
    page: {
      href: redactUrl(location.href),
      title: document.title,
      path: location.pathname,
      has_app_root: !!document.querySelector("#app"),
      has_password_input: !!document.querySelector("input[type='password']")
    },
    counts: {
      tables: results.length,
      row_actions: results.reduce((sum, table) => sum + (table.action_count || 0), 0),
      sampled_rows: results.reduce((sum, table) => sum + (table.row_count_sampled || 0), 0)
    },
    tables: results,
    note: "CDP row-action probe reads table headers and row action button labels only. It does not click row actions, read row cell values, type, submit forms, read cookies, read storage, or read tokens."
  };
})()`;

const ws = new WebSocket(page.webSocketDebuggerUrl);
let cdpId = 1;
const value = await new Promise((resolve, reject) => {
  const timer = setTimeout(() => {
    try { ws.close(); } catch {}
    reject(new Error("CDP row-action capture timed out."));
  }, 45000);
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

if (!value || typeof value !== "object" || !value.page || !value.counts) {
  throw new Error("CDP row-action capture did not return a structured result.");
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
