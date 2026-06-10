import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import http from '@ohos.net.http';
import fileIo from '@ohos.file.fs';
import util from '@ohos.util';
import { AppState, appState } from '../../store/AppState';
import common from '@ohos.app.ability.common';
import { PixivService } from '../../services/PixivService';
import { pixivCacheDB } from '../../database/PixivCacheDB';
import { TranslationStorage } from '../../common/utils/TranslationStorage';
import { getDeepSeekService } from '../../services/DeepSeekService';
import { ProxyService, ProxyMode } from '../../services/ProxyService';
import { SubscriptionService } from '../../services/SubscriptionService';
import { SegmentedTabBar } from '../../components/SegmentedTabBar';
function formatFileSize(bytes: number): string {
  if (bytes <= 0) return '0 B';
  if (bytes < 1024) return bytes + ' B';
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
  return (bytes / (1024 * 1024)).toFixed(2) + ' MB';
}

@Entry
@Component
export struct SettingsPage {
  @StorageLink('appState') appState: AppState = appState;

  @State illustCacheSize: number = 0;
  @State illustCacheCount: number = 0;
  @State novelCoverCacheSize: number = 0;
  @State novelCoverCacheCount: number = 0;
  @State avatarCacheSize: number = 0;
  @State avatarCacheCount: number = 0;
  @State totalCacheSize: number = 0;
  @State cachedNovelCount: number = 0;
  @State isLoadingCache: boolean = true;
  @State deepseekApiKey: string = '';
  @State showApiKeyText: boolean = false;
  @State resetOnReachEnd: boolean = false;
  @State apiKeyCheckState: 'idle' | 'checking' | 'ok' | 'fail' = 'idle';
  @State balanceAmount: string = '';
  @State balanceFetchState: 'idle' | 'loading' | 'ok' | 'fail' = 'idle';
  @State ratioValue: number = 0;
  @State ratioCount: number = 0;

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
  aboutToAppear() {
    this.deepseekApiKey = AppStorage.get<string>('deepseekApiKey') ?? '';
    this.resetOnReachEnd = AppStorage.get<boolean>('resetOnReachEnd') ?? false;
    this.proxyMode = AppStorage.get<ProxyMode>('proxyMode') ?? 'off';
    this.proxyHost = AppStorage.get<string>('proxyHost') ?? '';
    const savedPort = AppStorage.get<number>('proxyPort') ?? 0;
    this.proxyPort = savedPort > 0 ? String(savedPort) : '';
    this.proxySubscriptionUrl = AppStorage.get<string>('proxySubscriptionUrl') ?? '';
    this.nativeAvailable = ProxyService.isNativeAvailable();
    this.proxyAutoStart = AppStorage.get<boolean>('proxyAutoStart') ?? false;
    this.loadRatioInfo();
    if (this.deepseekApiKey.length > 0) {
      this.fetchBalance();
    }
    this.initCache();
    this.checkNativeRunning();
    this.restoreProxyContent();
  }

  async restoreProxyContent(): Promise<void> {
    const raw = await ProxyService.getRawContent();
    if (raw) {
      this.proxyFetchRawContent = raw;
      this.proxyFetchState = 'ok';
      this.proxyFetchMessage = '订阅已保存';
    }
    const status = await ProxyService.getNativeStatus();
    this.nativeRunning = status.running ?? false;
  }

  async loadRatioInfo(): Promise<void> {
    const ctx = globalThis.appContext as common.UIAbilityContext;
    if (ctx) {
      const service = getDeepSeekService();
      await service.loadRatio(ctx);
      this.ratioValue = service.getAdaptiveRatio();
      this.ratioCount = service.getRatioCount();
    }
  }

  async checkApiKeyValidity(): Promise<void> {
    this.apiKeyCheckState = 'checking';
    const service = getDeepSeekService();
    const result = await service.fetchBalance(this.deepseekApiKey);
    if (result.success) {
      this.apiKeyCheckState = 'ok';
      this.balanceAmount = result.data;
      this.balanceFetchState = 'ok';
    } else {
      this.apiKeyCheckState = 'fail';
    }
  }

  async clearApiKey(): Promise<void> {
    this.deepseekApiKey = '';
    AppStorage.setOrCreate('deepseekApiKey', '');
    await TranslationStorage.clearDeepSeekApiKey();
    this.apiKeyCheckState = 'idle';
    this.balanceAmount = '';
    this.balanceFetchState = 'idle';
  }

