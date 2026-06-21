import promptAction from '@ohos.promptAction';
import common from '@ohos.app.ability.common';
import { getDeepSeekService } from '../../services/DeepSeekService';
import { TranslationStorage } from '../../common/utils/TranslationStorage';
import { AppState, appState } from '../../store/AppState';

@Component
export struct TranslationSettingsSection {
  @StorageLink('appState') appState: AppState = appState;

  @State deepseekApiKey: string = '';
  @State showApiKeyText: boolean = false;
  @State apiKeyCheckState: 'idle' | 'checking' | 'ok' | 'fail' = 'idle';
  @State balanceAmount: string = '';
  @State balanceFetchState: 'idle' | 'loading' | 'ok' | 'fail' = 'idle';
  @State ratioValue: number = 0;
  @State ratioCount: number = 0;

  private pageActive: boolean = true;

  aboutToDisappear() {
    this.pageActive = false;
  }

  aboutToAppear() {
    this.deepseekApiKey = AppStorage.get<string>('deepseekApiKey') ?? '';
    this.loadRatioInfo();
    if (this.deepseekApiKey.length > 0) {
      this.fetchBalance();
    }
  }

  async loadRatioInfo(): Promise<void> {
    const ctx = globalThis.appContext as common.UIAbilityContext;
    if (ctx) {
      const service = getDeepSeekService();
      await service.loadRatio(ctx);
      if (!this.pageActive) return;
      this.ratioValue = service.getAdaptiveRatio();
      this.ratioCount = service.getRatioCount();
    }
  }

  async checkApiKeyValidity(): Promise<void> {
    this.apiKeyCheckState = 'checking';
    const service = getDeepSeekService();
    const result = await service.fetchBalance(this.deepseekApiKey);
    if (!this.pageActive) return;
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
    if (!this.pageActive) return;
    if (result.success) {
      this.balanceAmount = result.data;
      this.balanceFetchState = 'ok';
    } else {
      this.balanceFetchState = 'fail';
    }
  }

  build() {
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
}
