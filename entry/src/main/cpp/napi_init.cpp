#include "napi/native_api.h"
#include <cstring>
#include <cstdlib>
#include <dlfcn.h>
#include <cstdio>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>

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

static napi_value makeErrorResponse(napi_env env, const char* msg) {
    napi_value result;
    napi_create_string_utf8(env, msg, NAPI_AUTO_LENGTH, &result);
    return result;
}

static bool validateStringArg(napi_env env, napi_value val, size_t argIndex, napi_value* errorResult) {
    napi_valuetype type;
    if (napi_typeof(env, val, &type) != napi_ok || type != napi_string) {
        char errBuf[128];
        snprintf(errBuf, sizeof(errBuf),
            "{\"success\":false,\"error\":\"invalid argument at index %zu\"}", argIndex);
        *errorResult = makeErrorResponse(env, errBuf);
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
        return makeErrorResponse(env, "{\"success\":false,\"error\":\"native core not loaded\"}");
    }

    size_t argc = 2;
    napi_value argv[2];
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);

    if (argc < 2 || !validateStringArg(env, argv[0], 0, &result) || !validateStringArg(env, argv[1], 1, &result)) {
        return result;
    }

    size_t urlLen = 0, rawLen = 0;
    napi_get_value_string_utf8(env, argv[0], nullptr, 0, &urlLen);
    napi_get_value_string_utf8(env, argv[1], nullptr, 0, &rawLen);

    if (urlLen == 0 || rawLen == 0) {
        return makeErrorResponse(env, "{\"success\":false,\"error\":\"empty argument\"}");
    }

    char* url = (char*)malloc(urlLen + 1);
    char* rawContent = (char*)malloc(rawLen + 1);
    if (!url || !rawContent) {
        free(url);
        free(rawContent);
        return makeErrorResponse(env, "{\"success\":false,\"error\":\"malloc failed\"}");
    }

    napi_get_value_string_utf8(env, argv[0], url, urlLen + 1, &urlLen);
    napi_get_value_string_utf8(env, argv[1], rawContent, rawLen + 1, &rawLen);

    char* resp = g_prepareConfig(url, rawContent);
    napi_create_string_utf8(env, resp, NAPI_AUTO_LENGTH, &result);
    g_freeString(resp);

    free(url);
    free(rawContent);
    return result;
}

static napi_value JS_StartProxy(napi_env env, napi_callback_info info) {
    napi_value result;
    if (!ensureLoaded()) {
        return makeErrorResponse(env, "{\"success\":false,\"message\":\"native core not loaded\"}");
    }

    size_t argc = 1;
    napi_value argv[1];
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);

    if (argc < 1 || !validateStringArg(env, argv[0], 0, &result)) {
        return result;
    }

    size_t pathLen = 0;
    napi_get_value_string_utf8(env, argv[0], nullptr, 0, &pathLen);
    if (pathLen == 0) {
        return makeErrorResponse(env, "{\"success\":false,\"message\":\"empty config path\"}");
    }

    char* configPath = (char*)malloc(pathLen + 1);
    if (!configPath) {
        return makeErrorResponse(env, "{\"success\":false,\"message\":\"malloc failed\"}");
    }
    napi_get_value_string_utf8(env, argv[0], configPath, pathLen + 1, &pathLen);

    char* resp = g_startProxy(configPath);
    napi_create_string_utf8(env, resp, NAPI_AUTO_LENGTH, &result);
    g_freeString(resp);

    free(configPath);
    return result;
}

static napi_value JS_StopProxy(napi_env env, napi_callback_info info) {
    napi_value result;
    if (!ensureLoaded()) {
        return makeErrorResponse(env, "{\"success\":false,\"message\":\"native core not loaded\"}");
    }
    char* resp = g_stopProxy();
    napi_create_string_utf8(env, resp, NAPI_AUTO_LENGTH, &result);
    g_freeString(resp);
    return result;
}

static napi_value JS_GetStatus(napi_env env, napi_callback_info info) {
    napi_value result;
    if (!ensureLoaded()) {
        return makeErrorResponse(env, "{\"success\":false,\"running\":false}");
    }
    char* resp = g_getStatus();
    napi_create_string_utf8(env, resp, NAPI_AUTO_LENGTH, &result);
    g_freeString(resp);
    return result;
}

static napi_value JS_CheckPort(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value argv[1];
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);

    napi_value result;
    if (argc < 1) {
        napi_create_int32(env, -1, &result);
        return result;
    }

    napi_valuetype type;
    if (napi_typeof(env, argv[0], &type) != napi_ok || type != napi_number) {
        napi_create_int32(env, -1, &result);
        return result;
    }

    int32_t port = 7890;
    napi_get_value_int32(env, argv[0], &port);
    if (port <= 0 || port > 65535) {
        napi_create_int32(env, -1, &result);
        return result;
    }

    int sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) {
        napi_create_int32(env, -1, &result);
        return result;
    }

    int optval = 1;
    setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &optval, sizeof(optval));

    struct sockaddr_in addr;
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    addr.sin_addr.s_addr = inet_addr("127.0.0.1");

    int ret = bind(sock, (struct sockaddr*)&addr, sizeof(addr));
    close(sock);

    napi_create_int32(env, ret == 0 ? 0 : -1, &result);
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
        { "checkPort", nullptr, JS_CheckPort, nullptr, nullptr, nullptr, napi_default, nullptr },
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
