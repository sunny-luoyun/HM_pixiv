import { describe, it, expect } from '@ohos/hypium';
import { AjaxComment, AjaxCommentsResponse, AjaxCommentsBody } from '../main/ets/models/PixivModels';

export default function commentsServiceTest() {
  describe('CommentsService（评论回复功能校验）', () => {

    describe('AjaxComment 模型', () => {
      it('应有 replies 和 hasReplies 字段', 0, () => {
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

      it('回复返回格式与根评论相同', 0, () => {
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
        const resp: AjaxCommentsResponse = {
          error: false,
          body: {
            total: 1,
            comments: [reply],
          },
        };
        expect(resp.body.comments[0].id).assertEqual('r1');
        expect(resp.body.comments[0].comment).assertEqual('reply content');
        expect(resp.body.comments[0].userName).assertEqual('replier');
      });
    });

    describe('回复 API 路径', () => {
      it('绘画回复路径应使用 comment_id', 0, () => {
        const commentId: string = '999';
        const path: string = `/ajax/illusts/comments/replies?comment_id=${commentId}&page=1`;
        expect(path).assertContain('comment_id=999');
        expect(path).assertContain('page=1');
        expect(path).assertContain('/ajax/illusts/comments/replies');
      });

      it('小说回复路径应使用 comment_id', 0, () => {
        const commentId: string = '888';
        const path: string = `/ajax/novels/comments/replies?comment_id=${commentId}&page=1`;
        expect(path).assertContain('comment_id=888');
        expect(path).assertContain('/ajax/novels/comments/replies');
      });

      it('根评论路径应使用 illust_id + offset', 0, () => {
        const path: string = '/ajax/illusts/comments/roots?illust_id=123&offset=0&limit=20';
        expect(path).assertContain('illust_id=123');
        expect(path).assertContain('offset=0');
        expect(path).assertContain('/ajax/illusts/comments/roots');
      });
    });

    describe('PixivService 转发方法', () => {
      it('getIllustCommentReplies 应接受 commentId 和 page', 0, () => {
        const fn: string = 'getIllustCommentReplies';
        const params: string[] = ['commentId', 'page'];
        expect(fn).assertEqual('getIllustCommentReplies');
        expect(params.length).assertEqual(2);
      });

      it('getNovelCommentReplies 应接受 commentId 和 page', 0, () => {
        const fn: string = 'getNovelCommentReplies';
        const params: string[] = ['commentId', 'page'];
        expect(fn).assertEqual('getNovelCommentReplies');
        expect(params.length).assertEqual(2);
      });
    });
  });
}
