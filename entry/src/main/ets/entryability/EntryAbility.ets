import { AbilityConstant, UIAbility, Want, Configuration } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { CookieStorage } from '../common/utils/CookieStorage';
import { TokenStorage } from '../common/utils/TokenStorage';
import { TranslationStorage } from '../common/utils/TranslationStorage';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    CookieStorage.init(this.context);
    TokenStorage.init(this.context);
    TranslationStorage.init(this.context);
    console.info('✅ CookieStorage + TokenStorage + TranslationStorage 已初始化');

    TranslationStorage.getDeepSeekApiKey().then((key: string) => {
      AppStorage.setOrCreate('deepseekApiKey', key);
      if (key) {
        console.info('✅ DeepSeek API Key 已从磁盘恢复');
      }
    });

    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    globalThis.appContext = this.context;

    globalThis.isDarkMode = this.context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    // 监听配置变化（包括颜色模式）
    globalThis.isDarkMode = newConfig.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
      if (err) {
        console.error(`Failed to load content, error: ${JSON.stringify(err)}`);
        return;
      }
    });
  }
}