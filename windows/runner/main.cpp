#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter_windows.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  // 작업 영역(작업 표시줄 제외)의 85% 크기로 가운데에 둔다.
  RECT area;
  ::SystemParametersInfo(SPI_GETWORKAREA, 0, &area, 0);
  // Create()가 모니터 배율을 곱하므로 실제 픽셀을 논리 단위로 바꿔 넘긴다.
  const double scale =
      FlutterDesktopGetDpiForMonitor(
          ::MonitorFromPoint({area.left, area.top}, MONITOR_DEFAULTTOPRIMARY)) /
      96.0;
  const int area_w = static_cast<int>((area.right - area.left) / scale);
  const int area_h = static_cast<int>((area.bottom - area.top) / scale);
  Win32Window::Size size(area_w * 85 / 100, area_h * 85 / 100);
  Win32Window::Point origin(
      static_cast<int>(area.left / scale) + (area_w - size.width) / 2,
      static_cast<int>(area.top / scale) + (area_h - size.height) / 2);
  if (!window.Create(L"MgrS", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
