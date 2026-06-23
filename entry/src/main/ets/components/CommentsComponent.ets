import { PageContext } from '../common/utils/PageContext';
import promptAction from '@ohos.promptAction';
import { AjaxComment, AjaxCommentsResponse } from '../models/PixivModels';
import { BasicDataSource } from '../common/utils/BasicDataSource';
import { AppState } from '../store/AppState';
import { ImageComponent } from './ImageComponent';

@Component
export struct CommentsComponent {
  private entityId: string = '';
  private titleLabel: string = '评论';
  private emptyHint: string = '还没有人评论';
  private fetchComments: (id: string, offset: number) => Promise<AjaxCommentsResponse> = () => Promise.reject(new Error('not set'));
  private deleteComment: (commentId: number) => Promise<void> = () => Promise.reject(new Error('not set'));

  @State totalComments: number = 0;
  private commentSource: BasicDataSource<AjaxComment> = new BasicDataSource();
  @State isLoading: boolean = true;
  @State isLoadingMore: boolean = false;
  @State errorMsg: string = '';
  @State hasMore: boolean = false;
  @State deletingCommentId: number = -1;
  private nextOffset: number = 0;
  private appState: AppState = AppState.getInstance();

  aboutToAppear() {
    if (this.entityId) {
      this.loadComments();
    } else {
      this.errorMsg = '缺少ID';
      this.isLoading = false;
    }
  }

  async loadComments() {
    this.isLoading = true;
    this.errorMsg = '';
    try {
      const resp = await this.fetchComments(this.entityId, 0);
      if (!resp.error && resp.body) {
        this.commentSource.reset(resp.body.comments || []);
        this.totalComments = resp.body.total || 0;
        this.nextOffset = resp.body.comments ? resp.body.comments.length : 0;
        this.hasMore = this.commentSource.totalCount() < this.totalComments;
      } else {
        this.errorMsg = resp.message || '获取评论失败';
      }
      this.isLoading = false;
    } catch (err) {
      console.error('获取评论失败:', err);
      this.errorMsg = '加载评论失败，请检查网络';
      this.isLoading = false;
    }
  }

  async loadMore() {
    if (this.isLoadingMore || !this.hasMore) return;
    this.isLoadingMore = true;
    try {
      const resp = await this.fetchComments(this.entityId, this.nextOffset);
      if (!resp.error && resp.body) {
        const newComments = resp.body.comments || [];
        this.commentSource.push(...newComments);
        this.nextOffset += newComments.length;
        this.hasMore = this.nextOffset < this.totalComments;
      }
      this.isLoadingMore = false;
    } catch (err) {
      console.error('加载更多评论失败:', err);
      this.isLoadingMore = false;
    }
  }

  async handleDelete(commentId: number) {
    if (this.deletingCommentId === commentId) return;
    this.deletingCommentId = commentId;
    try {
      await this.deleteComment(commentId);
      this.commentSource.reset(this.commentSource.getDataArray().filter(c => parseInt(c.id) !== commentId));
      if (this.totalComments > 0) {
        this.totalComments--;
      }
      promptAction.showToast({ message: '评论已删除' });
    } catch (err) {
      promptAction.showToast({ message: '删除评论失败: ' + String(err) });
    }
    this.deletingCommentId = -1;
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

  isOwnComment(userId: number): boolean {
    const myId = parseInt(this.appState.userId);
    return !isNaN(myId) && myId === userId;
  }

  build() {
    Column() {
      Row() {
        Button({ type: ButtonType.Circle }) {
          Text('←').fontSize(20).fontColor(Color.White)
        }
        .width(36).height(36)
        .backgroundColor($r('app.color.overlay_light'))
        .onClick(() => {
          const pageCtx = AppStorage.get<PageContext>('rootPageContext');
          if (pageCtx) { pageCtx.popPage(); }
        })

        Text(`${this.titleLabel} (${this.totalComments})`)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .margin({ left: 12 })

        Blank()
      }
      .width('100%')
      .height(52)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)

      if (this.isLoading) {
        Column() {
          LoadingProgress().width(36).height(36).color($r('app.color.text_secondary'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.errorMsg) {
        Column() {
          Text(this.errorMsg).fontSize(14).fontColor($r('app.color.text_secondary'))
          Button('重试').margin({ top: 12 }).onClick(() => this.loadComments())
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.commentSource.totalCount() === 0) {
        Column() {
          Text('暂无评论').fontSize(14).fontColor($r('app.color.text_secondary'))
          Text(this.emptyHint).fontSize(12).fontColor($r('app.color.text_secondary')).margin({ top: 4 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ListItemGroup() {
            LazyForEach(this.commentSource, (comment: AjaxComment) => {
              ListItem() {
                Column() {
                  this.commentItem(comment)
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 12, bottom: 8 })
              }
            }, (comment: AjaxComment) => `comment_${comment.id}`)

            ListItem() {
              Row() {
                if (this.isLoadingMore) {
                  LoadingProgress().width(20).height(20).color($r('app.color.text_secondary'))
                } else if (this.hasMore) {
                  Text('加载更多')
                    .fontSize(12)
                    .fontColor($r('app.color.text_secondary'))
                    .onClick(() => this.loadMore())
                } else {
                  Text('— 没有更多了 —')
                    .fontSize(12)
                    .fontColor($r('app.color.text_secondary'))
                }
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .padding({ top: 12, bottom: 20 })
            }
          }
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .onReachEnd(() => this.loadMore())
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0f0f14')
  }

  @Builder
  commentItem(comment: AjaxComment) {
    Column() {
      Row() {
        if (comment.img) {
          ImageComponent({ src: comment.img, imgBorderRadius: 16, objectFit: ImageFit.Cover })
            .width(36).height(36)
        } else {
          Circle()
            .width(36).height(36)
            .fill($r('app.color.overlay_light'))
        }

        Column() {
          Row() {
            Text(comment.userName || '匿名用户')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .maxLines(1)

            if (this.isOwnComment(parseInt(comment.userId))) {
              if (this.deletingCommentId === parseInt(comment.id)) {
                LoadingProgress().width(14).height(14)
                  .color($r('app.color.danger'))
                  .margin({ left: 8 })
              } else {
                Text('删除')
                  .fontSize(11)
                  .fontColor($r('app.color.danger'))
                  .margin({ left: 8 })
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  .backgroundColor('#33FF0000')
                  .borderRadius(4)
                  .onClick(() => this.handleDelete(parseInt(comment.id)))
              }
            }
          }

          Row() {
            Text(this.formatDate(comment.date))
              .fontSize(11)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 1 })

            if (comment.hasReplies) {
              Text(' · 有回复')
                .fontSize(11)
                .fontColor($r('app.color.brand_accent'))
                .margin({ top: 1, left: 4 })
            }
          }
        }
        .margin({ left: 10 })
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Text(comment.comment)
        .fontSize(14)
        .fontColor('#CCCCCC')
        .margin({ top: 6, left: 46 })
        .width('100%')
    }
    .width('100%')
  }
}


