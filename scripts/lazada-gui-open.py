from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

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


def _norm(text: str | None) -> str:
    value = str(text or "").strip().lower()
    for suffix in (" 自营", "自营", "-自营", " 合作", "合作", "-合作"):
        if value.endswith(suffix):
            value = value[: -len(suffix)].strip()
            break
    return re.sub(r"[\s._\-]+", "", value)


def _load_config(path: str | None) -> dict:
    target = _resolve_repo_path(path) if path else ROOT / "ziniao.local.json"
    if not target.exists():
        target = ROOT / "ziniao.local.example.json"
    if not target.exists():
        return {}
    try:
        return json.loads(target.read_text(encoding="utf-8-sig"))
    except Exception:
        return {}


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


def _start_ziniao(config: dict) -> None:
    exe = _find_ziniao_exe(config)
    if not exe:
        return
    try:
        subprocess.Popen([str(exe)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(8)
    except Exception:
        return


def _import_pywinauto():
    try:
        from pywinauto import Desktop, keyboard
        return Desktop, keyboard
    except Exception as exc:
        _print_json(
            {
                "ok": False,
                "method": "ziniao_gui",
                "message": "Lazada 精准打开需要员工电脑安装 pywinauto：python -m pip install pywinauto",
                "error": str(exc),
            },
            3,
        )


def _find_ziniao_window(desktop):
    for _ in range(20):
        try:
            wins = desktop.windows()
        except Exception:
            wins = []
        for win in wins:
            try:
                title = (win.window_text() or "").strip()
                if "紫鸟" in title or "Ziniao" in title or "ZiNiao" in title:
                    return win
            except Exception:
                continue
        time.sleep(0.5)
    return None


def _top_window_text(win) -> str:
    parts: list[str] = []
    try:
        title = (win.window_text() or "").strip()
        if title:
            parts.append(title)
    except Exception:
        pass
    try:
        for ctrl in win.descendants():
            text = _control_text(ctrl)
            if text:
                parts.append(text)
            if len(parts) > 120:
                break
    except Exception:
        pass
    return "\n".join(parts)


def _looks_like_login_page(win) -> bool:
    text = _top_window_text(win)
    if not text:
        return False
    markers = ["验证码登录", "个人密码登录", "企业登录", "企业密码", "微信登录", "记住密码", "登录", "密码"]
    return sum(1 for marker in markers if marker in text) >= 2


def _wait_login_if_needed(desktop, win, timeout: int):
    if not _looks_like_login_page(win):
        return win, False, ""
    try:
        win.set_focus()
    except Exception:
        pass
    if timeout <= 0:
        return win, True, "紫鸟当前停留在登录页，请员工先在紫鸟窗口完成登录后重试。"
    deadline = time.time() + timeout
    while time.time() < deadline:
        time.sleep(2)
        refreshed = _find_ziniao_window(desktop) or win
        if not _looks_like_login_page(refreshed):
            return refreshed, True, ""
        try:
            refreshed.set_focus()
        except Exception:
            pass
        win = refreshed
    return win, True, "等待紫鸟登录超时，请员工完成登录后重新执行同一句命令。"


def _click_text(root, candidates: list[str], timeout: float = 8.0) -> bool:
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            for ctrl in root.descendants():
                try:
                    text = (ctrl.window_text() or "").strip()
                    if text in candidates:
                        ctrl.click_input()
                        return True
                except Exception:
                    continue
        except Exception:
            pass
        time.sleep(0.4)
    return False


def _control_text(ctrl) -> str:
    try:
        return (ctrl.window_text() or "").strip()
    except Exception:
        return ""


def _control_type(ctrl) -> str:
    try:
        return str(getattr(ctrl.element_info, "control_type", "") or "")
    except Exception:
        return ""


def _control_rect(ctrl):
    try:
        rect = ctrl.rectangle()
        if rect.width() <= 0 or rect.height() <= 0:
            return None
        return rect
    except Exception:
        return None


def _center_y(rect) -> float:
    return (rect.top + rect.bottom) / 2


def _matches_target_name(text: str, names: list[str]) -> bool:
    value = _norm(text)
    if not value:
        return False
    for name in names:
        target = _norm(name)
        if not target:
            continue
        if value == target:
            return True
        if len(target) >= 4 and target in value:
            return True
        if len(value) >= 4 and value in target:
            return True
    return False


def _find_first_edit(root):
    try:
        edits = [ctrl for ctrl in root.descendants(control_type="Edit")]
    except Exception:
        edits = []
    return edits[0] if edits else None


def _find_start_buttons(root):
    preferred = ["启动", "启 动", "切换", "切 换"]
    try:
        controls = root.descendants()
    except Exception:
        return []
    result = []
    seen = set()
    for label in preferred:
        for ctrl in controls:
            text = _control_text(ctrl)
            if text != label:
                continue
            handle = getattr(ctrl, "handle", id(ctrl))
            if handle in seen:
                continue
            seen.add(handle)
            result.append(ctrl)
    return result


def _find_target_labels(root, names: list[str]):
    try:
        controls = root.descendants()
    except Exception:
        return []
    result = []
    seen = set()
    for ctrl in controls:
        if _control_type(ctrl) == "Edit":
            continue
        text = _control_text(ctrl)
        if not _matches_target_name(text, names):
            continue
        rect = _control_rect(ctrl)
        if not rect:
            continue
        handle = getattr(ctrl, "handle", id(ctrl))
        if handle in seen:
            continue
        seen.add(handle)
        result.append(ctrl)
    return result


def _find_target_start_button(root, names: list[str]):
    labels = _find_target_labels(root, names)
    if not labels:
        return None, "搜索结果里未确认目标店铺名称", False

    buttons = _find_start_buttons(root)
    if not buttons:
        return None, "目标店铺结果附近未找到启动/切换按钮", False

    candidates = []
    for label in labels:
        label_rect = _control_rect(label)
        if not label_rect:
            continue
        for button in buttons:
            button_rect = _control_rect(button)
            if not button_rect:
                continue
            row_tolerance = max(16, min(36, label_rect.height() * 1.2))
            if abs(_center_y(label_rect) - _center_y(button_rect)) > row_tolerance:
                continue
            if button_rect.left < label_rect.left - 20:
                continue
            distance = abs(_center_y(label_rect) - _center_y(button_rect)) + max(0, button_rect.left - label_rect.right) / 1000
            candidates.append((distance, button))

    unique = {}
    for distance, button in candidates:
        handle = getattr(button, "handle", id(button))
        if handle not in unique or distance < unique[handle][0]:
            unique[handle] = (distance, button)
    ordered = sorted(unique.values(), key=lambda item: item[0])
    if len(ordered) == 1:
        return ordered[0][1], "", False
    if len(ordered) > 1:
        return None, "目标店铺行附近出现多个启动/切换按钮，已停止以避免开错店", True
    return None, "已看到目标店铺名称，但同一行附近没有可确认的启动/切换按钮", False


def _record_windows(desktop):
    result = set()
    try:
        for win in desktop.windows():
            try:
                result.add(int(win.handle))
            except Exception:
                pass
    except Exception:
        pass
    return result


def _wait_new_store_window(desktop, before_handles: set[int], timeout: float = 35.0):
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            wins = desktop.windows()
        except Exception:
            wins = []
        for win in wins:
            try:
                handle = int(win.handle)
                title = (win.window_text() or "").strip()
                class_name = getattr(win.element_info, "class_name", "")
                if handle not in before_handles and class_name == "Chrome_WidgetWin_1":
                    return win
                if handle not in before_handles and ("Seller Center" in title or "Lazada" in title):
                    return win
            except Exception:
                continue
        time.sleep(0.5)
    return None


def _window_title(win) -> str:
    try:
        return (win.window_text() or "").strip()
    except Exception:
        return ""


def _window_class_name(win) -> str:
    try:
        return str(getattr(win.element_info, "class_name", "") or "")
    except Exception:
        return ""


def _find_existing_store_window(desktop, names: list[str]):
    try:
        wins = desktop.windows()
    except Exception:
        wins = []
    for win in wins:
        title = _window_title(win)
        if not title:
            continue
        if "紫鸟" in title or "Ziniao" in title or "ZiNiao" in title:
            continue
        class_name = _window_class_name(win)
        if class_name != "Chrome_WidgetWin_1" and not any(marker in title for marker in ("Seller Center", "Lazada", "ASC")):
            continue
        if _matches_target_name(title, names):
            return win
    return None


def _open_visible_target_if_present(main, desktop, names: list[str]):
    button, error, fatal = _find_target_start_button(main, names)
    if fatal:
        return None, error, True
    if not button:
        return None, error, False
    before = _record_windows(desktop)
    try:
        button.click_input()
    except Exception as exc:
        return None, f"点击当前可见店铺行失败: {exc}", False
    store_win = _wait_new_store_window(desktop, before, timeout=18.0)
    if store_win:
        return store_win, "", False
    existing = _find_existing_store_window(desktop, names)
    if existing:
        return existing, "", False
    return None, "点击启动/切换后未确认到新的店铺窗口", False


def _navigate_window(win, keyboard, url: str) -> bool:
    if not url:
        return True
    try:
        win.set_focus()
        time.sleep(0.5)
        keyboard.send_keys("^l")
        time.sleep(0.2)
        keyboard.send_keys(url, with_spaces=True, pause=0.01)
        keyboard.send_keys("{ENTER}")
        return True
    except Exception:
        return False


def _search_and_open(main, desktop, keyboard, names: list[str], login_timeout: int):
    existing = _find_existing_store_window(desktop, names)
    if existing:
        return existing, ""
    main, was_login, login_error = _wait_login_if_needed(desktop, main, login_timeout)
    if login_error:
        return None, login_error
    try:
        main.set_focus()
    except Exception:
        pass
    _click_text(main, ["账号", "全部账号", "全 部 账 号"], timeout=4)
    time.sleep(1)
    main = _find_ziniao_window(desktop) or main
    main, was_login, login_error = _wait_login_if_needed(desktop, main, login_timeout)
    if login_error:
        return None, login_error

    store_win, error, fatal = _open_visible_target_if_present(main, desktop, names)
    if fatal:
        return None, error
    if store_win:
        return store_win, ""

    edit = _find_first_edit(main)
    if not edit:
        _click_text(main, ["搜索", "搜 索"], timeout=3)
        time.sleep(0.5)
        edit = _find_first_edit(main)
    if not edit:
        return None, "未找到紫鸟账号搜索框"

    last_error = ""
    for name in names:
        if not name:
            continue
        try:
            edit.click_input()
            keyboard.send_keys("^a")
            keyboard.send_keys(name, with_spaces=True, pause=0.01)
            keyboard.send_keys("{ENTER}")
            time.sleep(2)
            main = _find_ziniao_window(desktop) or main
            button, error, fatal = _find_target_start_button(main, [name])
            if fatal:
                return None, error
            if error:
                last_error = error
            if button:
                before = _record_windows(desktop)
                button.click_input()
                store_win = _wait_new_store_window(desktop, before)
                if store_win:
                    return store_win, ""
                existing = _find_existing_store_window(desktop, [name])
                if existing:
                    return existing, ""
                return None, "点击启动/切换后未确认到新的店铺窗口"
        except Exception as exc:
            return None, f"搜索/启动 Lazada 店铺失败: {exc}"
    return None, last_error or "紫鸟未匹配到 Lazada 店铺，请检查 ziniao_name / aliases"


def main() -> int:
    parser = argparse.ArgumentParser(description="Open Lazada store through local Ziniao GUI.")
    parser.add_argument("--shop-name", required=True)
    parser.add_argument("--view", default="dashboard")
    parser.add_argument("--url", default="")
    parser.add_argument("--ziniao-name", default="")
    parser.add_argument("--alias", action="append", default=[])
    parser.add_argument("--config", default="")
    parser.add_argument("--no-launch", action="store_true", help="Only use an already-open Ziniao window; do not launch Ziniao.")
    parser.add_argument("--login-timeout", type=int, default=180, help="Seconds to wait if Ziniao is on its own login page.")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    if os.name != "nt":
        _print_json(
            {
                "ok": False,
                "method": "ziniao_gui",
                "message": "Lazada GUI precision opening requires Windows because it uses Ziniao desktop and pywinauto.",
                "fallback": "Use a Windows machine with Ziniao installed, or use URL-only/manual opening.",
            },
            3,
        )

    Desktop, keyboard = _import_pywinauto()
    config = _load_config(args.config)
    desktop = Desktop(backend="uia")
    main_win = _find_ziniao_window(desktop)
    if not main_win and not args.no_launch:
        _start_ziniao(config)
        main_win = _find_ziniao_window(desktop)
    if not main_win:
        _print_json(
            {
                "ok": False,
                "method": "ziniao_gui",
                "message": "当前没有可复用的紫鸟窗口。" if args.no_launch else "未找到本机紫鸟窗口。请员工先打开并登录紫鸟。",
            },
            1,
        )

    names = []
    for item in [args.ziniao_name, args.shop_name] + list(args.alias or []):
        text = str(item or "").strip()
        if text and text not in names:
            names.append(text)

    store_win, error = _search_and_open(main_win, desktop, keyboard, names, args.login_timeout)
    if not store_win:
        _print_json(
            {
                "ok": False,
                "method": "ziniao_gui",
                "message": error or "Lazada 紫鸟 GUI 精准打开失败。",
                "searched": names,
            },
            1,
        )

    try:
        store_win.set_focus()
        _click_text(store_win, ["打开账号"], timeout=5)
        time.sleep(2)
    except Exception:
        pass
    navigated = _navigate_window(store_win, keyboard, args.url)
    _print_json(
        {
            "ok": True,
            "method": "ziniao_gui",
            "message": "已通过本机紫鸟 GUI 精准打开 Lazada 店铺环境；能否进入后台取决于该紫鸟店铺是否已登录平台账号。",
            "shop": args.shop_name,
            "view": args.view,
            "url": args.url,
            "navigated": navigated,
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
