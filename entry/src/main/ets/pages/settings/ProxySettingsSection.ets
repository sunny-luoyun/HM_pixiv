import http from '@ohos.net.http';
import fileIo from '@ohos.file.fs';
import util from '@ohos.util';
import common from '@ohos.app.ability.common';
import { ApiConfig } from '../../common/constants/ApiConfig';
import { ProxyService, ProxyMode } from '../../services/ProxyService';
import { SubscriptionService } from '../../services/SubscriptionService';
import { SegmentedTabBar } from '../../components/SegmentedTabBar';

@Component
export struct ProxySettingsSection {
  @State proxyMode: ProxyMode = 'off';
  @State proxyHost: string = '';
  @State proxyPort: string = '';
  @State proxySubscriptionUrl: string = '';
  @State proxyFetchState: 'idle' | 'fetching' | 'ok' | 'fail' = 'idle';
  @State proxyFetchMessage: string = '';
  @State proxyFetchRawContent: string = '';
  @State proxyAutoStart: boolean = false;
  @State proxyTestState: 'idle' | 'testing' | 'ok' | 'fail' = 'idle';
  @State proxyTestMessage: string = '';
  @State nativeRunning: boolean = false;
  @State nativeAvailable: boolean = false;
  @State nativeStatusMessage: string = '';
  private pageActive: boolean = true;

  aboutToDisappear() {
    this.pageActive = false;
  }

  aboutToAppear() {
    this.proxyMode = AppStorage.get<ProxyMode>('proxyMode') ?? 'off';
    this.proxyHost = AppStorage.get<string>('proxyHost') ?? '';
    const savedPort = AppStorage.get<number>('proxyPort') ?? 0;
    this.proxyPort = savedPort > 0 ? String(savedPort) : '';
    this.proxySubscriptionUrl = AppStorage.get<string>('proxySubscriptionUrl') ?? '';
    this.nativeAvailable = ProxyService.isNativeAvailable();
    this.proxyAutoStart = AppStorage.get<boolean>('proxyAutoStart') ?? false;
    this.restoreProxyContent();
  }

  async restoreProxyContent(): Promise<void> {
    const raw = await ProxyService.getRawContent();
    if (!this.pageActive) return;
    if (raw) {
      this.proxyFetchRawContent = raw;
      this.proxyFetchState = 'ok';
      this.proxyFetchMessage = '订阅已保存';
    }
  }

  async fetchSubscription(): Promise<void> {
    this.proxyFetchState = 'fetching';
    this.proxyFetchMessage = '正在拉取...';
    const result = await SubscriptionService.fetch(this.proxySubscriptionUrl);
    if (!this.pageActive) return;
    if (result.success) {
      this.proxyFetchState = 'ok';
      this.proxyFetchMessage = `拉取成功 ${result.fileName ? '(已保存)' : ''}`;
      this.proxyFetchRawContent = result.rawContent ?? '';
      ProxyService.saveRawContent(result.rawContent ?? '');
      if (result.fileName) {
        console.info(`订阅已保存到: ${SubscriptionService.getSavedFilePath(result.fileName)}`);
      }
      if (this.nativeRunning) {
        console.info('🔄 订阅已更新，重新启动内核');
        await this.stopNativeKernel();
        await this.startNativeKernel();
      }
    } else {
      this.proxyFetchState = 'fail';
      this.proxyFetchMessage = result.error || '拉取失败';
    }
  }

