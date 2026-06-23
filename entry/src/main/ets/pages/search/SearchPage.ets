import { curves } from '@kit.ArkUI';
import { PixivService } from '../../services/PixivService';
import { IllustBookmark, NovelBookmark, UserSearchResult } from '../../models/PixivModels';
import { IllustCard } from '../../components/IllustCard';
import { NovelCard } from '../../components/NovelCard';
import { UserCard } from '../../components/UserCard';
import { SegmentedTabBar } from '../../components/SegmentedTabBar';
import { pixivCacheDB } from '../../database/PixivCacheDB';
import { BasicDataSource } from '../../common/utils/BasicDataSource';
import inputMethod from '@ohos.inputMethod';
import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';

@Component
export struct SearchPage {
  @State keyword: string = '';
  @State currentTab: number = 0;
  @State isHeaderVisible: boolean = true;
  @State swipeProgress: number = 0;
  @State isAnimationStarted: boolean = false;
  private lastScrollY: number = 0;
  private swiperController: SwiperController = new SwiperController();
  private swiperWidth: number = 0;
  private animStartIndex: number = 0;
  @State showHistory: boolean = false;
  @State searchHistory: string[] = [];

  // illust
  private illustSource: BasicDataSource<IllustBookmark> = new BasicDataSource();
  @State illustPage: number = 1;
  @State illustPages: number = 0;
  @State isLoadingIllust: boolean = false;
  @State isLoadingMoreIllust: boolean = false;
  @State illustError: string = '';

  // novel
  private novelSource: BasicDataSource<NovelBookmark> = new BasicDataSource();
  @State novelPage: number = 1;
  @State novelPages: number = 0;
  @State isLoadingNovel: boolean = false;
  @State isLoadingMoreNovel: boolean = false;
  @State novelError: string = '';

  // user
  private userSource: BasicDataSource<UserSearchResult> = new BasicDataSource();
  @State userPage: number = 1;
  @State userPages: number = 0;
  @State isLoadingUser: boolean = false;
  @State isLoadingMoreUser: boolean = false;
  @State userError: string = '';

  @State hasSearched: boolean = false;

  aboutToAppear() {
    this.loadSearchHistory();
  }

  loadSearchHistory() {
    const ctx = AppStorage.get<common.UIAbilityContext>('appContext');
    if (!ctx) return;
    preferences.getPreferences(ctx, 'app_search_history')
      .then(pref => pref.get('searchHistory', '[]'))
      .then((stored: string | preferences.ValueType) => {
        try {
          this.searchHistory = JSON.parse(stored as string);
        } catch {
          this.searchHistory = [];
        }
      })
      .catch(() => {});
  }

  saveSearchHistory() {
    const ctx = AppStorage.get<common.UIAbilityContext>('appContext');
    if (!ctx) return;
    preferences.getPreferences(ctx, 'app_search_history')
      .then(pref => {
        pref.put('searchHistory', JSON.stringify(this.searchHistory));
        pref.flush();
      })
      .catch(() => {});
  }

  addToHistory(keyword: string) {
    const trimmed = keyword.trim();
    if (!trimmed) return;
    const filtered = this.searchHistory.filter(h => h !== trimmed);
    this.searchHistory = [trimmed, ...filtered].slice(0, 10);
    this.saveSearchHistory();
  }

  removeFromHistory(keyword: string) {
    this.searchHistory = this.searchHistory.filter(h => h !== keyword);
    if (this.searchHistory.length === 0) {
      this.showHistory = false;
    }
    this.saveSearchHistory();
  }

  clearHistory() {
    this.searchHistory = [];
    this.showHistory = false;
    this.saveSearchHistory();
  }

