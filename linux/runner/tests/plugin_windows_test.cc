#include "../plugin_windows.cc"

namespace {
void wait_for_client_size(PluginWindow *window, int width, int height) {
  const gint64 deadline = g_get_monotonic_time() + 2 * G_TIME_SPAN_SECOND;
  XWindowAttributes attributes{};
  do {
    while (g_main_context_iteration(nullptr, false)) {}
    g_assert_true(XGetWindowAttributes(window->display, window->window, &attributes));
    if (attributes.width == width && attributes.height == height) return;
    g_usleep(1000);
  } while (g_get_monotonic_time() < deadline);
  g_assert_cmpint(attributes.width, ==, width);
  g_assert_cmpint(attributes.height, ==, height);
}

void window_properties_follow_the_native_api() {
  GtkWidget *owner = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  g_object_ref_sink(owner);
  app_window = GTK_WINDOW(owner);
  GdkDisplay *app_display = gdk_display_get_default();
  uintptr_t parent = 0;
  uintptr_t token = api.create("DigiDAW — Vital — Synth", 640, 480, &parent);
  g_assert_cmpuint(token, !=, 0);
  g_assert_cmpuint(parent, !=, 0);
  g_assert_true(app_display == gdk_display_get_default());
  auto *window = reinterpret_cast<PluginWindow *>(token);
  g_assert_cmpuint(parent, ==, window->window);
  api.focus(token);
  wait_for_client_size(window, 640, 480);

  g_assert_true(api.set_title(token, "DigiDAW — Vital — Renamed synth"));
  Atom actual_type;
  int format;
  unsigned long length, remaining;
  unsigned char *value = nullptr;
  g_assert_cmpint(XGetWindowProperty(window->display, window->window,
      XInternAtom(window->display, "_NET_WM_NAME", False), 0, 256, False,
      XInternAtom(window->display, "UTF8_STRING", False), &actual_type, &format,
      &length, &remaining, &value), ==, Success);
  g_assert_cmpint(format, ==, 8);
  g_assert_cmpuint(remaining, ==, 0);
  g_assert_cmpstr(reinterpret_cast<const char *>(value), ==,
                 "DigiDAW — Vital — Renamed synth");
  XFree(value);

  g_assert_true(api.set_resizable(token, false));
  XSizeHints hints{};
  long supplied = 0;
  g_assert_true(XGetWMNormalHints(window->display, window->window, &hints, &supplied));
  g_assert_cmpint(hints.min_width, ==, 640);
  g_assert_cmpint(hints.max_width, ==, 640);
  g_assert_cmpint(hints.min_height, ==, 480);
  g_assert_cmpint(hints.max_height, ==, 480);

  g_assert_true(api.resize(token, 800, 600));
  wait_for_client_size(window, 800, 600);
  g_assert_true(XGetWMNormalHints(window->display, window->window, &hints, &supplied));
  g_assert_cmpint(hints.min_width, ==, 800);
  g_assert_cmpint(hints.max_height, ==, 600);
  g_assert_true(api.set_resizable(token, true));
  g_assert_true(XGetWMNormalHints(window->display, window->window, &hints, &supplied));
  g_assert_cmpint(hints.min_width, ==, 1);
  g_assert_cmpint(hints.max_width, ==, 16384);
  g_assert_false(api.resize(token, 0, 600));

  api.destroy(token);
  app_window = nullptr;
  gtk_widget_destroy(owner);
  g_object_unref(owner);
}
}  // namespace

int main(int argc, char **argv) {
  g_test_init(&argc, &argv, nullptr);
  gtk_init(&argc, &argv);
  g_test_add_func("/plugin-window/native-properties", window_properties_follow_the_native_api);
  return g_test_run();
}
