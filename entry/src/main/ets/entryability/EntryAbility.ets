import { AbilityConstant, UIAbility, Want, Configuration } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { ConfigurationConstant } from '@kit.AbilityKit';
import fileIo from '@ohos.file.fs';
import { CookieStorage } from '../common/utils/CookieStorage';
import { TranslationStorage } from '../common/utils/TranslationStorage';
import { ProxyService } from '../services/ProxyService';
import { pixivCacheDB } from '../database/PixivCacheDB';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    CookieStorage.init(this.context);
    TranslationStorage.init(this.context);
    ProxyService.init(this.context);
    ProxyService.tryAutoStart();
    console.info('✅ CookieStorage + TranslationStorage + ProxyService 已初始化');

    setTimeout(() => {
      this.migrateImageCache();
    }, 500);

    TranslationStorage.getDeepSeekApiKey().then((key: string) => {
      AppStorage.setOrCreate('deepseekApiKey', key);
      if (key) {
        console.info('✅ DeepSeek API Key 已从磁盘恢复');
      }
    });

    TranslationStorage.getResetOnReachEnd().then((enabled: boolean) => {
      AppStorage.setOrCreate('resetOnReachEnd', enabled);
      console.info('✅ resetOnReachEnd 已从磁盘恢复: ' + enabled);
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

    // 颜色模式切换时同步更新状态栏内容颜色
    const contentColor = globalThis.isDarkMode ? '#FFFFFF' : '#000000';
    window.getLastWindow(this.context).then((w: window.Window) => {
      w.setWindowSystemBarProperties({
        statusBarContentColor: contentColor,
        navigationBarContentColor: contentColor,
      });
    });
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // 沉浸式窗口设置：透明系统栏，内容区域由系统自动避让状态栏
    const contentColor = globalThis.isDarkMode ? '#FFFFFF' : '#000000';
    windowStage.getMainWindow().then((mainWindow: window.Window) => {
      mainWindow.setWindowSystemBarProperties({
        statusBarContentColor: contentColor,
        navigationBarContentColor: contentColor,
      });
      console.info('✅ 沉浸式系统栏已启用');
    });

    windowStage.loadContent('pages/Index', (err) => {
      if (err) {
        console.error(`Failed to load content, error: ${JSON.stringify(err)}`);
        return;
      }
    });
  }

  async onBackground(): Promise<void> {
    console.info('[MX] Ability onBackground');
    const novelId = AppStorage.get<string>('bgNovelId') ?? '';
    if (novelId) {
      const scrollY = AppStorage.get<number>('bgScrollY') ?? 0;
      const isTranslated = AppStorage.get<boolean>('bgIsTranslated') ?? false;
      console.info(`[MX] onBackground save novelId=${novelId} scrollY=${scrollY}`);
      await pixivCacheDB.init(this.context);
      await pixivCacheDB.saveReadingProgress(novelId, scrollY, isTranslated);
      console.info('[MX] onBackground save done');
    } else {
      console.info('[MX] onBackground skipped: no novelId');
    }
  }

  private migrateImageCache(): void {
    const ctx = this.context;
    const oldDir = ctx.cacheDir;
    const newDir = ctx.filesDir + '/image_cache';
    try {
      fileIo.mkdirSync(newDir, true);
    } catch (_) {}
    const prefixes = ['illust_', 'novel_', 'user_', 'avatar_'];
    try {
      const files = fileIo.listFileSync(oldDir);
      for (const fileName of files) {
        if (!prefixes.some(p => fileName.startsWith(p))) continue;
        const src = oldDir + '/' + fileName;
        const dest = newDir + '/' + fileName;
        try {
          const testFile = fileIo.openSync(dest, fileIo.OpenMode.READ_ONLY);
          fileIo.closeSync(testFile);
          fileIo.unlinkSync(src);
          continue;
        } catch (_) {}
        try {
          const srcFile = fileIo.openSync(src, fileIo.OpenMode.READ_ONLY);
          const dstFile = fileIo.openSync(dest, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);
          fileIo.copyFileSync(srcFile.fd, dstFile.fd);
          fileIo.closeSync(srcFile);
          fileIo.closeSync(dstFile);
          fileIo.unlinkSync(src);
        } catch (_) {}
      }
    } catch (_) {}
  }
}