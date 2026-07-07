import { SymbolGlyphModifier, display } from '@kit.ArkUI';
import { window } from '@kit.ArkUI';
import promptAction from '@ohos.promptAction';
import { common } from '@kit.AbilityKit';
import { HdsTabs, HdsTabsController, hdsMaterial } from '@kit.UIDesignKit';
import { HomePage } from './home/HomePage';
import { LatestPage } from './latest/LatestPage';
import { SearchPage } from './search/SearchPage';
import { SettingPage } from './setting/SettingPage';
import { resolveBreakpoint, publishBreakpoint } from '../common/utils/BreakpointManager';

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

@Component
export struct MainTabsPage {
  @State currentIndex: number = 0;
  @State materialLevel: hdsMaterial.MaterialLevel = hdsMaterial.MaterialLevel.EXQUISITE;
  @State bottomInsetVp: number = 0;
  @StorageLink('notificationNavigateTab') @Watch('onNotificationNavigateTabChange') notificationNavigateTab: number = -1;
  private tabsController: HdsTabsController = new HdsTabsController();
  private backPressTime: number = 0;
  private readonly PRESS_INTERVAL: number = 1500;

  aboutToAppear(): void {
    this.readBottomInset();
    const materialTypes = hdsMaterial.getSystemMaterialTypes();
    if (materialTypes.indexOf(hdsMaterial.MaterialType.IMMERSIVE) < 0) {
      this.materialLevel = hdsMaterial.MaterialLevel.SMOOTH;
      console.info('⚠️ 当前设备不支持 IMMERSIVE 材质，沉浸光感降级为 SMOOTH');
    }
    this.initBreakpoint();
  }

  private initBreakpoint(): void {
    const dd = display.getDefaultDisplaySync();
    const widthVp = px2vp(dd.width);
    const bp = resolveBreakpoint(widthVp);
    publishBreakpoint(bp);
    console.info(`📐 断点初始: ${bp} (${widthVp}vp, ${dd.width}px)`);
  }

  onNotificationNavigateTabChange(): void {
    if (this.notificationNavigateTab >= 0 && this.notificationNavigateTab !== this.currentIndex) {
      this.currentIndex = this.notificationNavigateTab;
      this.tabsController.changeIndex(this.currentIndex);
      AppStorage.setOrCreate('notificationNavigateTab', -1);
    }
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

  build() {
    NavDestination() {
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
    }
    .hideTitleBar(true)
    .onBackPressed(() => {
      const now = new Date().getTime();
      if (this.backPressTime > 0 && now - this.backPressTime < this.PRESS_INTERVAL) {
        this.backPressTime = 0;
        const ctx = getContext(this) as common.UIAbilityContext;
        ctx.terminateSelf();
        return true;
      }
      this.backPressTime = now;
      promptAction.showToast({ message: '再按一次退出应用', duration: this.PRESS_INTERVAL });
      return true;
    })
  }
}

@Builder
export function MainTabsBuilder() {
  MainTabsPage()
}
