
import { curves } from '@kit.ArkUI';
import { AppApiService } from '../../services/AppApiService';
import { PixivService } from '../../services/PixivService';
import { IllustBookmark, NovelBookmark, BookmarkData, ProfileIllust, ProfileNovel } from '../../models/PixivModels';
import { IllustCard } from '../../components/IllustCard';
import { NovelCard } from '../../components/NovelCard';
import { SegmentedTabBar } from '../../components/SegmentedTabBar';
import { BasicDataSource } from '../../common/utils/BasicDataSource';
import { PageContext } from '../../common/utils/PageContext';

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
    bookmarkData: item.bookmarkData as BookmarkData,
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
    bookmarkData: null,
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
    seriesId: item.seriesId,
    seriesTitle: item.seriesTitle,
    seriesContentOrder: item.seriesContentOrder,
    seriesOrder: item.seriesOrder,
    series: item.series,
    originalWork: false,
    aiType: 0,
  };
}

@Component
struct UserProfilePage {
  @State navParams: Record<string, Object> = {};
  private userId: string = '';
  @State userName: string = '';
  @State userAvatarUrl: string = '';
  @State userComment: string = '';
  @State isLoadingProfile: boolean = true;
  @State profileError: string = '';

  @State currentTab: number = 0;
  @State isHeaderVisible: boolean = true;
  @State swipeProgress: number = 0;
  @State isAnimationStarted: boolean = false;
  private lastScrollY: number = 0;
  private swiperController: SwiperController = new SwiperController();
  private swiperWidth: number = 0;
  private animStartIndex: number = 0;

  private illustSource: BasicDataSource<IllustBookmark> = new BasicDataSource();
  @State illustOffset: number = 0;
  @State hasMoreIllust: boolean = true;
  @State isLoadingIllust: boolean = true;
  @State isLoadingMoreIllust: boolean = false;
  @State illustError: string = '';

  private novelSource: BasicDataSource<NovelBookmark> = new BasicDataSource();
  @State novelOffset: number = 0;
  @State hasMoreNovel: boolean = true;
  @State isLoadingNovel: boolean = false;
  @State isLoadingMoreNovel: boolean = false;
  @State novelError: string = '';
  private allNovelIds: string[] = [];
  private novelPage: number = 1;

  private bookmarkIllustSource: BasicDataSource<IllustBookmark> = new BasicDataSource();
  @State bookmarkIllustOffset: number = 0;
  @State hasMoreBookmarkIllust: boolean = true;
  @State isLoadingBookmarkIllust: boolean = false;
  @State isLoadingMoreBookmarkIllust: boolean = false;
  @State bookmarkIllustError: string = '';

  private bookmarkNovelSource: BasicDataSource<NovelBookmark> = new BasicDataSource();
  @State bookmarkNovelOffset: number = 0;
  @State hasMoreBookmarkNovel: boolean = true;
  @State isLoadingBookmarkNovel: boolean = false;
  @State isLoadingMoreBookmarkNovel: boolean = false;
  @State bookmarkNovelError: string = '';

  private isActive: boolean = true;

  aboutToDisappear() {
    this.isActive = false;
  }

  aboutToAppear() {
    // 参数由 onReady 获取
  }

  async loadProfile() {
    this.isLoadingProfile = true;
    this.profileError = '';
    let avatarUrl = '';
    try {
      const res = await AppApiService.getUserDetail(Number(this.userId)) as Record<string, Object>;
      if (!this.isActive) return;
      const user = res['user'] as Record<string, Object>;
      const profile = res['profile'] as Record<string, Object>;
      if (user) {
        this.userName = String(user['name'] || '');
        const urls = user['profile_image_urls'] as Record<string, string> || {};
        avatarUrl = urls['medium'] || '';
        this.userComment = String(user['comment'] || '');
      }
    } catch (err) {
      console.error('加载作者资料失败:', err);
      try {
        const userInfo = await PixivService.getUserProfile(this.userId);
        if (!this.isActive) return;
        if (userInfo && !userInfo.error && userInfo.body) {
          this.userName = userInfo.body.name || this.userName;
          if (userInfo.body.imageBig) avatarUrl = userInfo.body.imageBig;
          else if (userInfo.body.image) avatarUrl = userInfo.body.image;
        }
      } catch (_) {}
    }
    if (avatarUrl) {
      this.userAvatarUrl = await PixivService.cacheImage(avatarUrl, `user_${this.userId}.jpg`);
      if (!this.isActive) return;
    }
    this.isLoadingProfile = false;
  }

