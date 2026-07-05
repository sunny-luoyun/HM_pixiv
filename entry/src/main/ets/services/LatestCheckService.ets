import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';
import { PixivService } from './PixivService';
import { CookieStorage } from '../common/utils/CookieStorage';
import { NotificationHelper } from '../notification/NotificationHelper';

const PREFERENCES_NAME = 'app_latest_check';
const KEY_LAST_ILLUST_IDS = 'lastIllustIds';
const KEY_LAST_NOVEL_IDS = 'lastNovelIds';
const KEY_FIRST_CHECK_DONE = 'firstCheckDone';
const KEY_LAST_CHECK_TIME = 'lastCheckTime';
const KEY_WORK_REGISTERED_AT = 'workRegisteredAt';
const KEY_WS_TRIGGERED_AT = 'wsTriggeredAt';
const KEY_WS_TRIGGER_COUNT = 'wsTriggerCount';
const REPEAT_CYCLE_MS = 7200000;

function formatTime(ts: number): string {
  const d = new Date(ts);
  const hh = String(d.getHours()).padStart(2, '0');
  const mm = String(d.getMinutes()).padStart(2, '0');
  const ss = String(d.getSeconds()).padStart(2, '0');
  return `${hh}:${mm}:${ss}`;
}

interface NewWork {
  authorName: string;
  workTitle: string;
  workId: string;
}

export interface CheckResult {
  illustCount: number;
  novelCount: number;
}

export class LatestCheckService {
  static async checkForUpdates(context: common.BaseContext): Promise<CheckResult> {
    const phpsessid = await CookieStorage.getPhpSessId();
    if (!phpsessid) {
      console.info('LatestCheck: 未登录，跳过检查');
      return { illustCount: 0, novelCount: 0 };
    }
    const illustCount = await LatestCheckService.checkIllustUpdates(context);
    const novelCount = await LatestCheckService.checkNovelUpdates(context);
    const now = Date.now();
    const pref = await preferences.getPreferences(context, PREFERENCES_NAME);
    await pref.put(KEY_LAST_CHECK_TIME, now);
    await pref.flush();
    const registeredAt = await pref.get(KEY_WORK_REGISTERED_AT, 0) as number;
    const lastCheckAt = await pref.get(KEY_LAST_CHECK_TIME, 0) as number;
    const wsTriggeredAt = await pref.get(KEY_WS_TRIGGERED_AT, 0) as number;
    const lastCheckStr = formatTime(now);
    const registeredStr = registeredAt > 0 ? formatTime(registeredAt) : '未知';
    let nextEstimate = '未知';
    if (wsTriggeredAt > 0) {
      nextEstimate = formatTime(wsTriggeredAt + REPEAT_CYCLE_MS);
    } else if (registeredAt > 0) {
      nextEstimate = formatTime(registeredAt + REPEAT_CYCLE_MS);
    }
    const wsTriggerCount = await pref.get(KEY_WS_TRIGGER_COUNT, 0) as number;
    const wsStr = wsTriggeredAt > 0 ? `${formatTime(wsTriggeredAt)}（累计 ${wsTriggerCount} 次）` : '无';
    console.info(`LatestCheck 完成: ${illustCount} 插画, ${novelCount} 小说`);
    console.info(`📋 参考注册时间: ${registeredStr}`);
    console.info(`📋 最近后台触发: ${wsStr}`);
    console.info(`📋 本次检查时间: ${lastCheckStr}`);
    console.info(`📋 周期: ${REPEAT_CYCLE_MS / 3600000}小时`);
    console.info(`📋 预计下次后台触发: ${nextEstimate}（实际由系统调度，可能有延迟）`);
    return { illustCount, novelCount };
  }

