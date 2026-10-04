import 'package:PiliPlus/common/skeleton/whisper_item.dart';
import 'package:PiliPlus/common/sliver_single_child_delegate.dart';
import 'package:PiliPlus/common/widgets/desktop/desktop_content.dart';
import 'package:PiliPlus/common/widgets/desktop/desktop_tokens.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/grpc/bilibili/app/im/v1.pb.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/pages/member/view.dart';
import 'package:PiliPlus/pages/msg_feed_top/at_me/view.dart';
import 'package:PiliPlus/pages/msg_feed_top/like_me/view.dart';
import 'package:PiliPlus/pages/msg_feed_top/reply_me/view.dart';
import 'package:PiliPlus/pages/msg_feed_top/sys_msg/view.dart';
import 'package:PiliPlus/pages/whisper/controller.dart';
import 'package:PiliPlus/pages/whisper/widgets/item.dart';
import 'package:PiliPlus/pages/whisper_detail/view.dart';
import 'package:PiliPlus/utils/extension/theme_ext.dart';
import 'package:PiliPlus/utils/extension/three_dot_ext.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/theme_utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class WhisperPage extends StatefulWidget {
  const WhisperPage({
    super.key,
    this.desktopEmbedded = false,
    this.onBack,
    this.hideAppBar = false,
  });

  /// 桌面端：由主壳「主内容区」就地承载（与侧栏并排），而非独立路由页。
  /// 仅用于桌面嵌入时的排布微调，移动端 / 路由方式保持默认 false。
  final bool desktopEmbedded;

  /// 桌面嵌入时的「离开本页」回调（由主壳收起内容页 → 恢复进入前的主 Tab）。
  /// 为空时退回原有路由返回行为（移动端）。
  final VoidCallback? onBack;

  /// 桌面端「我的」页快捷入口**内嵌**时置 true：省略 AppBar（页面标题 /
  /// 返回按钮 / 顶栏操作），只渲染主体内容。默认 false，移动端、路由方式
  /// 与主壳内容区嵌入（[desktopEmbedded]）均不受影响。
  final bool hideAppBar;

  @override
  State<WhisperPage> createState() => _WhisperPageState();
}

class _WhisperPageState extends State<WhisperPage> {
  final _controller = Get.put(WhisperController());

  /// 桌面紧凑入口条的启用下限宽度：4 项（每项水平 padding 12×2 + 图标 20 +
  /// 图标与文字间距 8 + 文字）合计约 400px，留出余量后取 480。
  /// 可用宽度低于该值（例如「我的」页窄预览内嵌）时回退原有入口行，
  /// 保证 4 个入口永不横向溢出。
  static const double _kCompactTopItemsMinWidth = 480;

  /// 桌面端：4 个消息分类入口就地打开的右侧半屏抽屉。
  ///
  /// 用 material_ui 内置 [DrawerController]（`DrawerAlignment.end`）承载目标页，
  /// 因此右侧滑入、半透明遮罩、点击遮罩关闭、反向退出、抽屉内正常交互全部由
  /// 框架提供；作用域严格等于本页盒子（主壳内容区 / 「我的」页预览面板），
  /// 不会越出宿主，也不需要新增 Overlay / Route / 公共组件。
  final GlobalKey<DrawerControllerState> _msgFeedDrawerKey =
      GlobalKey<DrawerControllerState>();

  /// 当前抽屉内的入口下标（4 个消息入口时为其下标；头像等其它内容为 null），
  /// 仅用于记录状态 / 让点击遮罩关闭后同一条目仍能触发开启动画。
  int? _msgFeedDrawerIndex;

  /// 抽屉内容：保留最后一次打开的目标页，退出动画期间不会变空
  Widget? _msgFeedDrawerChild;

