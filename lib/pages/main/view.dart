import 'dart:io';

import 'package:PiliPlus/common/assets.dart';
import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/desktop/desktop_search_panel.dart';
import 'package:PiliPlus/common/widgets/desktop/desktop_shortcuts.dart';
import 'package:PiliPlus/common/widgets/desktop/desktop_side_bar.dart';
import 'package:PiliPlus/common/widgets/desktop/desktop_tokens.dart';
import 'package:PiliPlus/main.dart' show windowMinimumSize;
import 'package:PiliPlus/common/widgets/desktop/desktop_top_bar.dart';
import 'package:PiliPlus/common/widgets/floating_navigation_bar.dart';
import 'package:PiliPlus/common/widgets/flutter/pop_scope.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/main_layout.dart';
import 'package:PiliPlus/common/widgets/route_aware_mixin.dart';
import 'package:PiliPlus/models/common/nav_bar_config.dart';
import 'package:PiliPlus/pages/fav/view.dart';
import 'package:PiliPlus/pages/history/view.dart';
import 'package:PiliPlus/pages/home/view.dart';
import 'package:PiliPlus/pages/later/view.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/pages/mine/view.dart';
import 'package:PiliPlus/pages/subscription/view.dart';
import 'package:PiliPlus/pages/whisper/view.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/utils/android/android_helper.dart';
import 'package:PiliPlus/utils/app_scheme.dart';
import 'package:PiliPlus/utils/extension/context_ext.dart';
import 'package:PiliPlus/utils/extension/size_ext.dart';
import 'package:PiliPlus/utils/extension/theme_ext.dart';
import 'package:PiliPlus/utils/mobile_observer.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:win32/win32.dart' as kernel32;
import 'package:window_manager/window_manager.dart';

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  /// 侧栏「私信」面板宽度 = 当前**整个窗口可用宽度**的约 1/3。
  ///
  /// 不是侧栏宽度的 1/3、也不是内容区宽度的 1/3；再做合理上下限约束：
  /// 下限 320 保证窄窗可用，上限 `contentWidth − 16` 保证面板不会铺满内容区。
  /// 纯函数（不依赖 BuildContext），便于按窗口宽度直接验证。
  static double whisperPanelWidth(double windowWidth) {
    final double target = windowWidth / 3;
    const double max = DesktopTokens.contentWidth - 16;
    if (target < 320) return 320;
    if (target > max) return max;
    return target;
  }

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends PopScopeState<MainApp>
    with
        RouteAware,
        RouteAwareMixin,
        WidgetsBindingObserver,
        WindowListener,
        TrayListener {
  final _mainController = Get.put(MainController());
  late final _setting = GStorage.setting;
  late EdgeInsets _padding;
  late ColorScheme _colorScheme;
  Brightness? _brightness;

  /// 桌面顶栏的搜索浮层是否展开
  bool _searchPanelOpen = false;

  /// 桌面「私信 / 消息」面板（覆盖层，非路由页）。
  ///
  /// 侧栏「私信」磁贴与账号区「消息」铃铛**共用同一个面板宿主**：
  /// 面板挂在内容区（左缘 = 侧栏右缘），宽度约为窗口 1/3，
  /// 当前页面保持为背景、完全不重新布局。
  ///
  /// 采用**瞬时显示/隐藏**（无开关动画）：`true` 时面板直接以最终位置出现，
  /// `false` 时立即从树上卸载。
  bool _whisperPanelVisible = false;

  /// 侧栏「私信 / 消息」面板宽度（= [MainApp.whisperPanelWidth]，基于窗口宽度）
  double _whisperPanelWidth(BuildContext context) =>
      MainApp.whisperPanelWidth(MediaQuery.sizeOf(context).width);

  /// 两个入口共用：打开面板（立即显示）
  void _openWhisperPanel() {
    if (_whisperPanelVisible) return;
    setState(() {
      _whisperPanelVisible = true;
      // 侧栏「私信」项的选中态复用既有 desktopContentRoute 机制
      _mainController.desktopContentRoute.value = '/whisper';
    });
  }

  /// 两个入口共用：关闭面板（立即隐藏）
  void _closeWhisperPanel() {
    if (!_whisperPanelVisible) return;
    setState(() {
      _whisperPanelVisible = false;
      _mainController.desktopContentRoute.value = null;
    });
  }

  /// 「私信」磁贴入口：点当前入口即关闭（再次点击切换状态）
  void _toggleWhisperPanel() {
    if (_whisperPanelVisible) {
      _closeWhisperPanel();
    } else {
      _openWhisperPanel();
    }
  }

  /// 账号区「消息」铃铛入口：点击即打开同一个面板（不关闭再打开）
  void _openMsgPanel() {
    _openWhisperPanel();
  }

  /// 「私信 / 消息」面板覆盖层（无动画，直接落在最终位置）。
  ///
  /// * 遮罩：只覆盖面板之外的内容区，点它即关闭；颜色沿用 `black @ 54%`；
  /// * 面板：`Positioned(left: 0, width: 面板宽)` ⇒ 左缘恒等于内容区左缘
  ///   = 侧栏右缘（侧栏宽 216），不做任何平移；
  /// * 两个入口渲染同一个页面（二者在侧栏本来就指向同一功能）。
  Widget _whisperPanel() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 遮罩：点面板以外区域关闭
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _closeWhisperPanel,
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.54),
            child: const LimitedBox(
              maxWidth: 0,
              maxHeight: 0,
              child: SizedBox.expand(),
            ),
          ),
        ),
        // 面板：左缘固定在内容区左缘（= 侧栏右缘），直接使用最终位置
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: _whisperPanelWidth(context),
          child: Material(
            color: DesktopTokens.surface(_colorScheme),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(DesktopTokens.radius),
              ),
              side: BorderSide(color: DesktopTokens.divider(_colorScheme)),
            ),
            clipBehavior: Clip.hardEdge,
            // 私信内容原样复用既有页面；面板内返回关闭面板。
            child: WhisperPage(
              desktopEmbedded: true,
              onBack: _closeWhisperPanel,
            ),
          ),
        ),
      ],
    );
  }

  /// 顶栏搜索浮层状态（历史 / 联想；顶栏写入，浮层据此渲染）
  final ValueNotifier<DesktopSearchOverlayState> _searchOverlay = ValueNotifier(
    DesktopSearchOverlayState.empty,
  );

  @override
  bool get initCanPop => false;

  @override
  void initState() {
    super.initState();
    addObserverMobile(this);


    if (Platform.isMacOS) {
      HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    }
    if (PlatformUtils.isDesktop) {
      windowManager
        ..addListener(this)
        ..setPreventClose(true);
      if (_mainController.showTrayIcon) {
        trayManager.addListener(this);
        _handleTray();
      }
    }
    if (!Platform.isMacOS) {
      PiliScheme.init();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _padding = MediaQuery.viewPaddingOf(context);
    _colorScheme = ColorScheme.of(context);
    final brightness = _colorScheme.brightness;
    NetworkImgLayer.reduce =
        NetworkImgLayer.reduceLuxColor != null && brightness.isDark;
    if (PlatformUtils.isDesktop) {
      if (_brightness != brightness) {
        _brightness = brightness;
        windowManager.setBrightness(brightness);
      }
    }
    if (!_mainController.useSideBar) {
      // 桌面端粘滞：不因窗口变竖切到底部导航（移动端壳层）
      _mainController.useBottomNav =
          !context.isDesktopLayout && MediaQuery.sizeOf(context).isPortrait;
    }
  }

  @override
  void didPopNext() {
    addObserverMobile(this);
    _mainController
      ..checkUnreadDynamic()
      ..checkDefaultSearch(true)
      ..checkUnread(_mainController.useBottomNav);
    super.didPopNext();
  }

  @override
  void didPushNext() {
    removeObserverMobile(this);
    // 「我的」页快捷入口的就地预览（真实页面组件的第二个实例）不能与同类型的
    // 完整页面同时存活：这些页面在 initState 里 Get.put、dispose 里 Get.delete，
    // 两实例会共用同一个控制器并互相删除（例如 /fav 的 FavController.scrollController
    // 被两个滚动视图同时 attach）。压入同名路由（/fav、/whisper、/history…）前
    // 先收起预览，预览实例在本帧出树后再由路由页自行注册。
    if (_mainController.desktopShortcutPreview.value == Get.currentRoute) {
      _mainController.desktopShortcutPreview.value = null;
    }
    super.didPushNext();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _mainController
        ..checkUnreadDynamic()
        ..checkDefaultSearch(true)
        ..checkUnread(_mainController.useBottomNav);
    }
  }

  @override
  void dispose() {
    if (Platform.isMacOS) {
      HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    }
    if (PlatformUtils.isDesktop) {
      trayManager.removeListener(this);
      windowManager.removeListener(this);
    }
    removeObserverMobile(this);
    PiliScheme.listener?.cancel();
    _searchOverlay.dispose();
    GStorage.close();
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    return event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.keyR &&
        HardwareKeyboard.instance.isMetaPressed &&
        _mainController.refreshRecommendations();
  }

  @override
  void onWindowMaximize() {
    _setting.put(SettingBoxKey.isWindowMaximized, true);
  }

  @override
  void onWindowUnmaximize() {
    _setting.put(SettingBoxKey.isWindowMaximized, false);
  }

  @override
  Future<void> onWindowMoved() async {
    if (PlPlayerController.instance?.isDesktopPip ?? false) {
      return;
    }
    // 播放器全屏（含全屏期间窗口被移动）同样不写回几何：
    // 全屏是一次性 SetWindowPos，若在此持久化会把全屏尺寸/位置当成用户窗口几何。
    if (PlPlayerController.instance?.isFullScreen.value == true) {
      return;
    }
    final Offset offset = await windowManager.getPosition();
    _setting.put(SettingBoxKey.windowPosition, [offset.dx, offset.dy]);
  }

  @override
  Future<void> onWindowResized() async {
    if (PlPlayerController.instance?.isDesktopPip ?? false) {
      return;
    }
    // 同上：播放器全屏期间不写回 windowSize / windowPosition，退出全屏后恢复保存。
    if (PlPlayerController.instance?.isFullScreen.value == true) {
      return;
    }
    final Rect bounds = await windowManager.getBounds();
    // 被最小窗口尺寸（固定 960x640）夹住时不写回：
    // 该尺寸不是用户选择，持久化后会把窗口几何整体撑大。
    final minSize = windowMinimumSize();
    if (bounds.width <= minSize.width + 0.5 &&
        bounds.height <= minSize.height + 0.5) {
      return;
    }
    _setting.putAll({
      SettingBoxKey.windowSize: [bounds.width, bounds.height],
      SettingBoxKey.windowPosition: [bounds.left, bounds.top],
    });
  }

  @override
  void onWindowClose() {
    if (_mainController.showTrayIcon && _mainController.minimizeOnExit) {
      _hide();
      _onHideWindow();
    } else {
      _onClose();
    }
  }

  Future<void> _onClose() async {
    await GStorage.compact();
    await GStorage.close();
    await trayManager.destroy();
    if (Platform.isWindows) {
      // flutter_inappwebview
      // 6.2.0-beta.2+ https://github.com/pichillilorenzo/flutter_inappwebview/issues/2482
      // 6.1.5 https://github.com/pichillilorenzo/flutter_inappwebview/issues/2512#issuecomment-3031039587
      final hProcess = kernel32.GetCurrentProcess();
      kernel32.TerminateProcess(hProcess, 0);
    } else {
      exit(0);
    }
  }

  @override
  void onWindowMinimize() {
    _onHideWindow();
  }

  @override
  void onWindowRestore() {
    _onShowWindow();
  }

  void _onHideWindow() {
    if (_mainController.pauseOnMinimize) {
      if (PlPlayerController.instance case final player?) {
        if (_mainController.isPlaying = player.playerStatus.isPlaying) {
          player.pause();
        }
      } else {
        _mainController.isPlaying = false;
      }
    }
  }

  void _onShowWindow() {
    if (_mainController.pauseOnMinimize && _mainController.isPlaying) {
      PlPlayerController.instance?.play();
    }
  }

  double? _opacity;

  Future<void>? _setOpacity(double opacity) {
    if (Platform.isWindows && _opacity != opacity) {
      _opacity = opacity;
      return windowManager.setOpacity(opacity);
    }
    return null;
  }

  @override
  Future<void>? onWindowFocus() {
    return _setOpacity(1.0);
  }

  /// https://github.com/leanflutter/window_manager/issues/571
  Future<void> _hide() async {
    await _setOpacity(0.0);
    await windowManager.hide();
  }

  Future<void> _show() {
    return windowManager.show();
  }

  @override
  Future<void> onTrayIconMouseDown() async {
    if (await windowManager.isVisible()) {
      _onHideWindow();
      _hide();
    } else {
      _onShowWindow();
      _show();
    }
  }

  @override
  Future<void> onTrayIconRightMouseDown() async {
    // ignore: deprecated_member_use
    trayManager.popUpContextMenu(bringAppToFront: true);
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        _show();
      case 'exit':
        _onClose();
    }
  }

  Future<void> _handleTray() async {
    if (Platform.isWindows) {
      await trayManager.setIcon(Assets.logoIco);
    } else {
      await trayManager.setIcon(Assets.logoLarge);
    }
    if (!Platform.isLinux) {
      await trayManager.setToolTip(Constants.appName);
    }

    Menu trayMenu = Menu(
      items: [
        MenuItem(key: 'show', label: '显示窗口'),
        MenuItem.separator(),
        MenuItem(key: 'exit', label: '退出 ${Constants.appName}'),
      ],
    );
    await trayManager.setContextMenu(trayMenu);
  }

  @pragma('vm:prefer-inline')
  static void _onBack() {
    if (Platform.isAndroid) {
      PiliAndroidHelper.back();
    }
  }

  @override
  void onPopInvokedWithResult(bool didPop, Object? result) {
    if (_mainController.directExitOnBack) {
      _onBack();
    } else {
      if (_mainController.selectedIndex.value != 0) {
        _mainController
          ..setIndex(0)
          ..barOffset?.value = 0.0
          ..showBottomBar?.value = true
          ..setSearchBar();
      } else {
        _onBack();
      }
    }
  }

  Widget? get _bottomNav {
    Widget? bottomNav;
    if (_mainController.navigationBars.length > 1) {
      if (_mainController.floatingNavBar) {
        bottomNav = Obx(
          () => FloatingNavigationBar(
            onDestinationSelected: _mainController.setIndex,
            selectedIndex: _mainController.selectedIndex.value,
            destinations: _mainController.navigationBars
                .map(
                  (e) => FloatingNavigationDestination(
                    label: e.label,
                    icon: _buildIcon(type: e),
                    selectedIcon: _buildIcon(type: e, selected: true),
                  ),
                )
                .toList(),
          ),
        );
      } else if (_mainController.enableMYBar) {
        bottomNav = Obx(
          () => NavigationBar(
            maintainBottomViewPadding: true,
            onDestinationSelected: _mainController.setIndex,
            selectedIndex: _mainController.selectedIndex.value,
            destinations: _mainController.navigationBars
                .map(
                  (e) => NavigationDestination(
                    label: e.label,
                    icon: _buildIcon(type: e),
                    selectedIcon: _buildIcon(type: e, selected: true),
                  ),
                )
                .toList(),
          ),
        );
      } else {
        bottomNav = Obx(
          () => BottomNavigationBar(
            currentIndex: _mainController.selectedIndex.value,
            onTap: _mainController.setIndex,
            iconSize: 16,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            type: .fixed,
            items: _mainController.navigationBars
                .map(
                  (e) => BottomNavigationBarItem(
                    label: e.label,
                    icon: _buildIcon(type: e),
                    activeIcon: _buildIcon(type: e, selected: true),
                  ),
                )
                .toList(),
          ),
        );
      }

      if (_mainController.hideBottomBar) {
        if (_mainController.barOffset case final barOffset?) {
          return Obx(
            () => FractionalTranslation(
              translation: Offset(
                0.0,
                barOffset.value / Style.topBarHeight,
              ),
              child: bottomNav,
            ),
          );
        }
        if (_mainController.showBottomBar case final showBottomBar?) {
          return Obx(
            () => AnimatedSlide(
              curve: Curves.easeInOutCubicEmphasized,
              duration: const Duration(milliseconds: 500),
              offset: Offset(0, showBottomBar.value ? 0 : 1),
              child: bottomNav,
            ),
          );
        }
      }
    }

    return bottomNav;
  }

  /// 桌面端：右侧主内容区 = 常驻的主 Tab + 带动画的内容页层。
  /// 主 Tab 的 PageView/TabBarView 始终留在树中（不销毁），只叠加 / 移除
  /// 内容页层，因此首页/动态/我的的滚动位置与状态保持
  /// （与改动前 IndexedStack 的保活语义一致）。
  Widget _desktopContentArea(Widget child) {
    if (!PlatformUtils.isDesktop) {
      return child;
    }
    return Obx(() {
      final content = _mainController.desktopContentPage.value;
      _syncRootCanPop(hasContentPage: content != null);
      return _DesktopContentArea(
        route: _mainController.desktopContentRoute.value,
        content: content,
        child: child,
      );
    });
  }

  /// 同步根路由的 pop 否决（[PopScopeState.canPopNotifier]，仅桌面端）：
  ///
  /// 主壳 MainApp 通过 `initCanPop => false` 在根路由上登记了 pop 否决，用于把
  /// 返回请求交给它自己的 onPopInvokedWithResult（退出 / 切回首页 Tab）。
  /// 但桌面内容页（历史记录等）是**就地承载、不是路由**，它们 `popScope(canPop:
  /// !enableMultiSelect)` 内部态也登记在同一个根路由上；两者混在一起会让
  /// `Get.routing.route.popDisposition` 恒为 doNotPop，导致 main.dart 的 `_onBack`
  /// 在到达 desktopContentBackHandler 之前就 return（侧键失效的根因）。
  ///
  /// 因此：承载内容页时撤掉主壳自己的否决，让根路由的否决只反映内容页声明的内部态
  /// （多选态 → 由内容页自己退出，与改动前一致）；收起内容页后恢复否决，
  /// 维持原有根路由兜底行为。移动端不执行（[PlatformUtils.isDesktop] 保护）。
  void _syncRootCanPop({required bool hasContentPage}) {
    // 未承载内容页 → 保持主壳原有的否决（canPop=false）；
    // 承载内容页 → 撤掉主壳的否决（canPop=true），把否决权让给内容页自己的 popScope。
    final canPop = hasContentPage;
    if (canPopNotifier.value != canPop) {
      canPopNotifier.value = canPop;
    }
  }

  /// 桌面顶栏是否显示：只在「当前主 Tab 是首页 且 未承载桌面内容页」时显示。
  /// 其余页面（动态 / 我的 / 历史记录等就地内容页）完全无顶栏。
  /// 注意：读取了 Rx，必须在响应式构建（Obx）里调用。
  bool get _showDesktopTopBar {
    final nav = _mainController.navigationBars;
    final index = _mainController.selectedIndex.value;
    return _mainController.desktopContentPage.value == null &&
        index < nav.length &&
        nav[index] == NavigationBarType.home;
  }

  /// 主 Tab 页：桌面端把「快捷入口」的就地打开回调交给「我的」页
  /// （与侧栏共用同一个闭包 → 两处入口行为完全一致）；
  /// 移动端 / 其它主 Tab 保持原样（返回既有页面实例）。
  Widget _tabPage(NavigationBarType type) {
    if (PlatformUtils.isDesktop && type == NavigationBarType.mine) {
      return MinePage(onSelectShortcut: _openDesktopShortcut);
    }
    return type.page;
  }

  /// 桌面快捷入口的统一点击路径（侧栏与「我的」页共用同一个闭包）：
  /// 在主内容区就地承载对应页面（页面自带返回按钮 + 两级返回 + 鼠标侧键），
  /// 返回 true 表示已处理；未接入的入口返回 false → 调用方保持原有
  /// `Get.toNamed(entry.route)` 行为不变。
  ///
  /// 「我的」页的就地预览若正在显示，先把它收起（清空预览选中项）并**推迟一帧**
  /// 再建内容页：预览实例与内容页实例会用同一套 GetX 控制器
  /// （initState `Get.put` / dispose `Get.delete`），必须先让预览出树销毁，
  /// 内容页才能拿到干净的控制器与滚动控制器（否则预览 dispose 会删掉内容页正在
  /// 用的控制器，例如 LaterBaseController）。
  bool _openDesktopShortcut(DesktopNavEntry entry) {
    // 桌面「私信」：不走「主内容区就地打开完整页面」，改为从侧栏右缘滑出约 1/3 宽面板
    if (PlatformUtils.isDesktop && entry.route == '/whisper') {
      _toggleWhisperPanel();
      return true;
    }
    if (_mainController.desktopShortcutPreview.value != null) {
      _mainController.desktopShortcutPreview.value = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openDesktopContentPage(entry);
      });
      return true;
    }
    return _openDesktopContentPage(entry);
  }

  bool _openDesktopContentPage(DesktopNavEntry entry) {
    final Widget? page = switch (entry.route) {
      '/history' => HistoryPage(
        desktopEmbedded: true,
        onBack: _mainController.closeDesktopContentPage,
      ),
      '/later' => LaterPage(
        desktopEmbedded: true,
        onBack: _mainController.closeDesktopContentPage,
      ),
      '/fav' => FavPage(
        desktopEmbedded: true,
        onBack: _mainController.closeDesktopContentPage,
      ),
      '/subscription' => SubPage(
        desktopEmbedded: true,
        onBack: _mainController.closeDesktopContentPage,
      ),
      '/whisper' => WhisperPage(
        desktopEmbedded: true,
        onBack: _mainController.closeDesktopContentPage,
      ),
      _ => null,
    };
    if (page == null) {
      return false;
    }
    _mainController.openDesktopContentPage(entry.route, page);
    return true;
  }

  Widget _sideBar() {
    // M2 桌面导航（与构建树同一套：桌面端走图标+文字扩展侧栏）
    if (PlatformUtils.isDesktop) {
      return DesktopSideBar(
        mainController: _mainController,
        colorScheme: _colorScheme,
        onSelect: (value) {
          // 切回主 Tab（首页/动态/我的）时先收起桌面内容页
          _mainController
            ..closeDesktopContentPage()
            ..setIndex(value);
        },
        // 桌面主内容区就地承载的快捷入口（页面自带返回按钮 + 两级返回 + 侧键），
        // 与「我的」页快捷入口共用同一个闭包
        onSelectShortcut: _openDesktopShortcut,
        // 账号区「消息」铃铛：与「私信」共用同一个侧滑面板，不再走完整路由页
        onSelectMsg: _openMsgPanel,
      );
    }
    if (_mainController.navigationBars.length > 1) {
      if (context.isTablet && _mainController.optTabletNav) {
        return Padding(
          padding: const .only(top: 25),
          child: MediaQuery.removePadding(
            context: context,
            removeRight: true,
            child: DrawerTheme(
              data: DrawerThemeData(width: 130 + _padding.left),
              child: Obx(
                () => NavigationDrawer(
                  /// apply `lib/scripts/navigation_drawer.patch`
                  flex: 5,
                  backgroundColor: Colors.transparent,
                  onDestinationSelected: _mainController.setIndex,
                  selectedIndex: _mainController.selectedIndex.value,
                  header: Expanded(flex: 4, child: userAndSearchVertical()),
                  tilePadding: const .symmetric(vertical: 5, horizontal: 12),
                  indicatorShape: const RoundedRectangleBorder(
                    borderRadius: .all(.circular(16)),
                  ),
                  children: _mainController.navigationBars
                      .map(
                        (e) => NavigationDrawerDestination(
                          label: Text(e.label),
                          icon: _buildIcon(type: e),
                          selectedIcon: _buildIcon(
                            type: e,
                            selected: true,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
        );
      }
      return Obx(
        () => NavigationRail(
          groupAlignment: 0.5,
          labelType: .selected,
          leading: userAndSearchVertical(),
          backgroundColor: Colors.transparent,
          onDestinationSelected: _mainController.setIndex,
          selectedIndex: _mainController.selectedIndex.value,
          destinations: _mainController.navigationBars
              .map(
                (e) => NavigationRailDestination(
                  label: Text(e.label),
                  icon: _buildIcon(type: e),
                  selectedIcon: _buildIcon(type: e, selected: true),
                ),
              )
              .toList(),
        ),
      );
    }
    return Container(
      width: 80,
      margin: .only(top: 12 + _padding.top, left: _padding.left),
      child: userAndSearchVertical(),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (_mainController.mainTabBarView) {
      child = TabBarView(
        controller: _mainController.controller,
        physics: const NeverScrollableScrollPhysics(),
        scrollDirection: _mainController.useBottomNav ? .horizontal : .vertical,
        children: _mainController.navigationBars.map(_tabPage).toList(),
      );
    } else {
      child = PageView(
        controller: _mainController.controller,
        physics: const NeverScrollableScrollPhysics(),
        children: _mainController.navigationBars.map(_tabPage).toList(),
      );
    }

    Widget? sideBar;
    Widget? bottomNav;
    final EdgeInsets padding;
    if (_mainController.useBottomNav) {
      bottomNav = _bottomNav;
      if (bottomNav != null) {
        bottomNav = MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: bottomNav,
        );
      }
      padding = _padding.copyWith(bottom: 0);
    } else {
      sideBar = DecoratedBox(
        decoration: BoxDecoration(
          // 桌面深色模式：侧栏用「深色模式颜色」里的侧栏配色
          // （浅色模式 / 非桌面端为 null → 沿用主题底色，行为不变）
          color:
              PlatformUtils.isDesktop &&
                  _colorScheme.brightness == Brightness.dark
              ? Pref.darkThemeColor.sidebar
              : null,
          border: Border(
            right: BorderSide(
              color: _colorScheme.outline.withValues(alpha: 0.06),
            ),
          ),
        ),
        child: _sideBar(),
      );
      padding = .only(top: _padding.top, right: _padding.right);
    }

    // 桌面顶栏：桌面 + 宽窗口（沿用既有 showNavbar = width > 800，不新增断点）
    // 时，**仅首页**（当前主 Tab 是首页，且未承载桌面内容页）在内容区上方保留
    // 一个只有搜索框的顶栏；其余页面（动态 / 我的 / 桌面内容页）顶栏与其下的
    // Divider 都不进 widget 树，内容直接顶到原顶栏位置。
    // 搜索历史 / 联想浮层在搜索框正下方按同一右边缘就地展开，不跳转搜索页。
    final Widget body = PlatformUtils.isDesktop && context.showNavbar
        ? Stack(
            fit: StackFit.expand,
            children: [
              Column(
                children: [
                  // 顶栏槽位固定为同一个 Obx（元素类型不随显示 / 隐藏变化），
                  // 因此下方 Expanded 不会被重建，_desktopContentArea 里
                  // IndexedStack 的保活语义不变（主 Tab 滚动位置不丢）。
                  Obx(() {
                    if (!_showDesktopTopBar) {
                      // 顶栏不在树里时浮层也不渲染，并同步收起展开状态，
                      // 避免切回首页时残留搜索历史浮层。
                      if (_searchPanelOpen) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) _closeSearch();
                        });
                      }
                      return const SizedBox.shrink();
                    }
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DesktopTopBar(
                          searchPanelOpen: _searchPanelOpen,
                          onOpenSearch: () =>
                              setState(() => _searchPanelOpen = true),
                          onCloseSearch: _closeSearch,
                          onOverlayChanged: (state) =>
                              _searchOverlay.value = state,
                        ),
                        const Divider(height: 1),
                      ],
                    );
                  }),
                  Expanded(child: _desktopContentArea(child)),
                ],
              ),
              // 搜索浮层：输入为空显示搜索历史，输入关键词后显示联想推荐。
              // 只在顶栏显示（首页）时渲染：非首页连遮挡层一起消失。
              if (_searchPanelOpen)
                Obx(
                  () => _showDesktopTopBar
                      ? ValueListenableBuilder<DesktopSearchOverlayState>(
                          valueListenable: _searchOverlay,
                          builder: (context, state, _) {
                            if (!state.visible) {
                              return const SizedBox.shrink();
                            }
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                // 透明遮罩：覆盖整个背景，但**挖空搜索框**所在矩形。
                                // 点搜索框不取消；点浮层不取消（浮层自身吸收点击）；
                                // 点其余任何位置都收起浮层。
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  height: DesktopTopBar.searchTop,
                                  child: _searchDismissBarrier(),
                                ),
                                Positioned(
                                  top:
                                      DesktopTopBar.searchTop +
                                      DesktopTopBar.searchHeight,
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: _searchDismissBarrier(),
                                ),
                                Positioned(
                                  top: DesktopTopBar.searchTop,
                                  left: 0,
                                  right:
                                      DesktopTopBar.searchWidth +
                                      DesktopTopBar.paddingH,
                                  height: DesktopTopBar.searchHeight,
                                  child: _searchDismissBarrier(),
                                ),
                                Positioned(
                                  top: DesktopTopBar.searchTop,
                                  right: 0,
                                  width: DesktopTopBar.paddingH,
                                  height: DesktopTopBar.searchHeight,
                                  child: _searchDismissBarrier(),
                                ),
                                // 浮层：锚定在搜索框正下方，右边缘与搜索框一致
                                Positioned(
                                  top: DesktopTopBar.height + 1,
                                  right: DesktopTopBar.paddingH,
                                  child: DesktopSearchPanel(
                                    state: state,
                                    onSelect: (word) {
                                      _closeSearch();
                                      desktopSearch(word);
                                    },
                                    onClose: _closeSearch,
                                  ),
                                ),
                              ],
                            );
                          },
                        )
                      : const SizedBox.shrink(),
                ),
            ],
          )
        : _desktopContentArea(child);

    child = Material(
      child: MainLayout(
        sideBar: sideBar,
        bottomNav: bottomNav,
        body: Padding(
          padding: padding,
          // 桌面「私信」左侧面板：覆盖层，挂在**内容区**（侧栏右侧）之上 ⇒
          // 侧栏位置/宽度不变、底层页面不重新布局、被挤到右边；遮罩只覆盖
          // 内容区（面板以外区域），点它即关闭。Mobile / Tablet 不进入本分支。
          child: PlatformUtils.isDesktop
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    // 底层：原有内容区（保持静止：不重新布局、不被挤动）
                    Positioned.fill(child: body),
                    // 覆盖层：私信 / 消息面板（无动画，直接以最终位置出现）
                    if (_whisperPanelVisible) _whisperPanel(),
                  ],
                )
              : body,
        ),
      ),
    );

    if (PlatformUtils.isMobile) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarBrightness: _colorScheme.brightness,
          statusBarIconBrightness: _colorScheme.brightness.reverse,
          systemStatusBarContrastEnforced: false,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: _colorScheme.brightness.reverse,
        ),
        child: child,
      );
    }

    // 桌面壳层快捷键：Ctrl+1/2/3 切主入口、Ctrl+K 展开搜索面板
    // （沿用既有 showNavbar = width > 800，不新增断点）
    if (PlatformUtils.isDesktop && context.showNavbar) {
      child = DesktopShortcuts(
        mainController: _mainController,
        onSearch: () => setState(() => _searchPanelOpen = true),
        child: child,
      );
    }

    return child;
  }

  /// 收起搜索浮层：回到「输入为空」状态并退出输入状态
  void _closeSearch() {
    _searchOverlay.value = DesktopSearchOverlayState.empty;
    setState(() => _searchPanelOpen = false);
  }

  /// 点击即收起联想浮层的透明遮罩（覆盖搜索框与浮层之外的背景）
  Widget _searchDismissBarrier() =>
      GestureDetector(behavior: HitTestBehavior.opaque, onTap: _closeSearch);

  Widget _buildIcon({required NavigationBarType type, bool selected = false}) {
    final icon = selected ? type.selectIcon : type.icon;
    return type == .dynamics
        ? Obx(
            () {
              final dynCount = _mainController.dynCount.value;
              return Badge(
                isLabelVisible: dynCount > 0,
                label: _mainController.dynamicBadgeMode == .number
                    ? Text(dynCount.toString())
                    : null,
                padding: const .symmetric(horizontal: 6),
                child: icon,
              );
            },
          )
        : icon;
  }

  /// 侧栏上方的用户区（搜索入口已统一到桌面顶栏，此处不再提供搜索）
  Widget userAndSearchVertical() {
    return Column(
      children: [
        userAvatar(colorScheme: _colorScheme, mainController: _mainController),
        const SizedBox(height: 8),
        msgBadge(_mainController),
      ],
    );
  }
}

