import 'dart:math';

import 'package:PiliPlus/common/widgets/desktop/desktop_tokens.dart';
import 'package:PiliPlus/common/widgets/loading_widget/loading_widget.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/fav/fav_folder/list.dart';
import 'package:PiliPlus/pages/common/common_intro_controller.dart';
import 'package:PiliPlus/pages/fav_panel/widgets.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// 收藏夹选择 **Popover 内容**（桌面端）。
///
/// 复用 [FavFolderListView]（列表 + 勾选）与 [FavMixin.actionFavVideo]（提交），
/// 与移动端底部面板是同一份业务逻辑，只是换了容器：
/// 紧凑标题行 + 内部独立滚动的列表 + 底部「取消 / 完成」。
///
/// 视觉上不再额外叠加 Card/Material —— 外层由 `showMenu` 的菜单容器提供
/// 底色、圆角与阴影（与项目其它右键菜单同源），因此明暗主题自动一致。
class FavPopover extends StatefulWidget {
  const FavPopover({
    super.key,
    required this.ctr,
    required this.height,
    this.preferredHeight,
  });

  final FavMixin ctr;

  /// 兜底高度（一般为打开时刻该方向的可用高度）。
  ///
  /// 必须显式定高：`showMenu` 会把菜单内容包进 `SingleChildScrollView`，
  /// 否则 `Column` + `Expanded` 拿到的是无界高度约束
  /// （表现为 RenderFlex 报错且内容塌陷为 0）。
  ///
  /// 仅当 [preferredHeight] 为 null 时使用。
  final double height;

  /// **每次布局**重算的期望高度（与 `showMenu` 的 `positionBuilder` 同源）。
  ///
  /// 传它而不是只用 [height]，是为了避免「打开窗口后窗口变高，面板仍被打开
  /// 时刻的高度冻结（只减不增）」。返回 null 时回退到 [height]。
  final double Function()? preferredHeight;

  /// 期望的面板宽度（目标宽度或打开时窗口宽度余量）。
  static const double targetWidth = 320;

  @override
  State<FavPopover> createState() => _FavPopoverState();
}

class _FavPopoverState extends State<FavPopover> with WidgetsBindingObserver {
  LoadingState loadingState = LoadingState.loading();

  /// 本面板自身所属的路由（在 build 中捕获，避免在回调里做 InheritedWidget 查找）。
  ModalRoute<dynamic>? _selfRoute;

  /// 上一个已知的窗口逻辑尺寸：用于区分「窗口指标真的变了」与普通重建。
  Size? _lastViewSize;

