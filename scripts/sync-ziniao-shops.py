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
from datetime import datetime
from pathlib import Path
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CONFIG = ROOT / "ziniao.local.json"
DEFAULT_OUT = ROOT / "shops.json"

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
    result = _http_post(port, _request_payload("getBrowserList"), timeout=30)
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


def _text_values(browser: dict) -> list[str]:
    keys = [
        "browserName",
        "name",
        "platformName",
        "remark",
        "groupName",
        "browserOauth",
        "browserId",
    ]
    values: list[str] = []
    for key in keys:
        value = str(browser.get(key) or "").strip()
        if value and value not in values:
            values.append(value)
    return values


def _norm(text: str | None) -> str:
    value = str(text or "").strip().lower()
    for suffix in (" 自营", "自营", "-自营", " 自營", "自營", " 合作", "合作", "-合作"):
        if value.endswith(suffix):
            value = value[: -len(suffix)].strip()
            break
    return re.sub(r"[\s._\-]+", "", value)


def _strip_owner_suffix(text: str) -> str:
    value = text.strip()
    for suffix in (" 自营", "自营", "-自营", " 自營", "自營", "-自營", " 合作", "合作", "-合作"):
        if value.endswith(suffix):
            return value[: -len(suffix)].strip(" -_")
    return value


def _detect_platform(texts: list[str]) -> str:
    joined = " ".join(texts).lower()
    compact = re.sub(r"[\s._\-]+", "", joined)
    if re.search(r"(^|[\s._\-])(sp|shopee)([\s._\-]|$)", joined) or "shopee" in compact:
        return "shopee"
    if re.search(r"(^|[\s._\-])(tt|tiktok|tokopedia)([\s._\-]|$)", joined) or "tiktok" in compact or "tokopedia" in compact:
        return "tiktok"
    if re.search(r"(^|[\s._\-])(laz|lazada|lzd)([\s._\-]|$)", joined) or "lazada" in compact:
        return "lazada"
    return "unknown"


def _detect_country(texts: list[str]) -> str:
    known = {
        "br",
        "cl",
        "co",
        "id",
        "my",
        "mx",
        "ph",
        "sg",
        "th",
        "tw",
        "vn",
    }
    for text in texts:
        for match in re.finditer(r"(?:^|[\s._\-])([a-zA-Z]{2})(?:[\s._\-]|$)", text):
            code = match.group(1).lower()
            if code in known:
                return code
    return ""


def _pick_name(browser: dict) -> str:
    for key in ("browserName", "name", "remark", "platformName"):
        value = str(browser.get(key) or "").strip()
        if value:
            return value
    for key in ("browserOauth", "browserId"):
        value = str(browser.get(key) or "").strip()
        if value:
            return value
    return ""


def _aliases_for(name: str, texts: list[str]) -> list[str]:
    aliases: list[str] = []
    candidates = [name, _strip_owner_suffix(name)] + texts
    for item in candidates:
        value = str(item or "").strip()
        if not value:
            continue
        for candidate in (value, _strip_owner_suffix(value), value.replace("_", "-"), value.replace("-", " ")):
            candidate = candidate.strip()
            if candidate and candidate != name and candidate not in aliases:
                aliases.append(candidate)
    return aliases


def _open_method(platform: str) -> str:
    if platform in {"shopee", "tiktok"}:
        return "ziniao_webdriver"
    if platform == "lazada":
        return "ziniao_gui"
    return "ziniao_webdriver"


COMMON_VIEW_KEYS = (
    "home",
    "overview",
    "orders",
    "products",
    "inventory",
    "ads",
    "marketing",
    "business",
    "traffic",
    "finance",
    "chat",
    "reviews",
    "vouchers",
    "campaigns",
    "livestream",
    "affiliate",
    "logistics",
    "returns",
)


def _unique_keys(*groups: tuple[str, ...]) -> tuple[str, ...]:
    result: list[str] = []
    for group in groups:
        for key in group:
            if key not in result:
                result.append(key)
    return tuple(result)


def _views_for(platform: str) -> dict:
    if platform == "shopee":
        keys = _unique_keys(COMMON_VIEW_KEYS)
    elif platform == "tiktok":
        keys = _unique_keys(COMMON_VIEW_KEYS, ("compass",))
    elif platform == "lazada":
        keys = _unique_keys(COMMON_VIEW_KEYS, ("dashboard", "discovery", "smax"))
    else:
        keys = _unique_keys(COMMON_VIEW_KEYS, ("compass", "dashboard", "discovery", "smax"))
    return {key: {"url": "", "visual_hint": True} for key in keys}


