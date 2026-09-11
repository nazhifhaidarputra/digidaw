#include "plugin_windows.h"
#include "../../rust/karbeat-host/include/digidaw_native_host.h"

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <gdk/gdkx.h>
#include <dlfcn.h>
#include <new>
#include <cstring>

namespace {
struct PluginWindow {
  Display *display;
  Window window;
  Atom close_atom;
  bool closed = false;
  bool resizable = true;
};
GtkWindow *app_window = nullptr;

bool set_title(uintptr_t token, const char *title) {
  auto *host = reinterpret_cast<PluginWindow *>(token);
  XStoreName(host->display, host->window, title);
  XChangeProperty(host->display, host->window,
      XInternAtom(host->display, "_NET_WM_NAME", False),
      XInternAtom(host->display, "UTF8_STRING", False), 8, PropModeReplace,
      reinterpret_cast<const unsigned char *>(title), std::strlen(title));
  XFlush(host->display);
  return true;
}
void set_size_hints(PluginWindow *host, uint32_t width, uint32_t height) {
  XSizeHints hints{};
  hints.flags = PMinSize | PMaxSize;
  hints.min_width = host->resizable ? 1 : width;
  hints.min_height = host->resizable ? 1 : height;
  hints.max_width = host->resizable ? 16384 : width;
  hints.max_height = host->resizable ? 16384 : height;
  XSetWMNormalHints(host->display, host->window, &hints);
}
bool set_resizable(uintptr_t token, bool resizable) {
  auto *host = reinterpret_cast<PluginWindow *>(token);
  XWindowAttributes attributes{};
  if (!XGetWindowAttributes(host->display, host->window, &attributes)) return false;
  host->resizable = resizable;
  set_size_hints(host, attributes.width, attributes.height);
  XFlush(host->display);
  return true;
}

uintptr_t create_window(const char *title, uint32_t width, uint32_t height,
                        uintptr_t *parent) {
  Display *display = XOpenDisplay(nullptr);
  if (!display) return 0;
  Window window = XCreateSimpleWindow(display, DefaultRootWindow(display),
                                     0, 0, width, height, 0, 0, 0);
  if (!window) {
    XCloseDisplay(display);
    return 0;
  }
  auto *host = new (std::nothrow) PluginWindow;
  if (!host) {
    XDestroyWindow(display, window);
    XCloseDisplay(display);
    return 0;
  }
  host->display = display;
  host->window = window;
  host->close_atom = XInternAtom(display, "WM_DELETE_WINDOW", False);
  XSetWMProtocols(display, window, &host->close_atom, 1);
  set_title(reinterpret_cast<uintptr_t>(host), title);
  XClassHint class_hint{};
  class_hint.res_name = const_cast<char *>(g_get_prgname() ? g_get_prgname() : "digidaw");
  class_hint.res_class = const_cast<char *>(gdk_get_program_class() ? gdk_get_program_class() : "DigiDAW");
  XSetClassHint(display, window, &class_hint);
  XSelectInput(display, window, StructureNotifyMask);
  if (app_window) {
    GdkWindow *owner = gtk_widget_get_window(GTK_WIDGET(app_window));
    if (owner && GDK_IS_X11_WINDOW(owner)) {
      XSetTransientForHint(display, window, gdk_x11_window_get_xid(owner));
    }
  }
  // Plugins may attach using another X connection; the parent must exist first.
  XSync(display, False);
  *parent = window;
  return reinterpret_cast<uintptr_t>(host);
}
void destroy_window(uintptr_t token) {
  auto *host = reinterpret_cast<PluginWindow *>(token);
  XDestroyWindow(host->display, host->window);
  XCloseDisplay(host->display);
  delete host;
}
void focus_window(uintptr_t token) {
  auto *host = reinterpret_cast<PluginWindow *>(token);
  XMapRaised(host->display, host->window);
  XFlush(host->display);
}
bool resize_window(uintptr_t token, uint32_t width, uint32_t height) {
  if (!width || !height || width > 16384 || height > 16384) return false;
  auto *host = reinterpret_cast<PluginWindow *>(token);
  set_size_hints(host, width, height);
  XResizeWindow(host->display, host->window, width, height);
  XFlush(host->display);
  return true;
}
uint32_t poll_window(uintptr_t token, uint32_t *width, uint32_t *height) {
  auto *host = reinterpret_cast<PluginWindow *>(token);
  uint32_t flags = 0;
  for (int count = 0; count < 256 && XPending(host->display); ++count) {
    XEvent event;
    XNextEvent(host->display, &event);
    if (event.type == ClientMessage &&
        static_cast<Atom>(event.xclient.data.l[0]) == host->close_atom) {
      host->closed = true;
    } else if (event.type == ConfigureNotify &&
               event.xconfigure.window == host->window) {
      *width = event.xconfigure.width;
      *height = event.xconfigure.height;
      flags |= 2;
    }
  }
  return flags | (host->closed ? 1 : 0);
}
const DigidawNativeWindowApi api = {
    2, 1, create_window, destroy_window, focus_window, resize_window, poll_window,
    set_title, set_resizable};

gboolean poll_host(gpointer) {
  static void *library = nullptr;
  static DigidawNativeHostPoll poll = nullptr;
  if (!library) library = dlopen("libkarbeat_flutter_ffi.so", RTLD_NOW | RTLD_NOLOAD);
  if (library && !poll) {
    poll = reinterpret_cast<DigidawNativeHostPoll>(
        dlsym(library, "digidaw_native_host_poll"));
  }
  if (poll) poll(&api);
  return G_SOURCE_CONTINUE;
}
}  // namespace

void digidaw_native_host_start(GtkWindow *owner) {
  app_window = owner;
  g_object_add_weak_pointer(G_OBJECT(owner), reinterpret_cast<gpointer *>(&app_window));
  g_timeout_add(16, poll_host, nullptr);
}
