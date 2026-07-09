#!/usr/bin/env node
import fs from "node:fs/promises";

function argValue(name, fallback = "") {
  const index = process.argv.indexOf(name);
  if (index < 0 || index + 1 >= process.argv.length) return fallback;
  return process.argv[index + 1];
}

function hasFlag(name) {
  return process.argv.includes(name);
}

const port = Number(argValue("--port", "9342"));
const matchUrl = argValue("--match-url", "");
const actionFile = argValue("--action-file", "");
const allowWrite = hasFlag("--allow-write");
const allowExport = hasFlag("--allow-export");

if (!Number.isFinite(port) || port <= 0) throw new Error("Invalid --port.");
if (!actionFile) throw new Error("Missing --action-file.");

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

const action = JSON.parse((await fs.readFile(actionFile, "utf8")).replace(/^\uFEFF/, ""));
const safety = String(action.safety || "");
if (safety.startsWith("confirmation_required_export") && !allowExport && !allowWrite) {
  throw new Error("Action requires explicit --allow-export or --allow-write.");
}
if (safety.startsWith("confirmation_required") && !allowWrite && !safety.startsWith("confirmation_required_export")) {
  throw new Error("Action requires explicit --allow-write.");
}

const pages = await (await fetch(`http://127.0.0.1:${port}/json`, { signal: AbortSignal.timeout(8000) })).json();
const pageCandidates = pages
  .filter((item) => item.webSocketDebuggerUrl && item.type === "page");
const matchedPageCandidates = matchUrl ? pageCandidates.filter(isTargetPage) : pageCandidates;
const page = matchedPageCandidates
  .sort((a, b) => pageScore(b) - pageScore(a))[0];

if (!page?.webSocketDebuggerUrl) {
  throw new Error(matchUrl ? `No debuggable page matching ${matchUrl} was found on port ${port}.` : `No debuggable page was found on port ${port}.`);
}