  /// 桌面端统一入口：把任意目标页放进同一个右侧半屏抽屉并滑入。
  /// （4 个消息入口、会话行 UP 主头像都走这里，全局只有一个 Drawer / 一个 key）
  void _openDrawerPage(Widget page, {int? index}) {
    setState(() {
      _msgFeedDrawerIndex = index;
      _msgFeedDrawerChild = page;
    });
    // DrawerController 的 isDrawerOpen 只做瞬时同步（didUpdateWidget 直接赋值、无动画），
    // 动画必须由 open()/close() 驱动；等本帧挂载完成后再开，保证有过渡。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _msgFeedDrawerKey.currentState?.open();
      }
    });
  }

  /// 桌面端改走右侧抽屉：与移动端「压入独立路由」等价，但就在本页右半屏展示。
  void _openMsgFeedDrawer(int index) {
    _openDrawerPage(
      switch (_controller.msgFeedTopItems[index].route) {
        '/replyMe' => const ReplyMePage(),
        '/atMe' => const AtMePage(),
        '/likeMe' => const LikeMePage(),
        _ => const SysMsgPage(),
      },
      index: index,
    );
  }

  /// 桌面端：会话行 UP 主头像 → 复用同一个右侧半屏抽屉就地打开其主页
  /// （`/member` 那条路由的页面本体，仅显式传入 mid，页面自身不改动业务逻辑）
  void _openMemberDrawer(int mid) {
    _openDrawerPage(MemberPage(mid: mid));
  }

  /// 桌面端：会话主体（私信会话）→ 同一个右侧半屏抽屉打开会话详情
  /// （`/whisperDetail` 那条路由的页面本体；5 个参数与原路由 arguments 完全一致，
  /// 并通过 isDrawer/onClose 让页内返回只关闭抽屉，不 pop 根路由）
  void _openWhisperDetailDrawer({
    required int talkerId,
    required String name,
    required String face,
    int? mid,
    required bool isLive,
  }) {
    _openDrawerPage(
      WhisperDetailPage(
        talkerId: talkerId,
        name: name,
        face: face,
        mid: mid,
        isLive: isLive,
        isDrawer: true,
        onClose: _closeDrawer,
      ),
    );
  }

  /// 关闭当前右侧抽屉（Drawer 模式下的「返回」）
  void _closeDrawer() {
    _msgFeedDrawerKey.currentState?.close();
  }

  /// 返回按钮（桌面嵌入）：本页没有需要拦截的内部二级状态
  /// （无页面内搜索 / 无多选 / 无内层 Tab；会话详情与「回复我的」等
  /// 都是正常路由跳转，不由本页返回键接管），
  /// 离开时由主壳收起内容页，主 Tab 索引沿用 MainController.selectedIndex
  /// （进入时未改动）；路由方式退回原有 Get.back()。
  void _handleBack() {
    final onBack = widget.onBack;
    if (onBack != null) {
      onBack();
    } else {
      Get.back();
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.desktopEmbedded) {
      // 接入主壳既有的鼠标返回侧键机制（main.dart 的 BackDetector → _onBack），
      // 复用同一个返回，不新增全局监听
      Get.find<MainController>().desktopContentBackHandler = _handleBack;
    }
  }

  @override
  void dispose() {
    if (widget.desktopEmbedded && Get.isRegistered<MainController>()) {
      final mainController = Get.find<MainController>();
      // 仅在本实例仍是注册者时清空，避免覆盖后进入实例的注册
      if (mainController.desktopContentBackHandler == _handleBack) {
        mainController.desktopContentBackHandler = null;
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = MediaQuery.viewPaddingOf(context);
    final page = SimpleScaffold(
      // 「我的」页内嵌（hideAppBar）→ 整块顶栏（标题 / 返回按钮 / 新增粉丝 /
      // 更多）都不嵌入，只渲染主体内容；
      // 桌面嵌入：标题左侧为返回按钮；标题在原有间距上再左移 10px（36 → 26）
      appBar: widget.hideAppBar ? null : AppBar(
        leading: widget.desktopEmbedded
            ? BackButton(onPressed: _handleBack)
            : null,
        titleSpacing: widget.desktopEmbedded ? 26 : null,
        title: const Text('消息'),
        actions: [
          IconButton(
            tooltip: '新增粉丝',
            onPressed: () => Get.toNamed(
              '/webview',
              parameters: {
                'url':
                    'https://www.bilibili.com/h5/follow/newFans?navhide=1&${ThemeUtils.themeUrl(theme.isDark)}',
              },
            ),
            icon: const Icon(Icons.account_circle_outlined),
          ),
          Obx(() {
            final outsideItem = _controller.outsideItem.value;
            if (outsideItem != null && outsideItem.isNotEmpty) {
              return Row(
                mainAxisSize: .min,
                children: outsideItem.map((e) {
                  return IconButton(
                    tooltip: e.hasTitle() ? e.title : null,
                    onPressed: () => e.type.action(
                      context: context,
                      controller: _controller,
                      item: e,
                    ),
                    icon: e.type.icon,
                  );
                }).toList(),
              );
            }
            return const SizedBox.shrink();
          }),
          Obx(() {
            final threeDotItems = _controller.threeDotItems.value;
            if (threeDotItems != null && threeDotItems.isNotEmpty) {
              return PopupMenuButton(
                itemBuilder: (context) {
                  return threeDotItems
                      .map(
                        (e) => PopupMenuItem(
                          onTap: () => e.type.action(
                            context: context,
                            controller: _controller,
                            item: e,
                          ),
                          child: Row(
                            children: [
                              e.type.icon,
                              Text('  ${e.title}'),
                            ],
                          ),
                        ),
                      )
                      .toList();
                },
              );
            }
            return const SizedBox.shrink();
          }),
          const SizedBox(width: 5),
        ],
      ),
      body: refreshIndicator(
        onRefresh: _controller.onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 桌面端内容限宽（默认 1480 = Style.contentMaxWidth = 6 列 × 240 的
            // 同一唯一来源）：本页此前是唯一没有限宽的桌面主内容页（会话列表
            // 在超宽屏下会横向铺满），补齐后与历史/稍后/收藏/订阅一致。
            desktopLimitSliver(_buildTopItems(theme, padding)),
            SliverPadding(
              // 桌面端底部留白与其它桌面内容页一致（24），移动端保持原样。
              padding: EdgeInsets.only(
                bottom: PlatformUtils.isDesktop ? 24 : padding.bottom + 100,
              ),
              sliver: desktopLimitSliver(
                Obx(() => _buildBody(_controller.loadingState.value)),
              ),
            ),
          ],
        ),
      ),
    );
    // 移动端 / 平板：原样返回（4 个入口仍走 Get.toNamed 独立路由，不受本轮影响）
    if (!PlatformUtils.isDesktop) {
      return page;
    }
    // 桌面端：页面之上叠一层右对齐半屏抽屉。
    // 宽度基准 = 本页盒子宽度（主壳内容区 / 「我的」页预览面板）× 50%，
    // 既不把侧栏算进去，也不会越出窄预览宿主。
    return LayoutBuilder(
      builder: (context, constraints) {
        final colorScheme = theme.colorScheme;
        return Stack(
          fit: StackFit.expand,
          children: [
            page,
            DrawerController(
              key: _msgFeedDrawerKey,
              alignment: DrawerAlignment.end,
              // 桌面端不需要边缘拖拽唤出；关闭态会渲染 SizedBox.shrink()，
              // 完全不影响页面本身的点击 / 滚动
              enableOpenDragGesture: false,
              // 与项目既有多层遮罩同值（PublishRoute.barrierColor），不新增 Token
              scrimColor: const Color(0x80000000),
              drawerCallback: (isOpened) {
                // 点击遮罩关闭时同步状态，保证再次点同一条目仍能触发开启动画
                if (!isOpened && _msgFeedDrawerIndex != null) {
                  setState(() => _msgFeedDrawerIndex = null);
                }
              },
              child: Drawer(
                width: constraints.maxWidth * 0.5,
                backgroundColor: DesktopTokens.surface(colorScheme),
                // Desktop UI Kit 以描边而非投影表达层级
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(DesktopTokens.radius),
                  ),
                  side: BorderSide(color: DesktopTokens.divider(colorScheme)),
                ),
                child: _msgFeedDrawerChild ?? const SizedBox.shrink(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBody(LoadingState<List<Session>?> loadingState) {
    switch (loadingState) {
      case Loading():
        return const SliverPrototypeExtentList(
          prototypeItem: WhisperItemSkeleton(),
          delegate: SliverSingleChildDelegate(
            count: 12,
            child: WhisperItemSkeleton(),
          ),
        );
      case Success(:final response):
        if (response != null && response.isNotEmpty) {
          final divider = Divider(
            indent: 72,
            endIndent: 20,
            height: 0,
            color: Colors.grey.withValues(alpha: 0.1),
          );
          return SliverList.separated(
            itemCount: response.length,
            itemBuilder: (context, index) {
              if (index == response.length - 1) {
                _controller.onLoadMore();
              }
              final item = response[index];
              return WhisperSessionItem(
                item: item,
                onSetTop: (isTop, id) =>
                    _controller.onSetTop(item, index, isTop, id),
                onSetMute: (isMuted, talkerUid) =>
                    _controller.onSetMute(item, isMuted, talkerUid),
                onRemove: (talkerId) => _controller.onRemove(index, talkerId),
                // 桌面端：头像点击同样走本页右侧半屏抽屉（移动端保持原路由跳转）
                onTapAvatar: PlatformUtils.isDesktop
                    ? _openMemberDrawer
                    : null,
                // 桌面端：会话主体点击走同一个抽屉打开私信详情
                // （参数与原 Get.toNamed('/whisperDetail', arguments: …) 一致）
                onTapWhisperDetail: PlatformUtils.isDesktop
                    ? _openWhisperDetailDrawer
                    : null,
              );
            },
            separatorBuilder: (context, index) => divider,
          );
        }
        return HttpError(onReload: _controller.onReload);
      case Error(:final errMsg):
        return HttpError(
          errMsg: errMsg,
          onReload: _controller.onReload,
        );
    }
  }

  /// 入口点击逻辑（桌面紧凑入口条与移动端入口行共用，语义保持完全不变：
  /// 先判可用性 → 本地未读清零 → 压入该入口自己的独立路由）。
  void _onTapTopItem(int index) {
    final item = _controller.msgFeedTopItems[index];
    if (!item.enabled) {
      SmartDialog.showToast('已禁用');
      return;
    }
    _controller.unreadCounts[index] = 0;
    if (PlatformUtils.isDesktop) {
      // 桌面端：就地打开右侧半屏抽屉（目标页 Controller / 数据 / AppBar 均不改）
      _openMsgFeedDrawer(index);
      return;
    }
    Get.toNamed(item.route);
  }

  Widget _buildTopItems(ThemeData theme, EdgeInsets padding) {
    return SliverPadding(
      padding: EdgeInsets.only(left: padding.left, right: padding.right),
      sliver: SliverToBoxAdapter(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 仅 Windows 桌面端（PlatformUtils.isDesktop，不使用 Pref.horizontalScreen，
            // 以免影响平板）且可用宽度足够时使用左对齐紧凑入口条；
            // 「我的」页窄预览（hideAppBar 内嵌）等宽度不足的场景回退原有入口行，
            // 避免 4 个入口横向溢出。
            if (PlatformUtils.isDesktop &&
                constraints.maxWidth >= _kCompactTopItemsMinWidth) {
              return _buildDesktopTopItems(theme);
            }
            return _buildMobileTopItems(theme);
          },
        ),
      ),
    );
  }

  /// 移动端 / 平板（以及宽度不足的桌面预览）：保持原有入口行不变——
  /// 44×44 圆形底板 + 图标 + 文字，spaceEvenly 横向均分。
  Widget _buildMobileTopItems(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(_controller.msgFeedTopItems.length, (index) {
        final item = _controller.msgFeedTopItems[index];
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Obx(
                  () {
                    final count = _controller.unreadCounts[index];
                    return Badge(
                      isLabelVisible: count > 0,
                      label: Text(" $count "),
                      alignment: Alignment.topRight,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: .circle,
                          color: theme.colorScheme.onInverseSurface,
                        ),
                        child: Icon(
                          item.icon,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  item.name,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          onTap: () => _onTapTopItem(index),
        );
      }),
    );
  }

  /// 桌面紧凑功能入口条（**不是 TabBar**：4 项仍是 4 个独立路由入口，
  /// 没有选中态、不切换本页内容）。
  /// 左对齐、行高 45、项间距 gap4、每项水平 padding gap12、图标 20、
  /// 文字 13（默认 subtitleColor / hover titleColor）、底部 DesktopTokens.divider。
  Widget _buildDesktopTopItems(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: DesktopTokens.divider(colorScheme)),
        ),
      ),
      child: SizedBox(
        height: 45,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            for (
              var index = 0;
              index < _controller.msgFeedTopItems.length;
              index++
            )
              _DesktopWhisperTopItem(
                item: _controller.msgFeedTopItems[index],
                unreadCounts: _controller.unreadCounts,
                index: index,
                onTap: () => _onTapTopItem(index),
              ),
          ],
        ),
      ),
    );
  }
}

