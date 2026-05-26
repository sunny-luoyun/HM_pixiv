import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';
import http from '@ohos.net.http';
import fileIo from '@ohos.file.fs';
import util from '@ohos.util';
import { startProxy as nativeStartProxy, stopProxy as nativeStopProxy, getStatus as nativeGetStatus, ping as nativePing, prepareConfig as nativePrepareConfig } from 'libproxy_core.so';

export type ProxyMode = 'manual' | 'subscription' | 'off';

export interface ProxyConfig {
  mode: ProxyMode;
  host: string;
  port: number;
}

interface NativeResult {
  success: boolean;
  message?: string;
  running?: boolean;
}

export class ProxyService {
  private static PREFERENCES_NAME = 'app_proxy';
  private static KEY_MODE = 'proxy_mode';
  private static KEY_HOST = 'proxy_host';
  private static KEY_PORT = 'proxy_port';
  private static KEY_SUBSCRIPTION_URL = 'proxy_subscription_url';
  private static KEY_RAW_CONTENT = 'proxy_raw_content';
  private static KEY_AUTO_START = 'proxy_auto_start';
  private static context: common.BaseContext;
  private static nativeAvailable: boolean = false;
  static nativeErrorMessage: string = '';

  static init(context: common.BaseContext) {
    ProxyService.context = context;
    ProxyService.restoreToAppStorage();
    ProxyService.checkNativeAvailable();
  }

  private static checkNativeAvailable() {
    try {
      const pingResp = nativePing() as string;
      if (pingResp !== 'pong') {
        ProxyService.nativeAvailable = false;
        ProxyService.nativeErrorMessage = 'ping failed: ' + pingResp;
        return;
      }
      const resp = nativeGetStatus() as string;
      if (resp) {
        const parsed = JSON.parse(resp) as Record<string, Object>;
        if (parsed['success'] === true) {
          ProxyService.nativeAvailable = true;
          ProxyService.nativeErrorMessage = '';
          console.info('✅ Mihomo 原生内核可用');
        } else {
          ProxyService.nativeAvailable = false;
          ProxyService.nativeErrorMessage = String(parsed['dlopen_error'] ?? parsed['message'] ?? '');
          console.warn('⚠️ Mihomo 内核不可用: ' + ProxyService.nativeErrorMessage);
        }
      } else {
        ProxyService.nativeAvailable = false;
        ProxyService.nativeErrorMessage = 'no response';
      }
    } catch (_err) {
      ProxyService.nativeAvailable = false;
      ProxyService.nativeErrorMessage = 'NAPI exception: ' + String(_err);
    }
  }
  // ... rest stays the same

  static isNativeAvailable(): boolean {
    return ProxyService.nativeAvailable;
  }

  static async startNativeProxy(configPath: string): Promise<NativeResult> {
    try {
      const resp = nativeStartProxy(configPath) as string;
      const result = JSON.parse(resp) as NativeResult;
      if (result.success) {
        AppStorage.setOrCreate('proxyMode', 'subscription');
      }
      return result;
    } catch (err) {
      return { success: false, message: `启动失败: ${String(err)}` };
    }
  }

  static async stopNativeProxy(): Promise<NativeResult> {
    try {
      const resp = nativeStopProxy() as string;
      return JSON.parse(resp) as NativeResult;
    } catch (err) {
      return { success: false, message: `停止失败: ${String(err)}` };
    }
  }

  static async getNativeStatus(): Promise<NativeResult> {
    try {
      const resp = nativeGetStatus() as string;
      return JSON.parse(resp) as NativeResult;
    } catch (_err) {
      return { success: true, running: false };
    }
  }

  static async prepareConfig(subscriptionUrl: string, rawContent: string): Promise<string> {
    try {
      const resp = nativePrepareConfig(subscriptionUrl, rawContent) as string;
      const parsed = JSON.parse(resp) as Record<string, Object>;
      if (parsed['success'] === true) {
        return String(parsed['config'] ?? '');
      }
      return '';
    } catch (_err) {
      return '';
    }
  }