  async filterBlockedNovels(works: NovelBookmark[]): Promise<NovelBookmark[]> {
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      await pixivCacheDB.init(ctx);
      const blockedIds = await Promise.all([
        pixivCacheDB.getAllBlockedAuthorIds(),
        pixivCacheDB.getAllBlockedSeriesIds(),
        pixivCacheDB.getAllBlockedSeriesTitleSet()
      ]);
      const blockedAuthorIds = blockedIds[0];
      const blockedSeriesIds = blockedIds[1];
      const blockedSeriesTitleSet = blockedIds[2] as Set<string>;
      return works.filter(n => {
        if (blockedAuthorIds.has(n.userId)) return false;
        const sid = n.series?.id ?? n.seriesId;
        if (sid && blockedSeriesIds.has(String(sid))) return false;
        const seriesTitle = n.seriesTitle || n.series?.title || '';
        if (seriesTitle && blockedSeriesTitleSet.has(seriesTitle.toLowerCase())) return false;
        return true;
      });
    } catch (_) {
      return works;
    }
  }

  async searchIllusts(page: number, reset: boolean = false) {
    if (!this.keyword.trim()) return;
    if (reset) {
      this.isLoadingIllust = true;
      this.illustError = '';
      this.illustSource.reset([]);
    }
    try {
      const res = await PixivService.searchIllusts(this.keyword.trim(), page, 's_tag', 'illust_and_ugoira');
      if (!res.error) {
        const raw = res.body?.illust?.data ?? [];
        const works: IllustBookmark[] = [];
        for (let i = 0; i < raw.length; i++) {
          const item = raw[i];
          if (item && typeof item.id === 'string') {
            works.push(item);
          }
        }
        if (reset) {
          this.illustSource.reset(works);
        } else {
          this.illustSource.push(...works);
        }
        const total = res.body?.illust?.total ?? 0;
        this.illustPage = page;
        this.illustPages = Math.ceil(total / 30) || 1;
      } else {
        if (reset) this.illustError = '搜索失败';
      }
    } catch (err) {
      console.error('搜索插画失败:', err);
      if (reset) this.illustError = '搜索失败';
    }
    this.isLoadingIllust = false;
    this.isLoadingMoreIllust = false;
  }

  async searchNovels(page: number, reset: boolean = false) {
    if (!this.keyword.trim()) return;
    if (reset) {
      this.isLoadingNovel = true;
      this.novelError = '';
      this.novelSource.reset([]);
    }
    try {
      const res = await PixivService.searchNovels(this.keyword.trim(), page, 's_tag');
      if (!res.error) {
        const raw = res.body?.novel?.data ?? [];
        const works: NovelBookmark[] = [];
        for (let i = 0; i < raw.length; i++) {
          const item = raw[i];
          if (item && typeof item.id === 'string') {
            works.push(item);
          }
        }
        const filtered = await this.filterBlockedNovels(works);
        if (reset) {
          this.novelSource.reset(filtered);
        } else {
          this.novelSource.push(...filtered);
        }
        const total = res.body?.novel?.total ?? 0;
        this.novelPage = page;
        this.novelPages = Math.ceil(total / 30) || 1;
      } else {
        if (reset) this.novelError = '搜索失败';
      }
    } catch (err) {
      console.error('搜索小说失败:', err);
      if (reset) this.novelError = '搜索失败';
    }
    this.isLoadingNovel = false;
    this.isLoadingMoreNovel = false;
  }

  async searchUsers(page: number, reset: boolean = false) {
    if (!this.keyword.trim()) return;
    if (reset) {
      this.isLoadingUser = true;
      this.userError = '';
      this.userSource.reset([]);
    }
    try {
      const res = await PixivService.searchUsers(this.keyword.trim(), page);
      if (!res.error) {
        const raw = res.body?.users ?? [];
        const users: UserSearchResult[] = [];
        for (let i = 0; i < raw.length; i++) {
          const item = raw[i];
          if (item && typeof item.userId === 'string') {
            users.push(item);
          }
        }
        if (reset) {
          this.userSource.reset(users);
        } else {
          this.userSource.push(...users);
        }
        const total = res.body?.page?.total ?? 0;
        this.userPage = page;
        this.userPages = Math.ceil(total / 10) || 1;
      } else {
        if (reset) this.userError = '搜索失败';
      }
    } catch (err) {
      console.error('搜索用户失败:', err);
      if (reset) this.userError = '搜索失败';
    }
    this.isLoadingUser = false;
    this.isLoadingMoreUser = false;
  }

  async onSearch() {
    if (!this.keyword.trim()) return;
    this.addToHistory(this.keyword);
    this.hasSearched = true;
    this.showHistory = false;
    try {
      inputMethod.getController().stopInputSession();
    } catch (e) {
      console.warn('dismiss keyboard failed');
    }
    if (this.currentTab === 0) {
      await this.searchIllusts(1, true);
    } else if (this.currentTab === 1) {
      await this.searchNovels(1, true);
    } else {
      await this.searchUsers(1, true);
    }
  }

  async loadMoreIllusts() {
    if (this.isLoadingMoreIllust || this.illustPage >= this.illustPages) return;
    this.isLoadingMoreIllust = true;
    await this.searchIllusts(this.illustPage + 1, false);
  }

  async loadMoreNovels() {
    if (this.isLoadingMoreNovel || this.novelPage >= this.novelPages) return;
    this.isLoadingMoreNovel = true;
    await this.searchNovels(this.novelPage + 1, false);
  }

  async loadMoreUsers() {
    if (this.isLoadingMoreUser || this.userPage >= this.userPages) return;
    this.isLoadingMoreUser = true;
    await this.searchUsers(this.userPage + 1, false);
  }

  handleTabChange(index: number) {
    this.currentTab = index;
    if (!this.hasSearched) return;
    if (index === 0 && this.illustSource.totalCount() === 0 && !this.isLoadingIllust) {
      this.searchIllusts(1, true);
    } else if (index === 1 && this.novelSource.totalCount() === 0 && !this.isLoadingNovel) {
      this.searchNovels(1, true);
    } else if (index === 2 && this.userSource.totalCount() === 0 && !this.isLoadingUser) {
      this.searchUsers(1, true);
    }
  }

  build() {
    Column() {
      this.SearchBar()
      if (this.showHistory) {
        this.SearchHistoryPanel()
      } else if (this.hasSearched) {
        this.TabsSection()
      } else {
        this.EmptyHint()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  @Builder
  SearchBar() {
    Row() {
      TextInput({ placeholder: '搜索插画/小说/用户...', text: this.keyword })
        .layoutWeight(1)
        .height(44)
        .fontSize(14)
        .borderRadius(22)
        .backgroundColor($r('app.color.surface_secondary'))
        .padding({ left: 18, right: 18 })
        .onChange((val: string) => { this.keyword = val; })
        .onSubmit(() => { this.onSearch(); })
        .onClick(() => {
          if (this.searchHistory.length > 0) {
            this.showHistory = !this.showHistory;
          }
        })

      Blank()
        .width(10)

      Button('搜索')
        .fontSize(14)
        .fontColor(Color.White)
        .backgroundColor($r('app.color.tab_selected'))
        .borderRadius(22)
        .height(44)
        .padding({ left: 24, right: 24 })
        .onClick(() => { this.onSearch(); })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor($r('app.color.glass_bg'))
  }

  @Builder
  SearchHistoryPanel() {
    Column() {
      Row() {
        Text('搜索历史')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
        Blank()
        Text('清空')
          .fontSize(14)
          .fontColor($r('app.color.tab_selected'))
          .onClick(() => { this.clearHistory(); })
      }
      .padding({ left: 20, right: 20, top: 16, bottom: 8 })

      List() {
        ForEach(this.searchHistory, (item: string) => {
          ListItem() {
            Row() {
              Text('◉')
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .margin({ right: 12 })
              Text(item)
                .fontSize(14)
                .textAlign(TextAlign.Start)
                .layoutWeight(1)
              Text('✕')
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
                .padding({ left: 12, right: 4 })
                .onClick(() => { this.removeFromHistory(item); })
            }
            .padding({ left: 20, right: 20, top: 12, bottom: 12 })
            .width('100%')
            .onClick(() => {
              this.keyword = item;
              this.onSearch();
            })
          }
        }, (item: string) => item)
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  @Builder
  EmptyHint() {
    Column() {
      Text('输入关键词搜索作品或用户')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 80 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  handleHeaderScroll(yOffset: number) {
    const delta = yOffset - this.lastScrollY;
    this.lastScrollY = yOffset;

    if (delta > 8 && this.isHeaderVisible && yOffset > 30) {
      animateTo({ curve: curves.springMotion(0.45, 0.7) }, () => {
        this.isHeaderVisible = false;
      });
    } else if (delta < -8 && !this.isHeaderVisible && yOffset < 10) {
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
          tabs: ['插画', '小说', '用户'],
          currentIndex: this.currentTab,
          swipeProgress: this.swipeProgress,
          onChange: (index: number): void => {
            this.lastScrollY = 0;
            this.handleTabChange(index);
          }
        })
        .padding({ left: 16, right: 16, top: 8, bottom: 4 })
        .transition(TransitionEffect.translate({ y: -48 })
          .combine(TransitionEffect.OPACITY)
          .animation({ curve: curves.springMotion(0.45, 0.7) }))
      }

      Swiper(this.swiperController) {
        Column() {
          this.IllustContent()
        }
        .width('100%')

        Column() {
          this.NovelContent()
        }
        .width('100%')

        Column() {
          this.UserContent()
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
          (index === 2 && extraInfo.currentOffset < 0)) {
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
        if (targetIndex < 0 || targetIndex >= 3) return;
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
  IllustContent() {
    if (this.isLoadingIllust) {
      LoadingProgress().width(40).height(40).margin({ top: 100 })
    } else if (this.illustError) {
      Column() {
        Text(this.illustError).fontSize(14).fontColor($r('app.color.text_secondary'))
        Button('重试').margin({ top: 12 }).onClick(() => this.searchIllusts(1, true))
      }
      .margin({ top: 80 })
      .alignItems(HorizontalAlign.Center)
    } else if (this.illustSource.totalCount() === 0) {
      Text('未找到相关插画').fontSize(14).fontColor($r('app.color.text_secondary')).margin({ top: 100 })
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
          if (!this.isLoadingMoreIllust && this.illustPage >= this.illustPages && this.illustSource.totalCount() > 0) {
            Text('- 已显示全部作品 -')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ top: 8, bottom: 24 })
          }
        }
        .width('100%')
        .padding({ bottom: 120 })
      }
      .width('100%')
      .edgeEffect(EdgeEffect.Spring)
      .onReachEnd(() => {
        if (!this.isLoadingMoreIllust && this.illustPage < this.illustPages) {
          this.loadMoreIllusts();
        }
      })
      .onScroll((_xOffset: number, yOffset: number) => {
        this.handleHeaderScroll(yOffset);
      })
    }
  }

  @Builder
  NovelContent() {
    if (this.isLoadingNovel) {
      LoadingProgress().width(40).height(40).margin({ top: 100 })
    } else if (this.novelError) {
      Column() {
        Text(this.novelError).fontSize(14).fontColor($r('app.color.text_secondary'))
        Button('重试').margin({ top: 12 }).onClick(() => this.searchNovels(1, true))
      }
      .margin({ top: 80 })
      .alignItems(HorizontalAlign.Center)
    } else if (this.novelSource.totalCount() === 0) {
      Text('未找到相关小说').fontSize(14).fontColor($r('app.color.text_secondary')).margin({ top: 100 })
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
          .padding(12)
          .width('100%')

          if (this.isLoadingMoreNovel) {
            LoadingProgress().width(30).height(30).margin({ top: 8, bottom: 16 })
          }
          if (!this.isLoadingMoreNovel && this.novelPage >= this.novelPages && this.novelSource.totalCount() > 0) {
            Text('- 已显示全部作品 -')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ top: 8, bottom: 24 })
          }
        }
        .width('100%')
        .padding({ bottom: 120 })
      }
      .width('100%')
      .edgeEffect(EdgeEffect.Spring)
      .onReachEnd(() => {
        if (!this.isLoadingMoreNovel && this.novelPage < this.novelPages) {
          this.loadMoreNovels();
        }
      })
      .onScroll((_xOffset: number, yOffset: number) => {
        this.handleHeaderScroll(yOffset);
      })
    }
  }

  @Builder
  UserContent() {
    if (this.isLoadingUser) {
      LoadingProgress().width(40).height(40).margin({ top: 100 })
    } else if (this.userError) {
      Column() {
        Text(this.userError).fontSize(14).fontColor($r('app.color.text_secondary'))
        Button('重试').margin({ top: 12 }).onClick(() => this.searchUsers(1, true))
      }
      .margin({ top: 80 })
      .alignItems(HorizontalAlign.Center)
    } else if (this.userSource.totalCount() === 0) {
      Text('未找到相关用户').fontSize(14).fontColor($r('app.color.text_secondary')).margin({ top: 100 })
    } else {
      Scroll() {
        Column() {
          Grid() {
            LazyForEach(this.userSource, (item: UserSearchResult, index: number) => {
              GridItem() {
                UserCard({ item: item, index: index })
              }
            }, (item: UserSearchResult) => item.userId)
          }
          .columnsTemplate('1fr')
          .columnsGap(8)
          .rowsGap(8)
          .padding(12)
          .width('100%')

          if (this.isLoadingMoreUser) {
            LoadingProgress().width(30).height(30).margin({ top: 8, bottom: 16 })
          }
          if (!this.isLoadingMoreUser && this.userPage >= this.userPages && this.userSource.totalCount() > 0) {
            Text('- 已显示全部用户 -')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ top: 8, bottom: 24 })
          }
        }
        .width('100%')
        .padding({ bottom: 120 })
      }
      .width('100%')
      .edgeEffect(EdgeEffect.Spring)
      .onReachEnd(() => {
        if (!this.isLoadingMoreUser && this.userPage < this.userPages) {
          this.loadMoreUsers();
        }
      })
      .onScroll((_xOffset: number, yOffset: number) => {
        this.handleHeaderScroll(yOffset);
      })
    }
  }
}
