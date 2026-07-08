#!/usr/bin/env node
import fs from "node:fs/promises";
import path from "node:path";

function valuesOf(name) {
  const values = [];
  for (let index = 0; index < process.argv.length; index += 1) {
    if (process.argv[index] === name && index + 1 < process.argv.length) values.push(process.argv[index + 1]);
  }
  return values;
}

function argValue(name, fallback = "") {
  const values = valuesOf(name);
  return values.length ? values[values.length - 1] : fallback;
}

function hasFlag(name) {
  return process.argv.includes(name);
}

const captureDirs = valuesOf("--capture-dir");
const captureFiles = valuesOf("--capture");
const out = argValue("--out", "");
const dryRun = hasFlag("--dry-run");

if (!out) throw new Error("Missing --out.");

async function listCaptureFiles() {
  const files = [...captureFiles];
  for (const dir of captureDirs) {
    let entries = [];
    try {
      entries = await fs.readdir(dir, { withFileTypes: true });
    } catch {
      continue;
    }
    for (const entry of entries) {
      if (entry.isFile() && entry.name.toLowerCase().endsWith(".json")) {
        files.push(path.join(dir, entry.name));
      }
    }
  }
  return [...new Set(files)].sort();
}

function clean(value) {
  return String(value || "").replace(/[\uE000-\uF8FF]/g, " ").replace(/\s+/g, " ").trim();
}

function unique(values) {
  const seen = new Set();
  const result = [];
  for (const value of values) {
    const text = clean(value);
    const key = text.toLowerCase();
    if (!text || seen.has(key)) continue;
    seen.add(key);
    result.push(text);
  }
  return result;
}

function isPrivateLike(value) {
  const text = clean(value);
  if (!text) return false;
  return (
    /@/.test(text) ||
    /\b\d{7,}\b/.test(text) ||
    /[A-Za-z][A-Za-z0-9 ._-]{1,50}-(?:my|th|id|sg|ph|vn)-(?:sp|tt|la)\b/i.test(text) ||
    /(?:token|secret|password|passwd|cookie|session|auth)\s*[:=]/i.test(text)
  );
}

function isPublicUiText(value, maxLen = 60) {
  const text = clean(value);
  return !!text && text.length <= maxLen && !isPrivateLike(text);
}

function normalizePath(value) {
  let text = clean(value);
  if (!text) return "";
  try {
    const url = new URL(text);
    text = url.pathname;
  } catch {
  }
  if (!text.startsWith("/")) text = `/${text}`;
  text = text.replace(/\/+/g, "/");
  if (text.length > 1) text = text.replace(/\/+$/g, "");
  return text || "/";
}