  async testProxyConnection(): Promise<void> {
    this.proxyTestState = 'testing';
    this.proxyTestMessage = '正在测试（最多尝试30秒）...';
    try {
      if (this.proxyMode === 'subscription' && !this.nativeRunning) {
        this.proxyTestState = 'fail';
        this.proxyTestMessage = '内核未启动，请先启动内核';
        return;
      }
      if (this.proxyMode === 'manual') {
        await ProxyService.setManualProxy(this.proxyHost, parseInt(this.proxyPort) || 0);
      }
      const config = await ProxyService.getRequestProxyConfig();
      if (!config) {
        this.proxyTestState = 'fail';
        this.proxyTestMessage = '代理配置无效';
        return;
      }

      for (let attempt = 1; attempt <= 3; attempt++) {
        if (attempt > 1) {
          await new Promise<void>(resolve => setTimeout(resolve, 3000));
        }
        if (!this.pageActive) return;
        const httpRequest = http.createHttp();
        try {
          this.proxyTestMessage = `正在测试 (第${attempt}次)...`;
          const resp = await httpRequest.request(ApiConfig.PIXIV_WEB + '/', {
            method: http.RequestMethod.GET,
            connectTimeout: 15000,
            readTimeout: 15000,
            usingProxy: config,
          });
          if (!this.pageActive) return;
          if (resp.responseCode === 200) {
            this.proxyTestState = 'ok';
            this.proxyTestMessage = '';
            httpRequest.destroy();
            return;
          }
          httpRequest.destroy();
        } catch (_) {
          httpRequest.destroy();
          if (attempt >= 3) {
            this.proxyTestState = 'fail';
            this.proxyTestMessage = '连接代理服务器失败（提供商正在初始化）';
          }
        }
      }
    } catch (_) {
      this.proxyTestState = 'fail';
      this.proxyTestMessage = '测试异常';
    }
  }

  async checkNativeRunning(): Promise<void> {
    if (!this.nativeAvailable) return;
    const status = await ProxyService.getNativeStatus();
    if (!this.pageActive) return;
    this.nativeRunning = status.running ?? false;
    if (status.message) {
      this.nativeStatusMessage = status.message;
    }
  }

  async startNativeKernel(): Promise<void> {
    if (!this.nativeAvailable) return;
    this.nativeStatusMessage = '正在准备配置...';

    let rawContent = this.proxyFetchRawContent;
    let subUrl = this.proxySubscriptionUrl;

    if (!rawContent || !subUrl) {
      this.nativeStatusMessage = '请先拉取订阅';
      return;
    }

    this.nativeStatusMessage = '正在生成 Clash 配置...';
    const configYaml = await ProxyService.prepareConfig(subUrl, rawContent);
    if (!configYaml) {
      this.nativeStatusMessage = '配置生成失败';
      return;
    }
    if (!this.pageActive) return;

    const ctx = AppStorage.get<common.UIAbilityContext>('appContext');
    if (!ctx) return;
    const preparedPath = ctx.cacheDir + '/prepared_config.yaml';
    const encoder = new util.TextEncoder();
    const uint8Arr = encoder.encodeInto(configYaml);
    const file = fileIo.openSync(preparedPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);
    fileIo.writeSync(file.fd, uint8Arr.buffer);
    fileIo.closeSync(file);

    this.nativeStatusMessage = '正在启动内核...';
    const result = await ProxyService.startNativeProxy(preparedPath);
    if (!this.pageActive) return;
    if (result.success) {
      this.nativeRunning = true;
      this.nativeStatusMessage = '内核已启动';
      this.proxyMode = 'subscription';
      ProxyService.setMode('subscription');
    } else {
      if (result.message?.includes('already running')) {
        this.nativeRunning = true;
        this.nativeStatusMessage = '内核已在运行';
        this.proxyMode = 'subscription';
        ProxyService.setMode('subscription');
      } else {
        this.nativeRunning = false;
        this.nativeStatusMessage = result.message ?? '启动失败';
      }
    }
  }

  async stopNativeKernel(): Promise<void> {
    if (!this.nativeAvailable) return;
    this.nativeStatusMessage = '正在停止...';
    const result = await ProxyService.stopNativeProxy();
    if (!this.pageActive) return;
    if (result.success) {
      this.nativeRunning = false;
      this.nativeStatusMessage = '内核已停止';
    } else {
      this.nativeStatusMessage = result.message ?? '停止失败';
    }
  }

