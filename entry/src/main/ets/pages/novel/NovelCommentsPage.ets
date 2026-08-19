import common from '@ohos.app.ability.common';
import { PageContext } from '../../common/utils/PageContext';
import { CommentsComponent } from '../../components/CommentsComponent';
import { AppApiService } from '../../services/AppApiService';
import { PixivService } from '../../services/PixivService';
import { pixivCacheDB } from '../../database/PixivCacheDB';

/** 清理简介文本：<br> 换行、去掉 HTML 标签、还原常见实体 */
function cleanNovelIntro(raw: string): string {
  if (!raw) return '';
  return raw
    .replace(/<br\s*\/?\s*>/gi, '\n')
    .replace(/<[^>]+>/g, '')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"');
}

@Component
struct NovelCommentsPage {
  @State navParams: Record<string, Object> = {};
  @State novelId: string = '';
  @State introTitle: string = '';
  @State introText: string = '';

  aboutToAppear() {
    // 参数由 onReady 获取
  }

  private async loadNovelIntro(): Promise<void> {
    if (!this.novelId) return;
    // 优先读取本地缓存（离线可用，且是这本小说自己的简介）
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      await pixivCacheDB.init(ctx);
      const novel = await pixivCacheDB.getNovelById(this.novelId);
      if (novel && novel.caption) {
        this.introTitle = '作品简介';
        this.introText = cleanNovelIntro(novel.caption);
        return;
      }
    } catch (e) {
      console.error('读取小说简介(缓存)失败:', e);
    }
    // 缓存缺失时回退到网络详情
    try {
      const detail = await PixivService.fetchNovelDetail(this.novelId);
      if (detail && detail.caption) {
        this.introTitle = '作品简介';
        this.introText = cleanNovelIntro(detail.caption);
      }
    } catch (e) {
      console.error('获取小说简介(网络)失败:', e);
    }
  }

  build() {
    NavDestination() {
    Column() {
      CommentsComponent({
        entityId: this.novelId,
        titleLabel: '小说评论',
        introTitle: this.introTitle,
        introText: this.introText,
        fetchComments: (id: string, offset: number) => PixivService.getNovelComments(id, offset),
        fetchReplies: (commentId: string, page: number) => PixivService.getNovelCommentReplies(commentId, page),
        deleteComment: (id: number) => AppApiService.deleteNovelComment(id),
        postComment: async (id: string, comment: string, parentCommentId?: string): Promise<void> => {
          await AppApiService.postNovelComment(Number(id), comment, parentCommentId ? Number(parentCommentId) : undefined);
        },
      })
    }
    .width('100%')
    .height('100%')
    }
    .onReady((ctx: NavDestinationContext) => {
      const params = ctx.pathInfo.param as Record<string, Object>;
      if (params) {
        const novelId = params['novelId'] as string;
        if (novelId) {
          this.novelId = novelId;
          this.loadNovelIntro();
        }
      }
    })
    .onBackPressed(() => {
      const pageCtx = AppStorage.get<PageContext>('rootPageContext');
      if (pageCtx) { pageCtx.popPage(); }
      return true;
    })
    .hideTitleBar(true)
  }
}

@Builder
export function NovelCommentsBuilder(): void {
  NovelCommentsPage()
}
