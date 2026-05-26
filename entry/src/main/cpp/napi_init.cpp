#include "napi/native_api.h"
#include <cstring>
#include <dlfcn.h>
#include <cstdio>

typedef char* (*StartProxyFunc)(char*);
typedef char* (*StopProxyFunc)();
typedef char* (*GetStatusFunc)();
typedef char* (*PrepareConfigFunc)(char*, char*);
typedef void (*FreeStringFunc)(char*);

static void* g_mihomoHandle = nullptr;
static StartProxyFunc g_startProxy = nullptr;
static StopProxyFunc g_stopProxy = nullptr;
static GetStatusFunc g_getStatus = nullptr;
static PrepareConfigFunc g_prepareConfig = nullptr;
static FreeStringFunc g_freeString = nullptr;

static bool ensureLoaded() {
    if (g_mihomoHandle) return true;
    g_mihomoHandle = dlopen("libmihomocore.so", RTLD_NOW | RTLD_LOCAL);
    if (!g_mihomoHandle) return false;

    g_startProxy = (StartProxyFunc)dlsym(g_mihomoHandle, "StartProxy");
    g_stopProxy = (StopProxyFunc)dlsym(g_mihomoHandle, "StopProxy");
    g_getStatus = (GetStatusFunc)dlsym(g_mihomoHandle, "GetStatus");
    g_prepareConfig = (PrepareConfigFunc)dlsym(g_mihomoHandle, "PrepareConfig");
    g_freeString = (FreeStringFunc)dlsym(g_mihomoHandle, "FreeString");

    if (!g_startProxy || !g_stopProxy || !g_getStatus || !g_prepareConfig || !g_freeString) {
        dlclose(g_mihomoHandle);
        g_mihomoHandle = nullptr;
        return false;
    }
    return true;
}

static napi_value JS_Ping(napi_env env, napi_callback_info info) {
    napi_value result;
    napi_create_string_utf8(env, "pong", NAPI_AUTO_LENGTH, &result);
    return result;
}

static napi_value JS_PrepareConfig(napi_env env, napi_callback_info info) {
    napi_value result;
    if (!ensureLoaded()) {
        napi_create_string_utf8(env, "{\"success\":false,\"error\":\"native core not loaded\"}", NAPI_AUTO_LENGTH, &result);
        return result;
    }

    size_t argc = 2;
    napi_value argv[2];
    char url[2048] = {0};
    char rawContent[65536] = {0};
    size_t urlLen = 0, rawLen = 0;

    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    napi_get_value_string_utf8(env, argv[0], url, sizeof(url), &urlLen);
    napi_get_value_string_utf8(env, argv[1], rawContent, sizeof(rawContent), &rawLen);

    char* resp = g_prepareConfig(url, rawContent);
    napi_create_string_utf8(env, resp, NAPI_AUTO_LENGTH, &result);
    g_freeString(resp);
    return result;
}

static napi_value JS_StartProxy(napi_env env, napi_callback_info info) {
    napi_value result;
    if (!ensureLoaded()) {
        napi_create_string_utf8(env, "{\"success\":false,\"message\":\"native core not loaded\"}", NAPI_AUTO_LENGTH, &result);
        return result;
    }

    size_t argc = 1;
    napi_value argv[1];
    char configPath[1024] = {0};
    size_t pathLen = 0;
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    napi_get_value_string_utf8(env, argv[0], configPath, sizeof(configPath), &pathLen);

    char* resp = g_startProxy(configPath);
    napi_create_string_utf8(env, resp, NAPI_AUTO_LENGTH, &result);
    g_freeString(resp);
    return result;
}

static napi_value JS_StopProxy(napi_env env, napi_callback_info info) {
    napi_value result;
    if (!ensureLoaded()) {
        napi_create_string_utf8(env, "{\"success\":false,\"message\":\"native core not loaded\"}", NAPI_AUTO_LENGTH, &result);
        return result;
    }
    char* resp = g_stopProxy();
    napi_create_string_utf8(env, resp, NAPI_AUTO_LENGTH, &result);
    g_freeString(resp);
    return result;
}

static napi_value JS_GetStatus(napi_env env, napi_callback_info info) {
    napi_value result;
    if (!ensureLoaded()) {
        napi_create_string_utf8(env, "{\"success\":false,\"running\":false}", NAPI_AUTO_LENGTH, &result);
        return result;
    }
    char* resp = g_getStatus();
    napi_create_string_utf8(env, resp, NAPI_AUTO_LENGTH, &result);
    g_freeString(resp);
    return result;
}

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        { "ping", nullptr, JS_Ping, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "prepareConfig", nullptr, JS_PrepareConfig, nullptr, nullptr, nullptr, napi_default, nullptr },
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
