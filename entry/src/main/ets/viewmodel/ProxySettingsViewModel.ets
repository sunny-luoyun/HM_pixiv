import { BaseState } from './BaseState';
import { BaseVM, BaseVMEvent } from './BaseVM';
import { ProxyService, ProxyMode } from '../services/ProxyService';
import { SubscriptionService } from '../services/SubscriptionService';
import { ApiConfig } from '../common/constants/ApiConfig';
import http from '@ohos.net.http';
import fileIo from '@ohos.file.fs';
import util from '@ohos.util';
import common from '@ohos.app.ability.common';

export class ProxySettingsEventType {
  static readonly LOAD_SETTINGS = 'LOAD_SETTINGS';
  static readonly SET_MODE = 'SET_MODE';
  static readonly FETCH_SUBSCRIPTION = 'FETCH_SUBSCRIPTION';
  static readonly TEST_PROXY = 'TEST_PROXY';
  static readonly START_KERNEL = 'START_KERNEL';
  static readonly STOP_KERNEL = 'STOP_KERNEL';
  static readonly CHECK_NATIVE = 'CHECK_NATIVE';
  static readonly SET_AUTO_START = 'SET_AUTO_START';
}

@Observed
export class ProxySettingsState extends BaseState {
  proxyMode: ProxyMode = 'off';
  proxyHost: string = '';
  proxyPort: string = '';
  proxySubscriptionUrl: string = '';
  proxyFetchState: 'idle' | 'fetching' | 'ok' | 'fail' = 'idle';
  proxyFetchMessage: string = '';
  proxyFetchRawContent: string = '';
  proxyAutoStart: boolean = false;
  proxyTestState: 'idle' | 'testing' | 'ok' | 'fail' = 'idle';
  proxyTestMessage: string = '';
  nativeRunning: boolean = false;
  nativeAvailable: boolean = false;
  nativeStatusMessage: string = '';
}

export class ProxySettingsViewModel extends BaseVM<ProxySettingsState> {
  private static instance: ProxySettingsViewModel;

  static getInstance(): ProxySettingsViewModel {
    if (!ProxySettingsViewModel.instance) {
      ProxySettingsViewModel.instance = new ProxySettingsViewModel();
    }
    return ProxySettingsViewModel.instance;
  }

  private constructor() {
    super(new ProxySettingsState());
  }

  sendEvent(event: BaseVMEvent): void {
    switch (event.type) {
      case ProxySettingsEventType.LOAD_SETTINGS:
        this.loadSettings();
        break;
      case ProxySettingsEventType.SET_MODE:
        this.setMode((event.param as Record<string, ProxyMode>)['mode'] ?? 'off');
        break;
      case ProxySettingsEventType.FETCH_SUBSCRIPTION:
        this.fetchSubscription();
        break;
      case ProxySettingsEventType.TEST_PROXY:
        this.testProxyConnection();
        break;
      case ProxySettingsEventType.START_KERNEL:
        this.startNativeKernel();
        break;
      case ProxySettingsEventType.STOP_KERNEL:
        this.stopNativeKernel();
        break;
      case ProxySettingsEventType.CHECK_NATIVE:
        this.checkNativeRunning();
        break;
      case ProxySettingsEventType.SET_AUTO_START:
        this.saveAutoStart((event.param as Record<string, boolean>)['value'] ?? false);
        break;
    }
  }

  loadSettings(): void {
    const state = this.state;
    state.proxyMode = AppStorage.get<ProxyMode>('proxyMode') ?? 'off';
    state.proxyHost = AppStorage.get<string>('proxyHost') ?? '';
    const savedPort = AppStorage.get<number>('proxyPort') ?? 0;
    state.proxyPort = savedPort > 0 ? String(savedPort) : '';
    state.proxySubscriptionUrl = AppStorage.get<string>('proxySubscriptionUrl') ?? '';
    state.nativeAvailable = ProxyService.isNativeAvailable();
    state.proxyAutoStart = AppStorage.get<boolean>('proxyAutoStart') ?? false;
    this.checkNativeRunning();
    this.restoreProxyContent();
  }

  setMode(mode: ProxyMode): void {
    this.state.proxyMode = mode;
    ProxyService.setMode(mode);
  }

  async restoreProxyContent(): Promise<void> {
    const raw = await ProxyService.getRawContent();
    if (raw) {
      this.state.proxyFetchRawContent = raw;
      this.state.proxyFetchState = 'ok';
      this.state.proxyFetchMessage = '订阅已保存';
    }
    const status = await ProxyService.getNativeStatus();
    this.state.nativeRunning = status.running ?? false;
  }

  async fetchSubscription(): Promise<void> {
    const state = this.state;
    state.proxyFetchState = 'fetching';
    state.proxyFetchMessage = '正在拉取...';
    const result = await SubscriptionService.fetch(state.proxySubscriptionUrl);
    if (result.success) {
      state.proxyFetchState = 'ok';
      state.proxyFetchMessage = `拉取成功 ${result.fileName ? '(已保存)' : ''}`;
      state.proxyFetchRawContent = result.rawContent ?? '';
      ProxyService.saveRawContent(result.rawContent ?? '');
      if (result.fileName) {
        console.info(`订阅已保存到: ${SubscriptionService.getSavedFilePath(result.fileName)}`);
      }
    } else {
      state.proxyFetchState = 'fail';
      state.proxyFetchMessage = result.error || '拉取失败';
    }
  }

