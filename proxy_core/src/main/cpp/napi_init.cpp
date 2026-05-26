#include "napi/native_api.h"
#include <cstring>

extern "C" {
    char* StartProxy(char* configPath);
    char* StopProxy();
    char* GetStatus();
    void FreeString(char* s);
}

static napi_value JS_StartProxy(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value argv[1];
    napi_value result;
    char configPath[1024] = {0};
    size_t pathLen = 0;

    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    napi_get_value_string_utf8(env, argv[0], configPath, sizeof(configPath), &pathLen);

    char* resp = StartProxy(configPath);
    napi_create_string_utf8(env, resp, NAPI_AUTO_LENGTH, &result);
    FreeString(resp);

    return result;
}

static napi_value JS_StopProxy(napi_env env, napi_callback_info info) {
    napi_value result;
    char* resp = StopProxy();
    napi_create_string_utf8(env, resp, NAPI_AUTO_LENGTH, &result);
    FreeString(resp);
    return result;
}

static napi_value JS_GetStatus(napi_env env, napi_callback_info info) {
    napi_value result;
    char* resp = GetStatus();
    napi_create_string_utf8(env, resp, NAPI_AUTO_LENGTH, &result);
    FreeString(resp);
    return result;
}

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        { "startProxy", nullptr, JS_StartProxy, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "stopProxy", nullptr, JS_StopProxy, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "getStatus", nullptr, JS_GetStatus, nullptr, nullptr, nullptr, napi_default, nullptr },
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}
EXTERN_C_END

static napi_module proxyCoreModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "proxy_core",
    .nm_priv = nullptr,
    .reserved = { 0 },
};

extern "C" __attribute__((constructor)) void RegisterModule() {
    napi_module_register(&proxyCoreModule);
}
