import router from '@ohos.router';
import { AppApiService } from '../../services/AppApiService';
import { PixivService, IllustBookmark, NovelBookmark, BookmarkData, ProfileIllust, ProfileNovel } from '../../services/PixivService';
import { IllustCard } from '../../components/IllustCard';
import { NovelCard } from '../../components/NovelCard';

const PAGE_SIZE = 30;

function mapProfileIllustToBookmark(item: ProfileIllust, defaultName: string = ''): IllustBookmark {
  return {
    id: item.id,
    title: item.title,
    illustType: item.illustType,
    url: item.url,
    tags: item.tags,
    userId: item.userId,
    userName: item.userName || defaultName,
    width: item.width,
    height: item.height,
    pageCount: item.pageCount,
    bookmarkData: item.bookmarkData || { id: item.id, private: false, userId: item.userId } as BookmarkData,
    profileImageUrl: item.profileImageUrl || '',
    createDate: item.createDate || '',
  };
}

function extractNovelWorks(body: object): Record<string, ProfileNovel> {
  const bodyAny = body as Record<string, Object>;
  if (bodyAny['works'] && typeof bodyAny['works'] === 'object') {
    const works = bodyAny['works'] as Record<string, ProfileNovel>;
    if (Object.keys(works).length > 0) return works;
  }
  const direct: Record<string, ProfileNovel> = {};
  const keys = Object.keys(bodyAny);
  for (let i = 0; i < keys.length; i++) {
    const val = bodyAny[keys[i]];
    if (val && typeof val === 'object' && (val as Record<string, Object>)['id']) {
      direct[keys[i]] = val as ProfileNovel;
    }
  }
  return direct;
}

function mapProfileNovelToBookmark(item: ProfileNovel, defaultName: string = ''): NovelBookmark {
  return {
    id: item.id,
    title: item.title,
    tags: item.tags || [],
    userId: item.userId,
    userName: item.userName || defaultName,
    bookmarkData: { id: item.id, private: false, userId: item.userId } as BookmarkData,
    profileImageUrl: item.profileImageUrl || '',
    createDate: item.createDate || '',
    updateDate: item.updateDate || '',
    textCount: item.textCount || 0,
    wordCount: item.wordCount || 0,
    characterCount: 0,
    readingTime: item.readingTime || 0,
    useWordCount: true,
    url: item.url,
    description: item.description || '',
    pageCount: item.pageCount,
    width: 0,
    height: 0,
    restrict: 0,
    xRestrict: 0,
    sl: 6,
    isBookmarkable: true,
    isUnlisted: false,
    isMasked: false,
    bookmarkCount: item.bookmarkCount || 0,
    commentCount: 0,
    markerCount: 0,
    seriesId: undefined,
    seriesTitle: undefined,
    series: undefined,
    originalWork: false,
    aiType: 0,
  };
}

@Entry
@Component
struct UserProfilePage {
  private userId: string = '';
  @State userName: string = '';
  @State userAvatarUrl: string = '';
  @State userComment: string = '';
  @State totalIllusts: number = 0;
  @State totalNovels: number = 0;
  @State isLoadingProfile: boolean = true;
  @State profileError: string = '';

  @State currentTab: number = 0;

  @State illustWorks: IllustBookmark[] = [];
  @State illustOffset: number = 0;
  @State hasMoreIllust: boolean = true;
  @State isLoadingIllust: boolean = true;
  @State isLoadingMoreIllust: boolean = false;
  @State illustError: string = '';

  @State novelWorks: NovelBookmark[] = [];
  @State novelOffset: number = 0;
  @State hasMoreNovel: boolean = true;
  @State isLoadingNovel: boolean = false;
  @State isLoadingMoreNovel: boolean = false;
  @State novelError: string = '';
  private allNovelIds: string[] = [];
  private novelPage: number = 1;