  async loadIllusts() {
    this.isLoadingIllust = true;
    this.illustError = '';
    this.illustOffset = 0;
    this.hasMoreIllust = true;
    try {
      const allRes = await PixivService.getUserProfileAll(this.userId);
      if (!this.isActive) return;
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
      const res = await PixivService.getUserProfileIllusts(this.userId, allIds);
      if (!this.isActive) return;
      if (!res.error) {
        const workMap = res.body.works || {};
        const works: IllustBookmark[] = [];
        for (let i = 0; i < allIds.length; i++) {
          const work = workMap[allIds[i]];
          if (work) {
            works.push(mapProfileIllustToBookmark(work, this.userName));
          }
        }
        this.illustSource.reset(works);
        this.illustOffset = works.length;
        this.hasMoreIllust = false;
      } else {
        this.illustError = '加载失败';
      }
    } catch (err) {
      if (!this.isActive) return;
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
      const allRes = await PixivService.getUserProfileAll(this.userId);
      if (!this.isActive) return;
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
      const pageIds = allIds.slice(0, PAGE_SIZE);
      const res = await PixivService.getUserProfileNovels(this.userId, pageIds);
      if (!this.isActive) return;
      if (!res.error) {
        const workMap = extractNovelWorks(res.body as object);
        const works: NovelBookmark[] = [];
        for (let i = 0; i < pageIds.length; i++) {
          const work = workMap[pageIds[i]];
          if (work) {
            works.push(mapProfileNovelToBookmark(work, this.userName));
          }
        }
        this.novelSource.reset(works);
        this.novelOffset = works.length;
        this.hasMoreNovel = allIds.length > PAGE_SIZE;
      } else {
        this.novelError = '加载失败';
      }
    } catch (err) {
      if (!this.isActive) return;
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
      if (!this.isActive) return;
      if (!res.error) {
        const workMap = extractNovelWorks(res.body as object);
        const works: NovelBookmark[] = [];
        for (let i = 0; i < pageIds.length; i++) {
          const work = workMap[pageIds[i]];
          if (work) {
            works.push(mapProfileNovelToBookmark(work, this.userName));
          }
        }
        this.novelSource.push(...works);
        this.novelOffset += works.length;
        this.novelPage++;
        this.hasMoreNovel = start + PAGE_SIZE < this.allNovelIds.length;
      }
    } catch (err) {
      if (!this.isActive) return;
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
      if (!this.isActive) return;
      if (!res.error) {
        this.bookmarkIllustSource.reset(res.body.works);
        this.bookmarkIllustOffset = this.bookmarkIllustSource.totalCount();
        if (this.bookmarkIllustOffset >= res.body.total) {
          this.hasMoreBookmarkIllust = false;
        }
      } else {
        this.bookmarkIllustError = '加载失败';
      }
    } catch (err) {
      if (!this.isActive) return;
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
      if (!this.isActive) return;
      if (!res.error) {
        this.bookmarkIllustSource.push(...res.body.works);
        this.bookmarkIllustOffset += res.body.works.length;
        if (this.bookmarkIllustOffset >= res.body.total) {
          this.hasMoreBookmarkIllust = false;
        }
      }
    } catch (err) {
      if (!this.isActive) return;
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
      if (!this.isActive) return;
      if (!res.error) {
        this.bookmarkNovelSource.reset(res.body.works);
        this.bookmarkNovelOffset = this.bookmarkNovelSource.totalCount();
        if (this.bookmarkNovelOffset >= res.body.total) {
          this.hasMoreBookmarkNovel = false;
        }
      } else {
        this.bookmarkNovelError = '加载失败';
      }
    } catch (err) {
      if (!this.isActive) return;
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
      if (!this.isActive) return;
      if (!res.error) {
        this.bookmarkNovelSource.push(...res.body.works);
        this.bookmarkNovelOffset += res.body.works.length;
        if (this.bookmarkNovelOffset >= res.body.total) {
          this.hasMoreBookmarkNovel = false;
        }
      }
    } catch (err) {
      if (!this.isActive) return;
      console.error('加载更多作者收藏小说失败:', err);
    }
    this.isLoadingMoreBookmarkNovel = false;
  }

