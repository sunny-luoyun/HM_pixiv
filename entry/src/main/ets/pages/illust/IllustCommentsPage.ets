import { PageContext } from '../../common/utils/PageContext';
import { CommentsComponent } from '../../components/CommentsComponent';
import { AppApiService } from '../../services/AppApiService';
import { PixivService } from '../../services/PixivService';

@Component
struct IllustCommentsPage {
  @State navParams: Record<string, Object> = {};
  @State illustId: string = '';

  aboutToAppear() {
    // 参数由 onReady 获取
  }

  build() {
    NavDestination() {
    Column() {
      CommentsComponent({
        entityId: this.illustId,
        titleLabel: '评论',
        fetchComments: (id: string, offset: number) => PixivService.getIllustComments(id, offset),
        deleteComment: (id: number) => AppApiService.deleteIllustComment(id),
      })
    }
    .width('100%')
    .height('100%')
    }
    .onReady((ctx: NavDestinationContext) => {
      const params = ctx.pathInfo.param as Record<string, Object>;
      if (params) {
        const illustId = params['illustId'] as string;
        if (illustId) { this.illustId = illustId; }
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
export function IllustCommentsBuilder(): void {
  IllustCommentsPage()
}
