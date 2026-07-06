from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time
import uuid
from pathlib import Path
from urllib.parse import quote
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CONFIG = ROOT / "ziniao.local.json"

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass


def _print_json(payload: dict, code: int) -> None:
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    raise SystemExit(code)


def _load_config(path: str | None) -> dict:
    target = Path(path) if path else DEFAULT_CONFIG
    if not target.exists():
        example = ROOT / "ziniao.local.example.json"
        if example.exists():
            target = example
        else:
            return {}
    try:
        return json.loads(target.read_text(encoding="utf-8-sig"))
    except Exception:
        return {}


def _path_from_env_or_config(config: dict) -> list[Path]:
    values = [
        str(config.get("client_path") or "").strip(),
        os.environ.get("ZINIAO_CLIENT_PATH", "").strip(),
        os.environ.get("ZINIAO_PATH", "").strip(),
    ]
    result: list[Path] = []
    for value in values:
        if value:
            result.append(Path(os.path.expandvars(value)).expanduser())
    return result


def _common_ziniao_paths() -> list[Path]:
    names = [
        r"ZiNiao\ziniao.exe",
        r"ZiNiao\ZiNiao.exe",
        r"Ziniao\ziniao.exe",
        r"Ziniao\Ziniao.exe",
        r"紫鸟\ziniao.exe",
        r"紫鸟\ZiNiao.exe",
    ]
    roots = [
        os.environ.get("ProgramFiles", ""),
        os.environ.get("ProgramFiles(x86)", ""),
        os.environ.get("LOCALAPPDATA", ""),
        os.environ.get("APPDATA", ""),
    ]
    result: list[Path] = []
    for root in roots:
        if not root:
            continue
        for name in names:
            result.append(Path(root) / name)
    for drive in ("C", "D", "E", "F"):
        for name in names:
            result.append(Path(f"{drive}:\\") / name)
    return result


def _find_ziniao_exe(config: dict) -> Path | None:
    checked: set[str] = set()
    for candidate in _path_from_env_or_config(config) + _common_ziniao_paths():
        key = str(candidate).lower()
        if key in checked:
            continue
        checked.add(key)
        if candidate.exists() and candidate.is_file():
            return candidate
    for command in ("ziniao.exe", "ZiNiao.exe"):
        found = shutil.which(command)
        if found:
            return Path(found)
    return None


def _http_post(port: int, payload: dict, timeout: int = 30) -> dict | None:
    url = f"http://127.0.0.1:{port}"
    data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    req = Request(url, data=data, headers={"Content-Type": "application/json"})
    try:
        with urlopen(req, timeout=timeout) as resp:
            text = resp.read().decode("utf-8", errors="replace")
        return json.loads(text)
    except Exception:
        return None