  handleTabChange(index: number) {
    this.currentTab = index;
    this.lastScrollY = 0;
    if (index === 0 && this.illustSource.totalCount() === 0 && !this.isLoadingIllust) {
      this.loadIllusts();
    } else if (index === 1 && this.novelSource.totalCount() === 0 && !this.isLoadingNovel) {
      this.loadNovels();
    } else if (index === 2 && this.bookmarkIllustSource.totalCount() === 0 && !this.isLoadingBookmarkIllust) {
      this.loadBookmarkIllusts();
    } else if (index === 3 && this.bookmarkNovelSource.totalCount() === 0 && !this.isLoadingBookmarkNovel) {
      this.loadBookmarkNovels();
    }
  }

  build() {
    NavDestination() {
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
    .onReady((ctx: NavDestinationContext) => {
      this.navParams = ctx.pathInfo.param as Record<string, Object> ?? {};
      this.userId = (this.navParams['userId'] as string) || '';
      this.userName = (this.navParams['userName'] as string) || '';
      if (!this.userId) {
        this.profileError = '缺少用户ID';
        this.isLoadingProfile = false;
        return;
      }
      this.loadProfile();
      this.loadIllusts();
    })
    .onBackPressed(() => {
      const pageCtx = AppStorage.get<PageContext>('rootPageContext');
      if (pageCtx) { pageCtx.popPage(); }
      return true;
    })
    .hideTitleBar(true)
  }

  @Builder
  TopBar() {
    Row() {
      Text('‹')
        .fontSize(28)
        .fontColor($r('app.color.tab_selected'))
        .onClick(() => {
          const ctx = AppStorage.get<PageContext>('rootPageContext');
          if (ctx) { ctx.popPage(); }
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
    .height(52)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.glass_bg'))
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
          .backgroundColor($r('app.color.loading_card'))
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

    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  handleHeaderScroll(yOffset: number) {
    const delta = yOffset - this.lastScrollY;
    this.lastScrollY = yOffset;

    if (delta > 0 && this.isHeaderVisible && yOffset > 5) {
      animateTo({ curve: curves.springMotion(0.45, 0.7) }, () => {
        this.isHeaderVisible = false;
      });
    } else if (delta < -3 && !this.isHeaderVisible) {
      animateTo({ curve: curves.springMotion(0.45, 0.7) }, () => {
        this.isHeaderVisible = true;
      });
    }
  }

  handleHeaderReachStart() {
    if (!this.isHeaderVisible) {
      animateTo({ curve: curves.springMotion(0.45, 0.7) }, () => {
        this.isHeaderVisible = true;
      });
    }
  }

  @Builder
  TabsSection() {
    Column() {
      if (this.isHeaderVisible) {
        SegmentedTabBar({
          tabs: ['插画', '小说', '收藏插画', '收藏小说'],
          currentIndex: this.currentTab,
          swipeProgress: this.swipeProgress,
          onChange: (index: number): void => this.handleTabChange(index)
        })
        .padding({ left: 16, right: 16, top: 8, bottom: 4 })
        .transition(TransitionEffect.translate({ y: -48 })
          .combine(TransitionEffect.OPACITY)
          .animation({ curve: curves.springMotion(0.45, 0.7) }))
      }

      Swiper(this.swiperController) {
        Column() {
          this.IllustTabContent()
        }
        .width('100%')

        Column() {
          this.NovelTabContent()
        }
        .width('100%')

        Column() {
          this.BookmarkIllustTabContent()
        }
        .width('100%')

        Column() {
          this.BookmarkNovelTabContent()
        }
        .width('100%')
      }
      .index(this.currentTab)
      .indicator(false)
      .loop(false)
      .vertical(false)
      .cachedCount(1)
      .onGestureSwipe((index: number, extraInfo: SwiperAnimationEvent) => {
        if ((index === 0 && extraInfo.currentOffset > 0) ||
          (index === 3 && extraInfo.currentOffset < 0)) {
          this.swipeProgress = 0;
          return;
        }
        const w = this.swiperWidth > 0 ? this.swiperWidth : 1;
        const ratio = Math.abs(extraInfo.currentOffset) / w;
        this.swipeProgress = extraInfo.currentOffset < 0 ? ratio : -ratio;
      })
      .onAnimationStart((index: number, _targetIndex: number) => {
        this.isAnimationStarted = true;
        this.animStartIndex = index;
      })
      .onContentDidScroll((_selectedIndex: number, index: number, position: number, mainAxisLength: number) => {
        this.swiperWidth = mainAxisLength;
        if (!this.isAnimationStarted || index !== this.animStartIndex) return;
        const targetIndex = position < 0 ? index + 1 : index - 1;
        if (targetIndex < 0 || targetIndex >= 4) return;
        const dir = targetIndex > index ? 1 : -1;
        this.swipeProgress = dir * Math.abs(Math.min(Math.max(position, -1), 1));
      })
      .onAnimationEnd((index: number) => {
        this.isAnimationStarted = false;
        this.swipeProgress = 0;
        this.currentTab = index;
        this.handleTabChange(index);
      })
      .layoutWeight(1)
      .onAreaChange((_old: Area, area: Area) => {
        this.swiperWidth = area.width as number;
      })
    }
    .width('100%')
  }

  @Builder
  IllustTabContent() {
    if (this.isLoadingIllust) {
      LoadingProgress().width(40).height(40).margin({ top: 60 })
    } else if (this.illustError) {
      this.RetryView(this.illustError, (): Promise<void> => this.loadIllusts())
    } else if (this.illustSource.totalCount() === 0) {
      this.EmptyView('该作者暂无插画作品')
    } else {
      Scroll() {
        Column() {
          Grid() {
            LazyForEach(this.illustSource, (item: IllustBookmark, index: number) => {
              GridItem() {
                IllustCard({ item: item, index: index })
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
          if (!this.isLoadingMoreIllust && !this.hasMoreIllust && this.illustSource.totalCount() > 0) {
            Text('- 已显示全部作品 -')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ top: 8, bottom: 48 })
          }
        }
        .width('100%')
        .padding({ bottom: 120 })
      }
      .width('100%')
      .edgeEffect(EdgeEffect.Spring)
      .onReachStart(() => { this.handleHeaderReachStart(); })
      .onReachEnd(() => {
        if (this.hasMoreIllust && !this.isLoadingMoreIllust) {
          this.loadMoreIllusts();
        }
      })
      .onScroll((_xOffset: number, yOffset: number) => {
        this.handleHeaderScroll(yOffset);
      })
    }
  }

  @Builder
  NovelTabContent() {
    if (this.isLoadingNovel) {
      LoadingProgress().width(40).height(40).margin({ top: 60 })
    } else if (this.novelError) {
      this.RetryView(this.novelError, (): Promise<void> => this.loadNovels())
    } else if (this.novelSource.totalCount() === 0) {
      this.EmptyView('该作者暂无小说作品')
    } else {
      Scroll() {
        Column() {
          List() {
            LazyForEach(this.novelSource, (item: NovelBookmark, index: number) => {
              ListItem() {
                NovelCard({ item: item, index: index })
              }
            }, (item: NovelBookmark) => item.id)
          }

          if (this.isLoadingMoreNovel) {
            LoadingProgress().width(30).height(30).margin({ top: 8, bottom: 16 })
          }
          if (!this.isLoadingMoreNovel && !this.hasMoreNovel && this.novelSource.totalCount() > 0) {
            Text('- 已显示全部作品 -')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ top: 8, bottom: 24 })
          }
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 12, bottom: 120 })
      }
      .width('100%')
      .edgeEffect(EdgeEffect.Spring)
      .onReachStart(() => { this.handleHeaderReachStart(); })
      .onReachEnd(() => {
        if (this.hasMoreNovel && !this.isLoadingMoreNovel) {
          this.loadMoreNovels();
        }
      })
      .onScroll((_xOffset: number, yOffset: number) => {
        this.handleHeaderScroll(yOffset);
      })
    }
  }

  @Builder
  BookmarkIllustTabContent() {
    if (this.isLoadingBookmarkIllust) {
      LoadingProgress().width(40).height(40).margin({ top: 60 })
    } else if (this.bookmarkIllustError) {
      this.RetryView(this.bookmarkIllustError, (): Promise<void> => this.loadBookmarkIllusts())
    } else if (this.bookmarkIllustSource.totalCount() === 0) {
      this.EmptyView('该作者暂无收藏插画')
    } else {
      Scroll() {
        Column() {
          Grid() {
            LazyForEach(this.bookmarkIllustSource, (item: IllustBookmark, index: number) => {
              GridItem() {
                IllustCard({ item: item, index: index })
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
          if (!this.isLoadingMoreBookmarkIllust && !this.hasMoreBookmarkIllust && this.bookmarkIllustSource.totalCount() > 0) {
            Text('- 已显示全部作品 -')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ top: 8, bottom: 48 })
          }
        }
        .width('100%')
        .padding({ bottom: 120 })
      }
      .width('100%')
      .edgeEffect(EdgeEffect.Spring)
      .onReachStart(() => { this.handleHeaderReachStart(); })
      .onReachEnd(() => {
        if (this.hasMoreBookmarkIllust && !this.isLoadingMoreBookmarkIllust) {
          this.loadMoreBookmarkIllusts();
        }
      })
      .onScroll((_xOffset: number, yOffset: number) => {
        this.handleHeaderScroll(yOffset);
      })
    }
  }

  @Builder
  BookmarkNovelTabContent() {
    if (this.isLoadingBookmarkNovel) {
      LoadingProgress().width(40).height(40).margin({ top: 60 })
    } else if (this.bookmarkNovelError) {
      this.RetryView(this.bookmarkNovelError, (): Promise<void> => this.loadBookmarkNovels())
    } else if (this.bookmarkNovelSource.totalCount() === 0) {
      this.EmptyView('该作者暂无收藏小说')
    } else {
      Scroll() {
        Column() {
          List() {
            LazyForEach(this.bookmarkNovelSource, (item: NovelBookmark, index: number) => {
              ListItem() {
                NovelCard({ item: item, index: index })
              }
            }, (item: NovelBookmark) => item.id)
          }

          if (this.isLoadingMoreBookmarkNovel) {
            LoadingProgress().width(30).height(30).margin({ top: 8, bottom: 16 })
          }
          if (!this.isLoadingMoreBookmarkNovel && !this.hasMoreBookmarkNovel && this.bookmarkNovelSource.totalCount() > 0) {
            Text('- 已显示全部作品 -')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ top: 8, bottom: 24 })
          }
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 12, bottom: 120 })
      }
      .width('100%')
      .edgeEffect(EdgeEffect.Spring)
      .onReachStart(() => { this.handleHeaderReachStart(); })
      .onReachEnd(() => {
        if (this.hasMoreBookmarkNovel && !this.isLoadingMoreBookmarkNovel) {
          this.loadMoreBookmarkNovels();
        }
      })
      .onScroll((_xOffset: number, yOffset: number) => {
        this.handleHeaderScroll(yOffset);
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
          .onClick(() => { const ctx = AppStorage.get<PageContext>('rootPageContext'); if (ctx) { ctx.popPage(); } })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }
}

@Builder
export function UserProfileBuilder(): void {
  UserProfilePage()
}