  private static async checkIllustUpdates(context: common.BaseContext): Promise<number> {
    try {
      const res = await PixivService.getFollowLatestIllusts(1, 'all');
      if (res.error) {
        console.warn('LatestCheck: 获取最新插画失败');
        return 0;
      }
      const works = res.body?.thumbnails?.illust ?? [];
      const currentIds = works.map(w => w.id);
      const pref = await preferences.getPreferences(context, PREFERENCES_NAME);
      const storedJson = await pref.get(KEY_LAST_ILLUST_IDS, '[]') as string;
      const storedIds: string[] = JSON.parse(storedJson);
      const firstCheckDone = await pref.get(KEY_FIRST_CHECK_DONE, false) as boolean;
      if (!firstCheckDone || storedIds.length === 0) {
        await pref.put(KEY_LAST_ILLUST_IDS, JSON.stringify(currentIds));
        await pref.put(KEY_FIRST_CHECK_DONE, true);
        await pref.flush();
        console.info('LatestCheck: 首次检查插画，仅保存状态');
        return 0;
      }
      const storedSet = new Set(storedIds);
      const newWorks: NewWork[] = [];
      for (let i = 0; i < works.length; i++) {
        const work = works[i];
        if (!storedSet.has(work.id)) {
          newWorks.push({ authorName: work.userName, workTitle: work.title, workId: work.id });
        }
      }
      for (let i = 0; i < newWorks.length; i++) {
        await NotificationHelper.publishIllustNotification(newWorks[i].authorName, newWorks[i].workTitle, newWorks[i].workId);
      }
      await pref.put(KEY_LAST_ILLUST_IDS, JSON.stringify(currentIds));
      await pref.flush();
      return newWorks.length;
    } catch (err) {
      console.error('LatestCheck 检查插画更新失败:', err);
      return 0;
    }
  }

  private static async checkNovelUpdates(context: common.BaseContext): Promise<number> {
    try {
      const res = await PixivService.getFollowLatestNovels(1, 'all');
      if (res.error) {
        console.warn('LatestCheck: 获取最新小说失败');
        return 0;
      }
      const works = res.body?.thumbnails?.novel ?? [];
      const currentIds = works.map(w => w.id);
      const pref = await preferences.getPreferences(context, PREFERENCES_NAME);
      const storedJson = await pref.get(KEY_LAST_NOVEL_IDS, '[]') as string;
      const storedIds: string[] = JSON.parse(storedJson);
      const firstCheckDone = await pref.get(KEY_FIRST_CHECK_DONE, false) as boolean;
      if (!firstCheckDone || storedIds.length === 0) {
        await pref.put(KEY_LAST_NOVEL_IDS, JSON.stringify(currentIds));
        await pref.put(KEY_FIRST_CHECK_DONE, true);
        await pref.flush();
        console.info('LatestCheck: 首次检查小说，仅保存状态');
        return 0;
      }
      const storedSet = new Set(storedIds);
      const newWorks: NewWork[] = [];
      for (let i = 0; i < works.length; i++) {
        const work = works[i];
        if (!storedSet.has(work.id)) {
          newWorks.push({ authorName: work.userName, workTitle: work.title, workId: work.id });
        }
      }
      for (let i = 0; i < newWorks.length; i++) {
        await NotificationHelper.publishNovelNotification(newWorks[i].authorName, newWorks[i].workTitle, newWorks[i].workId);
      }
      await pref.put(KEY_LAST_NOVEL_IDS, JSON.stringify(currentIds));
      await pref.flush();
      return newWorks.length;
    } catch (err) {
      console.error('LatestCheck 检查小说更新失败:', err);
      return 0;
    }
  }

  static async setRegisteredTime(context: common.BaseContext): Promise<void> {
    try {
      const pref = await preferences.getPreferences(context, PREFERENCES_NAME);
      const existing = await pref.get(KEY_WORK_REGISTERED_AT, 0) as number;
      if (existing > 0) {
        console.info(`📋 注册时间已记录（${formatTime(existing)}），跳过`);
        return;
      }
      const now = Date.now();
      await pref.put(KEY_WORK_REGISTERED_AT, now);
      await pref.flush();
      console.info(`📋 已记录注册时间点: ${formatTime(now)}`);
    } catch (err) {
      console.error('记录注册时间失败:', err);
    }
  }

  static async clearCheckState(context: common.BaseContext): Promise<void> {
    try {
      const pref = await preferences.getPreferences(context, PREFERENCES_NAME);
      await pref.delete(KEY_LAST_ILLUST_IDS);
      await pref.delete(KEY_LAST_NOVEL_IDS);
      await pref.delete(KEY_FIRST_CHECK_DONE);
      await pref.delete(KEY_LAST_CHECK_TIME);
      await pref.delete(KEY_WORK_REGISTERED_AT);
      await pref.flush();
    } catch (err) {
      console.error('清除 LatestCheck 状态失败:', err);
    }
  }
}