  static async tryAutoStart(): Promise<void> {
    try {
      const autoStart = await ProxyService.getAutoStart();
      if (!autoStart) return;

      const mode = await ProxyService.getMode();
      if (mode !== 'subscription') return;

      const rawContent = await ProxyService.getRawContent();
      const subUrl = await ProxyService.getSubscriptionUrl();
      if (!rawContent || !subUrl) return;

      console.info('🔄 自动启动内核...');
      const ctx = ProxyService.context as common.UIAbilityContext;
      const configYaml = await ProxyService.prepareConfig(subUrl, rawContent);
      if (!configYaml) {
        console.warn('⚠️ 自动启动: 配置生成失败');
        return;
      }

      const preparedPath = ctx.cacheDir + '/prepared_config.yaml';
      const encoder = new util.TextEncoder();
      const uint8Arr = encoder.encodeInto(configYaml);
      const file = fileIo.openSync(preparedPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);
      fileIo.writeSync(file.fd, uint8Arr.buffer);
      fileIo.closeSync(file);

      const result = await ProxyService.startNativeProxy(preparedPath);
      if (result.success) {
        console.info('✅ 自动启动内核成功');
      } else {
        console.warn('⚠️ 自动启动失败: ' + (result.message ?? ''));
      }
    } catch (err) {
      console.warn('⚠️ 自动启动异常: ' + String(err));
    }
  }

  static async saveRawContent(content: string): Promise<void> {
    if (!ProxyService.context) return;
    const pref = await preferences.getPreferences(ProxyService.context, ProxyService.PREFERENCES_NAME);
    await pref.put(ProxyService.KEY_RAW_CONTENT, content);
    await pref.flush();
  }

  static async getRawContent(): Promise<string> {
    if (!ProxyService.context) return '';
    const pref = await preferences.getPreferences(ProxyService.context, ProxyService.PREFERENCES_NAME);
    return await pref.get(ProxyService.KEY_RAW_CONTENT, '') as string;
  }

  static async saveAutoStart(enabled: boolean): Promise<void> {
    if (!ProxyService.context) return;
    const pref = await preferences.getPreferences(ProxyService.context, ProxyService.PREFERENCES_NAME);
    await pref.put(ProxyService.KEY_AUTO_START, enabled);
    await pref.flush();
    AppStorage.setOrCreate('proxyAutoStart', enabled);
  }

  static async getAutoStart(): Promise<boolean> {
    if (!ProxyService.context) return false;
    const pref = await preferences.getPreferences(ProxyService.context, ProxyService.PREFERENCES_NAME);
    return await pref.get(ProxyService.KEY_AUTO_START, false) as boolean;
  }

  private static async restoreToAppStorage() {
    const mode = await ProxyService.getMode();
    AppStorage.setOrCreate('proxyMode', mode);
    const host = await ProxyService.getHost();
    AppStorage.setOrCreate('proxyHost', host);
    const port = await ProxyService.getPort();
    AppStorage.setOrCreate('proxyPort', port);
    const subUrl = await ProxyService.getSubscriptionUrl();
    AppStorage.setOrCreate('proxySubscriptionUrl', subUrl);
    const autoStart = await ProxyService.getAutoStart();
    AppStorage.setOrCreate('proxyAutoStart', autoStart);
  }

  static async getMode(): Promise<ProxyMode> {
    if (!ProxyService.context) return 'off';
    const pref = await preferences.getPreferences(ProxyService.context, ProxyService.PREFERENCES_NAME);
    return await pref.get(ProxyService.KEY_MODE, 'off') as ProxyMode;
  }

  static async setMode(mode: ProxyMode): Promise<void> {
    if (!ProxyService.context) return;
    const pref = await preferences.getPreferences(ProxyService.context, ProxyService.PREFERENCES_NAME);
    await pref.put(ProxyService.KEY_MODE, mode);
    await pref.flush();
    AppStorage.setOrCreate('proxyMode', mode);
  }

