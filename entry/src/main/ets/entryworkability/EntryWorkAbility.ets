import WorkSchedulerExtensionAbility from '@ohos.WorkSchedulerExtensionAbility';
import preferences from '@ohos.data.preferences';
import { BusinessError } from '@kit.BasicServicesKit';
import { CookieStorage } from '../common/utils/CookieStorage';
import { ProxyService } from '../services/ProxyService';
import { LatestCheckService, CheckResult } from '../services/LatestCheckService';

const PREFERENCES_NAME = 'app_latest_check';
const KEY_WS_TRIGGERED_AT = 'wsTriggeredAt';
const KEY_WS_TRIGGER_COUNT = 'wsTriggerCount';

export default class EntryWorkAbility extends WorkSchedulerExtensionAbility {
  onWorkStart(): void {
    console.info('🔄 [后台调度] EntryWorkAbility onWorkStart');
    CookieStorage.init(this.context);
    ProxyService.init(this.context);
    this.recordTriggerTime();
    ProxyService.tryAutoStart().then(() => {
      return LatestCheckService.checkForUpdates(this.context);
    }).then((result: CheckResult) => {
      console.info(`后台检查完成: 插画=${result.illustCount}, 小说=${result.novelCount}`);
    }).catch((err: BusinessError) => {
      console.error('后台检查失败:', err);
    });
  }

  private async recordTriggerTime(): Promise<void> {
    try {
      const pref = await preferences.getPreferences(this.context, PREFERENCES_NAME);
      const count = await pref.get(KEY_WS_TRIGGER_COUNT, 0) as number;
      await pref.put(KEY_WS_TRIGGERED_AT, Date.now());
      await pref.put(KEY_WS_TRIGGER_COUNT, count + 1);
      await pref.flush();
    } catch (e) {
      console.error('记录后台触发时间失败:', e);
    }
  }

  onWorkStop(): void {
    console.info('EntryWorkAbility onWorkStop');
  }
}
