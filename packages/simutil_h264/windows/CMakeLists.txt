cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "simutil_h264")
project(${PROJECT_NAME} LANGUAGES CXX)

cmake_policy(VERSION 3.14...3.25)

set(PLUGIN_NAME "simutil_h264_plugin")

add_library(${PLUGIN_NAME} SHARED
  "include/simutil_h264/simutil_h264_plugin_c_api.h"
  "simutil_h264_plugin.cpp"
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin
  mfplat mfuuid wmcodecdspuuid)

set(simutil_h264_bundled_libraries
  ""
  PARENT_SCOPE
)