  /// 关闭流程防重入：一旦决定关闭就不再重复触发。
  bool _closeRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastViewSize = _currentViewSize();
    _queryVideoInFolder();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 当前 FlutterView 的逻辑尺寸。
  ///
  /// 直接读 view，不经 `MediaQuery`/`View.of(context)`，以免在
  /// `didChangeMetrics` 回调中建立 InheritedWidget 依赖。
  Size? _currentViewSize() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) {
      return null;
    }
    final view = views.first;
    final dpr = view.devicePixelRatio;
    if (dpr <= 0) {
      return null;
    }
    return view.physicalSize / dpr;
  }

  /// 窗口尺寸变化（最大化 / 还原 / 拖拽缩放 / DPI 变化）时主动收起本面板。
  ///
  /// **这是防御性处理，不是某一已证实根因的直接修复。** 目的：不让面板跨越窗口
  /// 状态过渡继续存活 —— 过渡期间的指针事件可靠性在应用其它位置已有同类记录与
  /// 缓解（见 `plugin/pl_player` 的 `windowInputSettle`），且 `showMenu` 的宽度
  /// 约束在路由创建时即固定，窗口变化后必然过期。
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final now = _currentViewSize();
    final prev = _lastViewSize;
    _lastViewSize = now;
    if (_closeRequested || !mounted || prev == null || now == null) {
      return;
    }
    // 只有窗口尺寸确实变化（> 1 逻辑像素）才收面板。
    if ((now.width - prev.width).abs() <= 1 &&
        (now.height - prev.height).abs() <= 1) {
      return;
    }
    _requestClose();
  }

  /// 安全关闭：只关闭**本面板自身所在的**当前路由，绝不影响其它路由。
  void _requestClose() {
    if (_closeRequested || !mounted) {
      return;
    }
    // 只处理「本面板就是栈顶当前路由」的情形：若有页面压在面板之上
    // （例如「新建收藏夹」子页），isCurrent 为 false，这里直接不动。
    final route = _selfRoute;
    if (route == null || !route.isCurrent || !route.isActive) {
      return;
    }
    if (Navigator.maybeOf(context)?.canPop() != true) {
      return;
    }
    _closeRequested = true;
    // 指标回调发生在帧间：延后一帧再改导航栈，避免在回调里同步 pop。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_closeRequested) {
        return;
      }
      final r = _selfRoute;
      if (r == null || !r.isCurrent || !r.isActive) {
        return;
      }
      Navigator.maybeOf(context)?.maybePop();
    });
  }

  Future<void> _queryVideoInFolder() async {
    final res = await widget.ctr.queryVideoInFolder();
    if (mounted) {
      setState(() => loadingState = res);
    }
  }

  Future<void> _onCreateFav() async {
    final data = await Get.toNamed('/createFav');
    if (data is FavFolderInfo && mounted) {
      widget.ctr.favFolderData.value.list?.insert(
        1,
        data
          ..favState = 1
          ..mediaCount = 1,
      );
      setState(() {});
    }
  }

  Widget get _buildBody {
    switch (loadingState) {
      case Loading():
        return m3eLoading;
      case Success():
        final list = widget.ctr.favFolderData.value.list;
        if (list == null || list.isEmpty) {
          return const Center(child: Text('暂无收藏夹'));
        }
        return FavFolderListView(list: list);
      case Error(:final errMsg):
        return scrollErrorWidget(
          errMsg: errMsg,
          onReload: _queryVideoInFolder,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // 捕获本面板自身所属的路由：后续在窗口指标回调里据此判定
    // 「本面板是否仍是栈顶当前路由」，从而只关闭自己、不误伤其它路由。
    _selfRoute = ModalRoute.of(context);
    // 显式定尺寸：抵消 showMenu 内层 SingleChildScrollView 造成的**无界高度**约束
    // （否则 Column + Expanded 会报 RenderFlex 并塌陷为 0）。
    // 同时与**当前**窗口约束取小，保证窗口变小/变窄后面板也不会超出可用区域。
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.hasBoundedWidth
            ? min(FavPopover.targetWidth, constraints.maxWidth)
            : FavPopover.targetWidth;
        // 高度：优先取**每次布局**重算的期望高度（preferredHeight），再与当次
        // 约束取小。这样窗口变高/变矮时面板都能跟随，不再被打开时刻的高度冻结。
        final double target = widget.preferredHeight?.call() ?? widget.height;
        final double height = constraints.hasBoundedHeight
            ? min(target, constraints.maxHeight)
            : target;
        return SizedBox(
          width: width,
          height: height,
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .stretch,
            children: [
        // 紧凑标题行：与项目菜单/列表标题同一套语义色与间距
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DesktopTokens.gap12,
            DesktopTokens.gap8,
            4,
            DesktopTokens.gap8,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '添加到收藏夹',
                  maxLines: 1,
                  overflow: .ellipsis,
                  // 与播放器右栏标题同一套令牌（字号 18 / 行高 26 / 字重 w500 /
                  // 语义色），保证两处标题观感一致；不新建重复样式。
                  style: TextStyle(
                    fontSize: DesktopTokens.sidePanelTitleFontSize,
                    height:
                        DesktopTokens.sidePanelTitleLineHeight /
                        DesktopTokens.sidePanelTitleFontSize,
                    fontWeight: DesktopTokens.sidePanelTitleFontWeight,
                    color: DesktopTokens.titleColor(colorScheme),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _onCreateFav,
                icon: Icon(Icons.add, size: DesktopTokens.iconSize, color: colorScheme.primary),
                label: const Text(
                  '新建',
                  style: TextStyle(fontSize: DesktopTokens.fontSecondary),
                ),
                style: TextButton.styleFrom(
                  visualDensity: .compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  foregroundColor: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          color: DesktopTokens.divider(colorScheme),
        ),
        // 列表独占剩余高度并在面板内部独立滚动
        Expanded(child: _buildBody),
        Divider(
          height: 1,
          color: DesktopTokens.divider(colorScheme),
        ),
        // 底部操作区：始终可见（不参与滚动）
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DesktopTokens.gap12,
            DesktopTokens.gap8,
            DesktopTokens.gap12,
            DesktopTokens.gap8,
          ),
          child: Row(
            mainAxisAlignment: .end,
            spacing: DesktopTokens.gap8,
            children: [
              TextButton(
                onPressed: Get.back,
                style: TextButton.styleFrom(
                  visualDensity: .compact,
                  foregroundColor: DesktopTokens.subtitleColor(colorScheme),
                ),
                child: const Text('取消'),
              ),
              FilledButton.tonal(
                onPressed: () {
                  feedBack();
                  widget.ctr.actionFavVideo();
                },
                style: const ButtonStyle(visualDensity: .compact),
                child: const Text('完成'),
              ),
            ],
          ),
        ),
            ],
          ),
        );
      },
    );
  }
}
