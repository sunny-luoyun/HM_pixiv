import { describe, it, expect } from '@ohos/hypium';
import { AppApiService } from '../main/ets/services/AppApiService';
import { AjaxComment } from '../main/ets/models/PixivModels';

class MockV3User {
  id: number = 0;
  name: string = '';
  account: string = '';
  profile_image_urls: MockProfileUrls = new MockProfileUrls();
}

class MockProfileUrls {
  medium: string = '';
}

class MockStamp {
  stamp_id: number = 0;
  stamp_url: string = '';
}

class MockV3Comment {
  id: number = 0;
  comment: string = '';
  date: string = '';
  user: MockV3User = new MockV3User();
  stamp: MockStamp | null = null;
  has_replies: boolean = false;
  replies: MockV3Comment[] = [];
}

function mockUser(id: number, name: string, account: string): MockV3User {
  const u = new MockV3User();
  u.id = id;
  u.name = name;
  u.account = account;
  u.profile_image_urls.medium = 'https://example.com/icon.jpg';
  return u;
}

function transformV3Comment(raw: MockV3Comment): AjaxComment {
  const result: AjaxComment = {
    id: String(raw.id),
    comment: raw.comment,
    date: raw.date,
    userId: String(raw.user.id),
    userName: raw.user.name,
    userAccount: raw.user.account,
    img: raw.user.profile_image_urls.medium,
    hasReplies: raw.has_replies,
  };
  if (raw.replies && raw.replies.length > 0) {
    const replyList: AjaxComment[] = [];
    for (let i = 0; i < raw.replies.length; i++) {
      replyList.push(transformV3Comment(raw.replies[i]));
    }
    result.replies = replyList;
  }
  return result;
}

export default function appApiServiceTest() {
  describe('AppApiService', () => {
    describe('类结构', () => {
      it('AppApiService 应存在', 0, () => {
        expect(AppApiService !== null && AppApiService !== undefined).assertTrue();
      });

      it('应包含核心静态方法', 0, () => {
        expect(typeof AppApiService.addIllustBookmark).assertEqual('function');
        expect(typeof AppApiService.removeIllustBookmark).assertEqual('function');
        expect(typeof AppApiService.addNovelBookmark).assertEqual('function');
        expect(typeof AppApiService.removeNovelBookmark).assertEqual('function');
        expect(typeof AppApiService.getIllustComments).assertEqual('function');
        expect(typeof AppApiService.getUserIllusts).assertEqual('function');
        expect(typeof AppApiService.getUserNovels).assertEqual('function');
        expect(typeof AppApiService.followUser).assertEqual('function');
        expect(typeof AppApiService.unfollowUser).assertEqual('function');
      });
    });

    describe('评论数据转换（V3→Ajax）', () => {
      it('单条根评论转换', 0, () => {
        const v3 = new MockV3Comment();
        v3.id = 123;
        v3.comment = '测试评论';
        v3.date = '2025-01-01T00:00:00+00:00';
        v3.user = mockUser(1, '用户', 'user1');
        v3.has_replies = true;

        const ajax = transformV3Comment(v3);
        expect(ajax.id).assertEqual('123');
        expect(ajax.comment).assertEqual('测试评论');
        expect(ajax.userName).assertEqual('用户');
        expect(ajax.userId).assertEqual('1');
        expect(ajax.userAccount).assertEqual('user1');
        expect(ajax.hasReplies).assertTrue();
      });

      it('has_replies 为 false 时正确映射', 0, () => {
        const v3 = new MockV3Comment();
        v3.id = 456;
        v3.comment = 'no replies';
        v3.user = mockUser(2, 'u2', 'a2');
        v3.has_replies = false;

        const ajax = transformV3Comment(v3);
        expect(ajax.hasReplies).assertFalse();
      });

      it('回复嵌套转换', 0, () => {
        const reply = new MockV3Comment();
        reply.id = 2;
        reply.comment = 'reply';
        reply.user = mockUser(3, 'u3', 'a3');

        const v3 = new MockV3Comment();
        v3.id = 1;
        v3.comment = 'root';
        v3.user = mockUser(1, 'u1', 'a1');
        v3.has_replies = true;
        v3.replies = [reply];

        const ajax = transformV3Comment(v3);
        expect(ajax.replies !== undefined).assertTrue();
        if (ajax.replies) {
          expect(ajax.replies.length).assertEqual(1);
          expect(ajax.replies[0].id).assertEqual('2');
          expect(ajax.replies[0].comment).assertEqual('reply');
        }
      });
    });
  });
}
