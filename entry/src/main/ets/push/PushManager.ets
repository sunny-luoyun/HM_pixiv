import { pushService } from '@kit.PushKit';
import { BusinessError } from '@kit.BasicServicesKit';
import Ability from '@ohos.app.ability.Ability';
import common from '@ohos.app.ability.common';
import { NotificationHelper } from '../notification/NotificationHelper';
import { LatestCheckService } from '../services/LatestCheckService';

interface PushPayload {
  type: 'illust' | 'novel';
  authorName: string;
  workTitle: string;
  workId: string;
}

export class PushManager {
  private static context: common.BaseContext;
  private static ability: Ability | null = null;

  static init(context: common.BaseContext, ability: Ability): void {
    PushManager.context = context;
    PushManager.ability = ability;

    PushManager.getToken();
    PushManager.registerMessageListener();
  }

  private static async getToken(): Promise<void> {
    try {
      const token = await pushService.getToken();
      AppStorage.setOrCreate('pushToken', token);
      console.info('🎯 ========== PUSH TOKEN ==========');
      console.info('🎯 ' + token);
      console.info('🎯 ================================');
    } catch (err) {
      const errObj = err as BusinessError;
      console.info('PushManager: 获取 Token 失败 code=' + errObj.code + ' msg=' + errObj.message);
      AppStorage.setOrCreate('pushToken', '');
    }
  }

  private static registerMessageListener(): void {
    const ability = PushManager.ability;
    if (!ability) return;
    try {
      pushService.receiveMessage('BACKGROUND', ability, (payload) => {
        if (payload?.data) {
          PushManager.handlePushPayload(payload.data);
        }
      });
      console.info('PushManager: 消息监听已注册');
    } catch (err) {
      console.info('PushManager: 注册消息监听失败:', err);
    }
  }

  private static async handlePushPayload(rawData: string): Promise<void> {
    try {
      const payload: PushPayload = JSON.parse(rawData);
      console.info(`PushManager: 收到推送 type=${payload.type} workId=${payload.workId}`);
      const ctx = PushManager.context;
      if (!ctx) return;
      if (payload.type === 'illust') {
        await NotificationHelper.publishIllustNotification(
          payload.authorName, payload.workTitle, payload.workId);
        await LatestCheckService.markWorkChecked(ctx, payload.workId, 'illust');
      } else if (payload.type === 'novel') {
        await NotificationHelper.publishNovelNotification(
          payload.authorName, payload.workTitle, payload.workId);
        await LatestCheckService.markWorkChecked(ctx, payload.workId, 'novel');
      }
    } catch (err) {
      console.error('PushManager: 处理推送消息失败:', err);
    }
  }
}
