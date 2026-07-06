from __future__ import annotations

import argparse
import ctypes
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path
from ctypes import wintypes


ROOT = Path(__file__).resolve().parents[1]

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass


def _print_json(payload: dict, code: int) -> None:
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    raise SystemExit(code)


def _norm(text: str | None) -> str:
    value = str(text or "").strip().lower()
    for suffix in (" 自营", "自营", "-自营", " 自營", "自營", "-自營", " 合作", "合作", "-合作"):
        if value.endswith(suffix):
            value = value[: -len(suffix)].strip()
            break
    return re.sub(r"[\s._\-]+", "", value)


def _load_config(path: str | None) -> dict:
    target = Path(path) if path else ROOT / "ziniao.local.json"
    if not target.exists():
        target = ROOT / "ziniao.local.example.json"
    if not target.exists():
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


def _start_ziniao(config: dict) -> bool:
    exe = _find_ziniao_exe(config)
    if not exe:
        return False
    try:
        subprocess.Popen([str(exe)], cwd=str(exe.parent), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True
    except Exception:
        return False


def _restart_ziniao_visible(config: dict) -> bool:
    try:
        subprocess.run(
            ["taskkill", "/IM", "ziniao.exe", "/F"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=10,
        )
        time.sleep(3)
    except Exception:
        pass
    return _start_ziniao(config)


def _import_pywinauto():
    try:
        from pywinauto import Desktop, keyboard
        return Desktop, keyboard
    except Exception as exc:
        _print_json(
            {
                "ok": False,
                "method": "ziniao_gui",
                "error": "pywinauto_missing",
                "message": "紫鸟 GUI 兜底需要安装 pywinauto：python -m pip install pywinauto",
                "raw_error": str(exc),
            },
            3,
        )


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


def _enum_visible_windows():
    user32 = ctypes.windll.user32
    proc_type = ctypes.WINFUNCTYPE(ctypes.c_bool, wintypes.HWND, wintypes.LPARAM)
    result = []

    @proc_type
    def callback(hwnd, _lparam):
        if user32.IsWindowVisible(hwnd):
            length = user32.GetWindowTextLengthW(hwnd)
            title = ctypes.create_unicode_buffer(length + 1)
            user32.GetWindowTextW(hwnd, title, length + 1)
            class_name = ctypes.create_unicode_buffer(256)
            user32.GetClassNameW(hwnd, class_name, 256)
            pid = wintypes.DWORD()
            user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
            result.append(
                {
                    "handle": int(hwnd),
                    "pid": int(pid.value),
                    "class_name": class_name.value,
                    "title": title.value,
                }
            )
        return True

    user32.EnumWindows(callback, 0)
    return result


def _find_ziniao_window(desktop, timeout: float = 35.0):
    deadline = time.time() + timeout
    while time.time() < deadline:
        for item in _enum_visible_windows():
            title = item.get("title") or ""
            class_name = item.get("class_name") or ""
            if "紫鸟" in title or "Ziniao" in title or "ZiNiao" in title:
                try:
                    from pywinauto import Application

                    app = Application(backend="uia").connect(handle=item["handle"], timeout=5)
                    return app.window(handle=item["handle"])
                except Exception:
                    continue
            if class_name == "Chrome_WidgetWin_1":
                try:
                    import subprocess as _subprocess

                    output = _subprocess.check_output(
                        [
                            "powershell",
                            "-NoProfile",
                            "-Command",
                            f"(Get-Process -Id {int(item['pid'])} -ErrorAction SilentlyContinue).Path",
                        ],
                        text=True,
                        timeout=5,
                    ).strip()
                    if "ziniao" in output.lower():
                        from pywinauto import Application

                        app = Application(backend="uia").connect(handle=item["handle"], timeout=5)
                        return app.window(handle=item["handle"])
                except Exception:
                    continue
        time.sleep(0.5)
    return None


def _top_window_text(win) -> str:
    values: list[str] = []
    try:
        text = (win.window_text() or "").strip()
        if text:
            values.append(text)
    except Exception:
        pass
    try:
        for child in win.children():
            try:
                text = (child.window_text() or "").strip()
                if text:
                    values.append(text)
            except Exception:
                continue
    except Exception:
        pass
    return " ".join(values)


def _window_handle(win) -> int | None:
    try:
        return int(win.handle)
    except Exception:
        return None


def _ensure_on_primary_screen(handle: int) -> None:
    try:
        user32 = ctypes.windll.user32
        rect = wintypes.RECT()
        if not user32.GetWindowRect(wintypes.HWND(handle), ctypes.byref(rect)):
            return
        primary_left = 0
        primary_top = 0
        primary_right = int(user32.GetSystemMetrics(0))
        primary_bottom = int(user32.GetSystemMetrics(1))
        center_x = int((rect.left + rect.right) / 2)
        center_y = int((rect.top + rect.bottom) / 2)
        if primary_left <= center_x <= primary_right and primary_top <= center_y <= primary_bottom:
            return
        width = max(480, min(1200, int(rect.right - rect.left)))
        height = max(720, min(900, int(rect.bottom - rect.top)))
        user32.SetWindowPos(wintypes.HWND(handle), wintypes.HWND(-1), 80, 80, width, height, 0x0040)
        time.sleep(0.2)
        user32.SetWindowPos(wintypes.HWND(handle), wintypes.HWND(-2), 80, 80, width, height, 0x0040)
    except Exception:
        pass


def _bring_to_front(win) -> None:
    handle = _window_handle(win)
    if handle:
        _ensure_on_primary_screen(handle)
    try:
        win.set_focus()
        return
    except Exception:
        pass
    if not handle:
        return
    try:
        user32 = ctypes.windll.user32
        user32.ShowWindow(wintypes.HWND(handle), 9)
        _ensure_on_primary_screen(handle)
        user32.SetForegroundWindow(wintypes.HWND(handle))
    except Exception:
        pass


def _click_screen(x: int, y: int) -> None:
    user32 = ctypes.windll.user32
    user32.SetCursorPos(int(x), int(y))
    time.sleep(0.05)
    user32.mouse_event(0x0002, 0, 0, 0, 0)
    time.sleep(0.03)
    user32.mouse_event(0x0004, 0, 0, 0, 0)


def _looks_like_login_page(win) -> bool:
    text = _top_window_text(win)
    if not text:
        return False
    login_markers = ["验证码登录", "个人密码登录", "企业登录", "企业密码", "微信登录", "记住密码"]
    return sum(1 for marker in login_markers if marker in text) >= 2


def _wait_login_if_needed(desktop, win, timeout: int):
    if not _looks_like_login_page(win):
        return win, False
    _bring_to_front(win)
    deadline = time.time() + max(0, timeout)
    while time.time() < deadline:
        time.sleep(2)
        refreshed = _find_ziniao_window(desktop, timeout=2) or win
        if not _looks_like_login_page(refreshed):
            return refreshed, True
        _bring_to_front(refreshed)
        win = refreshed
    return win, True


def _click_text(root, candidates: list[str], timeout: float = 8.0) -> bool:
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            for ctrl in root.descendants():
                text = _control_text(ctrl)
                if text in candidates:
                    ctrl.click_input()
                    return True
        except Exception:
            pass
        time.sleep(0.4)
    return False


def _find_edit_controls(root):
    try:
        return [ctrl for ctrl in root.descendants(control_type="Edit")]
    except Exception:
        return []


def _find_best_search_edit(root):
    edits = _find_edit_controls(root)
    if not edits:
        return None
    root_rect = _control_rect(root)
    visible = []
    for edit in edits:
        rect = _control_rect(edit)
        if not rect:
            continue
        if root_rect and rect.top > root_rect.bottom - 90:
            # Bottom pager uses an Edit control too; do not type shop keywords there.
            continue
        if rect.width() < 140:
            continue
        text = _control_text(edit)
        score = 0
        if any(marker in text for marker in ("请输入", "关键词", "搜索", "批量")):
            score += 100
        if root_rect and root_rect.top + 120 <= rect.top <= root_rect.top + 280:
            score += 20
        visible.append((-score, rect.top, rect.left, edit))
    visible.sort(key=lambda item: (item[0], item[1], item[2]))
    return visible[0][3] if visible else None


def _click_search_icon(root) -> bool:
    root_rect = _control_rect(root)
    try:
        controls = root.descendants()
    except Exception:
        return False
    candidates = []
    for ctrl in controls:
        rect = _control_rect(ctrl)
        if not rect:
            continue
        text = _control_text(ctrl)
        ctype = _control_type(ctrl)
        if ctype not in {"Image", "Button"}:
            continue
        if root_rect:
            if not (root_rect.top + 130 <= rect.top <= root_rect.top + 230):
                continue
            if rect.left < root_rect.left + 330:
                continue
        score = 0
        if text in {"search", "搜索"}:
            score += 100
        if not text and 18 <= rect.width() <= 32 and 18 <= rect.height() <= 32:
            score += 20
        if score <= 0:
            continue
        candidates.append((-score, rect.left, ctrl))
    candidates.sort(key=lambda item: (item[0], item[1]))
    for _score, _left, ctrl in candidates:
        try:
            ctrl.click_input()
            return True
        except Exception:
            continue
    return False


def _click_search_submit(root) -> bool:
    root_rect = _control_rect(root)
    try:
        controls = root.descendants()
    except Exception:
        return False
    candidates = []
    for ctrl in controls:
        rect = _control_rect(ctrl)
        if not rect:
            continue
        text = _control_text(ctrl)
        ctype = _control_type(ctrl)
        if text not in {"search", "搜索"}:
            continue
        if root_rect and not (root_rect.top + 150 <= rect.top <= root_rect.top + 260):
            continue
        if ctype not in {"Button", "Image"}:
            continue
        candidates.append((rect.left, ctrl))
    candidates.sort(key=lambda item: item[0], reverse=True)
    for _left, ctrl in candidates:
        try:
            ctrl.click_input()
            return True
        except Exception:
            continue
    return False


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


def _find_start_buttons(root):
    preferred = ["启动", "启 动", "切换", "切 换", "打开", "打开账号"]
    try:
        controls = root.descendants()
    except Exception:
        return []
    result = []
    seen = set()
    for ctrl in controls:
        text = _control_text(ctrl)
        if text not in preferred:
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
            row_tolerance = max(16, min(40, label_rect.height() * 1.4))
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


def _wait_new_store_window(desktop, before_handles: set[int], timeout: float = 45.0):
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
                if handle not in before_handles and ("Seller" in title or "Shopee" in title or "TikTok" in title or "Lazada" in title):
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


def _text_at_points(desktop, points: list[tuple[int, int]]) -> list[str]:
    texts: list[str] = []
    seen: set[str] = set()
    for x, y in points:
        try:
            ctrl = desktop.from_point(int(x), int(y))
        except Exception:
            continue
        controls = [ctrl]
        try:
            parent = ctrl.parent()
            if parent:
                controls.append(parent)
        except Exception:
            pass
        for item in controls:
            text = _control_text(item)
            if text and text not in seen:
                seen.add(text)
                texts.append(text)
    return texts


def _fast_visible_search_and_open(main, desktop, keyboard, names: list[str]):
    if not names:
        return None, "缺少店铺关键词", False
    rect = _control_rect(main)
    if not rect:
        return None, "未能读取紫鸟窗口位置", False
    query = next((name for name in names if str(name or "").strip()), "")
    if not query:
        return None, "缺少店铺关键词", False

    _bring_to_front(main)
    time.sleep(0.2)
    width = max(1, rect.right - rect.left)

    # Ziniao's account list has stable geometry. This quick path is only used
    # for an already-open window; slow UIA enumeration remains the safe fallback.
    tab_x = rect.left + int(width * 0.50)
    tab_y = rect.top + 122
    search_x = rect.left + min(width - 70, max(150, int(width * 0.48)))
    search_y = rect.top + 204
    search_submit_x = rect.right - 26
    row_y = rect.top + 276
    button_x = rect.right - 78
    label_y = rect.top + 250
    label_points = [
        (rect.left + 95, label_y),
        (rect.left + 150, label_y),
        (rect.left + min(width - 150, 230), label_y),
        (rect.left + 150, label_y + 18),
    ]

    try:
        _click_screen(tab_x, tab_y)
        time.sleep(0.15)
        _click_screen(search_x, search_y)
        keyboard.send_keys("^a")
        keyboard.send_keys(query, with_spaces=True, pause=0.01)
        _click_screen(search_submit_x, search_y)
        time.sleep(1.4)
        main = _find_ziniao_window(desktop, timeout=1) or main
        texts = _text_at_points(desktop, label_points)
        if not any(_matches_target_name(text, names) for text in texts):
            return None, "当前可见首行没有确认到目标店铺名称", False
        before = _record_windows(desktop)
        _click_screen(button_x, row_y)
        store_win = _wait_new_store_window(desktop, before, timeout=18.0)
        if store_win:
            _bring_to_front(store_win)
            return store_win, "", False
        existing = _find_existing_store_window(desktop, names)
        if existing:
            return existing, "", False
        return main, "", False
    except Exception as exc:
        return None, f"当前窗口快速点击失败: {exc}", False


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
        if class_name != "Chrome_WidgetWin_1" and not any(
            marker in title for marker in ("Seller", "Shopee", "TikTok", "Tokopedia", "Lazada", "ASC")
        ):
            continue
        if _matches_target_name(title, names):
            _bring_to_front(win)
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
        _bring_to_front(store_win)
        return store_win, "", False
    existing = _find_existing_store_window(desktop, names)
    if existing:
        return existing, "", False
    return main, "", False


def _search_and_open(main, desktop, keyboard, names: list[str]):
    existing = _find_existing_store_window(desktop, names)
    if existing:
        return existing, ""
    try:
        main.set_focus()
    except Exception:
        pass
    _click_text(main, ["账号", "全部账号", "全 部 账 号", "浏览器", "店铺"], timeout=4)
    time.sleep(1)
    main = _find_ziniao_window(desktop, timeout=3) or main

    store_win, error, fatal = _open_visible_target_if_present(main, desktop, names)
    if fatal:
        return None, error
    if store_win:
        return store_win, ""

    edit = _find_best_search_edit(main)
    if not edit:
        if not _click_search_icon(main):
            _click_text(main, ["搜索", "搜 索"], timeout=3)
        time.sleep(0.5)
        main = _find_ziniao_window(desktop, timeout=3) or main
        edit = _find_best_search_edit(main)
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
            if not _click_search_submit(main):
                keyboard.send_keys("{ENTER}")
            time.sleep(2.5)
            main = _find_ziniao_window(desktop, timeout=3) or main
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
                return main, ""
        except Exception as exc:
            return None, f"搜索/启动紫鸟店铺失败: {exc}"
    return None, last_error or "紫鸟未匹配到店铺，请检查本机紫鸟是否已登录且包含该店铺"


def main() -> int:
    parser = argparse.ArgumentParser(description="Open a local Ziniao store through GUI when webdriver browser list is unavailable.")
    parser.add_argument("--shop-name", required=True)
    parser.add_argument("--query", default="")
    parser.add_argument("--view", default="home")
    parser.add_argument("--ziniao-name", default="")
    parser.add_argument("--alias", action="append", default=[])
    parser.add_argument("--config", default="")
    parser.add_argument("--login-timeout", type=int, default=180)
    parser.add_argument("--login-check-only", action="store_true", help="Only launch/foreground Ziniao and verify it is past the login page.")
    parser.add_argument("--no-launch", action="store_true", help="Only use an already-open Ziniao window; do not launch or restart Ziniao.")
    parser.add_argument("--fast-visible-click", action="store_true", help="Use coordinate-based quick click for an already-filtered/open Ziniao account list.")
    parser.add_argument("--quick-only", action="store_true", help="Return after quick current-window checks; do not run slow UIA search.")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    if os.name != "nt":
        _print_json(
            {
                "ok": False,
                "method": "ziniao_gui",
                "error": "non_windows",
                "message": "紫鸟 GUI 兜底需要 Windows 桌面环境。",
            },
            3,
        )

    Desktop, keyboard = _import_pywinauto()
    config = _load_config(args.config)
    desktop = Desktop(backend="uia")
    main_win = _find_ziniao_window(desktop, timeout=3 if args.no_launch else 5)
    started_ziniao = False
    if not main_win and not args.no_launch:
        started_ziniao = _start_ziniao(config)
        main_win = _find_ziniao_window(desktop, timeout=35)
    if not main_win and not args.no_launch:
        started_ziniao = _restart_ziniao_visible(config) or started_ziniao
        main_win = _find_ziniao_window(desktop, timeout=45)
    if not main_win:
        _print_json(
            {
                "ok": False,
                "method": "ziniao_gui",
                "error": "ziniao_window_not_found_current_only" if args.no_launch else "ziniao_window_not_found",
                "message": "当前没有可复用的紫鸟窗口。" if args.no_launch else "未找到本机紫鸟窗口。请员工先打开并登录紫鸟。",
                "started_ziniao": started_ziniao,
            },
            1,
        )

    main_win, waited_for_login = _wait_login_if_needed(desktop, main_win, args.login_timeout)
    if _looks_like_login_page(main_win):
        _print_json(
            {
                "ok": False,
                "method": "ziniao_gui",
                "error": "ziniao_login_required",
                "message": "紫鸟已打开并已置顶，但当前仍停在登录页。请员工在本机完成登录后重新执行同一条命令。",
                "started_ziniao": started_ziniao,
                "waited_login_seconds": args.login_timeout,
                "login_window_raised": True,
                "login_policy": {
                    "requires_local_ziniao": True,
                    "auto_login": False,
                    "bypass_login": False,
                    "credential_storage": False,
                },
            },
            4,
        )

    if args.login_check_only:
        _print_json(
            {
                "ok": True,
                "method": "ziniao_gui",
                "mode": "login_check",
                "message": "紫鸟已打开，且当前未停在紫鸟登录页；可以继续扫描本机店铺列表。",
                "started_ziniao": started_ziniao,
                "waited_for_login": waited_for_login,
                "login_policy": {
                    "requires_local_ziniao": True,
                    "auto_login": False,
                    "bypass_login": False,
                    "credential_storage": False,
                },
            },
            0,
        )

    names = []
    for item in [args.ziniao_name, args.query, args.shop_name] + list(args.alias or []):
        text = str(item or "").strip()
        if text and text not in names:
            names.append(text)

    if args.fast_visible_click:
        existing = _find_existing_store_window(desktop, names)
        if existing:
            _print_json(
                {
                    "ok": True,
                    "method": "ziniao_gui_current_window",
                    "message": "已复用当前已打开的店铺窗口。",
                    "shop": args.shop_name,
                    "view": args.view,
                    "searched": names,
                    "started_ziniao": started_ziniao,
                },
                0,
            )
        store_win, error, fatal = _fast_visible_search_and_open(main_win, desktop, keyboard, names)
        if store_win:
            _print_json(
                {
                    "ok": True,
                    "method": "ziniao_gui_current_window",
                    "message": "已复用当前紫鸟窗口并点击可见店铺行的启动/切换按钮。",
                    "shop": args.shop_name,
                    "view": args.view,
                    "searched": names,
                    "started_ziniao": started_ziniao,
                },
                0,
            )
        if fatal or args.quick_only:
            _print_json(
                {
                    "ok": False,
                    "method": "ziniao_gui_current_window",
                    "error": "current_window_not_reusable",
                    "message": error or "当前紫鸟窗口无法快速复用。",
                    "searched": names,
                    "started_ziniao": started_ziniao,
                },
                1,
            )

    store_win, error = _search_and_open(main_win, desktop, keyboard, names)
    if not store_win:
        _print_json(
            {
                "ok": False,
                "method": "ziniao_gui",
                "error": "ziniao_gui_match_failed",
                "message": error or "紫鸟 GUI 兜底打开失败。",
                "searched": names,
                "started_ziniao": started_ziniao,
            },
            1,
        )

    _print_json(
        {
            "ok": True,
            "method": "ziniao_gui",
            "message": "已通过本机紫鸟 GUI 发起店铺打开；能否进入后台取决于该紫鸟店铺是否已登录平台账号。",
            "shop": args.shop_name,
            "view": args.view,
            "searched": names,
            "started_ziniao": started_ziniao,
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
