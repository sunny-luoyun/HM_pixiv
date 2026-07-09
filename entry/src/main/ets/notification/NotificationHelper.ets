import notificationManager from '@ohos.notificationManager';
import wantAgent from '@ohos.wantAgent';

const ILLUST_GROUP = 'illust_update';
const NOVEL_GROUP = 'novel_update';

export class NotificationHelper {
  static async init(): Promise<void> {
    try {
      await notificationManager.addSlot(notificationManager.SlotType.SERVICE_INFORMATION);
    } catch (err) {
      console.error('创建通知渠道失败:', err);
    }
  }

  static async requestPermission(): Promise<void> {
    try {
      await notificationManager.requestEnableNotification();
      console.info('通知权限已获得');
    } catch (err) {
      console.error('请求通知权限失败:', err);
    }
  }

  static async publishIllustNotification(authorName: string, workTitle: string, workId: string): Promise<void> {
    try {
      await notificationManager.publish({
        id: Number(workId),
        notificationSlotType: notificationManager.SlotType.SERVICE_INFORMATION,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: '关注的作者更新',
            text: `${authorName} 发布了新插画《${workTitle}》`,
          },
        },
        groupName: ILLUST_GROUP,
        badgeNumber: 1,
        isAlertOnce: true,
      });
      console.info(`已发布插画通知: ${workTitle}`);
    } catch (err) {
      console.error('发布插画通知失败:', err);
    }
  }

  static async publishNovelNotification(authorName: string, workTitle: string, workId: string): Promise<void> {
    try {
      await notificationManager.publish({
        id: Number(workId),
        notificationSlotType: notificationManager.SlotType.SERVICE_INFORMATION,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: '关注的作者更新',
            text: `${authorName} 发布了新小说《${workTitle}》`,
          },
        },
        groupName: NOVEL_GROUP,
        badgeNumber: 1,
        isAlertOnce: true,
      });
      console.info(`已发布小说通知: ${workTitle}`);
    } catch (err) {
      console.error('发布小说通知失败:', err);
    }
  }
}
