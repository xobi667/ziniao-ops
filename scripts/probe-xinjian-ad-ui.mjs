#!/usr/bin/env node
import fs from "node:fs/promises";
import path from "node:path";

function argValue(name, fallback = "") {
  const index = process.argv.indexOf(name);
  if (index < 0 || index + 1 >= process.argv.length) return fallback;
  return process.argv[index + 1];
}

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

async function listPages(port) {
  const response = await fetch(`http://127.0.0.1:${port}/json`);
  return response.json();
}

function pageScore(item, matchUrl, targetUrl) {
  const url = String(item.url || "");
  const title = String(item.title || "");
  const currentUrl = parseUrl(url);
  const match = parseUrl(matchUrl);
  const target = parseUrl(targetUrl);
  let score = 0;
  if (item.type === "page") score += 10;
  if (url.includes("erp.xinjianerp.com")) score += 50;
  if (title.includes("心舰")) score += 40;
  if (url.includes("/ad/")) score += 30;
  for (const expected of [match, target].filter(Boolean)) {
    if (!currentUrl) continue;
    if (currentUrl.href === expected.href) score += 120;
    if (currentUrl.origin === expected.origin) score += 80;
    const currentPath = comparablePath(currentUrl.pathname);
    const expectedPath = comparablePath(expected.pathname);
    if (currentPath === expectedPath) score += 70;
    else if (currentPath.startsWith(expectedPath) || expectedPath.startsWith(currentPath)) score += 25;
  }
  if (url.startsWith("chrome-extension://")) score -= 1000;
  return score;
}

async function resolvePage({ port, websocketUrl, matchUrl, targetUrl }) {
  if (websocketUrl) {
    return {
      webSocketDebuggerUrl: websocketUrl,
      url: matchUrl || "",
      title: "",
    };
  }
  const pages = await listPages(port);
  const page = pages
    .filter((item) => item.webSocketDebuggerUrl && item.type === "page")
    .sort((a, b) => pageScore(b, matchUrl, targetUrl) - pageScore(a, matchUrl, targetUrl))[0];
  if (!page?.webSocketDebuggerUrl) {
    throw new Error(`No debuggable page was found on port ${port}.`);
  }
  return page;
}