  static async getHost(): Promise<string> {
    if (!ProxyService.context) return '';
    const pref = await preferences.getPreferences(ProxyService.context, ProxyService.PREFERENCES_NAME);
    return await pref.get(ProxyService.KEY_HOST, '') as string;
  }

  static async setHost(host: string): Promise<void> {
    if (!ProxyService.context) return;
    const pref = await preferences.getPreferences(ProxyService.context, ProxyService.PREFERENCES_NAME);
    await pref.put(ProxyService.KEY_HOST, host);
    await pref.flush();
    AppStorage.setOrCreate('proxyHost', host);
  }

  static async getPort(): Promise<number> {
    if (!ProxyService.context) return 0;
    const pref = await preferences.getPreferences(ProxyService.context, ProxyService.PREFERENCES_NAME);
    return await pref.get(ProxyService.KEY_PORT, 0) as number;
  }

  static async setPort(port: number): Promise<void> {
    if (!ProxyService.context) return;
    const pref = await preferences.getPreferences(ProxyService.context, ProxyService.PREFERENCES_NAME);
    await pref.put(ProxyService.KEY_PORT, port);
    await pref.flush();
    AppStorage.setOrCreate('proxyPort', port);
  }

  static async getSubscriptionUrl(): Promise<string> {
    if (!ProxyService.context) return '';
    const pref = await preferences.getPreferences(ProxyService.context, ProxyService.PREFERENCES_NAME);
    return await pref.get(ProxyService.KEY_SUBSCRIPTION_URL, '') as string;
  }

  static async setSubscriptionUrl(url: string): Promise<void> {
    if (!ProxyService.context) return;
    const pref = await preferences.getPreferences(ProxyService.context, ProxyService.PREFERENCES_NAME);
    await pref.put(ProxyService.KEY_SUBSCRIPTION_URL, url);
    await pref.flush();
    AppStorage.setOrCreate('proxySubscriptionUrl', url);
  }

  static async setManualProxy(host: string, port: number): Promise<void> {
    await ProxyService.setHost(host);
    await ProxyService.setPort(port);
  }

  static async getManualProxyConfig(): Promise<ProxyConfig | null> {
    const host = await ProxyService.getHost();
    const port = await ProxyService.getPort();
    if (!host || port <= 0) return null;
    return { mode: 'manual', host, port };
  }

  static async getRequestProxyConfig(): Promise<http.HttpProxy | null> {
    const mode = await ProxyService.getMode();
    if (mode === 'off') return null;

    if (mode === 'manual') {
      const config = await ProxyService.getManualProxyConfig();
      if (config) {
        return { host: config.host, port: config.port, exclusionList: [] };
      }
    }

    if (mode === 'subscription') {
      return { host: '127.0.0.1', port: 7890, exclusionList: [] };
    }

    return null;
  }

  static async clearAll(): Promise<void> {
    if (!ProxyService.context) return;
    const pref = await preferences.getPreferences(ProxyService.context, ProxyService.PREFERENCES_NAME);
    await pref.delete(ProxyService.KEY_MODE);
    await pref.delete(ProxyService.KEY_HOST);
    await pref.delete(ProxyService.KEY_PORT);
    await pref.delete(ProxyService.KEY_SUBSCRIPTION_URL);
    await pref.delete(ProxyService.KEY_RAW_CONTENT);
    await pref.delete(ProxyService.KEY_AUTO_START);
    await pref.flush();
    AppStorage.setOrCreate('proxyMode', 'off');
    AppStorage.setOrCreate('proxyHost', '');
    AppStorage.setOrCreate('proxyPort', 0);
    AppStorage.setOrCreate('proxySubscriptionUrl', '');
    AppStorage.setOrCreate('proxyAutoStart', false);
  }
}