  async fetchBalance(): Promise<void> {
    this.balanceFetchState = 'loading';
    const service = getDeepSeekService();
    const result = await service.fetchBalance(this.deepseekApiKey);
    if (result.success) {
      this.balanceAmount = result.data;
      this.balanceFetchState = 'ok';
    } else {
      this.balanceFetchState = 'fail';
    }
  }

  async initCache() {
    const ctx = globalThis.appContext as common.UIAbilityContext;
    if (ctx) {
      await pixivCacheDB.init(ctx);
    }
    await this.refreshCacheInfo();
  }

  async refreshCacheInfo() {
    this.isLoadingCache = true;
    try {
      const results = await Promise.all([
        PixivService.getCategoryCacheInfo('illust_'),
        PixivService.getCategoryCacheInfo('novel_'),
        PixivService.getCategoryCacheInfo('user_'),
        PixivService.getCategoryCacheInfo('avatar_'),
        pixivCacheDB.getCachedNovelCount()
      ]);
      const illust = results[0];
      const novelCover = results[1];
      const user = results[2];
      const avatar = results[3];
      const novelCount = results[4];
      this.illustCacheSize = illust.size;
      this.illustCacheCount = illust.count;
      this.novelCoverCacheSize = novelCover.size;
      this.novelCoverCacheCount = novelCover.count;
      this.avatarCacheSize = user.size + avatar.size;
      this.avatarCacheCount = user.count + avatar.count;
      this.totalCacheSize = illust.size + novelCover.size + user.size + avatar.size;
      this.cachedNovelCount = novelCount;
    } catch (err) {
      console.error('获取缓存信息失败:', err);
    }
    this.isLoadingCache = false;
  }

