include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(my_project_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(my_project_setup_options)
  option(my_project_ENABLE_HARDENING "Enable hardening" ON)
  option(my_project_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    my_project_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    my_project_ENABLE_HARDENING
    OFF)

  my_project_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR my_project_PACKAGING_MAINTAINER_MODE)
    option(my_project_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(my_project_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(my_project_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(my_project_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(my_project_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(my_project_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(my_project_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(my_project_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(my_project_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(my_project_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(my_project_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(my_project_ENABLE_PCH "Enable precompiled headers" OFF)
    option(my_project_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(my_project_ENABLE_IPO "Enable IPO/LTO" ON)
    option(my_project_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(my_project_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(my_project_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(my_project_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(my_project_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(my_project_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(my_project_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(my_project_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(my_project_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(my_project_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(my_project_ENABLE_PCH "Enable precompiled headers" OFF)
    option(my_project_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      my_project_ENABLE_IPO
      my_project_WARNINGS_AS_ERRORS
      my_project_ENABLE_USER_LINKER
      my_project_ENABLE_SANITIZER_ADDRESS
      my_project_ENABLE_SANITIZER_LEAK
      my_project_ENABLE_SANITIZER_UNDEFINED
      my_project_ENABLE_SANITIZER_THREAD
      my_project_ENABLE_SANITIZER_MEMORY
      my_project_ENABLE_UNITY_BUILD
      my_project_ENABLE_CLANG_TIDY
      my_project_ENABLE_CPPCHECK
      my_project_ENABLE_COVERAGE
      my_project_ENABLE_PCH
      my_project_ENABLE_CACHE)
  endif()

  my_project_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (my_project_ENABLE_SANITIZER_ADDRESS OR my_project_ENABLE_SANITIZER_THREAD OR my_project_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(my_project_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(my_project_global_options)
  if(my_project_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    my_project_enable_ipo()
  endif()

  my_project_supports_sanitizers()

  if(my_project_ENABLE_HARDENING AND my_project_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR my_project_ENABLE_SANITIZER_UNDEFINED
       OR my_project_ENABLE_SANITIZER_ADDRESS
       OR my_project_ENABLE_SANITIZER_THREAD
       OR my_project_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${my_project_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${my_project_ENABLE_SANITIZER_UNDEFINED}")
    my_project_enable_hardening(my_project_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(my_project_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(my_project_warnings INTERFACE)
  add_library(my_project_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  my_project_set_project_warnings(
    my_project_warnings
    ${my_project_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(my_project_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(my_project_options)
  endif()

  include(cmake/Sanitizers.cmake)
  my_project_enable_sanitizers(
    my_project_options
    ${my_project_ENABLE_SANITIZER_ADDRESS}
    ${my_project_ENABLE_SANITIZER_LEAK}
    ${my_project_ENABLE_SANITIZER_UNDEFINED}
    ${my_project_ENABLE_SANITIZER_THREAD}
    ${my_project_ENABLE_SANITIZER_MEMORY})

  set_target_properties(my_project_options PROPERTIES UNITY_BUILD ${my_project_ENABLE_UNITY_BUILD})

  if(my_project_ENABLE_PCH)
    target_precompile_headers(
      my_project_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(my_project_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    my_project_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(my_project_ENABLE_CLANG_TIDY)
    my_project_enable_clang_tidy(my_project_options ${my_project_WARNINGS_AS_ERRORS})
  endif()

  if(my_project_ENABLE_CPPCHECK)
    my_project_enable_cppcheck(${my_project_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(my_project_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    my_project_enable_coverage(my_project_options)
  endif()

  if(my_project_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(my_project_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(my_project_ENABLE_HARDENING AND NOT my_project_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR my_project_ENABLE_SANITIZER_UNDEFINED
       OR my_project_ENABLE_SANITIZER_ADDRESS
       OR my_project_ENABLE_SANITIZER_THREAD
       OR my_project_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    my_project_enable_hardening(my_project_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