function slug(value) {
  const text = clean(value)
    .toLowerCase()
    .replace(/^https?:\/\//, "")
    .replace(/[^a-z0-9\u4e00-\u9fa5]+/gi, ".")
    .replace(/^\.+|\.+$/g, "")
    .replace(/\.+/g, ".");
  return text || "item";
}

function escapeRegex(value) {
  return String(value).replace(/[\\^$.*+?()[\]{}|]/g, "\\$&");
}

function pageIdFromPath(routePath) {
  const parts = normalizePath(routePath).replace(/^\/+|\/+$/g, "").split(/[/?#]+/).filter(Boolean);
  return `row.${slug(parts.join(".") || "root")}`;
}

function moduleFromPath(routePath) {
  const text = normalizePath(routePath).toLowerCase();
  if (text.startsWith("/ad") || text.startsWith("/erp/ads")) return "ADS";
  if (text.startsWith("/crm") || text.startsWith("/invitation") || text.startsWith("/batch-message") || text.startsWith("/content")) return "CRM";
  if (text.startsWith("/bi") || text.startsWith("/data") || text.includes("analyse") || text.includes("analyze")) return "BI";
  if (text.startsWith("/download")) return "System";
  if (text.startsWith("/index")) return "System";
  if (text.startsWith("/ai")) return "AI";
  return "ERP";
}

function classifySafety(name) {
  const compact = clean(name).replace(/\s+/g, "");
  if (/导出|下载/.test(compact)) return "confirmation_required_export";
  if (/删除|恢复|修改|编辑|更新|设置|配置|分配|认领|转移|添加|新增|创建|上传|导入|启用|禁用|授权|同步|清除|移除|审核|审批|发货|作废|取消关注|拉黑|黑名单|执行|开通|续费/.test(compact)) {
    return "confirmation_required_write";
  }
  if (/详情|查看|打开|进入|日志|预览|复制/.test(compact)) return "navigation";
  return "unknown_observed";
}

function aliasesForRowAction(actionName, columnHeader) {
  const action = clean(actionName).replace(/\s+/g, "");
  const column = clean(columnHeader).replace(/\s+/g, "");
  return unique([
    actionName,
    action,
    column ? `${column}${action}` : "",
    column ? `${action}${column}` : "",
    `行${action}`,
    `表格${action}`
  ]);
}

function ensureUniqueActionIds(actions) {
  const seen = new Map();
  for (const action of actions) {
    const base = clean(action.id) || "row.action";
    const count = seen.get(base) || 0;
    seen.set(base, count + 1);
    if (count > 0) action.id = `${base}.${count + 1}`;
  }
  return actions;
}

function rowActionIdentity(action) {
  const locator = action.locator || {};
  return [
    action.type || "row_action",
    clean(locator.row_action_text).toLowerCase(),
    clean(locator.column_class).toLowerCase() || clean(locator.table_selector).toLowerCase()
  ].join("|");
}

function preferRowAction(current, candidate) {
  if (!current) return candidate;
  const currentHeader = clean(current.locator?.column_header);
  const candidateHeader = clean(candidate.locator?.column_header);
  if (!currentHeader && candidateHeader) return candidate;
  if (current.safety === "unknown_observed" && candidate.safety !== "unknown_observed") return candidate;
  return current;
}

function dedupeRowActions(actions) {
  const byIdentity = new Map();
  for (const action of actions) {
    const key = rowActionIdentity(action);
    byIdentity.set(key, preferRowAction(byIdentity.get(key), action));
  }
  return ensureUniqueActionIds([...byIdentity.values()]);
}

function actionNameSet(table) {
  return unique((table.actions || []).map((item) => item.name)).sort().join("|");
}

function tableIdentity(table) {
  const headers = unique(table.headers || []).map((item) => item.toLowerCase()).join("|");
  const actions = unique((table.actions || []).map((item) =>
    `${clean(item.column_header).toLowerCase()}:${clean(item.name).toLowerCase()}`
  )).sort().join("|");
  return `${headers}::${actions}`;
}

function mergeTableActions(actions) {
  const byAction = new Map();
  for (const item of actions || []) {
    const key = `${clean(item.column_header).toLowerCase()}|${clean(item.name).toLowerCase()}`;
    const existing = byAction.get(key);
    if (existing) {
      existing.disabled = existing.disabled && !!item.disabled;
    } else {
      byAction.set(key, {
        name: clean(item.name),
        column_header: clean(item.column_header),
        disabled: !!item.disabled
      });
    }
  }
  return [...byAction.values()];
}

function dedupeTables(tables) {
  const filtered = tables.filter((table, index) => {
    if ((table.headers || []).length > 0) return true;
    const names = actionNameSet(table);
    if (!names) return true;
    return !tables.some((candidate, candidateIndex) =>
      candidateIndex !== index &&
      (candidate.headers || []).length > 0 &&
      actionNameSet(candidate) === names
    );
  });
  const byIdentity = new Map();
  for (const table of filtered) {
    const key = tableIdentity(table);
    const existing = byIdentity.get(key);
    if (!existing) {
      byIdentity.set(key, {
        ...table,
        headers: unique(table.headers || []),
        actions: mergeTableActions(table.actions || [])
      });
      continue;
    }
    existing.row_count_sampled = Math.max(existing.row_count_sampled || 0, table.row_count_sampled || 0);
    existing.actions = mergeTableActions([...(existing.actions || []), ...(table.actions || [])]);
    if (!existing.title && table.title) existing.title = table.title;
  }
  return [...byIdentity.values()];
}

function pageFromCapture(capture) {
  const page = capture.page || {};
  const routePath = normalizePath(page.path);
  if (!routePath || routePath === "/" || routePath === "/login" || routePath === "/404" || routePath === "/401") return null;
  const pageName = clean(String(page.title || "").replace(/\s*-\s*心舰\s*$/g, "")) || routePath;
  const tables = [];
  const actions = [];
  for (const table of capture.tables || []) {
    const rowActions = Array.isArray(table.actions) ? table.actions.filter((item) => isPublicUiText(item.name, 24)) : [];
    const headers = unique((table.headers || []).filter((item) => isPublicUiText(item, 40)));
    if (headers.length > 0 || rowActions.length > 0) {
      tables.push({
        title: isPublicUiText(table.title, 40) ? clean(table.title) : "",
        headers,
        row_count_sampled: table.row_count_sampled || 0,
        actions: rowActions.map((item) => ({
          name: clean(item.name),
          column_header: isPublicUiText(item.column_header, 40) ? clean(item.column_header) : "",
          disabled: !!item.disabled
        }))
      });
    }
    for (const item of rowActions) {
      const name = clean(item.name);
      const columnHeader = isPublicUiText(item.column_header, 40) ? clean(item.column_header) : "";
      actions.push({
        id: `${pageIdFromPath(routePath)}.row_action.${slug(columnHeader || "row")}.${slug(name)}`,
        name: columnHeader ? `${columnHeader}${name}` : name,
        aliases: aliasesForRowAction(name, columnHeader),
        type: "row_action",
        safety: classifySafety(name),
        purpose: `Use row action ${name}${columnHeader ? ` in the ${columnHeader} column` : ""} on ${pageName}.`,
        function_source: "auto-generated from observed table row action label; row action was not clicked and row data was not read",
        locator: {
          row_action_text: name,
          column_header: columnHeader,
          column_class: item.column_class || "",
          table_selector: table.selector || ""
        }
      });
    }
  }
  const dedupedTables = dedupeTables(tables);
  const dedupedActions = dedupeRowActions(actions);
  return {
    id: pageIdFromPath(routePath),
    name: pageName,
    module: moduleFromPath(routePath),
    route_pattern: `^${escapeRegex(routePath)}\\/?$`,
    url_contains: [routePath],
    title_aliases: unique([page.title, pageName]),
    purpose: `Auto-generated row-action memory for ${pageName}.`,
    evidence: {
      source: "chrome_cdp_row_action_probe",
      captured_page_url: page.href || "",
      captured_page_title: page.title || "",
      captured_counts: capture.counts || {},
      coverage_result: dedupedActions.length > 0 ? "actions_promoted" : "probe_ran_no_public_row_actions",
      function_source: "observed table row action labels and generic headers only; row actions not clicked"
    },
    observed_controls: { tables: dedupedTables },
    actions: dedupedActions
  };
}

const files = await listCaptureFiles();
const pagesById = new Map();
let considered = 0;
let promoted = 0;
let skippedInvalid = 0;
for (const file of files) {
  let capture = null;
  try {
    capture = JSON.parse(await fs.readFile(file, "utf8"));
  } catch {
    skippedInvalid += 1;
    continue;
  }
  if (!capture?.ok || !capture.page) {
    skippedInvalid += 1;
    continue;
  }
  considered += 1;
  const page = pageFromCapture(capture);
  if (!page) {
    skippedInvalid += 1;
    continue;
  }
  const existing = pagesById.get(page.id);
  if (existing) {
    existing.actions.push(...page.actions);
    existing.observed_controls.tables.push(...page.observed_controls.tables);
    promoted += 1;
  } else {
    pagesById.set(page.id, page);
    promoted += 1;
  }
}

const pages = [...pagesById.values()].map((page) => {
  page.actions = dedupeRowActions(page.actions);
  page.observed_controls.tables = dedupeTables(page.observed_controls.tables || []);
  page.evidence.captured_counts = {
    tables: page.observed_controls.tables.length,
    row_actions: page.actions.length,
    sampled_rows: page.observed_controls.tables.reduce((sum, table) => sum + (table.row_count_sampled || 0), 0)
  };
  page.evidence.coverage_result = page.actions.length > 0 ? "actions_promoted" : "probe_ran_no_public_row_actions";
  return page;
}).sort((a, b) => `${a.module}.${a.id}`.localeCompare(`${b.module}.${b.id}`));

const payload = {
  version: new Date().toISOString().slice(0, 10),
  system: "xinjian_erp",
  source: "generated_from_sanitized_cdp_row_action_captures",
  generated_at: new Date().toISOString(),
  policy: {
    default_mode: "read_only_map_first",
    note: "Row action map stores table headers and row action button labels only. It does not store row cell values, cookies, storage, tokens, or private-looking text.",
    write_action_rule: "Row write/export/delete/edit actions are confirmation-required until manually verified."
  },
  pages
};

if (!dryRun) await fs.writeFile(out, JSON.stringify(payload, null, 2) + "\n", "utf8");
process.stdout.write(JSON.stringify({
  ok: true,
  dry_run: dryRun,
  output_path: path.resolve(out),
  files: files.length,
  considered,
  promoted,
  skipped_invalid: skippedInvalid,
  pages: pages.length,
  actions: pages.reduce((sum, page) => sum + page.actions.length, 0)
}, null, 2));