/// 桌面紧凑功能入口（单个）：图标 + 文字 + 未读计数 pill。
///
/// 悬停只改变底色与文字/图标颜色（AnimatedContainer + DesktopTokens.hoverDuration），
/// 不改变任何尺寸；未读计数用 Positioned 叠加在图标右上角，因此计数变化
/// 永远不会撑开本项或推动相邻入口。
class _DesktopWhisperTopItem extends StatefulWidget {
  const _DesktopWhisperTopItem({
    required this.item,
    required this.unreadCounts,
    required this.index,
    required this.onTap,
  });

  final MsgFeedTopItem item;
  final RxList<int> unreadCounts;
  final int index;
  final VoidCallback onTap;

  @override
  State<_DesktopWhisperTopItem> createState() => _DesktopWhisperTopItemState();
}

class _DesktopWhisperTopItemState extends State<_DesktopWhisperTopItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(8);
    final contentColor = _hover
        ? DesktopTokens.titleColor(colorScheme)
        : DesktopTokens.subtitleColor(colorScheme);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: DesktopTokens.hoverDuration,
        curve: DesktopTokens.curve,
        decoration: BoxDecoration(
          color: _hover
              ? DesktopTokens.hoverSurface(colorScheme)
              : Colors.transparent,
          borderRadius: radius,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: widget.onTap,
            splashFactory: NoSplash.splashFactory,
            hoverColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DesktopTokens.gap12,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Obx(() {
                    final count = widget.unreadCounts[widget.index];
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          widget.item.icon,
                          size: DesktopTokens.iconSize,
                          color: contentColor,
                        ),
                        if (count > 0)
                          Positioned(
                            right: -6,
                            top: -6,
                            child: _UnreadCountPill(count: count),
                          ),
                      ],
                    );
                  }),
                  const SizedBox(width: DesktopTokens.gap8),
                  Text(
                    widget.item.name,
                    style: TextStyle(
                      fontSize: DesktopTokens.fontSecondary,
                      color: contentColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 未读计数 pill：高 16、水平 padding 5、圆角 8、error / onError 配色；
/// 超过 99 显示「99+」，保证窄 pill 内数字始终可读。
class _UnreadCountPill extends StatelessWidget {
  const _UnreadCountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 16,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: colorScheme.error,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          fontSize: 11,
          height: 1.1,
          fontWeight: FontWeight.w500,
          color: colorScheme.onError,
        ),
      ),
    );
  }
}
