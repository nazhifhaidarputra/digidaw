#include "plugin_windows.h"
#include "win32_window.h"
#include "../../rust/karbeat-host/include/digidaw_native_host.h"
#include <new>
#include <string>

namespace {
struct PluginWindow {
  HWND window = nullptr;
  bool closed = false;
  bool resized = false;
};
HWND app_window = nullptr;
constexpr wchar_t window_class[] = L"DigidawPluginEditor";

bool set_title(uintptr_t token, const char *title) {
  auto *host = reinterpret_cast<PluginWindow *>(token);
  int size = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, title, -1, nullptr, 0);
  if (size <= 0) return false;
  std::wstring name(size, L'\0');
  if (!MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, title, -1, name.data(), size)) return false;
  return SetWindowTextW(host->window, name.c_str()) != 0;
}
bool resize_window(uintptr_t token, uint32_t width, uint32_t height);
bool set_resizable(uintptr_t token, bool resizable) {
  auto *host = reinterpret_cast<PluginWindow *>(token);
  RECT bounds{};
  if (!GetClientRect(host->window, &bounds)) return false;
  LONG_PTR style = GetWindowLongPtrW(host->window, GWL_STYLE);
  if (resizable) style |= WS_THICKFRAME | WS_MAXIMIZEBOX;
  else style &= ~(WS_THICKFRAME | WS_MAXIMIZEBOX);
  SetLastError(0);
  if (!SetWindowLongPtrW(host->window, GWL_STYLE, style) && GetLastError() != 0) return false;
  return resize_window(token, bounds.right - bounds.left, bounds.bottom - bounds.top);
}

LRESULT CALLBACK window_proc(HWND window, UINT message, WPARAM wp, LPARAM lp) {
  auto *host = reinterpret_cast<PluginWindow *>(GetWindowLongPtrW(window, GWLP_USERDATA));
  if (message == WM_NCCREATE) {
    host = static_cast<PluginWindow *>(reinterpret_cast<CREATESTRUCTW *>(lp)->lpCreateParams);
    SetWindowLongPtrW(window, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(host));
    EnableNonClientDpiScaling(window);
  }
  if (host) {
    if (message == WM_CLOSE) {
      host->closed = true;
      return 0;
    }
    if (message == WM_SIZE) host->resized = true;
    if (message == WM_DWMCOLORIZATIONCOLORCHANGED || message == WM_SETTINGCHANGE) {
      Win32Window::UpdateTheme(window);
    }
    if (message == WM_DPICHANGED) {
      const auto *bounds = reinterpret_cast<RECT *>(lp);
      SetWindowPos(window, nullptr, bounds->left, bounds->top,
                   bounds->right - bounds->left, bounds->bottom - bounds->top,
                   SWP_NOACTIVATE | SWP_NOZORDER);
    }
  }
  return DefWindowProcW(window, message, wp, lp);
}
uintptr_t create_window(const char *title, uint32_t width, uint32_t height,
                        uintptr_t *parent) {
  auto *host = new (std::nothrow) PluginWindow;
  if (!host) return 0;
  RECT bounds{0, 0, static_cast<LONG>(width), static_cast<LONG>(height)};
  const UINT dpi = app_window ? GetDpiForWindow(app_window) : USER_DEFAULT_SCREEN_DPI;
  if (!AdjustWindowRectExForDpi(&bounds, WS_OVERLAPPEDWINDOW, FALSE, 0, dpi)) {
    delete host;
    return 0;
  }
  host->window = CreateWindowExW(0, window_class, L"DigiDAW",
      WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT,
      bounds.right - bounds.left, bounds.bottom - bounds.top,
      app_window, nullptr, GetModuleHandleW(nullptr), host);
  if (!host->window) { delete host; return 0; }
  if (!set_title(reinterpret_cast<uintptr_t>(host), title)) {
    DestroyWindow(host->window);
    delete host;
    return 0;
  }
  Win32Window::UpdateTheme(host->window);
  *parent = reinterpret_cast<uintptr_t>(host->window);
  return reinterpret_cast<uintptr_t>(host);
}
void destroy_window(uintptr_t token) {
  auto *host = reinterpret_cast<PluginWindow *>(token);
  DestroyWindow(host->window);
  delete host;
}
void focus_window(uintptr_t token) {
  auto *host = reinterpret_cast<PluginWindow *>(token);
  ShowWindow(host->window, SW_SHOWNORMAL);
  SetForegroundWindow(host->window);
}
bool resize_window(uintptr_t token, uint32_t width, uint32_t height) {
  if (!width || !height || width > 16384 || height > 16384) return false;
  auto *host = reinterpret_cast<PluginWindow *>(token);
  RECT bounds{0, 0, static_cast<LONG>(width), static_cast<LONG>(height)};
  const auto style = static_cast<DWORD>(GetWindowLongPtrW(host->window, GWL_STYLE));
  const auto ex_style = static_cast<DWORD>(GetWindowLongPtrW(host->window, GWL_EXSTYLE));
  if (!AdjustWindowRectExForDpi(&bounds, style, FALSE, ex_style, GetDpiForWindow(host->window))) return false;
  return SetWindowPos(host->window, nullptr, 0, 0, bounds.right - bounds.left,
      bounds.bottom - bounds.top, SWP_NOMOVE | SWP_NOACTIVATE | SWP_NOZORDER | SWP_FRAMECHANGED) != 0;
}
uint32_t poll_window(uintptr_t token, uint32_t *width, uint32_t *height) {
  auto *host = reinterpret_cast<PluginWindow *>(token);
  RECT bounds;
  GetClientRect(host->window, &bounds);
  *width = bounds.right - bounds.left;
  *height = bounds.bottom - bounds.top;
  uint32_t flags = (host->closed ? 1 : 0) | (host->resized ? 2 : 0);
  host->resized = false;
  return flags;
}
const DigidawNativeWindowApi api = {
    2, 2, create_window, destroy_window, focus_window, resize_window, poll_window,
    set_title, set_resizable};
void CALLBACK poll_host(HWND, UINT, UINT_PTR, DWORD) {
  HMODULE library = GetModuleHandleW(L"karbeat_flutter_ffi.dll");
  if (!library) return;
  auto poll = reinterpret_cast<DigidawNativeHostPoll>(GetProcAddress(library, "digidaw_native_host_poll"));
  if (poll) poll(&api);
}
}  // namespace

void digidaw_native_host_start(HWND owner) {
  app_window = owner;
  WNDCLASSW type{};
  type.lpfnWndProc = window_proc;
  type.hInstance = GetModuleHandleW(nullptr);
  type.lpszClassName = window_class;
  type.hCursor = LoadCursorW(nullptr, IDC_ARROW);
  RegisterClassW(&type);
  SetTimer(owner, 0xDA03, 16, poll_host);
}