  @State bookmarkIllustWorks: IllustBookmark[] = [];
  @State bookmarkIllustOffset: number = 0;
  @State hasMoreBookmarkIllust: boolean = true;
  @State isLoadingBookmarkIllust: boolean = false;
  @State isLoadingMoreBookmarkIllust: boolean = false;
  @State bookmarkIllustError: string = '';

  @State bookmarkNovelWorks: NovelBookmark[] = [];
  @State bookmarkNovelOffset: number = 0;
  @State hasMoreBookmarkNovel: boolean = true;
  @State isLoadingBookmarkNovel: boolean = false;
  @State isLoadingMoreBookmarkNovel: boolean = false;
  @State bookmarkNovelError: string = '';

  async aboutToAppear() {
    const params = router.getParams() as Record<string, string>;
    this.userId = params['userId'];
    this.userName = params['userName'] || '';
    if (!this.userId) {
      this.profileError = '缺少用户ID';
      this.isLoadingProfile = false;
      return;
    }
    await this.loadProfile();
    await this.loadIllusts();
  }

  async loadProfile() {
    this.isLoadingProfile = true;
    this.profileError = '';
    try {
      const res = await AppApiService.getUserDetail(Number(this.userId)) as Record<string, Object>;
      const user = res['user'] as Record<string, Object>;
      const profile = res['profile'] as Record<string, Object>;
      if (user) {
        this.userName = String(user['name'] || '');
        const urls = user['profile_image_urls'] as Record<string, string> || {};
        this.userAvatarUrl = urls['medium'] || '';
        this.userComment = String(user['comment'] || '');
      }
      if (profile) {
        this.totalIllusts = Number(profile['total_illusts'] || 0) + Number(profile['total_manga'] || 0);
        this.totalNovels = Number(profile['total_novels'] || 0);
      }
    } catch (err) {
      console.error('加载作者资料失败:', err);
      try {
        const userInfo = await PixivService.getUserProfile(this.userId);
        if (userInfo && !userInfo.error && userInfo.body) {
          this.userName = userInfo.body.name || this.userName;
          if (userInfo.body.imageBig) this.userAvatarUrl = userInfo.body.imageBig;
          else if (userInfo.body.image) this.userAvatarUrl = userInfo.body.image;
        }
      } catch (_) {}
    }
    this.isLoadingProfile = false;
  }

  async loadIllusts() {
    this.isLoadingIllust = true;
    this.illustError = '';
    this.illustOffset = 0;
    this.hasMoreIllust = true;
    try {
      // Step 1: get all work IDs
      const allRes = await PixivService.getUserProfileAll(this.userId);
      if (allRes.error) {
        this.illustError = '加载失败';
        this.isLoadingIllust = false;
        return;
      }
      const allIds: string[] = [];
      const illustMap = allRes.body.illusts || {};
      const mangaMap = allRes.body.manga || {};
      const illustKeys = Object.keys(illustMap);
      for (let i = 0; i < illustKeys.length; i++) {
        allIds.push(illustKeys[i]);
      }
      const mangaKeys = Object.keys(mangaMap);
      for (let i = 0; i < mangaKeys.length; i++) {
        allIds.push(mangaKeys[i]);
      }
      if (allIds.length === 0) {
        this.hasMoreIllust = false;
        this.isLoadingIllust = false;
        return;
      }
      allIds.sort((a, b) => Number(b) - Number(a));
      // Step 2: fetch full data with ids[]
      const res = await PixivService.getUserProfileIllusts(this.userId, allIds);
      if (!res.error) {
        const workMap = res.body.works || {};
        const works: IllustBookmark[] = [];
        for (let i = 0; i < allIds.length; i++) {
          const work = workMap[allIds[i]];
          if (work) {
            works.push(mapProfileIllustToBookmark(work, this.userName));
          }
        }
        this.illustWorks = works;
        this.illustOffset = works.length;
        this.hasMoreIllust = false;
      } else {
        this.illustError = '加载失败';
      }
    } catch (err) {
      console.error('加载作者插画失败:', err);
      this.illustError = '加载失败';
    }
    this.isLoadingIllust = false;
  }

