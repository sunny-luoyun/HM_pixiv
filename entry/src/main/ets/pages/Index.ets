import { SymbolGlyphModifier } from '@kit.ArkUI';
import { window } from '@kit.ArkUI';
import { HdsTabs, HdsTabsController, hdsMaterial } from '@kit.UIDesignKit';
import { HomePage } from './home/HomePage';
import { LatestPage } from './latest/LatestPage';
import { SearchPage } from './search/SearchPage';
import { SettingPage } from './setting/SettingPage';
import { appState } from '../store/AppState';
import { PageContext } from '../common/utils/PageContext';
import { PageEnum } from '../common/constants/PageEnum';
import { IllustDetailBuilder } from './illust/IllustDetailPage';
import { IllustCommentsBuilder } from './illust/IllustCommentsPage';
import { NovelReaderBuilder } from './novel/NovelReaderPage';
import { NovelSeriesBuilder } from './novel/NovelSeriesPage';
import { NovelCommentsBuilder } from './novel/NovelCommentsPage';
import { UserProfileBuilder } from './user/UserProfilePage';
import { LoginBuilder } from './login/LoginPage';
import { FavoritesBuilder } from './favorites/FavoritesPage';
import { FollowingBuilder } from './setting/FollowingPage';
import { BlockedContentBuilder } from './setting/BlockedContentPage';
import { SettingsBuilder } from './settings/SettingsPage';
import { AuthorDetailBuilder } from './settings/AuthorDetailPage';
import { CachedNovelsBuilder } from './settings/CachedNovelsPage';
import { CachedNovelsSimpleBuilder } from './settings/CachedNovelsSimplePage';
import { SeriesDetailBuilder } from './settings/SeriesDetailPage';
import { AnimateCallback, CustomTransition } from '../common/utils/CustomTransitionUtils';

interface TabConfig {
  iconNormal: SymbolGlyphModifier;
  iconSelected: SymbolGlyphModifier;
  label: string;
}

