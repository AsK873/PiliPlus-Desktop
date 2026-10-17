import 'package:PiliPlus/common/widgets/desktop/desktop_content.dart';
import 'package:PiliPlus/common/widgets/desktop/desktop_search_box.dart';
import 'package:PiliPlus/common/widgets/desktop/desktop_top_bar.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/common/widgets/scroll_physics.dart' show tabBarView;
import 'package:PiliPlus/common/widgets/view_safe_area.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/fav_type.dart';
import 'package:PiliPlus/models_new/fav/fav_detail/media.dart';
import 'package:PiliPlus/pages/fav/article/controller.dart';
import 'package:PiliPlus/pages/fav/cheese/controller.dart';
import 'package:PiliPlus/pages/fav/topic/controller.dart';
import 'package:PiliPlus/pages/fav/video/controller.dart';
import 'package:PiliPlus/pages/fav/video/view.dart';
import 'package:PiliPlus/pages/fav_detail/widget/fav_video_card.dart';
import 'package:PiliPlus/pages/fav_folder_sort/view.dart';
import 'package:PiliPlus/pages/fav_search/controller.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/utils/extension/scroll_controller_ext.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class FavPage extends StatefulWidget {
  const FavPage({
    super.key,
    this.desktopEmbedded = false,
    this.onBack,
    this.hideAppBar = false,
    this.searchRequest,
    this.instanceSuffix = '',
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

  /// 桌面端「我的」页内嵌预览的**外部搜索入口**（预览区一级标题行的搜索框）：
  /// 宿主每次提交都传入一个新的 [DesktopInlineSearchRequest]，本页据此复用
  /// **自身既有的就地搜索实现**（`_openSearch` + `_onSubmitSearch` /
  /// `_closeSearch`），不新增搜索路径、控制器或结果视图。
  /// 默认 null：移动端、路由方式与主壳内容区嵌入均不受影响。
  final DesktopInlineSearchRequest? searchRequest;

  /// GetX 实例命名空间后缀：由父级（嵌套子页的宿主）逐级下发。
  /// 默认 `''` ⇒ 移动端 / 路由方式 / 主壳内容区嵌入的注册与查找 key
  /// 与改动前逐字一致。
  final String instanceSuffix;

  @override
  State<FavPage> createState() => _FavPageState();
}

class _FavPageState extends State<FavPage>
    with SingleTickerProviderStateMixin, GridMixin {
  late final TabController _tabController;
  late final FavController _favController;
  late final RxBool _showVideoFavMenu;

  // ===== GetX 实例命名空间（「我的」页内嵌预览实例 vs 完整实例） =====

  /// 本实例是否为「我的」页快捷入口的**内嵌预览**实例
  /// （预览：hideAppBar && !desktopEmbedded；完整实例：主壳内容区嵌入或路由页）。
  bool get _isPreviewInstance =>
      PlatformUtils.isDesktop && widget.hideAppBar && !widget.desktopEmbedded;

  /// 本实例的命名空间后缀（只算一次）：预览实例 `@preview`，其余 `''`。
  /// 嵌套子页由父级通过 [FavPage.instanceSuffix] 下发，保持同一命名空间。
  /// `''` 时 GetX 的 `_getKey` 与改动前（tag == null）同键 ⇒ 移动端零变化。
  late final String _instanceSuffix = widget.instanceSuffix.isNotEmpty
      ? widget.instanceSuffix
      : (_isPreviewInstance ? '@preview' : '');

  String _tag(String base) => '$base$_instanceSuffix';

  void listener() {
    _showVideoFavMenu.value = _tabController.index == 0;
  }

  // ===== 桌面嵌入时的「页面内搜索」（移动端 / 路由方式不启用） =====

  /// 是否处于就地搜索状态
  bool _searchActive = false;

  /// 是否已提交关键词：未提交时展开搜索框也继续显示原收藏夹列表
  bool _searchSubmitted = false;

  /// 就地搜索业务控制器（懒创建；复用既有 FavSearchController 的搜索与分页）
  FavSearchController? _searchCtr;

  /// 就地搜索控制器在 GetX 中的 tag（与路由方式隔离，dispose 时按 tag 删除）
  static const String _searchTag = 'favDesktopEmbedded';

  /// 就地搜索的启用条件：桌面端 + （主壳内容区嵌入 **或** 「我的」页内嵌预览
  /// 通过 [FavPage.searchRequest] 下发了搜索请求）。移动端永远不满足
  /// （[PlatformUtils.isDesktop] 为 false），原有行为不变。
  bool get _desktopInlineSearch =>
      (widget.desktopEmbedded || widget.searchRequest != null) &&
      PlatformUtils.isDesktop;

  /// 返回按钮（桌面嵌入）两级返回：搜索态 → 收藏夹列表 → 上一个页面/主 Tab。
  /// 页面上层不新增导航状态：离开时由主壳收起内容页，
  /// 主 Tab 索引沿用 MainController.selectedIndex（进入时未改动）。
  void _handleBack() {
    if (_searchActive) {
      // 搜索结果态 / 搜索框展开态：只退出搜索，仍留在「我的收藏」
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

  /// 既有搜索入口使用的收藏夹参数（与 /favSearch 的 arguments 完全一致）：
  /// 取当前视频收藏夹列表的第一个收藏夹；尚未加载出收藏夹时返回 null
  /// （与原有搜索按钮相同：静默不跳转）。
  Map<String, dynamic>? _searchArguments() {
    if (_favController.loadingState.value case Success(:final response)) {
      try {
        final item = response!.first;
        return {
          'type': 1,
          'mediaId': item.id,
          'title': item.title,
          'count': item.mediaCount,
          'isOwner': true,
        };
      } catch (_) {}
    }
    return null;
  }

  /// 点搜索按钮：桌面嵌入 → 就地展开搜索框；其余情况保持原有跳转
  void _openSearch() {
    if (!_desktopInlineSearch) {
      final arguments = _searchArguments();
      if (arguments != null) {
        Get.toNamed('/favSearch', arguments: arguments);
      }
      return;
    }
    setState(() {
      _searchActive = true;
      _searchSubmitted = false; // 只展开搜索框，仍显示收藏夹列表
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

  /// 回车提交：写入既有 FavSearchController 的关键词并触发其查询（业务语义不变）
  void _onSubmitSearch(String value) {
    final keyword = value.trim();
    if (keyword.isEmpty) return;
    final ctr = _ensureSearchCtr;
    if (ctr == null) return; // 拿不到收藏夹信息（与原有搜索入口一致：不搜索）
    ctr.editController.text = keyword;
    ctr.onRefresh();
    // 只有提交关键词后才切到搜索结果区
    setState(() => _searchSubmitted = true);
  }

  /// 懒创建就地搜索控制器。
  /// FavSearchController.onInit 通过 Get.arguments 读取「收藏夹」信息
  /// （/favSearch 由 Get.toNamed 传入 arguments）；就地搜索没有路由，
  /// 因此在创建期间临时注入与 /favSearch 完全相同的参数、随后立即还原，
  /// 从而复用完全相同的业务控制器与搜索语义（不改动该搜索页与控制器）。
  FavSearchController? get _ensureSearchCtr {
    final existing = _searchCtr;
    if (existing != null) {
      return existing;
    }
    final arguments = _searchArguments();
    if (arguments == null) {
      return null;
    }
    final routing = Get.routing;
    final previousArgs = routing.args;
    routing.args = arguments;
    try {
      final created = Get.put(
        FavSearchController(),
        tag: _tag(_searchTag),
      );
      _searchCtr = created;
      return created;
    } finally {
      routing.args = previousArgs;
    }
  }

  @override
  void initState() {
    super.initState();
    _favController = Get.put(
      FavController(),
      tag: _instanceSuffix,
    );
    int initialIndex = Get.arguments is int ? Get.arguments as int : 0;
    _showVideoFavMenu = (initialIndex == 0).obs;
    _tabController = TabController(
      length: FavTabType.values.length,
      vsync: this,
      initialIndex: initialIndex,
    );
    _tabController.addListener(listener);
    if (widget.desktopEmbedded) {
      // 接入主壳既有的鼠标返回侧键机制（main.dart 的 BackDetector → _onBack），
      // 复用同一个两级返回，不新增全局监听
      Get.find<MainController>().desktopContentBackHandler = _handleBack;
    }
  }

  @override
  void didUpdateWidget(covariant FavPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final request = widget.searchRequest;
    // 宿主（「我的」页预览区一级标题行的搜索框）每次提交都是**新实例**：
    // 据此复用本页既有的「进入就地搜索 + 提交关键词」路径，不改搜索实现；
    // 空关键词 = 退出搜索（回到收藏夹列表）。移动端从不传该参数 → 不触发。
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
      Get.delete<FavSearchController>(tag: _tag(_searchTag));
    }
    _tabController
      ..removeListener(listener)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SimpleScaffold(
      // 「我的」页内嵌（hideAppBar）→ 整块顶栏（标题 / 返回按钮 / 新建 /
      // 排序 / 搜索）都不嵌入，只渲染主体内容
      // 顶栏其他区域（标题 / 空白）点击即退出就地搜索；
      // translucent → 不抢搜索框、菜单按钮自身的点击
      appBar: widget.hideAppBar
          ? null
          : _searchActive
              ? GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _closeSearch,
                  child: _buildAppBar,
                )
              : _buildAppBar,
      body: _withInlineSearch(
        ViewSafeArea(
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: FavTabType.values
                    .map((item) => Tab(text: item.title))
                    .toList(),
                onTap: (index) {
                  try {
                    if (!_tabController.indexIsChanging) {
                      switch (FavTabType.values[index]) {
                        case FavTabType.video:
                          _favController.scrollController.animToTop();
                        case FavTabType.article:
                          Get.find<FavArticleController>().scrollController
                              .animToTop();
                        case FavTabType.topic:
                          Get.find<FavTopicController>().scrollController
                              .animToTop();
                        case FavTabType.cheese:
                          Get.find<FavCheeseController>().scrollController
                              .animToTop();
                        default:
                      }
                    }
                  } catch (_) {}
                },
              ),
              Expanded(
                child: tabBarView(
                  controller: _tabController,
                  children: FavTabType.values
                      .map(
                        // 视频 tab：改用本实例命名空间下的 FavVideoPage
                        // （其余 tab 的实例隔离不在本批范围内，保持原样）
                        (item) => item == FavTabType.video
                            ? FavVideoPage(instanceSuffix: _instanceSuffix)
                            : item.page,
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget get _buildAppBar => AppBar(
    // 桌面嵌入：标题左侧为两级返回按钮；标题在原有间距上再左移 10px（36 → 26）
    leading: widget.desktopEmbedded
        ? BackButton(onPressed: _handleBack)
        : null,
    titleSpacing: widget.desktopEmbedded ? 26 : null,
    title: const Text('我的收藏'),
    actions: [
      Obx(
        () => _showVideoFavMenu.value
            ? IconButton(
                onPressed: () => Get.toNamed('/createFav')?.then(
                  (data) {
                    if (data != null) {
                      final list =
                          _favController.loadingState.value.dataOrNull;
                      if (list != null && list.isNotEmpty) {
                        list.insert(1, data);
                        _favController.loadingState.refresh();
                      } else {
                        _favController.loadingState.value = Success([data]);
                      }
                    }
                  },
                ),
                icon: const Icon(Icons.add),
                tooltip: '新建收藏夹',
              )
            : const SizedBox.shrink(),
      ),
      Obx(
        () => _showVideoFavMenu.value
            ? IconButton(
                onPressed: () {
                  if (_favController.loadingState.value.isSuccess) {
                    if (!_favController.isEnd) {
                      SmartDialog.showToast('加载全部收藏夹再排序');
                      return;
                    }
                    Get.to(
                      FavFolderSortPage(favController: _favController),
                    );
                  }
                },
                icon: const Icon(Icons.sort),
                tooltip: '收藏夹排序',
              )
            : const SizedBox.shrink(),
      ),
      Obx(
        () => _showVideoFavMenu.value
            ? (_searchActive && _desktopInlineSearch
                  // 就地搜索：复用主面板 DesktopSearchBox 的 UI/交互。
                  // 不传 initialText / fallbackQuery → 不显示「当前搜索关键词」；
                  // 不接 onOverlayChanged → 宿主不渲染 DesktopSearchPanel
                  // → 无联想浮层。
                  ? DesktopSearchBox(
                      active: true,
                      width: DesktopTopBar.searchWidth,
                      height: DesktopTopBar.searchHeight,
                      onSubmit: _onSubmitSearch,
                    )
                  : IconButton(
                      onPressed: _openSearch,
                      icon: const Icon(Icons.search_outlined),
                      tooltip: '搜索',
                    ))
            : const SizedBox.shrink(),
      ),
      const SizedBox(width: 6),
    ],
  );

  /// 桌面嵌入：在「收藏夹列表」与「就地搜索结果」之间切换。
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
        // 未提交关键词时保持 index=0：搜索框展开也继续显示收藏夹列表
        index: _searchActive && _searchSubmitted ? 1 : 0,
        sizing: StackFit.expand,
        children: [content, _buildSearchResults()],
      ),
    );
  }

  /// 就地搜索结果（复用既有 FavSearchController 的查询/分页数据）
  Widget _buildSearchResults() {
    final ctr = _searchCtr;
    if (ctr == null) {
      return const SizedBox.shrink();
    }
    return Obx(() {
      final padding = MediaQuery.viewPaddingOf(context);
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        controller: ctr.scrollController,
        slivers: [
          SliverPadding(
            padding: EdgeInsets.only(
              top: 7,
              bottom: PlatformUtils.isDesktop ? 24 : padding.bottom + 100,
            ),
            // 与首页网格一致：卡片网格不限宽、列数按可用宽度动态决定
            sliver: desktopLimitSliver(
              _buildSearchBody(ctr, ctr.loadingState.value),
              maxWidth: double.infinity,
            ),
          ),
        ],
      );
    });
  }

  /// 搜索结果主体：视觉沿用收藏搜索页既有的「限宽栅格 + FavVideoCardH」
  Widget _buildSearchBody(
    FavSearchController ctr,
    LoadingState<List<FavDetailItemModel>?> loadingState,
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
                      FavVideoCardH(
                        item: item,
                        index: index,
                        ctr: ctr,
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
}