  async loadMoreIllusts() {
    this.hasMoreIllust = false;
  }

  async loadNovels() {
    this.isLoadingNovel = true;
    this.novelError = '';
    this.novelOffset = 0;
    this.hasMoreNovel = true;
    this.novelPage = 1;
    this.allNovelIds = [];
    try {
      // Step 1: get all work IDs
      const allRes = await PixivService.getUserProfileAll(this.userId);
      if (allRes.error) {
        this.novelError = '加载失败';
        this.isLoadingNovel = false;
        return;
      }
      const novelMap = allRes.body.novels || {};
      const allIds = Object.keys(novelMap);
      if (allIds.length === 0) {
        this.hasMoreNovel = false;
        this.isLoadingNovel = false;
        return;
      }
      allIds.sort((a, b) => Number(b) - Number(a));
      this.allNovelIds = allIds;
      // Step 2: fetch first page
      const pageIds = allIds.slice(0, PAGE_SIZE);
      const res = await PixivService.getUserProfileNovels(this.userId, pageIds);
      if (!res.error) {
        const workMap = extractNovelWorks(res.body as object);
        const works: NovelBookmark[] = [];
        for (let i = 0; i < pageIds.length; i++) {
          const work = workMap[pageIds[i]];
          if (work) {
            works.push(mapProfileNovelToBookmark(work, this.userName));
          }
        }
        this.novelWorks = works;
        this.novelOffset = works.length;
        this.hasMoreNovel = allIds.length > PAGE_SIZE;
      } else {
        this.novelError = '加载失败';
      }
    } catch (err) {
      console.error('加载作者小说失败:', err);
      this.novelError = '加载失败';
    }
    this.isLoadingNovel = false;
  }

  async loadMoreNovels() {
    if (this.isLoadingMoreNovel || !this.hasMoreNovel) return;
    this.isLoadingMoreNovel = true;
    try {
      const start = this.novelPage * PAGE_SIZE;
      const pageIds = this.allNovelIds.slice(start, start + PAGE_SIZE);
      if (pageIds.length === 0) {
        this.hasMoreNovel = false;
        this.isLoadingMoreNovel = false;
        return;
      }
      const res = await PixivService.getUserProfileNovels(this.userId, pageIds);
      if (!res.error) {
        const workMap = extractNovelWorks(res.body as object);
        const works: NovelBookmark[] = [];
        for (let i = 0; i < pageIds.length; i++) {
          const work = workMap[pageIds[i]];
          if (work) {
            works.push(mapProfileNovelToBookmark(work, this.userName));
          }
        }
        this.novelWorks = [...this.novelWorks, ...works];
        this.novelOffset += works.length;
        this.novelPage++;
        this.hasMoreNovel = start + PAGE_SIZE < this.allNovelIds.length;
      }
    } catch (err) {
      console.error('加载更多作者小说失败:', err);
    }
    this.isLoadingMoreNovel = false;
  }

  async loadBookmarkIllusts() {
    this.isLoadingBookmarkIllust = true;
    this.bookmarkIllustError = '';
    this.bookmarkIllustOffset = 0;
    this.hasMoreBookmarkIllust = true;
    try {
      const res = await PixivService.getIllustBookmarks(this.userId, 0, PAGE_SIZE, '', 'show');
      if (!res.error) {
        this.bookmarkIllustWorks = res.body.works;
        this.bookmarkIllustOffset = this.bookmarkIllustWorks.length;
        if (this.bookmarkIllustOffset >= res.body.total) {
          this.hasMoreBookmarkIllust = false;
        }
      } else {
        this.bookmarkIllustError = '加载失败';
      }
    } catch (err) {
      console.error('加载作者收藏插画失败:', err);
      this.bookmarkIllustError = '加载失败';
    }
    this.isLoadingBookmarkIllust = false;
  }

