from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import time
import uuid
from datetime import datetime
from pathlib import Path
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CONFIG = ROOT / "ziniao.local.json"
DEFAULT_AUTH_CONFIG = ROOT / "ziniao.auth.local.json"
DEFAULT_OUT = ROOT / "shops.json"
AUTH_FIELDS = ("company", "username", "password")
AUTH_ENV_VARS = {
    "company": "ZINIAO_WEBDRIVER_COMPANY",
    "username": "ZINIAO_WEBDRIVER_USERNAME",
    "password": "ZINIAO_WEBDRIVER_PASSWORD",
}

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass


def _print_json(payload: dict, code: int) -> None:
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    raise SystemExit(code)


def _resolve_repo_path(value: str) -> Path:
    path = Path(os.path.expandvars(str(value))).expanduser()
    if not path.is_absolute():
        path = ROOT / path
    return path


def _load_config(path: str | None) -> dict:
    target = _resolve_repo_path(path) if path else DEFAULT_CONFIG
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


def _candidate_auth_paths(config: dict) -> list[Path]:
    candidates: list[Path] = []
    for key in ("webdriver_auth_config", "auth_config_path", "webdriver_auth_path"):
        value = str(config.get(key) or "").strip()
        if value:
            candidates.append(_resolve_repo_path(value))
    candidates.append(DEFAULT_AUTH_CONFIG)

    result: list[Path] = []
    seen: set[str] = set()
    for candidate in candidates:
        key = str(candidate).lower()
        if key not in seen:
            seen.add(key)
            result.append(candidate)
    return result


def _auth_node(payload: dict) -> dict:
    for key in ("webdriver_auth", "auth", "ziniao_webdriver"):
        nested = payload.get(key)
        if isinstance(nested, dict):
            return nested
    return payload


def _load_webdriver_auth(config: dict) -> tuple[dict[str, str], dict]:
    values: dict[str, str] = {}
    sources: list[str] = []
    configured_paths: list[str] = []

    for path in _candidate_auth_paths(config):
        if not path.exists():
            continue
        configured_paths.append(str(path))
        try:
            payload = json.loads(path.read_text(encoding="utf-8-sig"))
        except Exception:
            continue
        if not isinstance(payload, dict):
            continue
        node = _auth_node(payload)
        file_fields = []
        for field in AUTH_FIELDS:
            value = str(node.get(field) or "").strip()
            if value:
                values[field] = value
                file_fields.append(field)
        if file_fields:
            sources.append("auth_config_file")
            break

    env_fields = []
    for field, env_name in AUTH_ENV_VARS.items():
        value = os.environ.get(env_name, "").strip()
        if value:
            values[field] = value
            env_fields.append(field)
    if env_fields:
        sources.append("environment")

    fields_present = {field: bool(values.get(field)) for field in AUTH_FIELDS}
    missing_fields = [field for field in AUTH_FIELDS if not fields_present[field]]
    info = {
        "complete": not missing_fields,
        "fields_present": fields_present,
        "missing_fields": missing_fields,
        "sources": sources,
        "configured_paths": configured_paths,
        "env_var_names": list(AUTH_ENV_VARS.values()),
    }
    return values, info


def _path_from_env_or_config(config: dict) -> list[Path]:
    result: list[Path] = []
    config_value = str(config.get("client_path") or "").strip()
    if config_value:
        result.append(_resolve_repo_path(config_value))
    for value in [
        os.environ.get("ZINIAO_CLIENT_PATH", "").strip(),
        os.environ.get("ZINIAO_PATH", "").strip(),
    ]:
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


def _is_ziniao_desktop_exe(candidate: Path) -> bool:
    if not candidate.exists() or not candidate.is_file():
        return False
    parent = candidate.parent
    if (parent / "resources.pak").exists() or (parent / "resources").is_dir():
        return True
    try:
        return candidate.stat().st_size > 10_000_000
    except OSError:
        return False


