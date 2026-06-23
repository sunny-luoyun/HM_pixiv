import { BaseState } from './BaseState';
import { BaseVM, BaseVMEvent } from './BaseVM';
import { BasicDataSource } from '../common/utils/BasicDataSource';
import { AjaxComment, AjaxCommentsResponse } from '../models/PixivModels';
import { AppState } from '../store/AppState';

export class CommentsEventType {
  static readonly LOAD_COMMENTS = 'LOAD_COMMENTS';
  static readonly LOAD_MORE = 'LOAD_MORE';
  static readonly DELETE_COMMENT = 'DELETE_COMMENT';
}

@Observed
export class CommentsState extends BaseState {
  entityId: string = '';
  titleLabel: string = '评论';
  emptyHint: string = '还没有人评论';
  totalComments: number = 0;
  commentSource: BasicDataSource<AjaxComment> = new BasicDataSource();
  isLoading: boolean = true;
  isLoadingMore: boolean = false;
  errorMsg: string = '';
  hasMore: boolean = false;
  deletingCommentId: number = -1;
  nextOffset: number = 0;
}

export class CommentsViewModel extends BaseVM<CommentsState> {
  private static instance: CommentsViewModel;
  private fetchCommentsFn: (id: string, offset: number) => Promise<AjaxCommentsResponse> = () => Promise.reject(new Error('not set'));
  private deleteCommentFn: (commentId: number) => Promise<void> = () => Promise.reject(new Error('not set'));
  private myUserId: string = '';

  static getInstance(): CommentsViewModel {
    if (!CommentsViewModel.instance) {
      CommentsViewModel.instance = new CommentsViewModel();
    }
    return CommentsViewModel.instance;
  }

  private constructor() {
    super(new CommentsState());
  }

  sendEvent(event: BaseVMEvent): void {
    switch (event.type) {
      case CommentsEventType.LOAD_COMMENTS:
        this.loadComments();
        break;
      case CommentsEventType.LOAD_MORE:
        this.loadMore();
        break;
      case CommentsEventType.DELETE_COMMENT:
        this.handleDelete((event.param as Record<string, number>)['commentId'] ?? 0);
        break;
    }
  }

  setup(entityId: string, titleLabel: string, emptyHint: string,
    fetchFn: (id: string, offset: number) => Promise<AjaxCommentsResponse>,
    deleteFn: (commentId: number) => Promise<void>): void {
    const state = this.state;
    state.entityId = entityId;
    state.titleLabel = titleLabel || '评论';
    state.emptyHint = emptyHint || '还没有人评论';
    this.fetchCommentsFn = fetchFn;
    this.deleteCommentFn = deleteFn;
    this.myUserId = AppState.getInstance().userId;
  }

  async loadComments(): Promise<void> {
    const state = this.state;
    if (!state.entityId) {
      state.errorMsg = '缺少ID';
      state.isLoading = false;
      return;
    }
    state.isLoading = true;
    state.errorMsg = '';
    try {
      const resp = await this.fetchCommentsFn(state.entityId, 0);
      if (!resp.error && resp.body) {
        state.commentSource.reset(resp.body.comments || []);
        state.totalComments = resp.body.total || 0;
        state.nextOffset = resp.body.comments ? resp.body.comments.length : 0;
        state.hasMore = state.commentSource.totalCount() < state.totalComments;
      } else {
        state.errorMsg = resp.message || '获取评论失败';
      }
    } catch (err) {
      console.error('获取评论失败:', err);
      state.errorMsg = '加载评论失败，请检查网络';
    }
    state.isLoading = false;
  }

  async loadMore(): Promise<void> {
    const state = this.state;
    if (state.isLoadingMore || !state.hasMore) return;
    state.isLoadingMore = true;
    try {
      const resp = await this.fetchCommentsFn(state.entityId, state.nextOffset);
      if (!resp.error && resp.body) {
        const newComments = resp.body.comments || [];
        state.commentSource.push(...newComments);
        state.nextOffset += newComments.length;
        state.hasMore = state.nextOffset < state.totalComments;
      }
    } catch (err) {
      console.error('加载更多评论失败:', err);
    }
    state.isLoadingMore = false;
  }

  async handleDelete(commentId: number): Promise<void> {
    const state = this.state;
    if (state.deletingCommentId === commentId) return;
    state.deletingCommentId = commentId;
    try {
      await this.deleteCommentFn(commentId);
      state.commentSource.reset(state.commentSource.getDataArray().filter(c => parseInt(c.id) !== commentId));
      if (state.totalComments > 0) {
        state.totalComments--;
      }
    } catch (err) {
      throw new Error('删除评论失败: ' + String(err));
    }
    state.deletingCommentId = -1;
  }

  isOwnComment(userId: number): boolean {
    const myId = parseInt(this.myUserId);
    return !isNaN(myId) && myId === userId;
  }

  formatDate(isoDate: string): string {
    if (!isoDate) return '';
    try {
      const d = new Date(isoDate);
      const year = d.getFullYear();
      const month = String(d.getMonth() + 1).padStart(2, '0');
      const day = String(d.getDate()).padStart(2, '0');
      const hour = String(d.getHours()).padStart(2, '0');
      const min = String(d.getMinutes()).padStart(2, '0');
      return `${year}-${month}-${day} ${hour}:${min}`;
    } catch (_) {
      return '';
    }
  }
}