def _browser_to_shop(browser: dict) -> dict | None:
    name = _pick_name(browser)
    if not name:
        return None
    texts = _text_values(browser)
    platform = _detect_platform(texts)
    country = _detect_country(texts)
    return {
        "name": name,
        "platform": platform,
        "country": country,
        "aliases": _aliases_for(name, texts),
        "open_method": _open_method(platform),
        "ziniao_name": name,
        "browser_oauth": str(browser.get("browserOauth") or "").strip(),
        "browser_id": str(browser.get("browserId") or "").strip(),
        "views": _views_for(platform),
        "detected_from": "ziniao_webdriver",
    }


def _dedupe_shops(shops: list[dict]) -> list[dict]:
    result: list[dict] = []
    seen: set[str] = set()
    for shop in shops:
        key = str(shop.get("browser_oauth") or shop.get("browser_id") or _norm(shop.get("name"))).lower()
        if not key or key in seen:
            continue
        seen.add(key)
        result.append(shop)
    return result


def _load_browsers_from_file(path: str) -> list[dict]:
    payload = json.loads(Path(path).read_text(encoding="utf-8-sig"))
    if isinstance(payload, list):
        return payload
    if isinstance(payload, dict):
        return list(payload.get("browserList") or payload.get("browsers") or [])
    return []


def main() -> int:
    parser = argparse.ArgumentParser(description="Sync local shops from the current computer's Ziniao browser list.")
    parser.add_argument("--out", default=str(DEFAULT_OUT))
    parser.add_argument("--config", default="")
    parser.add_argument("--timeout", type=int, default=25)
    parser.add_argument("--login-timeout", type=int, default=180)
    parser.add_argument("--input-json", default="", help="Testing helper: read a saved Ziniao browserList JSON instead of connecting to Ziniao.")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    config = _load_config(args.config)
    port = int(config.get("webdriver_port") or os.environ.get("ZINIAO_WEBDRIVER_PORT") or 16851)
    raw_status = None
    started_ziniao = False
    if args.input_json:
        browsers = _load_browsers_from_file(args.input_json)
        login_error_seen = False
    else:
        browsers, raw_status, started_ziniao, login_error_seen = _wait_browser_list(
            config, port, timeout=args.timeout, login_timeout=args.login_timeout
        )

    if not browsers:
        _print_json(
            {
                "ok": False,
                "error": "ziniao_browser_list_empty",
                "message": "没有从本机紫鸟读取到店铺浏览器列表。请先打开并登录紫鸟，再重试。",
                "webdriver_port": port,
                "started_ziniao": started_ziniao,
                "login_error_seen": login_error_seen,
                "waited_login_seconds": args.login_timeout if login_error_seen else args.timeout,
                "next_step": "如果紫鸟窗口已被自动打开，请在本机完成登录；脚本等待超时后才会失败。",
                "raw_status": raw_status,
            },
            1,
        )

    shops = _dedupe_shops([shop for browser in browsers if (shop := _browser_to_shop(browser))])
    if not shops:
        _print_json(
            {
                "ok": False,
                "error": "ziniao_no_usable_shops",
                "message": "紫鸟返回了浏览器列表，但没有可转换成店铺的记录。",
                "webdriver_port": port,
                "raw_count": len(browsers),
            },
            1,
        )

    payload = {
        "version": 1,
        "updated_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "source": "ziniao_detected",
        "webdriver_port": port,
        "shops": shops,
    }

    out_path = Path(args.out)
    if not args.dry_run:
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    _print_json(
        {
            "ok": True,
            "message": f"已从本机紫鸟检测到 {len(shops)} 个店铺。",
            "out": str(out_path),
            "dry_run": args.dry_run,
            "source": "ziniao_detected",
            "webdriver_port": port,
            "started_ziniao": started_ziniao,
            "shops_count": len(shops),
            "platform_counts": {
                platform: len([shop for shop in shops if shop.get("platform") == platform])
                for platform in sorted({str(shop.get("platform") or "") for shop in shops})
            },
            "shops": [
                {
                    "platform": shop.get("platform"),
                    "name": shop.get("name"),
                    "country": shop.get("country"),
                }
                for shop in shops
            ],
        },
        0,
    )


if __name__ == "__main__":
    raise SystemExit(main())
