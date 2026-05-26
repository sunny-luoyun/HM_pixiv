import { AbilityConstant, UIAbility, Want, Configuration } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { CookieStorage } from '../common/utils/CookieStorage';
import { TranslationStorage } from '../common/utils/TranslationStorage';
import { ProxyService } from '../services/ProxyService';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    CookieStorage.init(this.context);
    TranslationStorage.init(this.context);
    ProxyService.init(this.context);
    console.info('✅ CookieStorage + TranslationStorage + ProxyService 已初始化');

    TranslationStorage.getDeepSeekApiKey().then((key: string) => {
      AppStorage.setOrCreate('deepseekApiKey', key);
      if (key) {
        console.info('✅ DeepSeek API Key 已从磁盘恢复');
      }
    });

    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    globalThis.appContext = this.context;

    globalThis.isDarkMode = this.context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    AppStorage.SetOrCreate('isDarkMode', globalThis.isDarkMode);
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    // 监听配置变化（包括颜色模式）
    globalThis.isDarkMode = newConfig.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    AppStorage.SetOrCreate('isDarkMode', globalThis.isDarkMode);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
      if (err) {
        console.error(`Failed to load content, error: ${JSON.stringify(err)}`);
        return;
      }
    });
    setTimeout(() => {
      ProxyService.tryAutoStart();
    }, 3000);
  }
}