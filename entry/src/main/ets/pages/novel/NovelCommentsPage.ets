import { PageContext } from '../../common/utils/PageContext';
import { CommentsComponent } from '../../components/CommentsComponent';
import { AppApiService } from '../../services/AppApiService';
import { PixivService } from '../../services/PixivService';

@Component
struct NovelCommentsPage {
  @State navParams: Record<string, Object> = {};
  @State novelId: string = '';

  aboutToAppear() {
    // 参数由 onReady 获取
  }

  build() {
    NavDestination() {
    Column() {
      CommentsComponent({
        entityId: this.novelId,
        titleLabel: '小说评论',
        fetchComments: (id: string, offset: number) => PixivService.getNovelComments(id, offset),
        deleteComment: (id: number) => AppApiService.deleteNovelComment(id),
        postComment: async (id: string, comment: string): Promise<void> => {
          await AppApiService.postNovelComment(Number(id), comment);
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
        if (novelId) { this.novelId = novelId; }
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