  build() {
    Column() {
      Row() {
        Text('代理设置')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.user_name'))
        Blank()
        if (this.proxyMode === 'subscription' && this.nativeRunning) {
          Text('● 内核运行中')
            .fontSize(12)
            .fontColor($r('app.color.success'))
        } else if (this.proxyMode !== 'off') {
          Text('● 代理已启用')
            .fontSize(12)
            .fontColor($r('app.color.success'))
        } else {
          Text('● 已关闭')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
        }
      }
      .width('100%')
      .margin({ bottom: 12 })

      SegmentedTabBar({
        tabs: ['关闭', '手动', '订阅'],
        currentIndex: this.proxyMode === 'off' ? 0 : this.proxyMode === 'manual' ? 1 : 2,
        swipeProgress: 0,
        onChange: (index: number) => {
          const modes: ProxyMode[] = ['off', 'manual', 'subscription'];
          this.proxyMode = modes[index];
          ProxyService.setMode(this.proxyMode);
        }
      })
      .margin({ bottom: 14 })

      if (this.proxyMode === 'manual') {
        this.buildManualProxyForm()
      } else if (this.proxyMode === 'subscription') {
        this.buildSubscriptionForm()
      }

      if (this.proxyMode !== 'off') {
        Divider().strokeWidth(1).color($r('app.color.divider')).margin({ top: 12, bottom: 12 })

        Row() {
          Button(this.proxyTestState === 'testing' ? '测试中...' : '测试代理连接')
            .fontSize(13)
            .height(36)
            .width('100%')
            .fontColor(Color.White)
            .backgroundColor($r('app.color.tab_selected'))
            .borderRadius(8)
            .enabled(this.proxyTestState !== 'testing')
            .onClick(() => { this.testProxyConnection(); })
        }

        if (this.proxyTestState === 'ok') {
          Text('✓ 连接成功')
            .fontSize(12)
            .fontColor($r('app.color.success'))
            .margin({ top: 6 })
        } else if (this.proxyTestState === 'fail') {
          Text('✗ ' + (this.proxyTestMessage || '连接失败'))
            .fontSize(12)
            .fontColor($r('app.color.danger'))
            .margin({ top: 6 })
        }
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(14)
    .shadow({ radius: 4, color: $r('app.color.card_shadow'), offsetY: 1 })
    .margin({ bottom: 12 })
  }

  @Builder
  buildManualProxyForm() {
    Column() {
      TextInput({ text: this.proxyHost, placeholder: '代理地址 (如 192.168.1.100)' })
        .width('100%')
        .height(44)
        .fontSize(14)
        .fontColor($r('app.color.user_name'))
        .placeholderColor($r('app.color.text_secondary'))
        .backgroundColor($r('app.color.page_background'))
        .borderRadius(8)
        .padding({ left: 12, right: 12 })
        .border({ width: 1, color: $r('app.color.divider'), radius: 8 })
        .onChange((val: string) => {
          this.proxyHost = val;
          ProxyService.setHost(val);
        })

      TextInput({ text: this.proxyPort, placeholder: '端口 (如 8080)' })
        .width('100%')
        .height(44)
        .fontSize(14)
        .fontColor($r('app.color.user_name'))
        .placeholderColor($r('app.color.text_secondary'))
        .backgroundColor($r('app.color.page_background'))
        .borderRadius(8)
        .padding({ left: 12, right: 12 })
        .margin({ top: 8 })
        .border({ width: 1, color: $r('app.color.divider'), radius: 8 })
        .type(InputType.Number)
        .onChange((val: string) => {
          this.proxyPort = val;
          const portNum = parseInt(val);
          if (!isNaN(portNum) && portNum > 0) {
            ProxyService.setPort(portNum);
          }
        })

      Text('输入你的 HTTP/HTTPS 代理服务器地址和端口。订阅模式需要 Phase 2 原生内核支持。')
        .fontSize(11)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 10 })
        .lineHeight(18)
    }
    .width('100%')
  }