  async clearImageCache(category: string) {
    AlertDialog.show({
      title: '确认清除',
      message: `确定要清除${this.getCategoryLabel(category)}缓存吗？`,
      autoCancel: true,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '清除',
        fontColor: '#FF4D4F',
        action: async () => {
          try {
            if (category === 'illust') {
              await PixivService.clearCategoryCache('illust_');
            } else if (category === 'novel') {
              await PixivService.clearCategoryCache('novel_');
            } else if (category === 'avatar') {
              await PixivService.clearCategoryCache('user_');
              await PixivService.clearCategoryCache('avatar_');
            } else if (category === 'all') {
              await PixivService.clearAllImageCache();
            }
            await this.refreshCacheInfo();
          } catch (err) {
            console.error('清除缓存失败:', err);
          }
        }
      }
    });
  }

  async fetchSubscription(): Promise<void> {
    this.proxyFetchState = 'fetching';
    this.proxyFetchMessage = '正在拉取...';
    const result = await SubscriptionService.fetch(this.proxySubscriptionUrl);
    if (result.success) {
      this.proxyFetchState = 'ok';
      this.proxyFetchMessage = `拉取成功 ${result.fileName ? '(已保存)' : ''}`;
      this.proxyFetchRawContent = result.rawContent ?? '';
      ProxyService.saveRawContent(result.rawContent ?? '');
      if (result.fileName) {
        console.info(`订阅已保存到: ${SubscriptionService.getSavedFilePath(result.fileName)}`);
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
        const httpRequest = http.createHttp();
        try {
          this.proxyTestMessage = `正在测试 (第${attempt}次)...`;
          const resp = await httpRequest.request('https://www.pixiv.net/', {
            method: http.RequestMethod.GET,
            connectTimeout: 15000,
            readTimeout: 15000,
            usingProxy: config,
          });
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

    const ctx = globalThis.appContext as common.UIAbilityContext;
    const preparedPath = ctx.cacheDir + '/prepared_config.yaml';
    const encoder = new util.TextEncoder();
    const uint8Arr = encoder.encodeInto(configYaml);
    const file = fileIo.openSync(preparedPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);
    fileIo.writeSync(file.fd, uint8Arr.buffer);
    fileIo.closeSync(file);

    this.nativeStatusMessage = '正在启动内核...';
    const result = await ProxyService.startNativeProxy(preparedPath);
    if (result.success) {
      this.nativeRunning = true;
      this.nativeStatusMessage = '内核已启动';
      this.proxyMode = 'subscription';
      ProxyService.setMode('subscription');
    } else {
      this.nativeRunning = false;
      this.nativeStatusMessage = result.message ?? '启动失败';
    }
  }

  async stopNativeKernel(): Promise<void> {
    if (!this.nativeAvailable) return;
    this.nativeStatusMessage = '正在停止...';
    const result = await ProxyService.stopNativeProxy();
    if (result.success) {
      this.nativeRunning = false;
      this.nativeStatusMessage = '内核已停止';
    } else {
      this.nativeStatusMessage = result.message ?? '停止失败';
    }
  }

  getCategoryLabel(category: string): string {
    switch (category) {
      case 'illust': return '插画';
      case 'novel': return '小说封面';
      case 'avatar': return '头像';
      case 'all': return '图片';
      default: return '';
    }
  }

  async clearNovelCache() {
    AlertDialog.show({
      title: '确认清除',
      message: `确定要清除全部 ${this.cachedNovelCount} 篇已缓存的小说吗？`,
      autoCancel: true,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '清除',
        fontColor: '#FF4D4F',
        action: async () => {
          try {
            await pixivCacheDB.deleteAllCachedNovels();
            await this.refreshCacheInfo();
          } catch (err) {
            console.error('清除小说缓存失败:', err);
          }
        }
      }
    });
  }



  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.Friction })
      .slide(SlideEffect.Right)
    PageTransitionExit({ duration: 300, curve: Curve.Friction })
      .slide(SlideEffect.Right)
  }

  build() {
    Column() {
      Row() {
        Text('设置')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.user_name'))
        Blank()
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 12, bottom: 12 })
      .backgroundColor($r('app.color.glass_bg'))

      Scroll() {
        Column() {
        this.PixivLoginCard()
        this.DeepSeekApiKeyCard()
        this.ReadingSettingsCard()
        this.ProxyCard()
        this.CacheSection()
        }
        .width('100%')
        .padding({ top: 12 })
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  @Builder
  PixivLoginCard() {
    Column() {
      Row() {
        Row() {
          Text('Pixiv 登录状态')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.user_name'))

          if (this.appState.isLoggedIn) {
            Text(' ●').fontSize(12).fontColor($r('app.color.success'))
          }
        }.alignItems(VerticalAlign.Center)

        Blank()

        if (this.appState.isLoggedIn) {
          Text('已登录')
            .fontSize(13)
            .fontColor($r('app.color.success'))
        } else {
          Text('未登录')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(14)
    .shadow({ radius: 4, color: $r('app.color.card_shadow'), offsetY: 1 })
    .margin({ bottom: 12 })
  }

  @Builder
  DeepSeekApiKeyCard() {
    Column() {
      Row() {
        Row() {
          Text('DeepSeek API 密钥')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.user_name'))

          if (this.apiKeyCheckState === 'ok') {
            Text(' ●').fontSize(12).fontColor($r('app.color.success'))
          } else if (this.apiKeyCheckState === 'fail') {
            Text(' ●').fontSize(12).fontColor($r('app.color.danger'))
          } else if (this.deepseekApiKey.length > 0 && this.apiKeyCheckState === 'idle') {
            Text(' ●').fontSize(12).fontColor($r('app.color.warning'))
          }
        }.alignItems(VerticalAlign.Center)

        Blank()

        Text(this.showApiKeyText ? '隐藏' : '显示')
          .fontSize(13)
          .fontColor($r('app.color.tab_selected'))
          .onClick(() => {
            this.showApiKeyText = !this.showApiKeyText;
          })
      }
      .width('100%')
      .margin({ bottom: 10 })

      TextInput({
        text: this.deepseekApiKey,
        placeholder: '粘贴 DeepSeek API 密钥...'
      })
        .width('100%')
        .height(44)
        .fontSize(13)
        .fontColor($r('app.color.user_name'))
        .placeholderColor($r('app.color.text_secondary'))
        .backgroundColor($r('app.color.page_background'))
        .borderRadius(8)
        .padding({ left: 12, right: 12 })
        .border({
          width: 1,
          color: this.deepseekApiKey.length === 0
            ? $r('app.color.divider')
              : this.apiKeyCheckState === 'ok'
                ? $r('app.color.success')
                : this.apiKeyCheckState === 'fail'
                  ? $r('app.color.danger')
                : $r('app.color.tab_selected'),
          radius: 8
        })
        .type(this.showApiKeyText ? InputType.Normal : InputType.Password)
        .enableAutoFill(false)
        .onChange((val: string): void => {
          this.deepseekApiKey = val;
          this.apiKeyCheckState = 'idle';
          AppStorage.setOrCreate('deepseekApiKey', val);
          TranslationStorage.saveDeepSeekApiKey(val);
        })

      Row() {
        Button(this.apiKeyCheckState === 'checking' ? '验证中...' : '验证密钥')
          .fontSize(13)
          .height(36)
          .layoutWeight(1)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.tab_selected'))
          .borderRadius(8)
          .enabled(this.apiKeyCheckState !== 'checking' && this.deepseekApiKey.length > 0)
          .onClick(() => { this.checkApiKeyValidity(); })

        if (this.deepseekApiKey.length > 0) {
          Button('清除')
            .fontSize(13)
            .height(36)
            .fontColor($r('app.color.danger'))
            .backgroundColor(Color.Transparent)
            .borderRadius(8)
            .margin({ left: 8 })
            .onClick(() => { this.clearApiKey(); })
        }
      }
      .width('100%')
      .margin({ top: 12 })

      Text('前往 deepseek.com 注册获取 API 密钥，用于翻译日文小说标题和内容')
        .fontSize(11)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 10 })
        .lineHeight(18)

      if (this.deepseekApiKey.length > 0) {
        Divider()
          .strokeWidth(1)
          .color($r('app.color.divider'))
          .margin({ top: 14, bottom: 14 })

        Row() {
          Column() {
            Text('账户余额')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.user_name'))

            if (this.balanceFetchState === 'loading') {
              Text('查询中...')
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .margin({ top: 4 })
            } else if (this.balanceFetchState === 'ok' && this.balanceAmount !== '') {
              Text('¥ ' + this.balanceAmount)
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.brand_accent'))
                .margin({ top: 4 })
              Text('约可翻译 ' + (Math.floor(parseFloat(this.balanceAmount) * 53.63 * 10) / 10).toString() + ' 万字小说')
                .fontSize(11)
                .fontColor($r('app.color.text_secondary'))
                .margin({ top: 4 })
            } else if (this.balanceFetchState === 'fail') {
              Text('获取失败，请重试')
                .fontSize(12)
                .fontColor($r('app.color.danger'))
                .margin({ top: 4 })
            } else {
              Text('点击刷新查询余额')
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .margin({ top: 4 })
            }
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Button(this.balanceFetchState === 'loading' ? '查询中' : '↻ 刷新')
            .fontSize(13)
            .height(34)
            .padding({ left: 14, right: 14 })
            .fontColor($r('app.color.tab_selected'))
            .backgroundColor($r('app.color.page_background'))
            .borderRadius(8)
            .border({ width: 1, color: $r('app.color.tab_selected'), radius: 8 })
            .enabled(this.balanceFetchState !== 'loading')
            .onClick(() => { this.fetchBalance(); })
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        Text('估算仅供参考，以官方为准')
          .fontSize(10)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 8 })

        Divider()
          .strokeWidth(1)
          .color($r('app.color.divider'))
          .margin({ top: 14, bottom: 14 })

        Row() {
          Column() {
            Text('校准比例')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.user_name'))
            Text(`输出/输入比 ${this.ratioValue.toFixed(3)}（已校准 ${this.ratioCount} 次）`)
              .fontSize(11)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 2 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Button('重置校准')
            .fontSize(12)
            .height(32)
            .fontColor($r('app.color.danger'))
            .backgroundColor(Color.Transparent)
            .border({ width: 1, color: $r('app.color.danger'), radius: 8 })
            .padding({ left: 14, right: 14 })
            .onClick(() => {
              AlertDialog.show({
                title: '重置校准比例',
                message: '确定要重置输出/输入校准比例吗？重置后将恢复默认值 0.650，之前的校准数据将被清除。',
                autoCancel: true,
                primaryButton: {
                  value: '取消',
                  action: () => {}
                },
                secondaryButton: {
                  value: '重置',
                  fontColor: '#FF4D4F',
                  action: async () => {
                    const service = getDeepSeekService();
                    await service.resetAdaptiveRatio();
                    this.loadRatioInfo();
                    promptAction.showToast({ message: '校准比例已重置' });
                  }
                }
              });
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
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
  ReadingSettingsCard() {
    Column() {
      Row() {
        Column() {
          Text('到底重置进度')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.user_name'))
          Text('滑到小说底部后，不保存进度，下次从头开始阅读')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Toggle({ type: ToggleType.Switch, isOn: this.resetOnReachEnd })
          .onChange((isOn: boolean) => {
            this.resetOnReachEnd = isOn;
            AppStorage.setOrCreate('resetOnReachEnd', isOn);
            TranslationStorage.saveResetOnReachEnd(isOn);
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(14)
    .shadow({ radius: 4, color: $r('app.color.card_shadow'), offsetY: 1 })
    .margin({ bottom: 12 })
  }

  @Builder
  ProxyCard() {
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
        onChange: (index: number) => {
          const modes: ProxyMode[] = ['off', 'manual', 'subscription'];
          this.proxyMode = modes[index];
          ProxyService.setMode(this.proxyMode);
        }
      })
      .margin({ bottom: 14 })

      if (this.proxyMode === 'manual') {
        this.ManualProxyForm()
      } else if (this.proxyMode === 'subscription') {
        this.SubscriptionForm()
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
  ManualProxyForm() {
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
  SubscriptionForm() {
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

  @Builder
  CacheSection() {
    Column() {
      Text('缓存管理')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.user_name'))
        .width('100%')
        .margin({ bottom: 12 })

      Column() {
        Text('图片缓存')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.user_name'))
          .width('100%')
          .margin({ bottom: 8 })

        if (this.isLoadingCache) {
          Text('正在加载...')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 8, bottom: 8 })
        } else {
          this.CacheRow('插画缓存', this.illustCacheSize, this.illustCacheCount, () => { this.clearImageCache('illust') })
          this.CacheRow('小说封面', this.novelCoverCacheSize, this.novelCoverCacheCount, () => { this.clearImageCache('novel') })
          this.CacheRow('头像缓存', this.avatarCacheSize, this.avatarCacheCount, () => { this.clearImageCache('avatar') })
          Divider()
            .height(1)
            .color($r('app.color.divider'))
            .margin({ top: 8, bottom: 8 })
          this.CacheRow('总计', this.totalCacheSize, this.illustCacheCount + this.novelCoverCacheCount + this.avatarCacheCount, () => { this.clearImageCache('all') })
        }
      }
      .width('100%')
      .padding(16)
      .backgroundColor($r('app.color.card_bg'))
      .borderRadius(14)
      .shadow({ radius: 4, color: $r('app.color.card_shadow'), offsetY: 1 })
      .margin({ bottom: 12 })

      Column() {
        Row() {
          Column() {
            Text('小说缓存')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.user_name'))
            if (!this.isLoadingCache) {
              Text(`已缓存 ${this.cachedNovelCount} 篇小说`)
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))
                .margin({ top: 4 })
            }
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          Text('查看详情')
            .fontSize(13)
            .fontColor($r('app.color.tab_selected'))
            .margin({ right: 12 })
            .onClick(() => {
              router.pushUrl({ url: 'pages/settings/CachedNovelsSimplePage' });
            })
          Button('清除全部')
            .fontSize(13)
            .fontColor($r('app.color.danger'))
            .backgroundColor('#33FF4D4F')
            .borderRadius(16)
            .height(32)
            .padding({ left: 16, right: 16 })
            .onClick(() => { this.clearNovelCache() })
        }
        .width('100%')
      }
      .width('100%')
      .padding(16)
      .backgroundColor($r('app.color.card_bg'))
      .borderRadius(14)
      .shadow({ radius: 4, color: $r('app.color.card_shadow'), offsetY: 1 })
      .margin({ bottom: 12 })
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
    .margin({ top: 20 })
  }

  @Builder
  CacheRow(label: string, size: number, count: number, action: () => void) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor($r('app.color.user_name'))
      Blank()
      Text(`${formatFileSize(size)} (${count} 个文件)`)
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .margin({ right: 12 })
      Text('清除')
        .fontSize(13)
        .fontColor($r('app.color.danger'))
        .onClick(action)
    }
    .width('100%')
    .height(36)
  }
}
