import 'package:PiliPlus/common/widgets/appbar/appbar.dart';
import 'package:PiliPlus/common/widgets/desktop/desktop_content.dart';
import 'package:PiliPlus/common/widgets/desktop/desktop_search_box.dart';
import 'package:PiliPlus/common/widgets/desktop/desktop_top_bar.dart';
import 'package:PiliPlus/common/widgets/flutter/pop_scope.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/gesture/horizontal_drag_gesture_recognizer.dart';
import 'package:PiliPlus/common/widgets/keep_alive_wrapper.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/common/widgets/scroll_physics.dart'
    show tabBarScrollPhysics;
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/history/list.dart';
import 'package:PiliPlus/pages/history/base_controller.dart';
import 'package:PiliPlus/pages/history/controller.dart';
import 'package:PiliPlus/pages/history/widgets/item.dart';
import 'package:PiliPlus/pages/history_search/controller.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/utils/extension/scroll_controller_ext.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    super.key,
    this.type,
    this.desktopEmbedded = false,
    this.onBack,
    this.hideAppBar = false,
    this.searchRequest,
    this.instanceSuffix = '',
  });

  final String? type;

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

  /// 桌面端「我的」页内嵌预览的**外部搜索入口**（预览区一级标题行的搜索框）：
  /// 宿主每次提交都传入一个新的 [DesktopInlineSearchRequest]，本页据此复用
  /// **自身既有的就地搜索实现**（`_openSearch` + `_onSubmitSearch` /
  /// `_closeSearch`），不新增搜索路径、控制器或结果视图。
  /// 默认 null：移动端、路由方式与主壳内容区嵌入均不受影响。
  final DesktopInlineSearchRequest? searchRequest;

  /// GetX 实例命名空间后缀：由父级（嵌套 tab 的宿主）逐级下发。
  /// 默认 `''` ⇒ 移动端 / 路由方式 / 主壳内容区嵌入的注册与查找 key
  /// 与改动前逐字一致。
  final String instanceSuffix;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage>
    with AutomaticKeepAliveClientMixin, GridMixin {
  late final HistoryController _historyController;

  // ===== GetX 实例命名空间（「我的」页内嵌预览实例 vs 完整实例） =====

  /// 本实例是否为「我的」页快捷入口的**内嵌预览**实例
  /// （预览：hideAppBar && !desktopEmbedded；完整实例：主壳内容区嵌入或路由页）。
  bool get _isPreviewInstance =>
      PlatformUtils.isDesktop && widget.hideAppBar && !widget.desktopEmbedded;

  /// 本实例的命名空间后缀（只算一次）：预览实例 `@preview`，其余 `''`。
  /// 嵌套 tab 子页由父级通过 [HistoryPage.instanceSuffix] 下发，保持同一命名空间。
  /// `''` 时 GetX 的 `_getKey` 与改动前（tag == null）同键 ⇒ 移动端零变化。
  late final String _instanceSuffix = widget.instanceSuffix.isNotEmpty
      ? widget.instanceSuffix
      : (_isPreviewInstance ? '@preview' : '');

  /// 基础 tag → 本实例命名空间下的 tag。
  /// `HistoryTab.type` 为 `String?`（既有代码里 `Get.find(tag: item.type)` 也允许
  /// null tag）：null 与 `''` 在 GetX `_getKey` 中同键
  /// （`name == null ? t : t + name`），故 `base ?? ''` 不改变原有 key；
  /// 预览实例下 null 基础 tag 也只会落在 `@preview` 命名空间内，不跨实例。
  String _tag(String? base) => '${base ?? ''}$_instanceSuffix';

  // ===== 桌面嵌入时的「页面内搜索」（移动端 / 路由方式不启用） =====

  /// 是否处于就地搜索状态
  bool _searchActive = false;

  /// 是否已提交关键词：未提交时展开搜索框也继续显示原历史列表
  bool _searchSubmitted = false;

  /// 就地搜索业务控制器（懒创建；复用既有 HistorySearchController 的搜索与分页）
  HistorySearchController? _searchCtr;

  /// 就地搜索的启用条件：桌面端 + （主壳内容区嵌入 **或** 「我的」页内嵌预览
  /// 通过 [HistoryPage.searchRequest] 下发了搜索请求）。移动端永远不满足
  /// （[PlatformUtils.isDesktop] 为 false），原有行为不变。
  bool get _desktopInlineSearch =>
      (widget.desktopEmbedded || widget.searchRequest != null) &&
      PlatformUtils.isDesktop;

  HistorySearchController get _ensureSearchCtr {
    final existing = _searchCtr;
    if (existing != null) {
      return existing;
    }
    final HistorySearchController created = Get.put(
      HistorySearchController(),
      tag: _tag('historyDesktopEmbedded'),
    );
    _searchCtr = created;
    return created;
  }

  /// 点搜索按钮：桌面嵌入 → 就地展开搜索；其余情况保持原有跳转
  void _openSearch() {
    if (!_desktopInlineSearch) {
      Get.toNamed('/historySearch');
      return;
    }
    setState(() {
      _searchActive = true;
      _searchSubmitted = false; // 只展开搜索框，仍显示历史列表
    });
  }

  /// 退出就地搜索（点页面空白 / 顶栏其他区域触发）
  void _closeSearch() {
    if (_searchActive) {
      setState(() {
        _searchActive = false;
        _searchSubmitted = false;
      });
    }
  }

  /// 返回按钮（桌面嵌入）两级返回：搜索态 → 历史列表 → 上一个页面/主 Tab。
  /// 页面上层不新增导航状态：离开时由主壳收起内容页，
  /// 主 Tab 索引沿用 MainController.selectedIndex（进入时未改动）。
  void _handleBack() {
    if (_searchActive) {
      // 搜索结果态 / 搜索框展开态：只退出搜索，仍留在历史记录列表
      _closeSearch();
      return;
    }
    final onBack = widget.onBack;
    if (onBack != null) {
      onBack();
    } else {
      Get.back();
    }
  }

  /// 回车提交：写入既有控制器的关键词并触发其查询（业务语义不变）
  void _onSubmitSearch(String value) {
    final keyword = value.trim();
    if (keyword.isEmpty) return;
    final ctr = _ensureSearchCtr;
    ctr.editController.text = keyword;
    ctr.onRefresh();
    // 只有提交关键词后才切到搜索结果区
    setState(() => _searchSubmitted = true);
  }

  @override
  void initState() {
    super.initState();
    _historyController = Get.put(
      HistoryController(
        widget.type,
        instanceSuffix: _instanceSuffix,
      ),
      tag: _tag(widget.type ?? 'all'),
    );
    if (widget.desktopEmbedded) {
      // 接入主壳既有的鼠标返回侧键机制（main.dart 的 BackDetector → _onBack），
      // 复用同一个两级返回，不新增全局监听
      Get.find<MainController>().desktopContentBackHandler = _handleBack;
    }
  }

  @override
  void didUpdateWidget(covariant HistoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final request = widget.searchRequest;
    // 宿主（「我的」页预览区一级标题行的搜索框）每次提交都是**新实例**：
    // 据此复用本页既有的「进入就地搜索 + 提交关键词」路径，不改搜索实现；
    // 空关键词 = 退出搜索（回到历史列表）。移动端从不传该参数 → 不触发。
    if (request == null ||
        !_desktopInlineSearch ||
        identical(request, oldWidget.searchRequest)) {
      return;
    }
    final keyword = request.keyword.trim();
    if (keyword.isEmpty) {
      _closeSearch();
    } else {
      _openSearch();
      _onSubmitSearch(keyword);
    }
  }

  HistoryController currCtr([int? index]) {
    try {
      index ??= _historyController.tabController!.index;
      if (index != 0) {
        return Get.find<HistoryController>(
          tag: _tag(_historyController.tabs[index - 1].type),
        );
      }
    } catch (_) {}
    return _historyController;
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
    if (_searchCtr != null) {
      Get.delete<HistorySearchController>(
        tag: _tag('historyDesktopEmbedded'),
      );
    }
    Get.delete<HistoryBaseController>(tag: _instanceSuffix);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final padding = MediaQuery.viewPaddingOf(context);
    Widget child = refreshIndicator(
      onRefresh: _historyController.onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        controller: _historyController.scrollController,
        slivers: [
          SliverPadding(
            padding: EdgeInsets.only(
              top: 7,
              bottom: PlatformUtils.isDesktop
                  ? 24
                  : padding.bottom + 100,
            ),
            // 与首页网格一致：卡片网格不限宽、列数按可用宽度动态决定
            sliver: desktopLimitSliver(
              Obx(
                () => _buildBody(_historyController.loadingState.value),
              ),
              maxWidth: double.infinity,
            ),
          ),
        ],
      ),
    );
    if (widget.type != null) {
      return child;
    }
    return Obx(
      () {
        final enableMultiSelect =
            _historyController.baseCtr.enableMultiSelect.value;
        final appBar = MultiSelectAppBarWidget(
          visible: enableMultiSelect,
          ctr: currCtr(),
          child: _buildAppBar,
        );
        return popScope(
          canPop: !enableMultiSelect,
          onPopInvokedWithResult: (didPop, result) {
            if (enableMultiSelect) {
              currCtr().handleSelect();
            }
          },
          child: SimpleScaffold(
            // 「我的」页内嵌（hideAppBar）→ 整块顶栏（标题 / 返回按钮 / 搜索 /
            // 更多）都不嵌入，只渲染主体内容
            // 顶栏其他区域（标题 / 空白）点击即退出就地搜索；
            // translucent → 不抢搜索框、菜单等控件自身的点击
            appBar: widget.hideAppBar
                ? null
                : _searchActive
                    ? GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _closeSearch,
                        child: appBar,
                      )
                    : appBar,
            body: Padding(
              padding: .only(left: padding.left, right: padding.right),
              child: Obx(() {
                final tabs = _historyController.tabs;
                if (tabs.isEmpty) {
                  return child;
                }
                final content = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ?_buildPauseTip,
                    TabBar(
                      controller: _historyController.tabController,
                      onTap: (index) {
                        if (!_historyController
                            .tabController!
                            .indexIsChanging) {
                          currCtr().scrollController.animToTop();
                        } else {
                          if (enableMultiSelect) {
                            currCtr(
                              _historyController.tabController!.previousIndex,
                            ).handleSelect();
                          }
                        }
                      },
                      tabs: [
                        const Tab(text: '全部'),
                        ...tabs.map((item) => Tab(text: item.name)),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        physics: enableMultiSelect
                            ? const NeverScrollableScrollPhysics()
                            : tabBarScrollPhysics,
                        controller: _historyController.tabController,
                        horizontalDragGestureRecognizer:
                            CustomHorizontalDragGestureRecognizer.new,
                        children: [
                          KeepAliveWrapper(child: child),
                          ...tabs.map(
                            (item) => HistoryPage(
                              type: item.type,
                              instanceSuffix: _instanceSuffix,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                return _withInlineSearch(content);
              }),
            ),
          ),
        );
      },
    );
  }

  AppBar get _buildAppBar => AppBar(
    // 桌面嵌入：标题左侧为两级返回按钮；标题在原有间距上再左移 10px（36 → 26）
    leading: widget.desktopEmbedded
        ? BackButton(onPressed: _handleBack)
        : null,
    titleSpacing: widget.desktopEmbedded ? 26 : null,
    title: const Text('观看记录'),
    actions: [
      if (_searchActive && _desktopInlineSearch)
        // 就地搜索：复用主面板 DesktopSearchBox 的 UI/交互。
        // 不传 initialText / fallbackQuery → 不显示「当前搜索关键词」；
        // 不接 onOverlayChanged → 宿主不渲染 DesktopSearchPanel → 无联想浮层。
        DesktopSearchBox(
          active: true,
          width: DesktopTopBar.searchWidth,
          height: DesktopTopBar.searchHeight,
          onSubmit: _onSubmitSearch,
        )
      else
        IconButton(
          tooltip: '搜索',
          onPressed: _openSearch,
          icon: const Icon(Icons.search_outlined),
        ),
      PopupMenuButton(
        itemBuilder: (_) => [
          PopupMenuItem(
            onTap: () => _historyController.baseCtr.onPauseHistory(context),
            child: Text(
              !_historyController.baseCtr.pauseStatus.value
                  ? '暂停观看记录'
                  : '恢复观看记录',
            ),
          ),
          PopupMenuItem(
            onTap: () => _historyController.baseCtr.onClearHistory(
              context,
              () {
                _historyController.loadingState.value = const Success(null);
                if (_historyController.tabController != null) {
                  for (final item in _historyController.tabs) {
                    try {
                      Get.find<HistoryController>(
                        tag: _tag(item.type),
                      ).loadingState.value = const Success(
                        null,
                      );
                    } catch (_) {}
                  }
                }
              },
            ),
            child: const Text('清空观看记录'),
          ),
          PopupMenuItem(
            onTap: currCtr().onDelViewedHistory,
            child: const Text('删除已看记录'),
          ),
        ],
      ),
      const SizedBox(width: 6),
    ],
  );

  Widget _buildBody(LoadingState<List<HistoryItemModel>?> loadingState) {
    return switch (loadingState) {
      Loading() => gridSkeleton,
      Success(:final response) =>
        response != null && response.isNotEmpty
            ? SliverGrid.builder(
                gridDelegate: gridDelegate,
                itemBuilder: (context, index) {
                  if (index == response.length - 1) {
                    _historyController.onLoadMore();
                  }
                  final item = response[index];
                  // gridDelegate.scaled = 卡片文字随本列实际列宽同比（非桌面端原样返回）
                  return gridDelegate.scaled(
                    desktopCard(
                      HistoryItem(
                        item: item,
                        ctr: _historyController,
                        onDelete: (kid, business) =>
                            _historyController.delHistory(item),
                      ),
                    ),
                  );
                },
                itemCount: response.length,
              )
            : HttpError(onReload: _historyController.onReload),
      Error(:final errMsg) => HttpError(
        errMsg: errMsg,
        onReload: _historyController.onReload,
      ),
    };
  }

  /// 桌面嵌入：在「历史列表」与「就地搜索结果」之间切换。
  /// 用 IndexedStack 保活列表视图（滚动位置不丢）；外层 translucent 点击层
  /// 让「点页面任意空白」退出搜索，同时不抢结果项/列表自身的点击与滚动。
  Widget _withInlineSearch(Widget content) {
    if (!_desktopInlineSearch) {
      return content;
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _searchActive ? _closeSearch : null,
      child: IndexedStack(
        // 未提交关键词时保持 index=0：搜索框展开也继续显示历史列表
        index: _searchActive && _searchSubmitted ? 1 : 0,
        sizing: StackFit.expand,
        children: [content, _buildSearchResults()],
      ),
    );
  }

  /// 就地搜索结果（复用既有 HistorySearchController 的查询/分页数据）
  Widget _buildSearchResults() {
    final ctr = _searchCtr;
    if (ctr == null) {
      return const SizedBox.shrink();
    }
    return Obx(() {
      final padding = MediaQuery.viewPaddingOf(context);
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.only(
              top: 7,
              bottom: PlatformUtils.isDesktop ? 24 : padding.bottom + 100,
            ),
            sliver: desktopLimitSliver(
              _buildSearchBody(ctr, ctr.loadingState.value),
              maxWidth: double.infinity,
            ),
          ),
        ],
      );
    });
  }

  /// 搜索结果主体：视觉沿用历史记录页既有的栅格 + HistoryItem，不另做设计
  Widget _buildSearchBody(
    HistorySearchController ctr,
    LoadingState<List<HistoryItemModel>?> loadingState,
  ) {
    return switch (loadingState) {
      Loading() => gridSkeleton,
      Success(:final response) =>
        response != null && response.isNotEmpty
            ? SliverGrid.builder(
                gridDelegate: gridDelegate,
                itemBuilder: (context, index) {
                  if (index == response.length - 1) {
                    ctr.onLoadMore();
                  }
                  final item = response[index];
                  // gridDelegate.scaled = 卡片文字随本列实际列宽同比（非桌面端原样返回）
                  return gridDelegate.scaled(
                    desktopCard(
                      HistoryItem(
                        item: item,
                        ctr: ctr,
                        onDelete: (kid, business) =>
                            ctr.onDelHistory(index, kid, business),
                      ),
                    ),
                  );
                },
                itemCount: response.length,
              )
            : HttpError(onReload: ctr.onReload),
      Error(:final errMsg) => HttpError(
        errMsg: errMsg,
        onReload: ctr.onReload,
      ),
    };
  }

  PreferredSizeWidget? get _buildPauseTip {
    if (_historyController.baseCtr.pauseStatus.value) {
      final theme = Theme.of(context).colorScheme;
      return PreferredSize(
        preferredSize: const Size.fromHeight(38),
        child: Container(
          height: 38,
          color: theme.secondaryContainer.withValues(alpha: 0.8),
          padding: const EdgeInsets.only(left: 16, right: 6),
          child: Row(
            children: [
              Expanded(
                child: Text.rich(
                  strutStyle: const StrutStyle(height: 1, leading: 0),
                  style: TextStyle(
                    height: 1,
                    color: theme.onSecondaryContainer,
                  ),
                  TextSpan(
                    children: [
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Icon(
                          Icons.info_outline,
                          size: 18,
                          color: theme.onSecondaryContainer,
                        ),
                      ),
                      const TextSpan(text: ' 历史记录功能已关闭'),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _historyController.baseCtr.onPauseHistory(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 10,
                  ),
                  child: Text(
                    '点击开启',
                    strutStyle: const StrutStyle(height: 1, leading: 0),
                    style: TextStyle(height: 1, color: theme.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return null;
  }

  @override
  bool get wantKeepAlive => widget.type != null;
}
