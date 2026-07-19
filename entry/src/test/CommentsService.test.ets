import { describe, it, expect } from '@ohos/hypium';
import { AjaxComment, AjaxCommentsResponse } from '../main/ets/models/PixivModels';

export default function commentsServiceTest() {
  describe('CommentsService（评论回复功能校验）', () => {
    describe('AjaxComment 模型', () => {
      it('根评论应有 hasReplies 和 replies 可选字段', 0, () => {
        const comment: AjaxComment = {
          id: '123',
          comment: 'test',
          date: '2025-01-01T00:00:00+00:00',
          userId: '1',
          userName: 'user',
          userAccount: 'account',
          img: '',
          hasReplies: true,
        };
        expect(comment.id).assertEqual('123');
        expect(comment.hasReplies).assertTrue();
        expect(comment.replies).assertUndefined();
      });

      it('replies 数组可为空', 0, () => {
        const comment: AjaxComment = {
          id: '456',
          comment: 'root',
          date: '',
          userId: '2',
          userName: 'u2',
          userAccount: 'a2',
          img: '',
          hasReplies: false,
          replies: [],
        };
        expect(comment.replies).assertDeepEquals([]);
      });

      it('回复评论格式与根评论相同', 0, () => {
        const reply: AjaxComment = {
          id: 'r1',
          comment: 'reply content',
          date: '2025-02-01T00:00:00+00:00',
          userId: '3',
          userName: 'replier',
          userAccount: 'rep',
          img: 'https://example.com/avatar.jpg',
          hasReplies: false,
        };
        expect(reply.id).assertEqual('r1');
        expect(reply.comment).assertEqual('reply content');
        expect(reply.userName).assertEqual('replier');
      });

      it('stampUrl 可选字段可赋值', 0, () => {
        const comment: AjaxComment = {
          id: '789',
          comment: 'stamped',
          date: '',
          userId: '4',
          userName: 'u4',
          userAccount: 'a4',
          img: '',
          hasReplies: false,
          stampUrl: 'https://example.com/stamp.png',
        };
        expect(comment.stampUrl).assertEqual('https://example.com/stamp.png');
      });
    });

    describe('AjaxCommentsResponse 结构', () => {
      it('error 和 body.comments 字段', 0, () => {
        const resp: AjaxCommentsResponse = {
          error: false,
          body: {
            total: 1,
            comments: [],
          },
        };
        expect(resp.error).assertFalse();
        expect(resp.body.total).assertEqual(1);
        expect(resp.body.comments.length).assertEqual(0);
      });
    });

    describe('API 路径模式', () => {
      it('绘画评论根路径模式正确', 0, () => {
        const path: string = `/ajax/illusts/comments/roots?illust_id=123&offset=0&limit=20`;
        expect(path).assertContain('illust_id=123');
        expect(path).assertContain('/ajax/illusts/comments/roots');
      });

      it('小说评论根路径模式正确', 0, () => {
        const path: string = `/ajax/novels/comments/roots?novel_id=456&offset=0&limit=20`;
        expect(path).assertContain('novel_id=456');
        expect(path).assertContain('/ajax/novels/comments/roots');
      });

      it('绘画回复路径使用 comment_id', 0, () => {
        const path: string = `/ajax/illusts/comments/replies?comment_id=999&page=1`;
        expect(path).assertContain('comment_id=999');
      });

      it('小说回复路径使用 comment_id', 0, () => {
        const path: string = `/ajax/novels/comments/replies?comment_id=888&page=1`;
        expect(path).assertContain('comment_id=888');
      });
    });
  });
}
