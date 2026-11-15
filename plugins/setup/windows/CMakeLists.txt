cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "setup")
project(${PROJECT_NAME} LANGUAGES CXX)

include("../buildkit/cmake/buildkit.cmake")
apply_buildkit()

add_dependencies(${BINARY_NAME} setup_buildkit_build)

get_filename_component(PROJECT_ROOT "${CMAKE_SOURCE_DIR}" DIRECTORY)

# Installed next to RoutaMi.exe (see lib/common/path.dart).
set(setup_bundled_libraries
  "${PROJECT_ROOT}/libclash/windows/RoutaMiCore.exe"
  "${PROJECT_ROOT}/libclash/windows/RoutaMiHelperService.exe"
  "${PROJECT_ROOT}/libclash/windows/RoutaMiTray.exe"
  "${PROJECT_ROOT}/libclash/windows/libcronet.dll"
  PARENT_SCOPE
)