function buildProbeExpression(targetUrl) {
  return `(() => {
  return (async () => {
    const targetUrl = ${JSON.stringify(targetUrl)};
    const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
    const normalize = (value) => String(value || "").replace(/\\s+/g, "").trim();
    const startedAt = new Date().toISOString();
    const actions = [];
    const before = {
      href: location.href,
      title: document.title
    };

    const isVisible = (el) => {
      if (!el || !el.isConnected) return false;
      const style = getComputedStyle(el);
      if (style.visibility === "hidden" || style.display === "none" || Number(style.opacity) === 0) return false;
      const rect = el.getBoundingClientRect();
      return rect.width > 0 && rect.height > 0 && rect.bottom > 0 && rect.right > 0 &&
        rect.top < window.innerHeight && rect.left < window.innerWidth;
    };

    const textOf = (el) => normalize(el?.innerText || el?.textContent || el?.getAttribute?.("aria-label") || el?.title || "");

    const dispatchClick = async (el, label) => {
      if (!el || !isVisible(el)) return false;
      el.scrollIntoView({ block: "center", inline: "center", behavior: "instant" });
      await sleep(120);
      const rect = el.getBoundingClientRect();
      const x = rect.left + Math.min(Math.max(rect.width / 2, 1), Math.max(rect.width - 1, 1));
      const y = rect.top + Math.min(Math.max(rect.height / 2, 1), Math.max(rect.height - 1, 1));
      const options = { bubbles: true, cancelable: true, view: window, clientX: x, clientY: y };
      for (const type of ["pointerdown", "mousedown", "pointerup", "mouseup", "click"]) {
        el.dispatchEvent(new MouseEvent(type, options));
      }
      if (typeof el.click === "function") el.click();
      actions.push({
        action: "click",
        label,
        text: textOf(el).slice(0, 80),
        selector: el.tagName.toLowerCase() + (el.id ? "#" + el.id : ""),
        href: location.href,
        clicked: true
      });
      await sleep(650);
      return true;
    };

    const waitForApp = async () => {
      for (let index = 0; index < 60; index += 1) {
        const bodyText = document.body?.innerText || "";
        if (document.querySelector("#app") || /首页|心舰|广告|登录|登陆|login/i.test(document.title + "\\n" + bodyText)) {
          return true;
        }
        await sleep(250);
      }
      return false;
    };

    const waitForAnyText = async (labels, timeoutMs) => {
      const deadline = Date.now() + timeoutMs;
      while (Date.now() < deadline) {
        const bodyText = document.body?.innerText || "";
        if (labels.some((label) => bodyText.includes(label))) return true;
        await sleep(300);
      }
      return false;
    };

    const closeBlockingPopups = async () => {
      let closed = 0;
      const closeSelectors = [
        ".el-dialog__close",
        ".el-message-box__close",
        ".el-drawer__close",
        ".el-notification__closeBtn",
        ".el-dialog .el-button",
        ".el-message-box .el-button",
        ".el-drawer .el-button"
      ];
      const allowedText = /^(关闭|取消|我知道了|知道了|跳过|稍后|Close)$/i;
      for (const el of Array.from(document.querySelectorAll(closeSelectors.join(","))).filter(isVisible)) {
        const text = textOf(el);
        const isCloseIcon = /close/i.test(el.className || "") || /close/i.test(el.getAttribute("aria-label") || "");
        if (!isCloseIcon && text && !allowedText.test(text)) continue;
        if (await dispatchClick(el, "close_blocking_popup")) closed += 1;
        if (closed >= 3) break;
      }
      if (closed === 0) {
        actions.push({ action: "close_blocking_popup", clicked: false, reason: "no_visible_safe_popup_close" });
      }
      return closed;
    };

    const findTextTarget = (labels, selectors) => {
      const normalizedLabels = labels.map(normalize).filter(Boolean);
      const elements = Array.from(document.querySelectorAll(selectors)).filter(isVisible);
      const exact = elements.find((el) => {
        const text = textOf(el);
        if (!text) return false;
        if (text.length > 80) return false;
        return normalizedLabels.some((label) => text === label);
      });
      if (exact) return exact;
      return elements.find((el) => {
        const text = textOf(el);
        if (!text) return false;
        if (text.length > 24) return false;
        return normalizedLabels.some((label) => text.includes(label));
      });
    };

    const clickText = async (labels, selectors, label) => {
      const el = findTextTarget(labels, selectors);
      if (!el) {
        actions.push({ action: "click", label, clicked: false, reason: "visible_text_not_found", expected_text: labels });
        return false;
      }
      return dispatchClick(el, label);
    };

    await waitForApp();
    await waitForAnyText(["店铺广告分析", "Tiktok", "TikTok", "近7天", "广告花费", "ROAS"], 12000);
    await closeBlockingPopups();

    const isAdRoute = () => /\\/ad\\/(shop-detail|group-detail|originality-detail)/.test(location.pathname);
    if (isAdRoute()) {
      actions.push({
        action: "route_check",
        label: "open_ads_module",
        clicked: false,
        verified: true,
        reason: "already_on_ad_analysis_route",
        href: location.href
      });
    } else {
      await clickText(
        ["ADS", "广告数据", "广告后台"],
        "button,.el-button,[role='button'],[role='tab'],a,li,.el-menu-item,.el-submenu__title,span",
        "open_ads_module"
      );
    }

    await waitForApp();
    await waitForAnyText(["店铺广告分析", "Tiktok", "TikTok", "近7天", "广告花费", "ROAS"], 12000);
    await closeBlockingPopups();

    await clickText(
      ["Tiktok", "TikTok", "tiktok"],
      ".el-tabs__item,[role='tab'],button,.el-button,[role='button'],li,a,span",
      "select_tiktok_platform"
    );

    await clickText(
      ["近7天", "最近7天", "最近七天"],
      ".el-tabs__item,[role='tab'],button,.el-button,[role='button'],li,a,span",
      "select_last_7_days"
    );

    await clickText(
      ["查询", "搜索"],
      "button,.el-button,[role='button']",
      "run_visible_query"
    );

    await sleep(1200);
    await closeBlockingPopups();

    const bodyText = document.body?.innerText || "";
    const visibleMarkers = ["店铺广告分析", "广告花费", "广告销售额", "广告订单量", "ROAS", "点击率", "转化率", "展现量"]
      .filter((text) => bodyText.includes(text));
    const metricMarkers = visibleMarkers.filter((text) => text !== "店铺广告分析");
    const clickedCount = actions.filter((item) => item.clicked && item.action === "click").length;
    const businessClickLabels = new Set(["select_tiktok_platform", "select_last_7_days", "run_visible_query"]);
    const businessClickedCount = actions.filter((item) => item.clicked && businessClickLabels.has(item.label)).length;
    const adRouteVisible = isAdRoute();
    const verified = businessClickedCount > 0 && adRouteVisible && metricMarkers.length >= 2;

    return {
      ok: true,
      required: true,
      verified,
      started_at: startedAt,
      target_url: targetUrl,
      before,
      after: {
        href: location.href,
        title: document.title,
        pathname: location.pathname,
        visible_markers: visibleMarkers,
        metric_markers: metricMarkers,
        has_password_input: !!document.querySelector("input[type='password']"),
        has_app_root: !!document.querySelector("#app")
      },
      clicked_count: clickedCount,
      business_clicked_count: businessClickedCount,
      actions,
      note: "UI probe navigates to the Xinjian ad analysis page, closes safe popups, and clicks only read-only/navigation controls before endpoint data is fetched."
    };
  })();
})()`;
}

