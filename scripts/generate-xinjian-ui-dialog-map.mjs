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

function normalizeButtonText(value) {
  const text = clean(value);
  if (/^close$/i.test(text)) return "关闭";
  const compact = text.replace(/\s+/g, "");
  if (compact === "取消") return "取消";
  if (compact === "确定") return "确定";
  return text;
}

function actionIdentity(action) {
  const locator = action.locator || {};
  return [
    action.type,
    action.name,
    locator.trigger_text || "",
    locator.dialog_title || "",
    locator.button_text || ""
  ].join("|");
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

function isPublicUiText(value) {
  const text = clean(value);
  return !!text && text.length <= 60 && !isPrivateLike(text);
}

function ensureUniqueActionIds(actions) {
  const seen = new Map();
  for (const action of actions) {
    const base = clean(action.id) || "dialog.action";
    const count = seen.get(base) || 0;
    seen.set(base, count + 1);
    if (count > 0) action.id = `${base}.${count + 1}`;
  }
  return actions;
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
  return `dialog.${slug(parts.join(".") || "root")}`;
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

function classifySafety(name, type) {
  const compact = clean(name).replace(/\s+/g, "");
  if (type === "dialog_opener") return "opens_dialog_no_submit";
  if (/^(取消|关闭|返回|Close)$/i.test(compact)) return "read_filter";
  if (/导出|下载/.test(compact)) return "confirmation_required_export";
  if (/保存|提交|确定|确认|删除|恢复|批量|修改|编辑|更新|应用|设置|配置|分配|认领|转移|添加|新增|创建|上传|导入|启用|禁用|授权|同步|清除|移除|审核|审批|发货|作废|标记/.test(compact)) {
    return "confirmation_required_write";
  }
  if (/详情|查看|打开|进入|预览/.test(compact)) return "navigation";
  return "unknown_observed";
}

function aliasesForDialog(triggerName, dialogTitle, buttonName) {
  const trigger = clean(triggerName).replace(/\s+/g, "");
  const title = clean(dialogTitle).replace(/\s+/g, "");
  const button = clean(buttonName).replace(/\s+/g, "");
  const aliases = [buttonName, button, `${trigger}${button}`, `${title}${button}`];
  for (const command of ["新增", "添加", "编辑", "修改", "创建", "设置", "配置"]) {
    if (trigger.startsWith(command) && trigger.length > command.length) {
      aliases.push(`${trigger.slice(command.length)}${command}${button}`);
    }
  }
  return unique(aliases);
}

function aliasesForOpener(triggerName) {
  const trigger = clean(triggerName).replace(/\s+/g, "");
  const aliases = [triggerName, trigger, `${trigger}弹窗`, `${trigger}表单`];
  for (const command of ["新增", "添加", "编辑", "修改", "创建", "设置", "配置"]) {
    if (trigger.startsWith(command) && trigger.length > command.length) {
      const reversed = `${trigger.slice(command.length)}${command}`;
      aliases.push(reversed, `${reversed}弹窗`, `${reversed}表单`);
    }
  }
  return unique(aliases);
}

function pageFromCapture(capture) {
  const page = capture.page || {};
  const routePath = normalizePath(page.path);
  if (!routePath || routePath === "/" || routePath === "/login" || routePath === "/404" || routePath === "/401") return null;
  const pageName = clean(String(page.title || "").replace(/\s*-\s*心舰\s*$/g, "")) || routePath;
  const dialogs = [];
  const actions = [];

  for (const trigger of capture.dialog_triggers || []) {
    const triggerName = clean(trigger.trigger_text);
    if (!triggerName || !isPublicUiText(triggerName)) continue;
    const triggerDialogs = Array.isArray(trigger.dialogs) ? trigger.dialogs.filter((dialog) => dialog && (dialog.buttons || dialog.field_labels || dialog.placeholders)) : [];
    if (triggerDialogs.length === 0) continue;
    dialogs.push({
      trigger: triggerName,
      trigger_selector: trigger.trigger_selector || "",
      dialog_count: triggerDialogs.length,
      dialogs: triggerDialogs.map((dialog) => ({
        title: isPublicUiText(dialog.title) ? clean(dialog.title) : "",
        type: clean(dialog.type),
        buttons: unique((dialog.buttons || []).map(normalizeButtonText).filter(isPublicUiText)),
        field_labels: unique((dialog.field_labels || []).filter(isPublicUiText)),
        placeholders: unique((dialog.placeholders || []).filter(isPublicUiText))
      }))
    });
    actions.push({
      id: `${pageIdFromPath(routePath)}.dialog_opener.${slug(triggerName)}`,
      name: triggerName,
      aliases: aliasesForOpener(triggerName),
      type: "dialog_opener",
      safety: classifySafety(triggerName, "dialog_opener"),
      purpose: `Open the ${triggerName} dialog/drawer on ${pageName}; do not submit changes without explicit confirmation.`,
      function_source: "auto-generated from observed dialog opener; opener clicked, no submit/confirm button clicked",
      locator: { trigger_text: triggerName, trigger_selector: trigger.trigger_selector || "" }
    });
    for (const dialog of triggerDialogs) {
      const dialogTitle = isPublicUiText(dialog.title) ? clean(dialog.title) : "";
      for (const buttonName of unique((dialog.buttons || []).map(normalizeButtonText).filter(isPublicUiText))) {
        actions.push({
          id: `${pageIdFromPath(routePath)}.dialog_button.${slug(triggerName)}.${slug(buttonName)}`,
          name: `${triggerName}${buttonName}`,
          aliases: aliasesForDialog(triggerName, dialogTitle, buttonName),
          type: "dialog_button",
          safety: classifySafety(buttonName, "dialog_button"),
          purpose: `Use ${buttonName} inside the ${triggerName} dialog/drawer on ${pageName}.`,
          function_source: "auto-generated from observed dialog/drawer button; button was not clicked",
          locator: {
            trigger_text: triggerName,
            dialog_title: dialogTitle,
            button_text: buttonName,
            trigger_selector: trigger.trigger_selector || ""
          }
        });
      }
    }
  }
  if (dialogs.length === 0 && actions.length === 0) return null;
  const seen = new Set();
  const dedupedActions = actions.filter((action) => {
    const key = actionIdentity(action);
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
  ensureUniqueActionIds(dedupedActions);
  return {
    id: pageIdFromPath(routePath),
    name: pageName,
    module: moduleFromPath(routePath),
    route_pattern: `^${escapeRegex(routePath)}\\/?$`,
    url_contains: [routePath],
    title_aliases: unique([page.title, pageName]),
    purpose: `Auto-generated dialog/drawer memory for ${pageName}.`,
    evidence: {
      source: "chrome_cdp_dialog_probe",
      captured_page_url: page.href || "",
      captured_page_title: page.title || "",
      captured_counts: capture.counts || {},
      function_source: "observed safe dialog openers and sanitized dialog controls; submit/confirm buttons not clicked"
    },
    observed_controls: { dialogs },
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
    existing.observed_controls.dialogs.push(...page.observed_controls.dialogs);
    promoted += 1;
  } else {
    pagesById.set(page.id, page);
    promoted += 1;
  }
}

const pages = [...pagesById.values()].map((page) => {
  const seenActions = new Set();
  page.actions = page.actions.filter((action) => {
    const key = actionIdentity(action);
    if (seenActions.has(key)) return false;
    seenActions.add(key);
    return true;
  });
  ensureUniqueActionIds(page.actions);
  return page;
}).sort((a, b) => `${a.module}.${a.id}`.localeCompare(`${b.module}.${b.id}`));

const payload = {
  version: new Date().toISOString().slice(0, 10),
  system: "xinjian_erp",
  source: "generated_from_sanitized_cdp_dialog_captures",
  generated_at: new Date().toISOString(),
  policy: {
    default_mode: "read_only_map_first",
    note: "Dialog map stores safe dialog/drawer opener labels plus generic button/field labels only. Input values, cookies, storage, tokens, and private-looking text are not captured.",
    write_action_rule: "Dialog submit/confirm/save/write buttons are confirmation-required and were not clicked during capture."
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
