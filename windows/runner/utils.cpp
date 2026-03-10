#include "utils.h"

#include <flutter_windows.h>
#include <io.h>
#include <stdio.h>
#include <windows.h>

#include <iostream>

void CreateAndAttachConsole() {
  if (::AllocConsole()) {
    FILE* unused;
    if (freopen_s(&unused, "CONOUT$", "w", stdout)) {
      _dup2(_fileno(stdout), 1);
    }
    if (freopen_s(&unused, "CONOUT$", "w", stderr)) {
      _dup2(_fileno(stderr), 2);
    }
    std::ios::sync_with_stdio();
    FlutterDesktopResyncOutputStreams();
  }
}

void GetCommandLineArguments(std::vector<std::string>* out) {
  int argc;
  wchar_t** argv = ::CommandLineToArgvW(::GetCommandLineW(), &argc);
  if (argv == nullptr) {
    return;
  }

  std::vector<std::string> arguments;
  for (int i = 1; i < argc; ++i) {
    std::wstring arg(argv[i]);
    int size_needed = WideCharToMultiByte(CP_UTF8, 0, &arg[0], (int)arg.size(),
                                          NULL, 0, NULL, NULL);
    std::string res(size_needed, 0);
    WideCharToMultiByte(CP_UTF8, 0, &arg[0], (int)arg.size(), &res[0],
                        size_needed, NULL, NULL);
    out->push_back(res);
  }

  ::LocalFree(argv);
}
