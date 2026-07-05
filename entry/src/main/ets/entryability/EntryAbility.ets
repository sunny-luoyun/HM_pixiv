import { AbilityConstant, UIAbility, Want, Configuration } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { ConfigurationConstant } from '@kit.AbilityKit';
import workScheduler from '@ohos.resourceschedule.workScheduler';
import { BusinessError } from '@kit.BasicServicesKit';
import fileIo from '@ohos.file.fs';
import { CookieStorage } from '../common/utils/CookieStorage';
import { TranslationStorage } from '../common/utils/TranslationStorage';
import { ProxyService } from '../services/ProxyService';
import { pixivCacheDB } from '../database/PixivCacheDB';
import { StorageKeys } from '../common/constants/StorageKeys';
import { appState } from '../store/AppState';
import { NotificationHelper } from '../notification/NotificationHelper';
import { LatestCheckService, CheckResult } from '../services/LatestCheckService';

const WORK_ID_LATEST_CHECK = 1001;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    CookieStorage.init(this.context);
    TranslationStorage.init(this.context);
    ProxyService.init(this.context);
    ProxyService.tryAutoStart();
    console.info('✅ CookieStorage + TranslationStorage + ProxyService 已初始化');

    this.initNotifications();
    this.registerWorkScheduler();
    this.handleNotificationWant(want);

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

    const isDark = this.context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    AppStorage.setOrCreate(StorageKeys.APP_CONTEXT, this.context);
    AppStorage.setOrCreate(StorageKeys.IS_DARK_MODE, isDark);
    AppStorage.setOrCreate('appState', appState);
    AppStorage.setOrCreate('isLoggedIn', appState.isLoggedIn);
  }

  onForeground(): void {
    AppStorage.setOrCreate('appForegroundTick', new Date().getTime());
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    const isDark = newConfig.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    AppStorage.setOrCreate(StorageKeys.IS_DARK_MODE, isDark);

    const contentColor = isDark ? '#FFFFFF' : '#000000';
    window.getLastWindow(this.context).then((w: window.Window) => {
      w.setWindowSystemBarProperties({
        statusBarContentColor: contentColor,
        navigationBarContentColor: contentColor,
      });
    });
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    const contentColor = AppStorage.get<boolean>(StorageKeys.IS_DARK_MODE) ? '#FFFFFF' : '#000000';
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

  onNewWant(want: Want): void {
    this.handleNotificationWant(want);
  }

  private handleNotificationWant(want: Want): void {
    if (want?.parameters?.target === 'latestPage') {
      AppStorage.setOrCreate('notificationNavigateTab', 1);
    }
  }

  private async initNotifications(): Promise<void> {
    try {
      await NotificationHelper.init();
      await NotificationHelper.requestPermission();
    } catch (err) {
      console.error('通知初始化失败:', err);
    }
  }

  private registerWorkScheduler(): void {
    workScheduler.obtainAllWorks().then((works: workScheduler.WorkInfo[]) => {
      const exists = works.some((w) => w.workId === WORK_ID_LATEST_CHECK);
      if (exists) {
        console.info(`✅ 后台检查任务已存在（workId=${WORK_ID_LATEST_CHECK}），跳过注册`);
        for (let w of works) {
          console.info(`  workId=${w.workId}, isRepeat=${w.isRepeat}, repeatCycleTime=${w.repeatCycleTime}`);
        }
        LatestCheckService.setRegisteredTime(this.context);
        return;
      }
      const workInfo: workScheduler.WorkInfo = {
        workId: WORK_ID_LATEST_CHECK,
        bundleName: 'com.example.hpixiv',
        abilityName: 'EntryWorkAbility',
        isPersisted: true,
        isRepeat: true,
        repeatCycleTime: 7200000,
        networkType: workScheduler.NetworkType.NETWORK_TYPE_ANY,
      };
      workScheduler.startWork(workInfo);
      console.info('✅ 后台检查任务已注册，间隔2小时');
      LatestCheckService.setRegisteredTime(this.context);
      workScheduler.obtainAllWorks().then((all: workScheduler.WorkInfo[]) => {
        console.info(`验证：已注册 ${all.length} 个后台任务`);
        for (let w of all) {
          console.info(`  workId=${w.workId}, isRepeat=${w.isRepeat}, repeatCycleTime=${w.repeatCycleTime}`);
        }
      }).catch((err: Error) => {
        console.error('查询已注册任务失败:', err);
      });
    }).catch((err: Error) => {
      console.error('检查已注册任务失败，尝试直接注册:', err);
      try {
        const workInfo: workScheduler.WorkInfo = {
          workId: WORK_ID_LATEST_CHECK,
          bundleName: 'com.example.hpixiv',
          abilityName: 'EntryWorkAbility',
          isPersisted: true,
          isRepeat: true,
          repeatCycleTime: 7200000,
          networkType: workScheduler.NetworkType.NETWORK_TYPE_ANY,
        };
        workScheduler.startWork(workInfo);
        console.info('✅ 后台检查任务已注册（兜底），间隔2小时');
        LatestCheckService.setRegisteredTime(this.context);
      } catch (err2) {
        console.error('注册后台检查任务失败:', err2);
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