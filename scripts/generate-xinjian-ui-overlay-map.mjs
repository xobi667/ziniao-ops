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
if (captureDirs.length === 0 && captureFiles.length === 0) {
  throw new Error("Provide --capture-dir or --capture.");
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
      if (entry.isFile() && entry.name.toLowerCase().endsWith(".json")) files.push(path.join(dir, entry.name));
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

function ensureUniqueActionIds(actions) {
  const seen = new Map();
  for (const action of actions) {
    const base = clean(action.id) || "overlay.action";
    const count = seen.get(base) || 0;
    seen.set(base, count + 1);
    if (count > 0) action.id = `${base}.${count + 1}`;
  }
  return actions;
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

function isGenericOverlayItem(value) {
  const text = clean(value);
  if (!text || text.length > 40 || isPrivateLike(text)) return false;
  return /^(全部|请选择|启用|禁用|是|否|成功|失败|已处理|未处理|今天|昨天|近7天|近30天|Shopee|Lazada|Tiktok|TikTok|视频|直播|商品|店铺|订单|利润|费用|导出|下载|删除|编辑|修改|新增|添加|恢复|转移|分配|认领|标记已处理|标记未处理|批量删除|批量导入|信息更新|应用|重置|搜索|详情|查看|达人ID|达人昵称|达人名称|视频ID号|视频名称|Tiktok账号|TikTok账号|店铺名称|店铺名|负责人|人员|商务)$/i.test(text) ||
    /^(按|选择|切换|批量|标记|导出|下载|删除|编辑|修改|新增|添加|恢复|转移|分配|认领)/.test(text);
}

function isFilterLikeTrigger(triggerName, triggerType) {
  const name = clean(triggerName).replace(/\s+/g, "");
  const type = clean(triggerType).toLowerCase();
  return /select|cascader|date/.test(type) || /选择|请选择|店铺|品类|商务|人员|负责人|状态|标签|年龄|日期|时间|月份/.test(name);
}

function isWriteMenuLikeItem(value) {
  const text = clean(value).replace(/\s+/g, "");
  return /批量|删除|导入|信息更新|编辑|修改|保存|提交|新增|添加|恢复|转移|分配|认领|应用|标记/.test(text);
}

function isStaleActionMenuForFilterTrigger(triggerName, triggerType, rawItems) {
  if (!isFilterLikeTrigger(triggerName, triggerType)) return false;
  const names = (rawItems || [])
    .map((item) => clean(item?.name))
    .filter(Boolean)
    .filter(isGenericOverlayItem);
  if (names.length === 0) return false;
  return names.every(isWriteMenuLikeItem);
}

function isDateShortcut(value) {
  const text = clean(value).replace(/\s+/g, "");
  return /^(今天|昨天|近7天|近30天|最近7天|最近14天|最近30天|最近半年|最近1年|本月|上月)$/.test(text);
}

function isDateLikeTrigger(value) {
  const text = clean(value).replace(/\s+/g, "");
  return /日期|时间|开始|结束|月份|选择月|月$|日$/.test(text);
}

function isStatusLikeTrigger(value) {
  const text = clean(value).replace(/\s+/g, "");
  return /状态|处理状态|是否/.test(text);
}

function isStatusLikeItem(value) {
  const text = clean(value).replace(/\s+/g, "");
  return /^(全部|请选择|启用|禁用|是|否|成功|失败|已处理|未处理|未开始|进行中|已完成|已取消|正常|异常)$/.test(text);
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
  return `overlay.${slug(parts.join(".") || "root")}`;
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
  if (type === "overlay_trigger") return "view_setting";
  if (/^(搜索|查询|重置|今天|昨天|近7天|近30天)$/.test(compact)) return "read_filter";
  if (/^(按|选择|切换)/.test(compact)) return "read_filter";
  if (/^(全部|请选择|启用|禁用|是|否|成功|失败|已处理|未处理|已邀约|未邀约|达人ID|达人昵称|达人名称|视频ID号|视频名称|Tiktok账号|TikTok账号|店铺名称|店铺名|负责人|人员|商务|店铺|订单|利润)$/.test(compact)) return "read_filter";
  if (/导出|下载/.test(compact)) return "confirmation_required_export";
  if (/保存|提交|删除|恢复|批量|修改|编辑|更新|应用|设置|配置|分配|认领|转移|添加|新增|创建|上传|导入|启用|禁用|授权|同步|清除|移除|审核|审批|发货|作废|取消|标记/.test(compact)) {
    return "confirmation_required_write";
  }
  if (/详情|查看|分析|打开|进入|首页|返回/.test(compact)) return "navigation";
  return "unknown_observed";
}

function aliasesForOverlay(triggerName, itemName) {
  const trigger = clean(triggerName).replace(/\s+/g, "");
  const item = clean(itemName).replace(/\s+/g, "");
  const aliases = [itemName, item, `${trigger}${item}`];
  if (/批量/.test(trigger) && item && !item.startsWith("批量")) aliases.push(`批量${item}`);
  for (const command of ["新增", "添加", "批量导入", "导入", "批量删除", "删除", "编辑", "修改", "保存", "提交", "导出", "下载", "标记已处理", "标记未处理"]) {
    if (item.startsWith(command) && item.length > command.length) aliases.push(`${item.slice(command.length)}${command}`);
  }
  return unique(aliases);
}

function pageFromCapture(capture) {
  const page = capture.page || {};
  const routePath = normalizePath(page.path);
  if (!routePath || routePath === "/" || routePath === "/login" || routePath === "/404" || routePath === "/401") return null;
  const pageName = clean(String(page.title || "").replace(/\s*-\s*心舰\s*$/g, "")) || routePath;
  const overlays = [];
  const actions = [];
  for (const trigger of capture.overlay_triggers || []) {
    const triggerName = clean(trigger.name || trigger.trigger_type);
    if (!triggerName || triggerName === "用户菜单") continue;
    const rawItems = Array.isArray(trigger.items) ? trigger.items : [];
    if (isStaleActionMenuForFilterTrigger(triggerName, trigger.trigger_type, rawItems)) continue;
    const items = rawItems.filter((item) => {
      const itemName = clean(item.name);
      if (!isGenericOverlayItem(itemName)) return false;
      if (isDateShortcut(itemName) && !isDateLikeTrigger(triggerName)) return false;
      if (isDateLikeTrigger(triggerName) && !isDateShortcut(itemName)) return false;
      if (isStatusLikeTrigger(triggerName) && !isStatusLikeItem(itemName)) return false;
      return true;
    });
    overlays.push({
      trigger: triggerName,
      trigger_type: trigger.trigger_type,
      item_count: trigger.item_count || 0,
      filtered_item_count: trigger.filtered_item_count || 0,
      items: items.map((item) => clean(item.name))
    });
    actions.push({
      id: `${pageIdFromPath(routePath)}.overlay_trigger.${slug(triggerName)}`,
      name: triggerName,
      aliases: unique([triggerName, triggerName.replace(/\s+/g, "")]),
      type: "overlay_trigger",
      safety: "view_setting",
      purpose: `Open the ${triggerName} overlay on ${pageName}.`,
      function_source: "auto-generated from observed overlay trigger; trigger opened but no overlay item clicked",
      locator: { trigger_text: triggerName, trigger_selector: trigger.selector || "" }
    });
    for (const item of items) {
      const itemName = clean(item.name);
      const displayName = /批量/.test(triggerName) && !/^批量/.test(itemName) ? `批量${itemName}` : itemName;
      actions.push({
        id: `${pageIdFromPath(routePath)}.overlay_item.${slug(triggerName)}.${slug(itemName)}`,
        name: displayName,
        aliases: aliasesForOverlay(triggerName, itemName),
        type: "overlay_item",
        safety: classifySafety(displayName, "overlay_item"),
        purpose: `Choose ${itemName} from the ${triggerName} overlay on ${pageName}.`,
        function_source: "auto-generated from observed overlay item; item was not clicked",
        locator: { trigger_text: triggerName, item_text: itemName, trigger_selector: trigger.selector || "" }
      });
    }
  }
  const seen = new Set();
  const dedupedActions = actions.filter((action) => {
    const key = `${action.type}|${action.name}|${JSON.stringify(action.locator)}`;
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
    purpose: `Auto-generated overlay memory for ${pageName}.`,
    evidence: {
      source: "chrome_cdp_overlay_probe",
      captured_page_url: page.href || "",
      captured_page_title: page.title || "",
      captured_counts: capture.counts || {},
      coverage_result: dedupedActions.length > 0 ? "actions_promoted" : "probe_ran_no_public_overlay_actions",
      function_source: "observed overlay triggers and sanitized generic overlay items; overlay items not clicked"
    },
    observed_controls: { overlays },
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
    existing.observed_controls.overlays.push(...page.observed_controls.overlays);
    promoted += 1;
  } else {
    pagesById.set(page.id, page);
    promoted += 1;
  }
}

const pages = [...pagesById.values()].map((page) => {
  const seenActions = new Set();
  page.actions = page.actions.filter((action) => {
    const key = `${action.type}|${action.name}|${JSON.stringify(action.locator)}`;
    if (seenActions.has(key)) return false;
    seenActions.add(key);
    return true;
  });
  ensureUniqueActionIds(page.actions);
  page.evidence.coverage_result = page.actions.length > 0 ? "actions_promoted" : "probe_ran_no_public_overlay_actions";
  page.evidence.captured_counts = {
    ...(page.evidence.captured_counts || {}),
    overlays: page.observed_controls.overlays.length,
    overlay_actions: page.actions.length
  };
  return page;
}).sort((a, b) => `${a.module}.${a.id}`.localeCompare(`${b.module}.${b.id}`));

const payload = {
  version: new Date().toISOString().slice(0, 10),
  system: "xinjian_erp",
  source: "generated_from_sanitized_cdp_overlay_captures",
  generated_at: new Date().toISOString(),
  policy: {
    default_mode: "read_only_map_first",
    note: "Overlay map stores generic dropdown/menu/date/select item labels only. Private-looking option values are filtered at capture time.",
    write_action_rule: "Overlay write/export/batch/edit/save/delete actions are confirmation-required until manually verified."
  },
  pages
};

await fs.mkdir(path.dirname(out), { recursive: true });
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
