function(digidaw_add_plugin_scanner rust_workspace)
  find_program(DIGIDAW_CARGO_EXECUTABLE cargo)
  if(NOT DIGIDAW_CARGO_EXECUTABLE)
    message(FATAL_ERROR "Cargo is required to package digidaw-plugin-scanner")
  endif()

  set(DIGIDAW_SCANNER_RUST_TARGET "" CACHE STRING "Rust target triple for the plugin scanner")
  if(DIGIDAW_SCANNER_RUST_TARGET)
    set(scanner_target "${DIGIDAW_SCANNER_RUST_TARGET}")
  elseif(WIN32)
    if(CMAKE_GENERATOR_PLATFORM STREQUAL "ARM64" OR CMAKE_SYSTEM_PROCESSOR MATCHES "^(ARM64|aarch64)$")
      set(scanner_target "aarch64-pc-windows-msvc")
    else()
      set(scanner_target "x86_64-pc-windows-msvc")
    endif()
  elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^(aarch64|arm64)$" OR FLUTTER_TARGET_PLATFORM STREQUAL "linux-arm64")
    set(scanner_target "aarch64-unknown-linux-gnu")
  elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|AMD64|amd64)$")
    set(scanner_target "x86_64-unknown-linux-gnu")
  else()
    message(FATAL_ERROR "Set DIGIDAW_SCANNER_RUST_TARGET for this desktop architecture")
  endif()

  set(scanner_directory "${CMAKE_BINARY_DIR}/plugin-scanner")
  set(scanner_profile "$<IF:$<CONFIG:Debug>,dev,release>")
  set(scanner_output_profile "$<IF:$<CONFIG:Debug>,debug,release>")
  set(scanner_executable "${scanner_directory}/${scanner_target}/${scanner_output_profile}/digidaw-plugin-scanner${CMAKE_EXECUTABLE_SUFFIX}")

  add_custom_target(digidaw_plugin_scanner ALL
    COMMAND "${DIGIDAW_CARGO_EXECUTABLE}" build
      --manifest-path "${rust_workspace}/Cargo.toml" --locked
      --package karbeat-vst3 --bin digidaw-plugin-scanner
      --target "${scanner_target}" --target-dir "${scanner_directory}"
      --profile "${scanner_profile}"
    WORKING_DIRECTORY "${rust_workspace}"
    VERBATIM
  )
  add_dependencies(${BINARY_NAME} digidaw_plugin_scanner)
  set(DIGIDAW_SCANNER_EXECUTABLE "${scanner_executable}" PARENT_SCOPE)
endfunction()