async function evaluateProbe(webSocketUrl, targetUrl, waitMs) {
  const expression = buildProbeExpression(targetUrl);
  const ws = new WebSocket(webSocketUrl);
  let cdpId = 1;
  return new Promise((resolve, reject) => {
    let loadTimer = null;
    let evaluateSent = false;
    let evaluateId = null;
    const timer = setTimeout(() => {
      if (loadTimer) clearTimeout(loadTimer);
      try { ws.close(); } catch {}
      reject(new Error("UI probe timed out."));
    }, Math.max(waitMs + 60000, 65000));
    const send = (method, params = {}) => {
      const id = cdpId++;
      ws.send(JSON.stringify({ id, method, params }));
      return id;
    };
    const sendEvaluate = () => {
      if (evaluateSent) return;
      evaluateSent = true;
      if (loadTimer) clearTimeout(loadTimer);
      evaluateId = send("Runtime.evaluate", {
        expression,
        awaitPromise: true,
        returnByValue: true,
      });
    };
    ws.onopen = () => {
      send("Page.enable");
      send("Runtime.enable");
      send("Page.navigate", { url: targetUrl });
      loadTimer = setTimeout(sendEvaluate, Number.isFinite(waitMs) ? waitMs : 8000);
    };
    ws.onmessage = (event) => {
      const message = JSON.parse(event.data);
      if (message.method === "Page.loadEventFired") {
        setTimeout(sendEvaluate, 1000);
        return;
      }
      if (!evaluateSent || message.id !== evaluateId) return;
      clearTimeout(timer);
      if (loadTimer) clearTimeout(loadTimer);
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
      if (loadTimer) clearTimeout(loadTimer);
      try { ws.close(); } catch {}
      reject(new Error("CDP websocket error during UI probe."));
    };
  });
}

async function callCdp(webSocketUrl, method, params = {}, timeoutMs = 15000) {
  const ws = new WebSocket(webSocketUrl);
  let cdpId = 1;
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      try { ws.close(); } catch {}
      reject(new Error(`${method} timed out.`));
    }, timeoutMs);
    ws.onopen = () => {
      ws.send(JSON.stringify({ id: cdpId++, method, params }));
    };
    ws.onmessage = (event) => {
      const message = JSON.parse(event.data);
      if (!message.id) return;
      clearTimeout(timer);
      try { ws.close(); } catch {}
      if (message.error) reject(new Error(JSON.stringify(message.error)));
      else resolve(message.result);
    };
    ws.onerror = () => {
      clearTimeout(timer);
      try { ws.close(); } catch {}
      reject(new Error(`CDP websocket error during ${method}.`));
    };
  });
}

const port = Number(argValue("--port", "9339"));
const websocketUrl = argValue("--websocket-url", "");
const matchUrl = argValue("--match-url", "");
const targetUrl = argValue("--target-url", "https://erp.xinjianerp.com/ad/shop-detail");
const screenshotPath = argValue("--screenshot", "");
const navigateWaitMs = Number(argValue("--navigate-wait-ms", "8000"));

if (!Number.isFinite(port) || port <= 0) {
  throw new Error("Invalid --port.");
}

const page = await resolvePage({ port, websocketUrl, matchUrl, targetUrl });
let probe = await evaluateProbe(page.webSocketDebuggerUrl, targetUrl, navigateWaitMs);
if (!probe || typeof probe !== "object") {
  probe = { ok: false, required: true, verified: false, error: "probe_returned_no_structured_value" };
}

let screenshot = null;
if (screenshotPath) {
  try {
    const result = await callCdp(page.webSocketDebuggerUrl, "Page.captureScreenshot", {
      format: "png",
      fromSurface: true,
    });
    if (result?.data) {
      await fs.mkdir(path.dirname(screenshotPath), { recursive: true });
      await fs.writeFile(screenshotPath, Buffer.from(result.data, "base64"));
      screenshot = path.resolve(screenshotPath);
    }
  } catch (error) {
    screenshot = { error: String(error && (error.message || error)) };
  }
}

const screenshotVerified = typeof screenshot === "string" && screenshot.length > 0;
const verified = !!probe.verified && screenshotVerified;

const payload = {
  ok: !!probe.ok,
  required: true,
  verified,
  ui_verified: !!probe.verified,
  screenshot_verified: screenshotVerified,
  port,
  webSocketDebuggerUrl: page.webSocketDebuggerUrl,
  page_url: probe.after?.href || page.url || null,
  page_title: probe.after?.title || page.title || null,
  target_url: targetUrl,
  screenshot,
  probe,
};

process.stdout.write(JSON.stringify(payload, null, 2));
