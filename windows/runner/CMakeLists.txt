cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

set(BINARY_NAME "doraty")
set(APPLICATION_ID "com.doraty.app")

add_executable(${BINARY_NAME} WIN32
  "main.cpp"
  "utils.cpp"
  "utils.h"
  "win32_window.cpp"
  "win32_window.h"
  "flutter_window.cpp"
  "flutter_window.h"
  "Runner.rc"
  "../flutter/generated_plugin_registrant.cc"
  "resources/Runner.exe.manifest"
)
apply_standard_settings(${BINARY_NAME})
# Extract version from pubspec.yaml
file(READ "${CMAKE_CURRENT_SOURCE_DIR}/../../pubspec.yaml" PUBSPEC_CONTENT)
if (PUBSPEC_CONTENT MATCHES "version: ([0-9]+)\\.([0-9]+)\\.([0-9]+)\\+([0-9]+)")
  set(MAJOR ${CMAKE_MATCH_1})
  set(MINOR ${CMAKE_MATCH_2})
  set(PATCH ${CMAKE_MATCH_3})
  set(BUILD ${CMAKE_MATCH_4})
  set(VERSION_STRING "${MAJOR}.${MINOR}.${PATCH}+${BUILD}")
else()
  # Fallback if parsing fails
  set(MAJOR 1)
  set(MINOR 0)
  set(PATCH 0)
  set(BUILD 1)
  set(VERSION_STRING "1.0.0+1")
endif()

target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${VERSION_STRING}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${BUILD}")

target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app dwmapi)
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")
add_dependencies(${BINARY_NAME} flutter_assemble)

# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
