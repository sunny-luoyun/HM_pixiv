import router from '@ohos.router';
import { CommentsComponent } from '../../components/CommentsComponent';
import { AppApiService } from '../../services/AppApiService';
import { PixivService } from '../../services/PixivService';

@Entry
@Component
struct NovelCommentsPage {
  private novelId: string = '';

  aboutToAppear() {
    const params = router.getParams() as Record<string, Object>;
    this.novelId = params['novelId'] as string || '';
  }

  build() {
    Column() {
      CommentsComponent({
        entityId: this.novelId,
        titleLabel: '小说评论',
        fetchComments: (id: string, offset: number) => PixivService.getNovelComments(id, offset),
        postComment: (id: number, text: string) => AppApiService.postNovelComment(id, text),
        deleteComment: (id: number) => AppApiService.deleteNovelComment(id),
      })
    }
    .width('100%')
    .height('100%')
  }
}