  async testProxyConnection(): Promise<void> {
    const state = this.state;
    state.proxyTestState = 'testing';
    state.proxyTestMessage = '正在测试（最多尝试30秒）...';
    try {
      if (state.proxyMode === 'subscription' && !state.nativeRunning) {
        state.proxyTestState = 'fail';
        state.proxyTestMessage = '内核未启动，请先启动内核';
        return;
      }
      if (state.proxyMode === 'manual') {
        await ProxyService.setManualProxy(state.proxyHost, parseInt(state.proxyPort) || 0);
      }
      const config = await ProxyService.getRequestProxyConfig();
      if (!config) {
        state.proxyTestState = 'fail';
        state.proxyTestMessage = '代理配置无效';
        return;
      }
      for (let attempt = 1; attempt <= 3; attempt++) {
        if (attempt > 1) {
          await new Promise<void>(resolve => setTimeout(resolve, 3000));
        }
        const httpRequest = http.createHttp();
        try {
          state.proxyTestMessage = `正在测试 (第${attempt}次)...`;
          const resp = await httpRequest.request(ApiConfig.PIXIV_WEB + '/', {
            method: http.RequestMethod.GET,
            connectTimeout: 15000,
            readTimeout: 15000,
            usingProxy: config,
          });
          if (resp.responseCode === 200) {
            state.proxyTestState = 'ok';
            state.proxyTestMessage = '';
            httpRequest.destroy();
            return;
          }
          httpRequest.destroy();
        } catch (_) {
          httpRequest.destroy();
          if (attempt >= 3) {
            state.proxyTestState = 'fail';
            state.proxyTestMessage = '连接代理服务器失败（提供商正在初始化）';
          }
        }
      }
    } catch (_) {
      state.proxyTestState = 'fail';
      state.proxyTestMessage = '测试异常';
    }
  }

  async checkNativeRunning(): Promise<void> {
    if (!this.state.nativeAvailable) return;
    const status = await ProxyService.getNativeStatus();
    this.state.nativeRunning = status.running ?? false;
    if (status.message) {
      this.state.nativeStatusMessage = status.message;
    }
  }

  async startNativeKernel(): Promise<void> {
    const state = this.state;
    if (!state.nativeAvailable) return;
    state.nativeStatusMessage = '正在准备配置...';
    let rawContent = state.proxyFetchRawContent;
    let subUrl = state.proxySubscriptionUrl;
    if (!rawContent || !subUrl) {
      state.nativeStatusMessage = '请先拉取订阅';
      return;
    }
    state.nativeStatusMessage = '正在生成 Clash 配置...';
    const configYaml = await ProxyService.prepareConfig(subUrl, rawContent);
    if (!configYaml) {
      state.nativeStatusMessage = '配置生成失败';
      return;
    }
    const ctx = AppStorage.get<common.UIAbilityContext>('appContext');
    if (!ctx) {
      state.nativeStatusMessage = '无法获取上下文';
      return;
    }
    const preparedPath = ctx.cacheDir + '/prepared_config.yaml';
    const encoder = new util.TextEncoder();
    const uint8Arr = encoder.encodeInto(configYaml);
    const file = fileIo.openSync(preparedPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);
    fileIo.writeSync(file.fd, uint8Arr.buffer);
    fileIo.closeSync(file);
    state.nativeStatusMessage = '正在启动内核...';
    const result = await ProxyService.startNativeProxy(preparedPath);
    if (result.success) {
      state.nativeRunning = true;
      state.nativeStatusMessage = '内核已启动';
      state.proxyMode = 'subscription';
      ProxyService.setMode('subscription');
    } else {
      state.nativeRunning = false;
      state.nativeStatusMessage = result.message ?? '启动失败';
    }
  }

  async stopNativeKernel(): Promise<void> {
    const state = this.state;
    if (!state.nativeAvailable) return;
    state.nativeStatusMessage = '正在停止...';
    const result = await ProxyService.stopNativeProxy();
    if (result.success) {
      state.nativeRunning = false;
      state.nativeStatusMessage = '内核已停止';
    } else {
      state.nativeStatusMessage = result.message ?? '停止失败';
    }
  }

  saveAutoStart(value: boolean): void {
    this.state.proxyAutoStart = value;
    ProxyService.saveAutoStart(value);
  }

  updateProxyHost(host: string): void {
    this.state.proxyHost = host;
    ProxyService.setHost(host);
  }

  updateProxyPort(port: string): void {
    this.state.proxyPort = port;
    const portNum = parseInt(port);
    if (!isNaN(portNum) && portNum > 0) {
      ProxyService.setPort(portNum);
    }
  }

  updateSubscriptionUrl(url: string): void {
    this.state.proxySubscriptionUrl = url;
    ProxyService.setSubscriptionUrl(url);
    this.state.proxyFetchState = 'idle';
    this.state.proxyFetchMessage = '';
  }
}
