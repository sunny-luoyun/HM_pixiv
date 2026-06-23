import router from '@ohos.router';
import { CommentsComponent } from '../../components/CommentsComponent';
import { AppApiService } from '../../services/AppApiService';
import { PixivService } from '../../services/PixivService';

@Entry
@Component
struct IllustCommentsPage {
  private illustId: string = '';

  aboutToAppear() {
    const params = router.getParams() as Record<string, Object>;
    this.illustId = params['illustId'] as string || '';
  }

  build() {
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
}