const expression = `(() => {
  const action = ${JSON.stringify(action)};
  const clean = (value) => String(value || "")
    .replace(/[\\uE000-\\uF8FF]/g, " ")
    .replace(/\\s+/g, " ")
    .trim();
  const isVisible = (el) => {
    if (!el || el.nodeType !== 1) return false;
    const style = window.getComputedStyle(el);
    const rect = el.getBoundingClientRect();
    return style && style.display !== "none" && style.visibility !== "hidden" && rect.width > 0 && rect.height > 0;
  };
  const textOf = (el) => clean(el.getAttribute("aria-label") || el.getAttribute("title") || el.innerText || el.textContent || el.getAttribute("placeholder") || "");
  const clickElement = (el) => {
    if (!el || !isVisible(el)) return false;
    el.scrollIntoView({ block: "center", inline: "center" });
    el.click();
    return true;
  };
  const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
  const query = (selector, root = document) => {
    if (!selector) return null;
    try { return root.querySelector(selector); } catch { return null; }
  };
  const visibleCandidates = (selector, root = document) => Array.from(root.querySelectorAll(selector)).filter(isVisible);
  const interactiveTextSelector = "button,a,[role='button'],[role='tab'],[role='menuitem'],.el-button,.el-dropdown,.el-select,.el-input,.el-input__inner,.el-date-editor,.el-range-editor,.el-tabs__item,.el-menu-item,.el-submenu__title,.el-radio,.el-radio-button,.el-radio-button__inner,[tabindex]";
  const findByText = (text, root = document, selector = interactiveTextSelector) => {
    const target = clean(text);
    if (!target) return null;
    const candidates = visibleCandidates(selector, root);
    return candidates.find((el) => textOf(el) === target) ||
      candidates.find((el) => textOf(el).replace(/\\s+/g, "").includes(target.replace(/\\s+/g, ""))) ||
      null;
  };
  const visibleDialogs = () => visibleCandidates(".el-dialog,.el-drawer,.el-message-box,[role='dialog']");
  const findOverlayItem = (text) => findByText(text, document, ".el-select-dropdown__item,.el-dropdown-menu__item,.el-cascader-node,[role='option'],li,button,a,[role='button']");
  const queryLocatorSelector = () => query(action.locator?.selector);
  const clickDomText = () => clickElement(queryLocatorSelector()) || clickElement(findByText(action.locator?.dom_text || action.name));
  const focusElement = (el) => {
    if (!el || !isVisible(el)) return false;
    el.scrollIntoView({ block: "center", inline: "center" });
    el.click();
    if (typeof el.focus === "function") el.focus();
    return true;
  };
  const clickInputByPlaceholder = (placeholder) => {
    if (action.locator?.selector && focusElement(queryLocatorSelector())) return true;
    const target = clean(placeholder || action.locator?.dom_placeholder || action.name);
    if (!target) return false;
    const candidates = visibleCandidates("input[placeholder],textarea[placeholder],.el-input__inner[placeholder]");
    const normalizedTarget = target.replace(/\\s+/g, "");
    const input = candidates.find((el) => clean(el.getAttribute("placeholder")) === target) ||
      candidates.find((el) => clean(el.getAttribute("placeholder")).replace(/\\s+/g, "").includes(normalizedTarget));
    if (input) return focusElement(input);
    if (/^(开始日期|结束日期|日期)$/.test(target)) {
      const dateEditor = visibleCandidates(".el-date-editor,.el-range-editor")[0];
      if (dateEditor) return focusElement(dateEditor);
    }
    return clickElement(findByText(target, document, ".el-select,.el-cascader,.el-date-editor,.el-range-editor,.el-input"));
  };
  const normalizeChoice = (value) => clean(value)
    .toLowerCase()
    .replace(/最近/g, "近")
    .replace(/三十/g, "30")
    .replace(/七/g, "7")
    .replace(/[\\s\\-_/]/g, "");
  const textMatchesIntent = (candidate) => {
    const intent = normalizeChoice(action.runtime_intent || "");
    const value = normalizeChoice(candidate);
    return !!intent && !!value && (intent === value || intent.includes(value) || value.includes(intent));
  };
  const asTextList = (value) => Array.isArray(value) ? value.map(clean).filter(Boolean) : [];
  const clickPreferredText = (values, clicker) => {
    const list = asTextList(values);
    const preferred = list.find(textMatchesIntent);
    return preferred ? clicker(preferred) : false;
  };
  const clickTabTextFromList = () => {
    const list = asTextList(action.locator?.tab_texts);
    if (!list.length) return false;
    const preferred = list.find(textMatchesIntent) || list[0];
    return clickElement(findByText(preferred));
  };
  const clickTabText = () => {
    const target = clean(action.locator?.tab_text || action.locator?.dom_text || action.name);
    return clickElement(queryLocatorSelector()) ||
      clickElement(findByText(target, document, "[role='tab'],.el-tabs__item,.el-radio,.el-radio-button,.el-radio-button__inner,.el-menu-item,.el-submenu__title,a,button,[role='button']"));
  };
  const clickPlaceholderFromList = () => {
    const placeholders = asTextList(action.locator?.dom_placeholders);
    if (!placeholders.length) return false;
    if (clickPreferredText(placeholders, clickInputByPlaceholder)) return true;
    return placeholders.some((placeholder) => clickInputByPlaceholder(placeholder));
  };
  const findControlNearText = (text) => {
    const target = clean(text);
    if (!target) return null;
    const normalizedTarget = target.replace(/\\s+/g, "");
    const labels = visibleCandidates("label,.el-form-item__label,.filter-label,.search-label,span,div")
      .filter((el) => {
        const value = textOf(el);
        if (!value) return false;
        const normalizedValue = value.replace(/\\s+/g, "");
        return value === target || normalizedValue === normalizedTarget;
      });
    for (const label of labels) {
      const forId = label.getAttribute("for");
      if (forId) {
        const byFor = document.getElementById(forId);
        if (byFor && isVisible(byFor)) return byFor;
      }
      const containers = [
        label.closest(".el-form-item"),
        label.closest(".filter-item"),
        label.closest(".search-item"),
        label.closest(".el-col"),
        label.parentElement
      ].filter(Boolean);
      for (const container of containers) {
        const control = visibleCandidates("input,textarea,.el-input__inner,.el-select,.el-cascader,.el-date-editor,.el-range-editor,button,[role='button']", container)
          .find((el) => el !== label && !label.contains(el));
        if (control) return control;
      }
    }
    return null;
  };
  const clickFilterLabelOrText = () => clickInputByPlaceholder(action.locator?.dom_placeholder) ||
    clickPlaceholderFromList() ||
    focusElement(findControlNearText(action.name)) ||
    clickDomText();
  const clickDateFilter = () => clickTabTextFromList() || clickPlaceholderFromList() || clickFilterLabelOrText();
  const clickNavigation = () => {
    const href = action.locator?.href || "";
    if (href) {
      const url = new URL(href, location.href);
      if (url.hostname !== "erp.xinjianerp.com") throw new Error("Refusing cross-origin navigation.");
      window.setTimeout(() => location.assign(url.href), 200);
      return true;
    }
    return clickDomText();
  };
  const clickOverlay = async () => {
    const triggerSelector = action.locator?.trigger_selector || "";
    const triggerText = action.locator?.trigger_text || action.name;
    const trigger = query(triggerSelector) || findByText(triggerText) || findControlNearText(triggerText);
    if (!clickElement(trigger)) return false;
    await wait(350);
    if (action.type === "overlay_trigger") return true;
    const item = findOverlayItem(action.locator?.item_text || action.name);
    return clickElement(item);
  };
  const clickDialog = async () => {
    const triggerSelector = action.locator?.trigger_selector || "";
    const triggerText = action.locator?.trigger_text || "";
    const trigger = query(triggerSelector) || (triggerText ? findByText(triggerText) : null);
    if (action.type === "dialog_opener") return clickElement(trigger);
    if (trigger) {
      clickElement(trigger);
      await wait(450);
    }
    const buttonText = action.locator?.button_text || action.name;
    for (const dialog of visibleDialogs()) {
      if (/^(关闭|close)$/i.test(clean(buttonText))) {
        const closeButton = visibleCandidates(".el-dialog__headerbtn,.el-drawer__close-btn,.el-message-box__headerbtn,[aria-label='Close']", dialog)[0];
        if (closeButton) return clickElement(closeButton);
      }
      const button = findByText(buttonText, dialog, "button,a,[role='button'],.el-button,.el-dialog__headerbtn");
      if (button) return clickElement(button);
    }
    return clickElement(findByText(buttonText));
  };
  const rowIndexValue = () => {
    const value = Number(action.runtime_row_index || 0);
    return Number.isFinite(value) && value > 0 ? Math.floor(value) : 0;
  };
  const rowTextValue = () => clean(action.runtime_row_text || "");
  const hasExplicitRowContext = () => rowIndexValue() > 0 || !!rowTextValue();
  const visibleRows = (table) => {
    const rows = visibleCandidates("tbody tr,.el-table__body tr,.el-table__row", table)
      .filter((row) => clean(row.innerText || row.textContent || ""));
    return Array.from(new Set(rows));
  };
  const rowMatchesContext = (row, index) => {
    const requestedIndex = rowIndexValue();
    if (requestedIndex > 0) return index === requestedIndex - 1;
    const requestedText = rowTextValue().replace(/\\s+/g, "");
    if (!requestedText) return false;
    return clean(row.innerText || row.textContent || "").replace(/\\s+/g, "").includes(requestedText);
  };
  const targetTables = () => {
    const locator = action.locator || {};
    const tables = locator.table_selector ? [query(locator.table_selector)].filter(Boolean) : visibleCandidates(".el-table,table");
    return tables.length ? tables : visibleCandidates(".el-table,table");
  };
  const targetRowInTable = (table) => {
    const rows = visibleRows(table);
    return rows.find((row, index) => rowMatchesContext(row, index)) || null;
  };
  const columnIndexesForTable = (table, headerText) => {
    const wanted = clean(headerText).replace(/\\s+/g, "");
    if (!wanted) return [];
    const headers = visibleCandidates("thead th,.el-table__header th", table);
    const indexes = [];
    headers.forEach((header, index) => {
      const text = clean(header.innerText || header.textContent || "").replace(/\\s+/g, "");
      if (text === wanted || text.includes(wanted) || wanted.includes(text)) indexes.push(index);
    });
    return indexes;
  };
  const targetCellsInRow = (row, wantedColumnClass, table = null, headerText = "") => {
    const cells = visibleCandidates("td,.el-table__cell", row);
    if (wantedColumnClass) {
      const matched = cells.filter((cell) => String(cell.className || "").includes(wantedColumnClass));
      if (matched.length) return matched;
    }
    const indexes = table ? columnIndexesForTable(table, headerText) : [];
    if (indexes.length) {
      const byIndex = cells.filter((_, index) => indexes.includes(index));
      if (byIndex.length) return byIndex;
    }
    return cells;
  };
  const findControlInRow = (row, wantedText, wantedColumnClass = "", table = null, headerText = "") => {
    const cells = targetCellsInRow(row, wantedColumnClass, table, headerText);
    for (const cell of cells) {
      if (wantedText) {
        const exact = findByText(wantedText, cell, "button,a,[role='button'],.el-button,.el-link,[tabindex]");
        if (exact) return exact;
      }
    }
    for (const cell of cells) {
      const firstControl = visibleCandidates("button,a,[role='button'],.el-button,.el-link,[tabindex]", cell)[0];
      if (firstControl) return firstControl;
    }
    return null;
  };
  const currentPageInfo = () => ({
    href: location.href.replace(/([?&][^=]*(token|secret|password|passwd|pwd|cookie|session|auth|key|code)[^=]*=)[^&#]*/ig, "$1[redacted]"),
    title: document.title,
    path: location.pathname
  });
  const readTableColumn = () => {
    const locator = action.locator || {};
    const headerText = clean(locator.table_column || locator.column_header || action.name);
    const wantedColumnClass = clean(locator.column_class);
    const rowContextUsed = hasExplicitRowContext();
    const tables = targetTables();
    const tableResults = [];
    tables.forEach((table, tableIndex) => {
      const indexes = columnIndexesForTable(table, headerText);
      const rows = visibleRows(table);
      const values = [];
      let matchedRowCount = 0;
      rows.forEach((row, originalIndex) => {
        if (rowContextUsed && !rowMatchesContext(row, originalIndex)) return;
        matchedRowCount += 1;
        const cells = visibleCandidates("td,.el-table__cell", row);
        let selected = [];
        if (indexes.length) selected = cells.filter((_, index) => indexes.includes(index));
        if (!selected.length && wantedColumnClass) {
          selected = cells.filter((cell) => String(cell.className || "").includes(wantedColumnClass));
        }
        if (!selected.length) return;
        const value = clean(selected.map((cell) => cell.innerText || cell.textContent || "").join(" "));
        if (value) values.push({ row_index: originalIndex + 1, text: value });
      });
      if (indexes.length || values.length || (rowContextUsed && matchedRowCount > 0)) {
        tableResults.push({
          table_index: tableIndex + 1,
          header: headerText,
          column_indexes: indexes,
          row_context_used: rowContextUsed,
          requested_row_index: rowIndexValue() || null,
          requested_row_text: rowTextValue() ? "[provided]" : null,
          matched_rows: matchedRowCount,
          row_count: values.length,
          values: values.slice(0, 20),
          truncated: values.length > 20
        });
      }
    });
    const columnFound = tableResults.some((result) => result.column_indexes.length > 0 || result.row_count > 0);
    const rowContextMatched = !rowContextUsed || tableResults.some((result) => result.matched_rows > 0);
    const found = columnFound && rowContextMatched;
    const error = !columnFound
      ? "target_table_column_not_found"
      : (!rowContextMatched ? "target_row_context_not_found" : "");
    const nextAction = !columnFound
      ? "Confirm the current page contains the requested table column or learn the current page again."
      : (!rowContextMatched ? "Confirm the requested row is visible in the current table, then rerun with RowIndex or RowText." : "");
    return {
      ok: found,
      action_id: action.id || "",
      action_name: action.name || "",
      action_type: action.type || "",
      safety: action.safety || "",
      read_only: true,
      page: currentPageInfo(),
      table_column: headerText,
      row_context_used: rowContextUsed,
      requested_row_index: rowIndexValue() || null,
      requested_row_text: rowTextValue() ? "[provided]" : null,
      tables: tableResults,
      error,
      next_action: nextAction
    };
  };
  const clickRowAction = () => {
    const locator = action.locator || {};
    if ((locator.row_context_required || locator.requires_row_context) && !hasExplicitRowContext()) return false;
    const tables = locator.table_selector ? [query(locator.table_selector)].filter(Boolean) : visibleCandidates(".el-table,table");
    const wantedText = clean(locator.row_action_text || action.name);
    const wantedColumnClass = clean(locator.column_class);
    for (const table of tables) {
      const targetRow = hasExplicitRowContext() ? targetRowInTable(table) : null;
      if (targetRow) {
        const control = findControlInRow(targetRow, wantedText, wantedColumnClass, table, locator.column_header || locator.table_column);
        if (control) return clickElement(control);
        continue;
      }
      const cells = visibleCandidates("tbody td", table);
      for (const cell of cells) {
        if (wantedColumnClass && !String(cell.className || "").includes(wantedColumnClass)) continue;
        const control = findByText(wantedText, cell, "button,a,[role='button'],.el-button");
        if (control) return clickElement(control);
      }
    }
    return false;
  };
  const clickRowScopedColumnAction = () => {
    const locator = action.locator || {};
    if (!hasExplicitRowContext()) return false;
    const wantedText = clean(locator.row_action_text || action.name || locator.table_column);
    const wantedColumnClass = clean(locator.column_class);
    for (const table of targetTables()) {
      const row = targetRowInTable(table);
      if (!row) continue;
      const control = findControlInRow(row, wantedText, wantedColumnClass, table, locator.column_header || locator.table_column);
      if (control) return clickElement(control);
    }
    return false;
  };
  const clickRowScopedDialog = async () => {
    const locator = action.locator || {};
    if (!hasExplicitRowContext()) return false;
    const triggerText = clean(locator.row_action_text || locator.trigger_text || action.name);
    for (const table of targetTables()) {
      const row = targetRowInTable(table);
      if (!row) continue;
      const trigger = findControlInRow(row, triggerText, clean(locator.column_class), table, locator.column_header || locator.table_column);
      if (!trigger || !clickElement(trigger)) continue;
      await wait(450);
      if (action.type === "dialog_opener") return true;
      const buttonText = clean(locator.button_text || action.name);
      for (const dialog of visibleDialogs()) {
        if (/^(关闭|close)$/i.test(buttonText)) {
          const closeButton = visibleCandidates(".el-dialog__headerbtn,.el-drawer__close-btn,.el-message-box__headerbtn,[aria-label='Close']", dialog)[0];
          if (closeButton) return clickElement(closeButton);
        }
        const button = findByText(buttonText, dialog, "button,a,[role='button'],.el-button,.el-dialog__headerbtn");
        if (button) return clickElement(button);
      }
      return clickElement(findByText(buttonText));
    }
    return false;
  };
  const run = async () => {
    if (action.type === "table_column" && action.locator?.table_column) {
      return readTableColumn();
    }
    if (["row_action", "row_navigation", "row_operation"].includes(action.type) && !hasExplicitRowContext()) {
      return {
        ok: false,
        action_id: action.id || "",
        action_name: action.name || "",
        action_type: action.type || "",
        safety: action.safety || "",
        page: {
          href: location.href.replace(/([?&][^=]*(token|secret|password|passwd|pwd|cookie|session|auth|key|code)[^=]*=)[^&#]*/ig, "$1[redacted]"),
          title: document.title,
          path: location.pathname
        },
        error: "row_context_required",
        next_action: "Pass a 1-based RowIndex or a RowText visible in the target row before executing row-level actions."
      };
    }
    if (action.locator?.table_column && ["row_navigation", "row_operation"].includes(action.type)) {
      if (hasExplicitRowContext() && clickRowScopedColumnAction()) {
        await wait(250);
        return {
          ok: true,
          action_id: action.id || "",
          action_name: action.name || "",
          action_type: action.type || "",
          safety: action.safety || "",
          page: {
            href: location.href.replace(/([?&][^=]*(token|secret|password|passwd|pwd|cookie|session|auth|key|code)[^=]*=)[^&#]*/ig, "$1[redacted]"),
            title: document.title,
            path: location.pathname
          },
          row_context_used: true
        };
      }
      return {
        ok: false,
        action_id: action.id || "",
        action_name: action.name || "",
        action_type: action.type || "",
        safety: action.safety || "",
        page: {
          href: location.href.replace(/([?&][^=]*(token|secret|password|passwd|pwd|cookie|session|auth|key|code)[^=]*=)[^&#]*/ig, "$1[redacted]"),
          title: document.title,
          path: location.pathname
        },
        error: "row_context_required",
        next_action: "Provide a row identifier or capture exact row action button metadata before executing this row-level action."
      };
    }
    let clicked = false;
    if (action.type === "navigation" || action.type === "module_switch") clicked = clickNavigation();
    else if (action.type === "overlay_trigger" || action.type === "overlay_item") clicked = await clickOverlay();
    else if ((action.type === "dialog_opener" || action.type === "dialog_button") && (action.locator?.row_context_required || action.locator?.requires_row_context)) clicked = await clickRowScopedDialog();
    else if (action.type === "dialog_opener" || action.type === "dialog_button") clicked = await clickDialog();
    else if (["filter_input", "filter_dropdown", "form_input"].includes(action.type) && action.locator?.dom_placeholder) clicked = clickFilterLabelOrText();
    else if (action.type === "date_filter") clicked = clickDateFilter();
    else if (Array.isArray(action.locator?.tab_texts) && action.locator.tab_texts.length) clicked = clickTabTextFromList() || clickTabText() || clickDomText();
    else if (Array.isArray(action.locator?.dom_placeholders) && action.locator.dom_placeholders.length) clicked = clickPlaceholderFromList();
    else if (action.type === "row_action") clicked = clickRowAction();
    else if (["tab", "status_tab", "row_navigation", "button_menu"].includes(action.type)) clicked = clickTabText() || clickDomText();
    else clicked = clickDomText();
    if (!(action.locator?.href && (action.type === "navigation" || action.type === "module_switch"))) {
      await wait(250);
    }
    return {
      ok: clicked,
      action_id: action.id || "",
      action_name: action.name || "",
      action_type: action.type || "",
      safety: action.safety || "",
      page: {
        href: location.href.replace(/([?&][^=]*(token|secret|password|passwd|pwd|cookie|session|auth|key|code)[^=]*=)[^&#]*/ig, "$1[redacted]"),
        title: document.title,
        path: location.pathname
      },
      error: clicked ? "" : "target_element_not_found"
    };
  };
  return run();
})()`;

