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
const curatedMapPath = argValue("--curated-map", "");
const existingMapPath = argValue("--existing-map", out);
const includePathRegex = argValue("--include-path-regex", "");
const maxPages = Number(argValue("--max-pages", "0"));
const includeCurated = hasFlag("--include-curated");
const dryRun = hasFlag("--dry-run");
const mergeExisting = !hasFlag("--no-merge-existing");

if (!out) throw new Error("Missing --out.");
if (captureDirs.length === 0 && captureFiles.length === 0) {
  throw new Error("Provide --capture-dir or --capture.");
}

const includeRegex = includePathRegex ? new RegExp(includePathRegex, "i") : null;

async function readJsonIfExists(file) {
  if (!file) return null;
  try {
    return JSON.parse(await fs.readFile(file, "utf8"));
  } catch (error) {
    if (error?.code === "ENOENT") return null;
    throw error;
  }
}

async function listCaptureFiles() {
  const files = [...captureFiles];
  for (const dir of captureDirs) {
    let entries = [];
    try {
      entries = await fs.readdir(dir, { withFileTypes: true });
    } catch (error) {
      if (error?.code === "ENOENT") continue;
      throw error;
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
  return String(value || "")
    .replace(/[\uE000-\uF8FF]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
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

function normalizeForGeneratedMetadataCompare(value) {
  if (!value || typeof value !== "object") return value;
  if (Array.isArray(value)) return value.map(normalizeForGeneratedMetadataCompare);
  const result = {};
  for (const key of Object.keys(value).sort()) {
    if (key === "captured_counts" || key === "generated_at" || key === "version") continue;
    result[key] = normalizeForGeneratedMetadataCompare(value[key]);
  }
  return result;
}

async function preserveGeneratedMetadataIfUnchanged(payload, outputPath) {
  try {
    const existing = JSON.parse(await fs.readFile(outputPath, "utf8"));
    const existingComparable = JSON.stringify(normalizeForGeneratedMetadataCompare(existing));
    const nextComparable = JSON.stringify(normalizeForGeneratedMetadataCompare(payload));
    if (existingComparable === nextComparable) {
      return existing;
    }
  } catch (error) {
    if (error?.code !== "ENOENT") throw error;
  }
  return payload;
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

function safeName(value, control = {}) {
  let text = clean(value);
  const classes = Array.isArray(control.classes) ? control.classes.join(" ") : String(control.classes || "");
  const selector = String(control.selector || "");
  if (/\bavatar-container\b|\bavatar-wrapper\b/.test(`${classes} ${selector}`)) text = "用户菜单";
  if (isPrivateLike(text)) return "";
  if (text.length > 80) return "";
  return text;
}

function isTransientOverlayControl(control = {}) {
  const selector = String(control.selector || "");
  const classes = Array.isArray(control.classes) ? control.classes.join(" ") : String(control.classes || "");
  const marker = `${selector} ${classes}`;
  return /(?:^|[ .#>])(?:el-picker-panel|el-date-picker|el-date-range-picker|el-select-dropdown|el-cascader-panel|el-dropdown-menu|el-popper|el-tooltip__popper|el-autocomplete-suggestion|el-dialog|el-drawer|el-message-box)(?:\\b|[ .#>_-])/i.test(marker);
}

function isAppShellControl(control = {}) {
  const selector = String(control.selector || "");
  const classes = Array.isArray(control.classes) ? control.classes.join(" ") : String(control.classes || "");
  const marker = `${selector} ${classes}`;
  return (
    /rightPanel-container|rightPanel-items|drawer-container|avatar-container|avatar-wrapper/i.test(marker) ||
    (/el-scrollbar\.theme-light|sidebar-container|scrollbar-wrapper\.el-scrollbar__wrap/i.test(marker) && /ul\.el-menu/i.test(marker))
  );
}

function isPrivateLike(value) {
  const text = clean(value);
  if (!text) return false;
  return (
    /@/.test(text) ||
    /\b\d{7,}\b/.test(text) ||
    /\b[A-Za-z][A-Za-z0-9 ._-]{1,50}-(?:my|th|id|sg|ph|vn)-(?:sp|tt|la)\b/i.test(text) ||
    /(?:token|secret|password|passwd|cookie|session|auth)\s*[:=]/i.test(text)
  );
}

function normalizeTab(value) {
  return clean(value).replace(/\s+\d+$/g, "").replace(/\(\d+\)$/g, "").trim();
}

function escapeRegex(value) {
  return String(value).replace(/[\\^$.*+?()[\]{}|]/g, "\\$&");
}

function slug(value) {
  const text = clean(value)
    .toLowerCase()
    .replace(/^https?:\/\//, "")
    .replace(/[^a-z0-9\u4e00-\u9fa5]+/gi, ".")
    .replace(/^\.+|\.+$/g, "")
    .replace(/\.+/g, ".");
  return text || "page";
}

function pageIdFromPath(routePath) {
  const parts = clean(routePath).replace(/^\/+|\/+$/g, "").split(/[/?#]+/).filter(Boolean);
  const base = parts.join(".") || "root";
  return `auto.${slug(base)}`;
}

function moduleFromPath(routePath) {
  const text = clean(routePath).toLowerCase();
  if (text.startsWith("/ad") || text.startsWith("/erp/ads")) return "ADS";
  if (text.startsWith("/crm") || text.startsWith("/invitation") || text.startsWith("/batch-message") || text.startsWith("/content")) return "CRM";
  if (text.startsWith("/bi") || text.startsWith("/data") || text.includes("analyse") || text.includes("analyze")) return "BI";
  if (text.startsWith("/download")) return "System";
  if (text.startsWith("/index")) return "System";
  if (text.startsWith("/ai")) return "AI";
  return "ERP";
}

function classifySafety(name, type) {
  const text = clean(name);
  const compact = text.replace(/\s+/g, "");
  if (type === "table_column") return "read_filter";
  if (type === "tab" || type === "status_tab" || type === "filter_input" || type === "filter_dropdown") return "read_filter";
  if (type === "form_input" || type === "form_dropdown") return "form_field";
  if (/^用户菜单$/.test(text)) return "account_menu";
  if (type === "navigation") return "navigation";
  if (/^(搜索|查询)$/.test(compact)) return "read_filter";
  if (/^重置$/.test(compact)) return "read_filter";
  if (/^(今天|昨天|本月|上月|最近7天|近7天|最近14天|近14天|最近30天|近30天|最近半年|近半年|最近1年|近1年)$/.test(compact)) return "read_filter";
  if (/导出|下载/.test(compact)) return "confirmation_required_export";
  if (/保存|提交|删除|恢复|批量|群发|邮件|修改|编辑|应用|设置|配置|分配|认领|转移|添加|新增|创建|上传|导入|启用|禁用|授权|同步|清除|移除|审核|审批|发货|作废|取消|标记|加黑/.test(compact)) {
    return "confirmation_required_write";
  }
  if (/详情|查看|分析|打开|进入|首页|返回/.test(compact)) return "navigation";
  if (/切换|币种|展开|收起|刷新|视图/.test(compact)) return "view_setting";
  return "unknown_observed";
}

function actionType(controlType, name, context = {}) {
  if (controlType === "table_column") return "table_column";
  if (controlType === "input") return context.isFormPage ? "form_input" : "filter_input";
  if (controlType === "select") return context.isFormPage ? "form_dropdown" : "filter_dropdown";
  if (controlType === "tab") return "tab";
  if (controlType === "menu") return "status_tab";
  if (controlType === "link") return "navigation";
  if (/详情|查看|分析|打开|进入/.test(name)) return "navigation";
  if (/批量/.test(name)) return "batch_action";
  return "button";
}

function purposeFor(name, type, pageName) {
  const safety = classifySafety(name, type);
  if (type === "table_column") return `Remember that ${pageName} has the ${name} table column/metric.`;
  if (type === "filter_input" || type === "filter_dropdown") return `Filter ${pageName} by ${name}.`;
  if (type === "form_input" || type === "form_dropdown") return `Fill or choose the ${name} field on ${pageName}; submitting the form still requires explicit confirmation.`;
  if (type === "tab" || type === "status_tab") return `Switch ${pageName} to the ${name} tab/view.`;
  if (safety === "read_filter") return `Apply or clear filters on ${pageName}.`;
  if (safety === "confirmation_required_export") return `Export or download data from ${pageName}; requires an explicit user request.`;
  if (safety === "confirmation_required_write") return `Open or run a write/configuration action on ${pageName}; requires explicit confirmation before committing changes.`;
  if (safety === "navigation") return `Navigate from ${pageName} to a related detail or analysis view.`;
  if (safety === "view_setting") return `Change the visible view setting on ${pageName}.`;
  if (safety === "account_menu") return "Open the current user/account menu.";
  return `Observed ${name} control on ${pageName}; exact behavior has not been clicked yet.`;
}

function aliasesForAction(name) {
  const text = clean(name);
  const compact = text.replace(/\s+/g, "");
  const aliases = [text, compact];
  for (const command of ["新增", "添加", "批量导入", "导入", "批量删除", "删除", "编辑", "修改", "保存", "提交", "导出", "下载", "标记已处理", "标记未处理"]) {
    if (compact.startsWith(command) && compact.length > command.length) {
      const subject = compact.slice(command.length);
      aliases.push(`${subject}${command}`);
    }
  }
  return unique(aliases);
}

function controlNames(controls, type) {
  return unique(controls
    .filter((item) => item.type === type && !isTransientOverlayControl(item))
    .filter((item) => !isAppShellControl(item))
    .map((item) => safeName(item.placeholder || item.name, item))
    .map((name) => type === "tab" ? normalizeTab(name) : name));
}

function selectorForControl(controls, type, name) {
  const target = clean(name).toLowerCase();
  for (const item of controls) {
    if (item.type !== type || isTransientOverlayControl(item) || isAppShellControl(item)) continue;
    const itemName = type === "tab" || type === "menu"
      ? normalizeTab(safeName(item.placeholder || item.name, item))
      : safeName(item.placeholder || item.name, item);
    if (clean(itemName).toLowerCase() === target) return item.selector || "";
  }
  return "";
}

function tableHeaders(controls) {
  return unique(controls
    .filter((item) => (item.tag === "th" || item.type === "columnheader") && !isTransientOverlayControl(item))
    .map((item) => safeName(item.name, item)));
}

function visibleButtons(controls) {
  return unique(controls
    .filter((item) => item.type === "button" && !isTransientOverlayControl(item))
    .filter((item) => !isAppShellControl(item))
    .map((item) => safeName(item.name, item))
    .filter(Boolean)
    .map((name) => name || "未命名按钮"));
}

function pageFromCapture(capture) {
  const page = capture.page || {};
  const routePath = normalizePath(page.path);
  if (!routePath || routePath === "/login" || routePath === "/404" || routePath === "/401") return null;
  if (includeRegex && !includeRegex.test(routePath)) return null;

  const controls = Array.isArray(capture.controls) ? capture.controls : [];
  const pageName = clean(String(page.title || "").replace(/\s*-\s*心舰\s*$/g, "")) || routePath;
  const isFormPage = /发起|编辑|创建|新增|create|edit/i.test(`${pageName} ${routePath}`);
  const buttons = visibleButtons(controls);
  const inputs = controlNames(controls, "input");
  const selects = controlNames(controls, "select");
  const tabs = controlNames(controls, "tab");
  const menus = controlNames(controls, "menu").map(normalizeTab);
  const headers = tableHeaders(controls);
  const links = controls
    .filter((item) => item.type === "link" && item.href && String(item.href).includes("erp.xinjianerp.com"))
    .filter((item) => !isTransientOverlayControl(item) && !isAppShellControl(item))
    .map((item) => ({ name: safeName(item.name, item), href: String(item.href || "") }))
    .filter((item) => item.name && item.href && item.name.length <= 40);

  if (buttons.length + inputs.length + selects.length + tabs.length + headers.length === 0) return null;

  const actions = [];
  const addAction = (name, observedType, locator) => {
    const cleanActionName = safeName(name);
    if (!cleanActionName) return;
    if ((observedType === "input" || observedType === "select") && cleanActionName === "请选择") return;
    const compactActionName = cleanActionName.replace(/\s+/g, "");
    const type = actionType(observedType, cleanActionName, { isFormPage });
    const safety = classifySafety(cleanActionName, type);
    actions.push({
      id: `${pageIdFromPath(routePath)}.${slug(type)}.${slug(cleanActionName)}`,
      name: cleanActionName,
      aliases: aliasesForAction(cleanActionName),
      type,
      safety,
      purpose: purposeFor(cleanActionName, type, pageName),
      function_source: "auto-generated from observed CDP DOM label/placeholder; behavior not clicked",
      locator
    });
  };

  for (const name of inputs) addAction(name, "input", { dom_placeholder: name, selector: selectorForControl(controls, "input", name) });
  for (const name of selects) addAction(name, "select", { dom_text: name, selector: selectorForControl(controls, "select", name) });
  for (const name of tabs) addAction(name, "tab", { tab_text: name, selector: selectorForControl(controls, "tab", name) });
  for (const name of menus) addAction(name, "menu", { dom_text: name, selector: selectorForControl(controls, "menu", name) });
  for (const name of buttons) addAction(name, "button", { dom_text: name, selector: selectorForControl(controls, "button", name) });
  for (const link of links) {
    addAction(link.name, "link", { dom_text: link.name, selector: selectorForControl(controls, "link", link.name), href: link.href.replace(/([?&][^=]*(token|secret|password|passwd|pwd|cookie|session|auth|key|code)[^=]*=)[^&#]*/ig, "$1[redacted]") });
  }
  for (const name of headers) addAction(name, "table_column", { table_column: name });

  const seenActions = new Set();
  const dedupedActions = actions.filter((action) => {
    const key = `${action.type}|${action.name}|${JSON.stringify(action.locator)}`;
    if (seenActions.has(key)) return false;
    seenActions.add(key);
    return true;
  });

  return {
    id: pageIdFromPath(routePath),
    name: pageName,
    module: moduleFromPath(routePath),
    route_pattern: `^${escapeRegex(routePath)}\\/?$`,
    url_contains: [routePath],
    title_aliases: unique([page.title, pageName]),
    purpose: `Auto-generated UI memory for ${pageName}.`,
    evidence: {
      source: "chrome_cdp_dom_auto",
      captured_page_url: page.href || "",
      captured_page_title: page.title || "",
      captured_counts: capture.counts || {
        controls: controls.length,
        buttons: buttons.length,
        inputs: inputs.length,
        tabs: tabs.length,
        menus: controlNames(controls, "menu").length,
        links: links.length
      },
      function_source: "observed DOM labels, placeholders, tabs, links, and table headers; behavior not clicked"
    },
    layout: {
      filters: unique([...inputs, ...selects].filter((name) => name && name !== "请选择")),
      tabs: unique([...tabs, ...menus]),
      table_columns: headers
    },
    observed_controls: {
      buttons,
      inputs,
      selects,
      tabs,
      menus,
      links,
      table_headers: headers
    },
    actions: dedupedActions
  };
}

const curatedMap = await readJsonIfExists(curatedMapPath);
const existingAutoMap = mergeExisting ? await readJsonIfExists(existingMapPath) : null;
const curatedPaths = new Set();
if (!includeCurated && curatedMap?.pages) {
  for (const page of curatedMap.pages) {
    for (const needle of page.url_contains || []) curatedPaths.add(normalizePath(needle).toLowerCase());
    if (page.id) curatedPaths.add(String(page.id).toLowerCase());
  }
}

const autoPages = new Map();
for (const page of existingAutoMap?.pages || []) {
  if (page?.id) autoPages.set(page.id, page);
}

const files = await listCaptureFiles();
let considered = 0;
let promoted = 0;
let skippedCurated = 0;
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
  const routeKey = normalizePath(page.url_contains?.[0] || "").toLowerCase();
  if (!includeCurated && (curatedPaths.has(routeKey) || curatedPaths.has(String(page.id).toLowerCase()))) {
    skippedCurated += 1;
    continue;
  }
  autoPages.set(page.id, page);
  promoted += 1;
}

let pages = [...autoPages.values()].sort((a, b) => `${a.module}.${a.id}`.localeCompare(`${b.module}.${b.id}`));
if (Number.isFinite(maxPages) && maxPages > 0) pages = pages.slice(0, maxPages);

const payload = {
  version: new Date().toISOString().slice(0, 10),
  system: "xinjian_erp",
  source: "generated_from_sanitized_cdp_dom_captures",
  generated_at: new Date().toISOString(),
  policy: {
    default_mode: "read_only_map_first",
    note: "This generated map stores generic page controls only. It must not contain credentials, cookies, tokens, storage values, input values, or private table row data.",
    write_action_rule: "Auto-generated write/export/batch/edit/save/delete actions are confirmation-required until manually verified."
  },
  pages
};

await fs.mkdir(path.dirname(out), { recursive: true });
if (!dryRun) {
  const stablePayload = await preserveGeneratedMetadataIfUnchanged(payload, out);
  await fs.writeFile(out, JSON.stringify(stablePayload, null, 2) + "\n", "utf8");
}

process.stdout.write(JSON.stringify({
  ok: true,
  dry_run: dryRun,
  output_path: path.resolve(out),
  files: files.length,
  considered,
  promoted,
  skipped_curated: skippedCurated,
  skipped_invalid: skippedInvalid,
  pages: pages.length
}, null, 2));
