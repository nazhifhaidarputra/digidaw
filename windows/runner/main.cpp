#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

extern "C" int digidaw_initialize_windows_main_thread();
extern "C" int digidaw_run_windows_main_loop();
extern "C" void digidaw_shutdown_windows_main_thread();

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  if (digidaw_initialize_windows_main_thread() != 0) {
    return EXIT_FAILURE;
  }

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Karbeat \u2014 Untitled", origin, size)) {
    digidaw_shutdown_windows_main_thread();
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  return digidaw_run_windows_main_loop();
}