def _find_ziniao_exe(config: dict) -> Path | None:
    checked: set[str] = set()
    for candidate in _path_from_env_or_config(config) + _common_ziniao_paths():
        key = str(candidate).lower()
        if key in checked:
            continue
        checked.add(key)
        if _is_ziniao_desktop_exe(candidate):
            return candidate
    for command in ("ziniao.exe", "ZiNiao.exe"):
        found = shutil.which(command)
        if found and _is_ziniao_desktop_exe(Path(found)):
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


def _hidden_startup_kwargs() -> dict:
    kwargs: dict = {
        "stdin": subprocess.DEVNULL,
        "stdout": subprocess.DEVNULL,
        "stderr": subprocess.DEVNULL,
    }
    if os.name == "nt":
        flags = getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0)
        flags |= getattr(subprocess, "CREATE_NO_WINDOW", 0)
        kwargs["creationflags"] = flags
        startupinfo = subprocess.STARTUPINFO()
        startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startupinfo.wShowWindow = 0
        kwargs["startupinfo"] = startupinfo
    return kwargs


def _webdriver_user_data_dir(config: dict) -> Path | None:
    configured = str(
        config.get("webdriver_user_data_dir")
        or config.get("user_data_dir")
        or ""
    ).strip()
    if configured:
        return _resolve_repo_path(configured)
    appdata = os.environ.get("APPDATA", "").strip()
    if not appdata:
        return None
    return Path(appdata) / "ziniaobrowser" / "instances" / "userdata1"


def _webdriver_user_data_arg(config: dict) -> list[str]:
    user_data_dir = _webdriver_user_data_dir(config)
    if not user_data_dir:
        return []
    try:
        user_data_dir.mkdir(parents=True, exist_ok=True)
        (user_data_dir / "app-cache" / "tmp").mkdir(parents=True, exist_ok=True)
    except OSError:
        pass
    return [f"--user-data-dir={user_data_dir}"]


def _is_webdriver_user_data_in_use(config: dict) -> bool:
    if os.name != "nt":
        return False
    user_data_dir = _webdriver_user_data_dir(config)
    if not user_data_dir:
        return False
    env = os.environ.copy()
    env["ZINIAO_WEBDRIVER_USER_DATA_DIR"] = str(user_data_dir)
    script = r"""
$dir = $env:ZINIAO_WEBDRIVER_USER_DATA_DIR
if (!$dir) { "false"; exit }
try {
  $resolved = if (Test-Path -LiteralPath $dir) { (Resolve-Path -LiteralPath $dir).Path } else { $dir }
  $escaped = [regex]::Escape($resolved)
  $count = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object {
      $_.Name -eq "ziniao.exe" -and
      $_.CommandLine -match "--user-data-dir=.*$escaped" -and
      $_.CommandLine -notmatch "--run_type=web_driver" -and
      $_.CommandLine -notmatch "--type="
    }).Count
  if ($count -gt 0) { "true" } else { "false" }
} catch {
  "false"
}
"""
    try:
        output = subprocess.check_output(
            ["powershell", "-NoProfile", "-Command", script],
            env=env,
            text=True,
            timeout=4,
            stderr=subprocess.DEVNULL,
        )
    except Exception:
        return False
    return output.strip().lower().startswith("true")


def _is_tcp_port_open(port: int) -> bool:
    try:
        with socket.create_connection(("127.0.0.1", int(port)), timeout=0.5):
            return True
    except OSError:
        return False


def _start_ziniao(config: dict, port: int, allow_visible_client: bool = False) -> tuple[bool, str]:
    exe = _find_ziniao_exe(config)
    if not exe:
        return False, "not_found"
    started = False
    mode = "web_driver"
    if allow_visible_client:
        try:
            subprocess.Popen(
                [str(exe)],
                cwd=str(exe.parent),
                **_hidden_startup_kwargs(),
            )
            started = True
            mode = "visible_then_web_driver"
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
                *_webdriver_user_data_arg(config),
            ],
            cwd=str(exe.parent),
            **_hidden_startup_kwargs(),
        )
        started = True
        mode = f"{mode}_with_user_data"
    except Exception:
        pass
    return started, mode if started else "failed"