const TAB_CONFIG: TabConfig[] = [
  {
    iconNormal: new SymbolGlyphModifier($r('sys.symbol.house'))
      .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_COLOR)
      .fontColor([$r('app.color.text_secondary')]),
    iconSelected: new SymbolGlyphModifier($r('sys.symbol.house_fill'))
      .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_COLOR)
      .fontColor([$r('app.color.tab_selected')]),
    label: '发现'
  },
  {
    iconNormal: new SymbolGlyphModifier($r('sys.symbol.clock'))
      .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_COLOR)
      .fontColor([$r('app.color.text_secondary')]),
    iconSelected: new SymbolGlyphModifier($r('sys.symbol.clock_fill'))
      .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_COLOR)
      .fontColor([$r('app.color.tab_selected')]),
    label: '最新'
  },
  {
    iconNormal: new SymbolGlyphModifier($r('sys.symbol.magnifyingglass'))
      .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_COLOR)
      .fontColor([$r('app.color.text_secondary')]),
    iconSelected: new SymbolGlyphModifier($r('sys.symbol.magnifyingglass'))
      .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_COLOR)
      .fontColor([$r('app.color.tab_selected')]),
    label: '搜索'
  },
  {
    iconNormal: new SymbolGlyphModifier($r('sys.symbol.person'))
      .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_COLOR)
      .fontColor([$r('app.color.text_secondary')]),
    iconSelected: new SymbolGlyphModifier($r('sys.symbol.person_fill'))
      .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_COLOR)
      .fontColor([$r('app.color.tab_selected')]),
    label: '我的'
  }
];

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  @State isReady: boolean = false;
  @Provide('isLoggedIn') isLoggedIn: boolean = false;
  @State materialLevel: hdsMaterial.MaterialLevel = hdsMaterial.MaterialLevel.EXQUISITE;
  @State bottomInsetVp: number = 0;
  @State isNavigationEnabled: boolean = true;
  private tabsController: HdsTabsController = new HdsTabsController();
  private rootStack: NavPathStack = new NavPathStack();
  private rootPageContext: PageContext = new PageContext(this.rootStack);

  async aboutToAppear() {
    // 读取底部导航条避让高度，确保浮动栏不被系统手势条遮挡
    this.readBottomInset();

    // 设备沉浸光感能力探测：不支持 IMMERSIVE 材质则降级为 SMOOTH 保障流畅度
    const materialTypes = hdsMaterial.getSystemMaterialTypes();
    if (materialTypes.indexOf(hdsMaterial.MaterialType.IMMERSIVE) < 0) {
      this.materialLevel = hdsMaterial.MaterialLevel.SMOOTH;
      console.info('⚠️ 当前设备不支持 IMMERSIVE 材质，沉浸光感降级为 SMOOTH');
    }

    await appState.checkLoginStatus(true);
    this.isLoggedIn = appState.isLoggedIn;
    console.info(`🔄 检查登录状态: ${appState.isLoggedIn ? '已登录' : '未登录'}`);
    console.info(`👤 用户: ${appState.userName || '未知用户'} (${appState.userId || '无ID'})`);
    AppStorage.setOrCreate('rootPageContext', this.rootPageContext);
    AppStorage.setOrCreate('uiContext', this.getUIContext());
    this.isReady = true;
  }

  onPageShow() {
    this.isLoggedIn = appState.isLoggedIn;
  }

  private readBottomInset(): void {
    const uiCtx = this.getUIContext();
    if (!uiCtx) { return; }
    const hostCtx = uiCtx.getHostContext();
    if (!hostCtx) { return; }
    window.getLastWindow(hostCtx).then((lastWindow: window.Window) => {
      const avoidArea = lastWindow.getWindowAvoidArea(
        window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR
      );
      const inset = uiCtx.px2vp(avoidArea.bottomRect.height);
      if (inset > 0) {
        this.bottomInsetVp = inset;
        console.info(`✅ 底部导航条避让高度: ${inset}vp`);
      }
    });
  }

  @Builder
  pagesBuilder(name: string, param: Object) {
    if (name === PageEnum.ILLUST_DETAIL) {
      IllustDetailBuilder()
    } else if (name === PageEnum.ILLUST_COMMENTS) {
      IllustCommentsBuilder()
    } else if (name === PageEnum.NOVEL_READER) {
      NovelReaderBuilder()
    } else if (name === PageEnum.NOVEL_SERIES) {
      NovelSeriesBuilder()
    } else if (name === PageEnum.NOVEL_COMMENTS) {
      NovelCommentsBuilder()
    } else if (name === PageEnum.USER_PROFILE) {
      UserProfileBuilder()
    } else if (name === PageEnum.LOGIN) {
      LoginBuilder()
    } else if (name === PageEnum.FAVORITES) {
      FavoritesBuilder()
    } else if (name === PageEnum.FOLLOWING) {
      FollowingBuilder()
    } else if (name === PageEnum.BLOCKED_CONTENT) {
      BlockedContentBuilder()
    } else if (name === PageEnum.SETTINGS) {
      SettingsBuilder()
    } else if (name === PageEnum.AUTHOR_DETAIL) {
      AuthorDetailBuilder()
    } else if (name === PageEnum.CACHED_NOVELS) {
      CachedNovelsBuilder()
    } else if (name === PageEnum.CACHED_NOVELS_SIMPLE) {
      CachedNovelsSimpleBuilder()
    } else if (name === PageEnum.SERIES_DETAIL) {
      SeriesDetailBuilder()
    }
  }

  build() {
    Navigation(this.rootStack) {
      if (this.isReady) {
        HdsTabs({
          controller: this.tabsController,
          index: this.currentIndex,
          barPosition: BarPosition.End
        }) {
          TabContent() {
            HomePage()
          }
          .tabBar(new BottomTabBarStyle({
            normal: TAB_CONFIG[0].iconNormal,
            selected: TAB_CONFIG[0].iconSelected
          }, TAB_CONFIG[0].label)
          .labelStyle({ selectedColor: $r('app.color.tab_selected') }))

          TabContent() {
            LatestPage()
          }
          .tabBar(new BottomTabBarStyle({
            normal: TAB_CONFIG[1].iconNormal,
            selected: TAB_CONFIG[1].iconSelected
          }, TAB_CONFIG[1].label)
          .labelStyle({ selectedColor: $r('app.color.tab_selected') }))

          TabContent() {
            SearchPage()
          }
          .tabBar(new BottomTabBarStyle({
            normal: TAB_CONFIG[2].iconNormal,
            selected: TAB_CONFIG[2].iconSelected
          }, TAB_CONFIG[2].label)
          .labelStyle({ selectedColor: $r('app.color.tab_selected') }))

          TabContent() {
            SettingPage()
          }
          .tabBar(new BottomTabBarStyle({
            normal: TAB_CONFIG[3].iconNormal,
            selected: TAB_CONFIG[3].iconSelected
          }, TAB_CONFIG[3].label)
          .labelStyle({ selectedColor: $r('app.color.tab_selected') }))
        }
        .barMode(BarMode.Fixed)
        .barOverlap(true)
        .vertical(false)
        .clip(false)
        .barFloatingStyle({
          barBottomMargin: this.bottomInsetVp,
          barOpacity: 0.95,
          systemMaterialEffect: {
            materialType: hdsMaterial.MaterialType.IMMERSIVE,
            materialLevel: this.materialLevel
          }
        })
        .onChange((index: number) => {
          this.currentIndex = index;
        })
      } else {
        Column() {
          LoadingProgress().width(40).height(40)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('app.color.page_background'))
      }
    }
    .navDestination(this.pagesBuilder)
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .hideToolBar(true)
    .enabled(this.isNavigationEnabled)
    .customNavContentTransition((from: NavContentInfo, to: NavContentInfo,
      operation: NavigationOperation) => {
      if (operation === NavigationOperation.PUSH) {
        if (!to || !to.navDestinationId) {
          return undefined;
        }
      } else {
        if (!to || to.navDestinationId) {
          return undefined;
        }
      }
      let fromParam: AnimateCallback = from?.navDestinationId
        ? CustomTransition.getInstance().getAnimateParam(from.navDestinationId)
        : {} as AnimateCallback;
      let toParam: AnimateCallback = to?.navDestinationId
        ? CustomTransition.getInstance().getAnimateParam(to.navDestinationId)
        : {} as AnimateCallback;
      CustomTransition.getInstance().operation = operation;
      if (!fromParam.animation && !toParam.animation) {
        return undefined;
      }
      let customAnimation: NavigationAnimatedTransition = {
        onTransitionEnd: () => {
          this.isNavigationEnabled = true;
        },
        timeout: 1500,
        transition: (transitionProxy: NavigationTransitionProxy) => {
          this.isNavigationEnabled = false;
          if (fromParam.animation) {
            fromParam.animation(transitionProxy);
          }
          if (toParam.animation) {
            toParam.animation(transitionProxy);
          }
        }
      };
      return customAnimation;
    })
  }
}