const ws = new WebSocket(page.webSocketDebuggerUrl);
let cdpId = 1;
const value = await new Promise((resolve, reject) => {
  const timer = setTimeout(() => {
    try { ws.close(); } catch {}
    reject(new Error("CDP action invocation timed out."));
  }, 45000);
  let evaluateId = null;
  const send = (method, params = {}) => {
    const id = cdpId++;
    ws.send(JSON.stringify({ id, method, params }));
    return id;
  };
  ws.onopen = () => {
    evaluateId = send("Runtime.evaluate", { expression, returnByValue: true, awaitPromise: true });
  };
  ws.onmessage = (event) => {
    const message = JSON.parse(event.data);
    if (message.id !== evaluateId) return;
    clearTimeout(timer);
    try { ws.close(); } catch {}
    if (message.error) {
      if (action?.locator?.href && String(message.error.message || "").includes("navigated")) {
        resolve({
          ok: true,
          action_id: action.id || "",
          action_name: action.name || "",
          action_type: action.type || "",
          safety: action.safety || "",
          page: {
            href: String(action.locator.href),
            title: "",
            path: parseUrl(action.locator.href)?.pathname || ""
          },
          warning: "target_navigated_before_cdp_result"
        });
        return;
      }
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

process.stdout.write(JSON.stringify({
  ok: !!value?.ok,
  port,
  matched_page: {
    url: page.url,
    title: page.title,
    score: pageScore(page)
  },
  ...value
}, null, 2));