  async loadMoreBookmarkIllusts() {
    if (this.isLoadingMoreBookmarkIllust || !this.hasMoreBookmarkIllust) return;
    this.isLoadingMoreBookmarkIllust = true;
    try {
      const res = await PixivService.getIllustBookmarks(this.userId, this.bookmarkIllustOffset, PAGE_SIZE, '', 'show');
      if (!res.error) {
        this.bookmarkIllustWorks = [...this.bookmarkIllustWorks, ...res.body.works];
        this.bookmarkIllustOffset += res.body.works.length;
        if (this.bookmarkIllustOffset >= res.body.total) {
          this.hasMoreBookmarkIllust = false;
        }
      }
    } catch (err) {
      console.error('加载更多作者收藏插画失败:', err);
    }
    this.isLoadingMoreBookmarkIllust = false;
  }

  async loadBookmarkNovels() {
    this.isLoadingBookmarkNovel = true;
    this.bookmarkNovelError = '';
    this.bookmarkNovelOffset = 0;
    this.hasMoreBookmarkNovel = true;
    try {
      const res = await PixivService.getNovelBookmarks(this.userId, 0, PAGE_SIZE, '', 'show');
      if (!res.error) {
        this.bookmarkNovelWorks = res.body.works;
        this.bookmarkNovelOffset = this.bookmarkNovelWorks.length;
        if (this.bookmarkNovelOffset >= res.body.total) {
          this.hasMoreBookmarkNovel = false;
        }
      } else {
        this.bookmarkNovelError = '加载失败';
      }
    } catch (err) {
      console.error('加载作者收藏小说失败:', err);
      this.bookmarkNovelError = '加载失败';
    }
    this.isLoadingBookmarkNovel = false;
  }

  async loadMoreBookmarkNovels() {
    if (this.isLoadingMoreBookmarkNovel || !this.hasMoreBookmarkNovel) return;
    this.isLoadingMoreBookmarkNovel = true;
    try {
      const res = await PixivService.getNovelBookmarks(this.userId, this.bookmarkNovelOffset, PAGE_SIZE, '', 'show');
      if (!res.error) {
        this.bookmarkNovelWorks = [...this.bookmarkNovelWorks, ...res.body.works];
        this.bookmarkNovelOffset += res.body.works.length;
        if (this.bookmarkNovelOffset >= res.body.total) {
          this.hasMoreBookmarkNovel = false;
        }
      }
    } catch (err) {
      console.error('加载更多作者收藏小说失败:', err);
    }
    this.isLoadingMoreBookmarkNovel = false;
  }

  handleTabChange(index: number) {
    this.currentTab = index;
    if (index === 0 && this.illustWorks.length === 0 && !this.isLoadingIllust) {
      this.loadIllusts();
    } else if (index === 1 && this.novelWorks.length === 0 && !this.isLoadingNovel) {
      this.loadNovels();
    } else if (index === 2 && this.bookmarkIllustWorks.length === 0 && !this.isLoadingBookmarkIllust) {
      this.loadBookmarkIllusts();
    } else if (index === 3 && this.bookmarkNovelWorks.length === 0 && !this.isLoadingBookmarkNovel) {
      this.loadBookmarkNovels();
    }
  }