/// 桌面端右侧「主内容区」的过渡容器（仅桌面端构建，移动端不经此处）。
///
/// - [child]：主 Tab（首页 / 动态 / 我的）常驻树中、**不参与动画**，
///   保活语义与改动前的 IndexedStack 一致（这三个页的滚动位置与状态不丢）；
/// - [content]：内容页层，打开 / 换页时做统一的「淡入 + 自下方 6px 上移入位」；
///   旧内容页立即出树，内容页 initState / dispose 的时机与改动前完全相同
///   （内容页在 initState 里 `Get.put`、在 dispose 里 `Get.delete`，不能让旧实例
///   多留一个过渡周期，否则快速重开同一入口会出现两个实例共用同一控制器）；
/// - 收起内容页时，改由常驻的主 Tab 层走同一套入场动画（方向对称）。
class _DesktopContentArea extends StatefulWidget {
  const _DesktopContentArea({
    required this.child,
    required this.route,
    required this.content,
  });

  final Widget child;

  /// 当前内容页对应的路由（仅用于识别「内容页是否发生了切换」）
  final String? route;

  /// 当前内容页；null = 显示主 Tab
  final Widget? content;

  @override
  State<_DesktopContentArea> createState() => _DesktopContentAreaState();
}

class _DesktopContentAreaState extends State<_DesktopContentArea>
    with SingleTickerProviderStateMixin {
  /// 过渡时长 ≈180ms，曲线 Curves.easeOutCubic
  static const Duration _duration = Duration(milliseconds: 180);

  /// 入场位移：+6px → 0px
  /// （SlideTransition 的偏移是「分数」，这里用像素位移做到精确 6px）
  static const double _offsetY = 6;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
    value: 1.0,
  );

  late final CurvedAnimation _enter = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void didUpdateWidget(covariant _DesktopContentArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 只在内容页发生切换（打开 / 换页 / 收起）时重播一次入场动画；
    // 重复点击同一入口（route 不变）不重播。
    if (widget.route != oldWidget.route) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// 入场过渡：FadeTransition（opacity 0 → 1）+ 自下方 6px 上移入位
  /// （无 Scale 动画）。[animation] 传 [kAlwaysCompleteAnimation] 表示
  /// 该层常驻、当前不参与过渡。
  Widget _enterTransition(Widget child, Animation<double> animation) {
    return FadeTransition(
      opacity: animation,
      child: AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) => Transform.translate(
          offset: Offset(0.0, _offsetY * (1.0 - animation.value)),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.content;
    return Stack(
      fit: StackFit.expand,
      children: [
        // 主 Tab 层：常驻保活；只有「收起内容页」时才播一次入场动画
        _enterTransition(
          widget.child,
          content == null ? _enter : kAlwaysCompleteAnimation,
        ),
        if (content != null)
          // 内容页层：透明色只用于挡住下层主 Tab 的命中测试（不改观感），
          // 等价于原 IndexedStack「只命中当前显示页」的行为；
          // 放在过渡之外，保证位移期间整块区域都不可穿透
          ColoredBox(
            color: Colors.transparent,
            child: _enterTransition(content, _enter),
          ),
      ],
    );
  }
}
