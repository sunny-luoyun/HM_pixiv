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
import { MainTabsBuilder } from './TabsPage';
import { AnimateCallback, CustomTransition } from '../common/utils/CustomTransitionUtils';

@Entry
@Component
struct Index {
  @State isReady: boolean = false;
  @State isNavigationEnabled: boolean = true;
  private rootStack: NavPathStack = new NavPathStack();
  private rootPageContext: PageContext = new PageContext(this.rootStack);

  async aboutToAppear() {
    await appState.checkLoginStatus(true);
    console.info(`🔄 检查登录状态: ${appState.isLoggedIn ? '已登录' : '未登录'}`);
    console.info(`👤 用户: ${appState.userName || '未知用户'} (${appState.userId || '无ID'})`);
    AppStorage.setOrCreate('rootPageContext', this.rootPageContext);
    AppStorage.setOrCreate('uiContext', this.getUIContext());
    this.isReady = true;
    if (this.rootStack.size() === 0) {
      this.rootStack.pushPath({ name: PageEnum.MAIN_TABS } as NavPathInfo, false);
    }
  }

  @Builder
  pagesBuilder(name: string, param: Object) {
    if (name === PageEnum.MAIN_TABS) {
      MainTabsBuilder()
    } else if (name === PageEnum.ILLUST_DETAIL) {
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
      if (!this.isReady) {
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
      if ((!from || !to) || (!from.navDestinationId || !to.navDestinationId)) {
        return undefined;
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