def _request_payload(action: str, config: dict) -> dict:
    payload = {"action": action, "requestId": str(uuid.uuid4())}
    auth_values, _ = _load_webdriver_auth(config)
    payload.update(auth_values)
    return payload


def _get_browser_list(port: int, config: dict) -> tuple[list[dict], dict | None]:
    result = _http_post(port, _request_payload("getBrowserList", config), timeout=30)
    if result and str(result.get("statusCode")) == "0":
        return list(result.get("browserList") or []), result
    return [], result


def _status_text(result: dict | None) -> str:
    if not isinstance(result, dict):
        return ""
    values = [
        result.get("err"),
        result.get("msg"),
        result.get("message"),
        result.get("error"),
    ]
    return " ".join(str(item or "") for item in values if item)


def _classify_empty_browser_list(
    result: dict | None,
    start_mode: str,
    auth_info: dict,
) -> dict:
    status_code = str(result.get("statusCode")) if isinstance(result, dict) else ""
    text = _status_text(result)
    if status_code == "-10003":
        if "参数不能为空" in text:
            if not auth_info.get("complete"):
                return {
                    "error": "ziniao_webdriver_auth_fields_missing",
                    "message": "紫鸟 WebDriver 返回“参数不能为空”，且本机未配置完整的 company/username/password 字段。这个版本的紫鸟 WebDriver 需要这些本机字段才能读取店铺列表。",
                    "next_step": "在本机创建 .\\ziniao.auth.local.json（已被 .gitignore 忽略）或设置 ZINIAO_WEBDRIVER_COMPANY / ZINIAO_WEBDRIVER_USERNAME / ZINIAO_WEBDRIVER_PASSWORD 环境变量；不要把字段值发到聊天或提交到 Git。配置后运行 .\\setup-ziniao.ps1 -ResetStaleWebDriver。",
                }
            return {
                "error": "ziniao_webdriver_invalid_session",
                "message": "紫鸟 WebDriver 返回“参数不能为空”。这通常不是等待登录能解决的问题，而是当前后台 WebDriver 会话/profile 不可用或接口参数不匹配。",
                "next_step": "先运行 .\\setup-ziniao.ps1 查看是否 WebDriver 用户目录被普通紫鸟占用；如果被占用，退出普通紫鸟/托盘后重试。只有接受前台窗口控制时才用 -AllowGuiMouse。",
            }
        return {
            "error": "ziniao_webdriver_login_state_error",
            "message": "紫鸟 WebDriver 返回登录态错误。后台模式没有登录入口，默认不会自动弹窗或抢鼠标。",
            "next_step": "请先手动打开并登录紫鸟，再运行 .\\setup-ziniao.ps1；只有接受前台窗口控制时才用 -AllowGuiMouse。",
        }
    if start_mode == "blocked_user_data_in_use":
        return {
            "error": "ziniao_webdriver_user_data_in_use",
            "message": "普通紫鸟正在占用 WebDriver 用户目录，后台 WebDriver 不能同时复用这个登录目录。",
            "next_step": "请先手动退出普通紫鸟窗口/托盘，再重试；这个流程不会抢鼠标。",
        }
    return {
        "error": "ziniao_browser_list_empty",
        "message": "没有从本机紫鸟读取到店铺浏览器列表。请先打开并登录紫鸟，再重试。",
        "next_step": "默认只尝试非鼠标 WebDriver 通道。请手动打开并登录紫鸟后重试；只有确认接受前台窗口控制时，才使用 setup-ziniao.ps1 -AllowGuiMouse。",
    }