  @Builder
  buildSubscriptionForm() {
    Column() {
      TextInput({ text: this.proxySubscriptionUrl, placeholder: '机场订阅链接 (Clash 格式)' })
        .width('100%')
        .height(44)
        .fontSize(13)
        .fontColor($r('app.color.user_name'))
        .placeholderColor($r('app.color.text_secondary'))
        .backgroundColor($r('app.color.page_background'))
        .borderRadius(8)
        .padding({ left: 12, right: 12 })
        .border({ width: 1, color: $r('app.color.divider'), radius: 8 })
        .onChange((val: string) => {
          this.proxySubscriptionUrl = val;
          ProxyService.setSubscriptionUrl(val);
          this.proxyFetchState = 'idle';
          this.proxyFetchMessage = '';
        })

      Row() {
        Button(this.proxyFetchState === 'fetching' ? '拉取中...' : '拉取订阅')
          .fontSize(13)
          .height(36)
          .layoutWeight(1)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.tab_selected'))
          .borderRadius(8)
          .enabled(this.proxyFetchState !== 'fetching' && this.proxySubscriptionUrl.length > 0)
          .onClick(() => { this.fetchSubscription(); })
      }
      .width('100%')
      .margin({ top: 10 })

      if (this.proxyFetchState === 'ok') {
        Text('✓ ' + this.proxyFetchMessage)
          .fontSize(12)
          .fontColor($r('app.color.success'))
          .margin({ top: 6 })
      } else if (this.proxyFetchState === 'fail') {
        Text('✗ ' + this.proxyFetchMessage)
          .fontSize(12)
          .fontColor($r('app.color.danger'))
          .margin({ top: 6 })
      }

      Divider().strokeWidth(1).color($r('app.color.divider')).margin({ top: 12, bottom: 12 })

      Row() {
        Column() {
          Text('开机自启')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.user_name'))
          Text('启动应用时自动启动内核并连接')
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Toggle({ type: ToggleType.Switch, isOn: this.proxyAutoStart })
          .onChange((isOn: boolean) => {
            this.proxyAutoStart = isOn;
            ProxyService.saveAutoStart(isOn);
          })
      }
      .width('100%')
      .margin({ bottom: 12 })

      Row() {
        if (this.nativeAvailable) {
          Text('● 原生内核可用')
            .fontSize(12)
            .fontColor($r('app.color.success'))
        } else {
          Text('● 原生内核不可用')
            .fontSize(12)
            .fontColor($r('app.color.warning'))
        }
      }
      .margin({ bottom: 8 })

      if (this.nativeAvailable) {
        Row() {
          if (this.nativeRunning) {
            Button('停止内核')
              .fontSize(13)
              .height(36)
              .layoutWeight(1)
              .fontColor($r('app.color.danger'))
              .backgroundColor('#33FF4D4F')
              .borderRadius(8)
              .margin({ right: 6 })
              .onClick(() => { this.stopNativeKernel(); })

            Text('● 运行中')
              .fontSize(12)
              .fontColor($r('app.color.success'))
              .margin({ left: 6 })
          } else {
            Button('启动内核')
              .fontSize(13)
              .height(36)
              .layoutWeight(1)
              .fontColor(Color.White)
              .backgroundColor($r('app.color.tab_selected'))
              .borderRadius(8)
              .margin({ right: 6 })
              .onClick(() => { this.startNativeKernel(); })
          }
        }
        .width('100%')

        if (this.nativeStatusMessage) {
          Text(this.nativeStatusMessage)
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 4 })
        }
      } else {
        if (ProxyService.nativeErrorMessage) {
          Text('✗ ' + ProxyService.nativeErrorMessage)
            .fontSize(11)
            .fontColor($r('app.color.danger'))
            .margin({ top: 6 })
            .lineHeight(18)
        } else {
          Text('原生内核未加载')
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 6 })
            .lineHeight(18)
        }
      }
    }
    .width('100%')
  }
}
