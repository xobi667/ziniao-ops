#!/usr/bin/env node
import fs from "node:fs/promises";
import path from "node:path";

function argValue(name, fallback = "") {
  const index = process.argv.indexOf(name);
  if (index < 0 || index + 1 >= process.argv.length) return fallback;
  return process.argv[index + 1];
}

function hasFlag(name) {
  return process.argv.includes(name);
}

const root = path.resolve(argValue("--root", process.cwd()));
const outJson = argValue("--out-json", path.join(root, "references", "xinjian-ui-action-catalog.json"));
const outMd = argValue("--out-md", path.join(root, "references", "xinjian-ui-action-catalog.md"));
const dryRun = hasFlag("--dry-run");

function clean(value) {
  return String(value || "").replace(/[\uE000-\uF8FF]/g, " ").replace(/\s+/g, " ").trim();
}

function unique(values) {
  const seen = new Set();
  const result = [];
  for (const value of values || []) {
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

function routeKey(input) {
  let value = clean(input);
  if (!value) return "";
  try {
    const parsed = new URL(value);
    value = parsed.pathname;
  } catch {
  }
  if (!value.startsWith("/")) value = `/${value}`;
  value = value.replace(/\/+/g, "/");
  if (value.length > 1) value = value.replace(/\/+$/g, "");
  return value || "/";
}

function locatorStrategy(action) {
  const locator = action?.locator || {};
  if (locator.row_context_required) return "row_context_required_dialog";
  if (locator.trigger_selector && locator.item_text) return "click_trigger_selector_then_overlay_item_text";
  if (locator.trigger_selector && locator.button_text) return "click_trigger_selector_then_dialog_button_text";
  if (locator.trigger_selector) return "click_trigger_selector";
  if (locator.table_selector && locator.row_action_text) return "click_first_matching_row_action_in_table";
  if (locator.href) return "navigate_href";
  if (locator.dom_text) return "click_visible_dom_text";
  if (locator.dom_placeholder) return "input_or_filter_placeholder";
  if (Array.isArray(locator.tab_texts) && locator.tab_texts.length && Array.isArray(locator.dom_placeholders) && locator.dom_placeholders.length) return "click_quick_tab_text_or_placeholder_list";
  if (Array.isArray(locator.tab_texts) && locator.tab_texts.length) return "click_visible_tab_text_from_list";
  if (Array.isArray(locator.dom_placeholders) && locator.dom_placeholders.length) return "input_or_filter_placeholder_list";
  if (clean(action?.type) === "table_column" && locator.table_column) return "read_table_column_header";
  if (locator.table_column) return "row_context_required_column_header";
  if (locator.uia_name) return "uia_locator";
  if (hasVisibleTextFallback(action)) return "click_visible_action_text";
  if (hasFilterLabelFallback(action)) return "click_visible_filter_label_or_text";
  return "map_only";
}

function hasVisibleTextFallback(action) {
  const name = clean(action?.name);
  const type = clean(action?.type);
  if (!name) return false;
  if (["tab", "status_tab"].includes(type)) return !["平台标签"].includes(name);
  if (type === "row_navigation") return !["行分析", "操作"].includes(name);
  return false;
}

function hasFilterLabelFallback(action) {
  const name = clean(action?.name);
  const type = clean(action?.type);
  if (!name) return false;
  return type === "date_filter";
}

function actionContext(action) {
  const locator = action?.locator || {};
  if (locator.trigger_text && locator.item_text) return `${clean(locator.trigger_text)} -> ${clean(locator.item_text)}`;
  if (locator.trigger_text && locator.button_text) return `${clean(locator.trigger_text)} -> ${clean(locator.button_text)}`;
  if (locator.dialog_title && locator.button_text) return `${clean(locator.dialog_title)} -> ${clean(locator.button_text)}`;
  if (locator.column_header && locator.row_action_text) return `${clean(locator.column_header)} -> ${clean(locator.row_action_text)}`;
  if (locator.row_action_text) return clean(locator.row_action_text);
  if (locator.table_column) return `column:${clean(locator.table_column)}`;
  if (Array.isArray(locator.tab_texts) && locator.tab_texts.length && Array.isArray(locator.dom_placeholders) && locator.dom_placeholders.length) {
    return `tabs:${unique(locator.tab_texts).join("/")}; placeholders:${unique(locator.dom_placeholders).join("/")}`;
  }
  if (Array.isArray(locator.tab_texts) && locator.tab_texts.length) return `tabs:${unique(locator.tab_texts).join("/")}`;
  if (Array.isArray(locator.dom_placeholders) && locator.dom_placeholders.length) return `placeholders:${unique(locator.dom_placeholders).join("/")}`;
  if (locator.dom_placeholder) return `placeholder:${clean(locator.dom_placeholder)}`;
  if (locator.dom_text) return `text:${clean(locator.dom_text)}`;
  if (locator.href) return `href:${clean(locator.href)}`;
  if (locator.uia_name) return `uia:${clean(locator.uia_name)}`;
  return "";
}

function safetyMode(action) {
  const safety = clean(action?.safety);
  if (safety.startsWith("confirmation_required_export")) return "confirmation_required_export";
  if (safety.startsWith("confirmation_required")) return "confirmation_required_write";
  if (["read_filter", "navigation", "view_setting", "account_menu", "opens_dialog_no_submit", "form_field"].includes(safety)) {
    return "safe_execute_allowed";
  }
  return "manual_review";
}

function confirmationRequired(action) {
  const mode = safetyMode(action);
  return mode === "confirmation_required_write" || mode === "confirmation_required_export" || mode === "manual_review";
}

function fallbackPurpose(action, pageName, global = false) {
  const name = clean(action?.name);
  const type = clean(action?.type) || "action";
  const mode = safetyMode(action);
  const scope = global ? "global 心舰 layout" : clean(pageName) || "this page";
  if (!name) return `Remember a ${type} action on ${scope}.`;
  if (type === "module_switch") return `Switch 心舰 to the ${name} module.`;
  if (type === "status_tab") return `Switch ${scope} to the ${name} status tab.`;
  if (type === "tab") return `Switch ${scope} to the ${name} tab.`;
  if (type === "table_column") return `Remember that ${scope} has the ${name} table column/metric.`;
  if (type === "filter_input" || type === "form_input") return `Focus or filter ${scope} by ${name}.`;
  if (type === "date_filter") return `Open or focus the ${name} date filter on ${scope}.`;
  if (type === "overlay_trigger") return `Open the ${name} overlay on ${scope}.`;
  if (type === "overlay_item") return `Choose ${name} from an overlay on ${scope}.`;
  if (type === "dialog_opener") return `Open the ${name} dialog/drawer on ${scope}; do not submit changes without explicit confirmation.`;
  if (type === "dialog_button") return `Use ${name} inside a dialog/drawer on ${scope}.`;
  if (type === "row_action" || type === "row_navigation" || type === "row_operation") return `Use the row-level ${name} action on ${scope} only when the target row is clear.`;
  if (type === "navigation") return `Navigate from ${scope} using ${name}.`;
  if (mode === "confirmation_required_export") return `Export or download from ${scope} with ${name}; requires explicit confirmation.`;
  if (mode === "confirmation_required_write") return `Run ${name} on ${scope}; this may change data and requires explicit confirmation.`;
  return `Use ${name} on ${scope}.`;
}

function fallbackFunctionSource(action, source, pageName, global = false) {
  const sourceName = clean(source?.label) || "unknown";
  const name = clean(action?.name) || "action";
  const scope = global ? "global 心舰 layout" : clean(pageName) || "this page";
  if (sourceName === "curated") return `curated public UI map entry for ${name} on ${scope}; behavior inferred from label, locator, and safety gate`;
  return `${sourceName} public UI map entry for ${name} on ${scope}; behavior inferred from sanitized capture metadata`;
}

function actionIdentity(pageKey, action, sourceId) {
  return [
    pageKey,
    clean(action?.type),
    clean(action?.name),
    clean(action?.safety),
    actionContext(action),
    sourceId === "curated" ? "curated" : ""
  ].join("|").toLowerCase();
}

async function readJson(filePath) {
  try {
    return JSON.parse(await fs.readFile(filePath, "utf8"));
  } catch {
    return null;
  }
}

const sources = [
  { id: "curated", label: "curated", file: path.join(root, "references", "xinjian-ui-map.json") },
  { id: "auto", label: "auto", file: path.join(root, "references", "xinjian-ui-auto-map.json") },
  { id: "overlay", label: "overlay", file: path.join(root, "references", "xinjian-ui-overlay-map.json") },
  { id: "dialog", label: "dialog", file: path.join(root, "references", "xinjian-ui-dialog-map.json") },
  { id: "row_action", label: "row-action", file: path.join(root, "references", "xinjian-ui-row-action-map.json") }
];

const pages = new Map();
const actionSeen = new Set();
const sourceStats = [];
const typeCounts = {};
const safetyCounts = {};
const locatorStrategyCounts = {};
let globalActionCount = 0;
let tableHeaderActionCount = 0;
const tableHeaderSource = { id: "table_header", label: "table-header" };

function ensurePage(pageLike, source) {
  const needles = unique(pageLike?.url_contains || []);
  const route = routeKey(needles[0] || "");
  const key = route || clean(pageLike?.id) || "__global__";
  if (!pages.has(key)) {
    pages.set(key, {
      id: clean(pageLike?.id) || (key === "__global__" ? "global" : `catalog.${key.replace(/[^a-z0-9\u4e00-\u9fa5]+/gi, ".").replace(/^\.+|\.+$/g, "")}`),
      name: clean(pageLike?.name) || (key === "__global__" ? "Global" : key),
      module: clean(pageLike?.module) || "Global",
      route,
      route_pattern: clean(pageLike?.route_pattern),
      url_contains: needles,
      title_aliases: unique(pageLike?.title_aliases || []),
      sources: [],
      actions: []
    });
  }
  const page = pages.get(key);
  if (source && !page.sources.includes(source.label)) page.sources.push(source.label);
  page.url_contains = unique([...page.url_contains, ...needles]);
  page.title_aliases = unique([...page.title_aliases, ...(pageLike?.title_aliases || [])]);
  if (!page.route && route) page.route = route;
  if (!page.route_pattern && pageLike?.route_pattern) page.route_pattern = clean(pageLike.route_pattern);
  return page;
}

function addAction(pageLike, action, source, global = false) {
  const page = ensurePage(global ? { id: "global", name: "Global", module: "Global" } : pageLike, source);
  const identity = actionIdentity(page.route || page.id, action, source.id);
  if (actionSeen.has(identity)) return false;
  actionSeen.add(identity);
  const mode = safetyMode(action);
  const strategy = locatorStrategy(action);
  typeCounts[clean(action.type) || "unknown"] = (typeCounts[clean(action.type) || "unknown"] || 0) + 1;
  safetyCounts[mode] = (safetyCounts[mode] || 0) + 1;
  locatorStrategyCounts[strategy] = (locatorStrategyCounts[strategy] || 0) + 1;
  if (global) globalActionCount += 1;
  page.actions.push({
    id: clean(action.id),
    name: clean(action.name),
    context: actionContext(action),
    aliases: unique(action.aliases || []),
    type: clean(action.type) || "unknown",
    safety: clean(action.safety) || "unknown",
    safety_mode: mode,
    confirmation_required: confirmationRequired(action),
    purpose: clean(action.purpose) || fallbackPurpose(action, page.name, global),
    function_source: clean(action.function_source) || fallbackFunctionSource(action, source, page.name, global),
    source_map: source.label,
    locator_strategy: strategy,
    locator: action.locator || {}
  });
  return true;
}

function actionIdSegment(value) {
  return clean(value)
    .toLowerCase()
    .replace(/[^a-z0-9\u4e00-\u9fa5]+/gi, ".")
    .replace(/^\.+|\.+$/g, "") || "column";
}

function collectTableHeaderNames(pageLike) {
  const names = [];
  const observedHeaders = pageLike?.observed_controls?.table_headers;
  if (Array.isArray(observedHeaders)) {
    for (const header of observedHeaders) {
      if (typeof header === "string") names.push(header);
      else if (header && typeof header === "object") names.push(header.name);
    }
  }
  for (const key of ["table_headers", "table_columns"]) {
    if (Array.isArray(pageLike?.[key])) names.push(...pageLike[key]);
  }
  if (Array.isArray(pageLike?.layout?.table_columns)) names.push(...pageLike.layout.table_columns);
  return unique(names).filter((name) => !["选择框", "操作"].includes(name));
}

function addTableHeaderActions(pageLike) {
  const explicitColumns = new Set(
    (pageLike?.actions || [])
      .filter((action) => clean(action?.type) === "table_column")
      .map((action) => clean(action?.name).toLowerCase())
  );
  let added = 0;
  for (const name of collectTableHeaderNames(pageLike)) {
    if (explicitColumns.has(name.toLowerCase())) continue;
    const idBase = clean(pageLike?.id) || routeKey((pageLike?.url_contains || [])[0]) || "xinjian.page";
    const action = {
      id: `${actionIdSegment(idBase)}.table.column.${actionIdSegment(name)}`,
      name,
      aliases: [name],
      type: "table_column",
      safety: "read_filter",
      purpose: `Remember that ${clean(pageLike?.name) || "this page"} has the ${name} table column/metric.`,
      function_source: "generated from sanitized public table header metadata; no row data was read",
      locator: { table_column: name }
    };
    if (addAction(pageLike, action, tableHeaderSource)) added += 1;
  }
  return added;
}

for (const source of sources) {
  const map = await readJson(source.file);
  if (!map) {
    sourceStats.push({ source: source.label, loaded: false, pages: 0, actions: 0 });
    continue;
  }
  let actionCount = 0;
  for (const action of map.global_actions || []) {
    addAction(null, action, source, true);
    actionCount += 1;
  }
  for (const page of map.pages || []) {
    ensurePage(page, source);
    for (const action of page.actions || []) {
      addAction(page, action, source);
      actionCount += 1;
    }
    tableHeaderActionCount += addTableHeaderActions(page);
  }
  sourceStats.push({
    source: source.label,
    loaded: true,
    version: clean(map.version),
    pages: (map.pages || []).length,
    actions: actionCount
  });
}

if (tableHeaderActionCount > 0) {
  sourceStats.push({
    source: tableHeaderSource.label,
    loaded: true,
    version: "generated",
    pages: 0,
    actions: tableHeaderActionCount
  });
}

const catalogPages = [...pages.values()]
  .map((page) => ({
    ...page,
    sources: unique(page.sources).sort(),
    actions: page.actions.sort((a, b) => `${a.type}.${a.name}.${a.id}`.localeCompare(`${b.type}.${b.name}.${b.id}`))
  }))
  .sort((a, b) => `${a.module}.${a.route || a.id}.${a.name}`.localeCompare(`${b.module}.${b.route || b.id}.${b.name}`));

const actionCount = catalogPages.reduce((sum, page) => sum + page.actions.length, 0);
const manualReviewActions = [];
const mapOnlyActions = [];
const emptyLocatorActions = [];
for (const page of catalogPages) {
  for (const action of page.actions) {
    const row = {
      page: page.name,
      route: page.route,
      action: action.name,
      context: action.context,
      type: action.type,
      safety_mode: action.safety_mode,
      locator_strategy: action.locator_strategy,
      source_map: action.source_map,
      purpose: action.purpose
    };
    if (action.safety_mode === "manual_review") manualReviewActions.push(row);
    if (action.locator_strategy === "map_only") mapOnlyActions.push(row);
    if (!action.locator || Object.keys(action.locator).length === 0) emptyLocatorActions.push(row);
  }
}
const payload = {
  version: new Date().toISOString().slice(0, 10),
  system: "xinjian_erp",
  source: "merged_public_xinjian_ui_action_maps",
  generated_at: new Date().toISOString(),
  policy: {
    default_mode: "map_first_dry_run_before_execute",
    note: "This catalog merges public sanitized UI maps. It does not contain credentials, cookies, tokens, storage values, input values, or private table row data.",
    execute_rule: "Use invoke-xinjian-ui-action.ps1 for execution. Confirmation-required write/export/manual-review actions must not execute without explicit user confirmation."
  },
  totals: {
    pages: catalogPages.length,
    actions: actionCount,
    global_actions: globalActionCount,
    source_stats: sourceStats,
    type_counts: Object.fromEntries(Object.entries(typeCounts).sort()),
    safety_counts: Object.fromEntries(Object.entries(safetyCounts).sort()),
    locator_strategy_counts: Object.fromEntries(Object.entries(locatorStrategyCounts).sort())
  },
  audit: {
    manual_review_actions: manualReviewActions,
    map_only_actions: mapOnlyActions,
    empty_locator_actions: emptyLocatorActions,
    next_improvements: [
      "Capture generic platform tabs, row navigation, and row operations with exact DOM text or row-action locators where possible.",
      "Manually classify manual_review actions before allowing execution.",
      "Keep write/export actions confirmation-required even when locators are known."
    ]
  },
  pages: catalogPages
};

function mdEscape(value) {
  return clean(value).replace(/\|/g, "\\|");
}

function renderMarkdown(catalog) {
  const lines = [];
  lines.push("# Xinjian UI Action Catalog");
  lines.push("");
  lines.push("Generated from sanitized public 心舰 UI maps. Use this as a compact index of remembered pages, buttons, filters, overlays, dialogs, row actions, safety gates, and locator strategies.");
  lines.push("");
  lines.push("## Totals");
  lines.push("");
  lines.push(`- Pages: ${catalog.totals.pages}`);
  lines.push(`- Actions: ${catalog.totals.actions}`);
  lines.push(`- Global actions: ${catalog.totals.global_actions}`);
  lines.push("");
  lines.push("### Sources");
  lines.push("");
  lines.push("| Source | Version | Pages | Actions |");
  lines.push("| --- | --- | ---: | ---: |");
  for (const stat of catalog.totals.source_stats) {
    lines.push(`| ${mdEscape(stat.source)} | ${mdEscape(stat.version || "")} | ${stat.pages || 0} | ${stat.actions || 0} |`);
  }
  lines.push("");
  lines.push("### Safety");
  lines.push("");
  lines.push("| Safety mode | Actions |");
  lines.push("| --- | ---: |");
  for (const [mode, count] of Object.entries(catalog.totals.safety_counts)) {
    lines.push(`| ${mdEscape(mode)} | ${count} |`);
  }
  lines.push("");
  lines.push("### Locator Strategies");
  lines.push("");
  lines.push("| Locator strategy | Actions |");
  lines.push("| --- | ---: |");
  for (const [strategy, count] of Object.entries(catalog.totals.locator_strategy_counts)) {
    lines.push(`| ${mdEscape(strategy)} | ${count} |`);
  }
  lines.push("");
  lines.push("## Audit");
  lines.push("");
  lines.push(`- Manual-review actions: ${catalog.audit.manual_review_actions.length}`);
  lines.push(`- Map-only actions: ${catalog.audit.map_only_actions.length}`);
  lines.push(`- Empty-locator actions: ${catalog.audit.empty_locator_actions.length}`);
  lines.push("");
  if (catalog.audit.manual_review_actions.length) {
    lines.push("### Manual Review Actions");
    lines.push("");
    lines.push("| Page | Route | Action | Type | Strategy | Purpose |");
    lines.push("| --- | --- | --- | --- | --- | --- |");
    for (const action of catalog.audit.manual_review_actions) {
      lines.push(`| ${mdEscape(action.page)} | \`${mdEscape(action.route)}\` | ${mdEscape(action.action)} | ${mdEscape(action.type)} | ${mdEscape(action.locator_strategy)} | ${mdEscape(action.purpose)} |`);
    }
    lines.push("");
  }
  if (catalog.audit.map_only_actions.length) {
    lines.push("### Map-Only Actions");
    lines.push("");
    lines.push("| Page | Route | Action | Type | Safety | Purpose |");
    lines.push("| --- | --- | --- | --- | --- | --- |");
    for (const action of catalog.audit.map_only_actions) {
      lines.push(`| ${mdEscape(action.page)} | \`${mdEscape(action.route)}\` | ${mdEscape(action.action)} | ${mdEscape(action.type)} | ${mdEscape(action.safety_mode)} | ${mdEscape(action.purpose)} |`);
    }
    lines.push("");
  }
  for (const page of catalog.pages) {
    lines.push(`## ${page.module} / ${page.name}`);
    lines.push("");
    lines.push(`- Route: \`${page.route || ""}\``);
    lines.push(`- Sources: ${page.sources.join(", ")}`);
    lines.push(`- Actions: ${page.actions.length}`);
    lines.push("");
    lines.push("| Action | Context | Type | Safety | Strategy | Source | Purpose |");
    lines.push("| --- | --- | --- | --- | --- | --- | --- |");
    for (const action of page.actions) {
      lines.push(`| ${mdEscape(action.name)} | ${mdEscape(action.context)} | ${mdEscape(action.type)} | ${mdEscape(action.safety_mode)} | ${mdEscape(action.locator_strategy)} | ${mdEscape(action.source_map)} | ${mdEscape(action.purpose)} |`);
    }
    lines.push("");
  }
  return `${lines.join("\n").trimEnd()}\n`;
}

if (!dryRun) {
  await fs.mkdir(path.dirname(outJson), { recursive: true });
  const stablePayload = await preserveGeneratedMetadataIfUnchanged(payload, outJson);
  await fs.writeFile(outJson, `${JSON.stringify(stablePayload, null, 2)}\n`, "utf8");
  await fs.writeFile(outMd, renderMarkdown(stablePayload), "utf8");
}

process.stdout.write(JSON.stringify({
  ok: true,
  dry_run: dryRun,
  json_output_path: path.resolve(outJson),
  markdown_output_path: path.resolve(outMd),
  pages: payload.totals.pages,
  actions: payload.totals.actions,
  source_stats: payload.totals.source_stats,
  safety_counts: payload.totals.safety_counts,
  locator_strategy_counts: payload.totals.locator_strategy_counts,
  audit: {
    manual_review_actions: payload.audit.manual_review_actions.length,
    map_only_actions: payload.audit.map_only_actions.length,
    empty_locator_actions: payload.audit.empty_locator_actions.length
  }
}, null, 2));