def _wait_browser_list(
    config: dict,
    port: int,
    timeout: int = 25,
    login_timeout: int = 180,
    allow_visible_client: bool = False,
) -> tuple[list[dict], dict | None, bool, bool, str]:
    deadline = time.time() + timeout
    last = None
    started = False
    login_error_seen = False
    _, auth_info = _load_webdriver_auth(config)
    if _is_webdriver_user_data_in_use(config) and not _is_tcp_port_open(port):
        user_data_dir = _webdriver_user_data_dir(config)
        return (
            [],
            {
                "error": "ziniao_webdriver_user_data_in_use",
                "message": "普通紫鸟正在占用 WebDriver 用户目录，后台 WebDriver 不能同时复用这个登录目录。",
                "webdriver_user_data_dir": str(user_data_dir or ""),
            },
            False,
            False,
            "blocked_user_data_in_use",
        )
    while time.time() < deadline:
        browsers, result = _get_browser_list(port, config)
        last = result
        if browsers:
            return browsers, result, started, login_error_seen, "already_running"
        if result and str(result.get("statusCode")) == "-10003":
            login_error_seen = True
            if not allow_visible_client:
                return [], result, started, login_error_seen, "existing_webdriver_login_error_no_visible_login"
            break
        time.sleep(1.5)

    start_mode = "login_error_no_restart" if login_error_seen else "not_started"
    if not login_error_seen:
        if _is_webdriver_user_data_in_use(config):
            user_data_dir = _webdriver_user_data_dir(config)
            return (
                [],
                {
                    "error": "ziniao_webdriver_user_data_in_use",
                    "message": "普通紫鸟正在占用 WebDriver 用户目录，后台 WebDriver 不能同时复用这个登录目录。",
                    "webdriver_user_data_dir": str(user_data_dir or ""),
                },
                False,
                False,
                "blocked_user_data_in_use",
            )
        started, start_mode = _start_ziniao(
            config, port, allow_visible_client=allow_visible_client
        )
    wait_seconds = login_timeout if login_error_seen else timeout
    deadline = time.time() + wait_seconds
    while time.time() < deadline:
        browsers, result = _get_browser_list(port, config)
        last = result
        if browsers:
            return browsers, result, started, login_error_seen, start_mode
        if result and str(result.get("statusCode")) == "-10003":
            login_error_seen = True
        time.sleep(1.5)
    return [], last, started, login_error_seen, start_mode


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
    parser.add_argument("--allow-visible-client", action="store_true", help="Allow launching the normal visible Ziniao client before WebDriver mode.")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    config = _load_config(args.config)
    port = int(config.get("webdriver_port") or os.environ.get("ZINIAO_WEBDRIVER_PORT") or 16851)
    _, auth_info = _load_webdriver_auth(config)
    raw_status = None
    started_ziniao = False
    if args.input_json:
        browsers = _load_browsers_from_file(args.input_json)
        login_error_seen = False
        start_mode = "input_json"
    else:
        browsers, raw_status, started_ziniao, login_error_seen, start_mode = _wait_browser_list(
            config,
            port,
            timeout=args.timeout,
            login_timeout=args.login_timeout,
            allow_visible_client=args.allow_visible_client,
        )

    if not browsers:
        blocked = start_mode == "blocked_user_data_in_use"
        failure = _classify_empty_browser_list(raw_status, start_mode, auth_info)
        waited_seconds = 0 if (
            blocked or start_mode == "existing_webdriver_login_error_no_visible_login"
        ) else (args.login_timeout if login_error_seen else args.timeout)
        _print_json(
            {
                "ok": False,
                "error": raw_status.get("error") if blocked and isinstance(raw_status, dict) else failure["error"],
                "message": raw_status.get("message") if blocked and isinstance(raw_status, dict) else failure["message"],
                "webdriver_port": port,
                "started_ziniao": started_ziniao,
                "start_mode": start_mode,
                "login_error_seen": login_error_seen,
                "waited_login_seconds": waited_seconds,
                "webdriver_auth": auth_info,
                "next_step": "请先手动退出普通紫鸟窗口/托盘，再重试；这个流程不会抢鼠标。" if blocked else failure["next_step"],
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
            "start_mode": start_mode,
            "webdriver_auth": auth_info,
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
