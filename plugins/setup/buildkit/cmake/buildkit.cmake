# Builds the Windows core, helper service and Cronet DLL (build_tool
# "windows") as part of `flutter build windows`. Ported from FlClash.

get_filename_component(BUILDKIT_DIR "${CMAKE_CURRENT_LIST_DIR}" DIRECTORY)

function(apply_buildkit)
  # The top-level CMakeLists.txt lives in windows/, the project root above it.
  get_filename_component(PROJECT_ROOT "${CMAKE_SOURCE_DIR}" DIRECTORY)
  set(_output "${PROJECT_ROOT}/libclash/windows/RoutaMiCore.exe")

  add_custom_command(
    OUTPUT ${_output}
    COMMAND ${CMAKE_COMMAND} -E env "PROJECT_DIR=${PROJECT_ROOT}"
            "${BUILDKIT_DIR}/run_build_tool.cmd" windows
    WORKING_DIRECTORY "${PROJECT_ROOT}"
    COMMENT "Building the RoutaMi core via buildkit..."
    VERBATIM
  )
  add_custom_target(setup_buildkit_build DEPENDS ${_output})
endfunction()
