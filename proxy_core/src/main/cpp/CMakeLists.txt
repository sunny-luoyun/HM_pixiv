cmake_minimum_required(VERSION 3.4.1)
project("proxy_core")

add_library(mihomocore SHARED IMPORTED)
set_target_properties(mihomocore PROPERTIES
    IMPORTED_LOCATION ${CMAKE_CURRENT_SOURCE_DIR}/../../../libs/${OHOS_ARCH}/libmihomocore.so
)

add_library(proxy_core SHARED napi_init.cpp)
target_link_libraries(proxy_core PUBLIC libace_napi.z.so mihomocore)
