cmake_minimum_required(VERSION 3.4.1)
project("proxy_core")

add_library(proxy_core SHARED napi_init.cpp)
target_link_libraries(proxy_core PUBLIC libace_napi.z.so libhilog_ndk.z.so)