  build() {
    Column() {
      this.TopBar()
      if (this.profileError && !this.isLoadingProfile) {
        this.ErrorView(this.profileError)
      } else {
        this.HeaderSection()
        this.TabsSection()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  @Builder
  TopBar() {
    Row() {
      Text('‹')
        .fontSize(28)
        .fontColor($r('app.color.tab_selected'))
        .onClick(() => {
          router.back();
        })
      Text(this.userName || '作者主页')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .margin({ left: 12 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Blank()
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.loading_card'))
  }

  @Builder
  HeaderSection() {
    Column() {
      if (this.userAvatarUrl) {
        Image(this.userAvatarUrl)
          .width(72)
          .height(72)
          .objectFit(ImageFit.Cover)
          .borderRadius(36)
          .margin({ top: 16 })
      } else {
        Text('👤')
          .fontSize(36)
          .width(72)
          .height(72)
          .borderRadius(36)
          .backgroundColor('#FFE8E8E8')
          .textAlign(TextAlign.Center)
          .margin({ top: 16 })
      }

      Text(this.userName)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 8 })

      if (this.userComment) {
        Text(this.userComment)
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 4 })
          .padding({ left: 24, right: 24 })
      }

      Row() {
        this.StatItem('插画', this.totalIllusts)
        this.StatItem('小说', this.totalNovels)
      }
      .margin({ top: 12, bottom: 12 })
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  StatItem(label: string, count: number) {
    Column() {
      Text(String(count))
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
      Text(label)
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
    }
    .padding({ left: 20, right: 20 })
  }

  @Builder
  TabsSection() {
    Tabs({ barPosition: BarPosition.Start, index: this.currentTab }) {
      TabContent() {
        this.IllustTabContent()
      }
      .tabBar('插画')

      TabContent() {
        this.NovelTabContent()
      }
      .tabBar('小说')

      TabContent() {
        this.BookmarkIllustTabContent()
      }
      .tabBar('收藏插画')

      TabContent() {
        this.BookmarkNovelTabContent()
      }
      .tabBar('收藏小说')
    }
    .vertical(false)
    .onChange((index: number) => { this.handleTabChange(index); })
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  IllustTabContent() {
    if (this.isLoadingIllust) {
      LoadingProgress().width(40).height(40).margin({ top: 60 })
    } else if (this.illustError) {
      this.RetryView(this.illustError, (): Promise<void> => this.loadIllusts())
    } else if (this.illustWorks.length === 0) {
      this.EmptyView('该作者暂无插画作品')
    } else {
      Scroll() {
        Column() {
          Grid() {
            ForEach(this.illustWorks, (item: IllustBookmark) => {
              GridItem() {
                IllustCard({ item: item })
              }
            }, (item: IllustBookmark) => item.id)
          }
          .columnsTemplate('1fr 1fr')
          .columnsGap(8)
          .rowsGap(8)
          .padding(12)
          .width('100%')

          if (this.isLoadingMoreIllust) {
            LoadingProgress().width(30).height(30).margin({ top: 8, bottom: 16 })
          }
          if (!this.isLoadingMoreIllust && !this.hasMoreIllust && this.illustWorks.length > 0) {
            Text('- 已显示全部作品 -')
              .fontSize(12)
              .fontColor('#999')
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ top: 8, bottom: 24 })
          }
        }
        .width('100%')
      }
      .width('100%')
      .onReachEnd(() => {
        if (this.hasMoreIllust && !this.isLoadingMoreIllust) {
          this.loadMoreIllusts();
        }
      })
    }
  }

  @Builder
  NovelTabContent() {
    if (this.isLoadingNovel) {
      LoadingProgress().width(40).height(40).margin({ top: 60 })
    } else if (this.novelError) {
      this.RetryView(this.novelError, (): Promise<void> => this.loadNovels())
    } else if (this.novelWorks.length === 0) {
      this.EmptyView('该作者暂无小说作品')
    } else {
      Scroll() {
        Column() {
          ForEach(this.novelWorks, (item: NovelBookmark) => {
            NovelCard({ item: item })
          }, (item: NovelBookmark) => item.id)

          if (this.isLoadingMoreNovel) {
            LoadingProgress().width(30).height(30).margin({ top: 8, bottom: 16 })
          }
          if (!this.isLoadingMoreNovel && !this.hasMoreNovel && this.novelWorks.length > 0) {
            Text('- 已显示全部作品 -')
              .fontSize(12)
              .fontColor('#999')
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ top: 8, bottom: 24 })
          }
        }
        .width('100%')
        .padding(12)
      }
      .width('100%')
      .onReachEnd(() => {
        if (this.hasMoreNovel && !this.isLoadingMoreNovel) {
          this.loadMoreNovels();
        }
      })
    }
  }

  @Builder
  BookmarkIllustTabContent() {
    if (this.isLoadingBookmarkIllust) {
      LoadingProgress().width(40).height(40).margin({ top: 60 })
    } else if (this.bookmarkIllustError) {
      this.RetryView(this.bookmarkIllustError, (): Promise<void> => this.loadBookmarkIllusts())
    } else if (this.bookmarkIllustWorks.length === 0) {
      this.EmptyView('该作者暂无收藏插画')
    } else {
      Scroll() {
        Column() {
          Grid() {
            ForEach(this.bookmarkIllustWorks, (item: IllustBookmark) => {
              GridItem() {
                IllustCard({ item: item })
              }
            }, (item: IllustBookmark) => item.id)
          }
          .columnsTemplate('1fr 1fr')
          .columnsGap(8)
          .rowsGap(8)
          .padding(12)
          .width('100%')

          if (this.isLoadingMoreBookmarkIllust) {
            LoadingProgress().width(30).height(30).margin({ top: 8, bottom: 16 })
          }
          if (!this.isLoadingMoreBookmarkIllust && !this.hasMoreBookmarkIllust && this.bookmarkIllustWorks.length > 0) {
            Text('- 已显示全部作品 -')
              .fontSize(12)
              .fontColor('#999')
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ top: 8, bottom: 24 })
          }
        }
        .width('100%')
      }
      .width('100%')
      .onReachEnd(() => {
        if (this.hasMoreBookmarkIllust && !this.isLoadingMoreBookmarkIllust) {
          this.loadMoreBookmarkIllusts();
        }
      })
    }
  }

  @Builder
  BookmarkNovelTabContent() {
    if (this.isLoadingBookmarkNovel) {
      LoadingProgress().width(40).height(40).margin({ top: 60 })
    } else if (this.bookmarkNovelError) {
      this.RetryView(this.bookmarkNovelError, (): Promise<void> => this.loadBookmarkNovels())
    } else if (this.bookmarkNovelWorks.length === 0) {
      this.EmptyView('该作者暂无收藏小说')
    } else {
      Scroll() {
        Column() {
          ForEach(this.bookmarkNovelWorks, (item: NovelBookmark) => {
            NovelCard({ item: item })
          }, (item: NovelBookmark) => item.id)

          if (this.isLoadingMoreBookmarkNovel) {
            LoadingProgress().width(30).height(30).margin({ top: 8, bottom: 16 })
          }
          if (!this.isLoadingMoreBookmarkNovel && !this.hasMoreBookmarkNovel && this.bookmarkNovelWorks.length > 0) {
            Text('- 已显示全部作品 -')
              .fontSize(12)
              .fontColor('#999')
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ top: 8, bottom: 24 })
          }
        }
        .width('100%')
        .padding(12)
      }
      .width('100%')
      .onReachEnd(() => {
        if (this.hasMoreBookmarkNovel && !this.isLoadingMoreBookmarkNovel) {
          this.loadMoreBookmarkNovels();
        }
      })
    }
  }

  @Builder
  RetryView(msg: string, onRetry: () => void) {
    Column() {
      Text(msg)
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
      Button('重试')
        .margin({ top: 12 })
        .onClick(() => onRetry())
    }
    .margin({ top: 60 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  EmptyView(msg: string) {
    Text(msg)
      .fontSize(14)
      .fontColor($r('app.color.text_secondary'))
      .margin({ top: 60 })
      .width('100%')
      .textAlign(TextAlign.Center)
  }

  @Builder
  ErrorView(msg: string) {
    Column() {
      Text(msg)
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 80 })
      Button('返回')
        .margin({ top: 12 })
        .onClick(() => { router.back(); })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }
}