def _start_ziniao(config: dict, port: int) -> bool:
    exe = _find_ziniao_exe(config)
    if not exe:
        return False
    started = False
    try:
        subprocess.Popen(
            [str(exe)],
            cwd=str(exe.parent),
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        started = True
        time.sleep(3)
    except Exception:
        pass
    try:
        subprocess.Popen(
            [
                str(exe),
                "--run_type=web_driver",
                "--ipc_type=http",
                f"--port={port}",
            ],
            cwd=str(exe.parent),
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        started = True
    except Exception:
        pass
    return started


def _request_payload(action: str) -> dict:
    return {"action": action, "requestId": str(uuid.uuid4())}


def _get_browser_list(port: int) -> tuple[list[dict], dict | None]:
    payload = _request_payload("getBrowserList")
    result = _http_post(port, payload, timeout=30)
    if result and str(result.get("statusCode")) == "0":
        return list(result.get("browserList") or []), result
    return [], result


def _wait_browser_list(
    config: dict, port: int, timeout: int = 25, login_timeout: int = 180
) -> tuple[list[dict], dict | None, bool, bool]:
    deadline = time.time() + timeout
    last = None
    started = False
    login_error_seen = False
    while time.time() < deadline:
        browsers, result = _get_browser_list(port)
        last = result
        if browsers:
            return browsers, result, started, login_error_seen
        if result and str(result.get("statusCode")) == "-10003":
            login_error_seen = True
            break
        time.sleep(1.5)
    started = _start_ziniao(config, port)
    wait_seconds = login_timeout if login_error_seen else timeout
    deadline = time.time() + wait_seconds
    while time.time() < deadline:
        browsers, result = _get_browser_list(port)
        last = result
        if browsers:
            return browsers, result, started, login_error_seen
        if result and str(result.get("statusCode")) == "-10003":
            login_error_seen = True
        time.sleep(1.5)
    return [], last, started, login_error_seen


def _norm(text: str | None) -> str:
    value = str(text or "").strip().lower()
    for suffix in (" 自营", "自营", "-自营", " 合作", "合作", "-合作"):
        if value.endswith(suffix):
            value = value[: -len(suffix)].strip()
            break
    return re.sub(r"[\s._\-]+", "", value)


def _browser_texts(browser: dict) -> list[str]:
    keys = [
        "browserName",
        "name",
        "platformName",
        "remark",
        "browserOauth",
        "browserId",
    ]
    values: list[str] = []
    for key in keys:
        value = str(browser.get(key) or "").strip()
        if value and value not in values:
            values.append(value)
    return values


def _score(query_values: list[str], browser: dict) -> int:
    best = 0
    browser_values = _browser_texts(browser)
    browser_norms = [_norm(item) for item in browser_values if _norm(item)]
    for query in query_values:
        q = _norm(query)
        if not q:
            continue
        for b in browser_norms:
            if q == b:
                best = max(best, 110)
            elif len(q) >= 4 and q in b:
                best = max(best, min(99, 84 + min(15, len(q))))
            elif len(b) >= 4 and b in q:
                best = max(best, 82)
    return best


def _find_browser(
    args: argparse.Namespace, browsers: list[dict]
) -> tuple[dict | None, list[dict], str, str]:
    if args.browser_oauth or args.browser_id:
        for browser in browsers:
            if args.browser_oauth and str(browser.get("browserOauth") or "") == str(args.browser_oauth):
                return browser, [], "", ""
            if args.browser_id and str(browser.get("browserId") or "") == str(args.browser_id):
                return browser, [], "", ""
        return (
            None,
            [],
            "browser_id_not_found",
            "已指定 browser_oauth/browser_id，但紫鸟列表中未找到对应记录；已停止，避免按名称模糊匹配开错店。",
        )
    query_values = [args.ziniao_name, args.shop_name] + list(args.alias or [])
    scored: list[dict] = []
    for browser in browsers:
        score = _score(query_values, browser)
        if score >= 55:
            scored.append({"score": score, "browser": browser, "texts": _browser_texts(browser)})
    scored.sort(key=lambda item: (-item["score"], str(item["texts"])))
    if not scored:
        return None, [], "browser_match_failed", "紫鸟店铺匹配失败，请检查 ziniao_name / aliases。"
    if len(scored) > 1 and scored[0]["score"] - scored[1]["score"] < 12:
        return None, scored[:8], "multiple_browser_matches", "紫鸟店铺匹配到多个候选，请补充 ziniao_name / browser_oauth / browser_id。"
    return scored[0]["browser"], scored[:8], "", ""


def _start_browser(port: int, browser: dict, timeout: int = 90) -> dict | None:
    store_id = str(browser.get("browserOauth") or browser.get("browserId") or "").strip()
    payload = _request_payload("startBrowser")
    payload.update(
        {
            "isWaitPluginUpdate": 0,
            "isHeadless": 0,
            "cookieTypeLoad": 0,
            "cookieTypeSave": 0,
            "runMode": "1",
            "isLoadUserPlugin": False,
            "pluginIdType": 1,
            "privacyMode": 0,
        }
    )
    if store_id.isdigit():
        payload["browserId"] = store_id
    else:
        payload["browserOauth"] = store_id
    result = _http_post(port, payload, timeout=timeout)
    if result and str(result.get("statusCode")) == "0":
        return result
    return result


def _open_debug_url(debug_port: str | int | None, url: str | None) -> bool:
    if not debug_port or not url:
        return False
    encoded = quote(url, safe="")
    endpoints = [
        f"http://127.0.0.1:{debug_port}/json/new?{encoded}",
        f"http://127.0.0.1:{debug_port}/json/new?url={encoded}",
    ]
    for endpoint in endpoints:
        for method in ("PUT", "GET"):
            try:
                req = Request(endpoint, method=method)
                with urlopen(req, timeout=8) as resp:
                    resp.read()
                return True
            except Exception:
                continue
    return False


def main() -> int:
    parser = argparse.ArgumentParser(description="Open Shopee/TikTok store through local Ziniao webdriver API.")
    parser.add_argument("--shop-name", required=True)
    parser.add_argument("--platform", required=True)
    parser.add_argument("--view", default="home")
    parser.add_argument("--url", default="")
    parser.add_argument("--ziniao-name", default="")
    parser.add_argument("--browser-oauth", default="")
    parser.add_argument("--browser-id", default="")
    parser.add_argument("--alias", action="append", default=[])
    parser.add_argument("--config", default="")
    parser.add_argument("--login-timeout", type=int, default=180)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    config = _load_config(args.config)
    port = int(config.get("webdriver_port") or os.environ.get("ZINIAO_WEBDRIVER_PORT") or 16851)
    browsers, raw, started_ziniao, login_error_seen = _wait_browser_list(
        config, port, login_timeout=args.login_timeout
    )
    if not browsers:
        _print_json(
            {
                "ok": False,
                "method": "ziniao_webdriver",
                "message": "紫鸟 webdriver/API 未就绪，或本机紫鸟未登录/未授权。请先在员工电脑打开并登录紫鸟。",
                "raw_status": raw,
                "started_ziniao": started_ziniao,
                "login_error_seen": login_error_seen,
                "waited_login_seconds": args.login_timeout if login_error_seen else 25,
                "next_step": "如果紫鸟窗口已被自动打开，请在本机完成登录；脚本等待超时后才会失败。",
                "login_policy": {
                    "requires_local_ziniao": True,
                    "requires_local_store_login": True,
                    "auto_login": False,
                    "bypass_login": False,
                },
            },
            1,
        )

    browser, candidates, match_error, match_message = _find_browser(args, browsers)
    if not browser:
        payload = {
            "ok": False,
            "method": "ziniao_webdriver",
            "error": match_error or "browser_match_failed",
            "message": match_message or "紫鸟店铺匹配失败或匹配到多个候选，请补充 ziniao_name / browser_oauth / browser_id。",
            "searched": {
                "shop_name": args.shop_name,
                "ziniao_name": args.ziniao_name,
                "browser_oauth": args.browser_oauth,
                "browser_id": args.browser_id,
            },
            "candidates": [
                {"score": item.get("score"), "texts": item.get("texts")}
                for item in candidates
            ],
        }
        _print_json(payload, 2)

    opened = _start_browser(port, browser)
    if not opened or str(opened.get("statusCode")) != "0":
        _print_json(
            {
                "ok": False,
                "method": "ziniao_webdriver",
                "message": "紫鸟已匹配店铺，但启动店铺窗口失败。",
                "raw_status": opened,
            },
            1,
        )

    navigated = _open_debug_url(opened.get("debuggingPort"), args.url)
    _print_json(
        {
            "ok": True,
            "method": "ziniao_webdriver",
            "message": "已通过本机紫鸟 webdriver/API 精准打开店铺环境；能否进入后台取决于该紫鸟店铺是否已登录平台账号。",
            "shop": args.shop_name,
            "platform": args.platform,
            "view": args.view,
            "url": args.url,
            "navigated": navigated,
            "launcher_page": opened.get("launcherPage"),
            "debugging_port": opened.get("debuggingPort"),
            "login_policy": {
                "requires_local_ziniao": True,
                "requires_local_store_login": True,
                "auto_login": False,
                "bypass_login": False,
                "credential_storage": False,
                "if_login_page": "如果页面跳到登录页，员工必须在本机手动登录对应店铺后重试。",
            },
        },
        0,
    )


if __name__ == "__main__":
    raise SystemExit(main())
