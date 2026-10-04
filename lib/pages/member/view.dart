import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/button/icon_button.dart';
import 'package:PiliPlus/common/widgets/desktop/desktop_tokens.dart';
import 'package:PiliPlus/common/widgets/dialog/report_member.dart';
import 'package:PiliPlus/common/widgets/dynamic_sliver_app_bar/dynamic_sliver_app_bar.dart';
import 'package:PiliPlus/common/widgets/gesture/tap_gesture_recognizer.dart';
import 'package:PiliPlus/common/widgets/loading_widget/loading_widget.dart';
import 'package:PiliPlus/common/widgets/scroll_behavior.dart'
    show NoOverscrollIndicator;
import 'package:PiliPlus/common/widgets/scroll_physics.dart' show tabBarView;
import 'package:PiliPlus/http/live.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/models_new/live/live_medal_wall/data.dart';
import 'package:PiliPlus/models_new/space/space/reservation_card_list.dart';
import 'package:PiliPlus/models_new/space/space/data.dart';
import 'package:PiliPlus/pages/coin_log/controller.dart';
import 'package:PiliPlus/pages/exp_log/controller.dart';
import 'package:PiliPlus/pages/log_table/view.dart';
import 'package:PiliPlus/pages/login_devices/view.dart';
import 'package:PiliPlus/pages/login_log/controller.dart';
import 'package:PiliPlus/pages/member/controller.dart';
import 'package:PiliPlus/pages/member/widget/medal_wall.dart';
import 'package:PiliPlus/pages/member/widget/reserve_button.dart';
import 'package:PiliPlus/pages/member/widget/user_info_card.dart';
import 'package:PiliPlus/pages/member_cheese/view.dart';
import 'package:PiliPlus/pages/member_contribute/controller.dart';
import 'package:PiliPlus/pages/member_contribute/view.dart';
import 'package:PiliPlus/pages/member_dynamics/view.dart';
import 'package:PiliPlus/pages/member_favorite/view.dart';
import 'package:PiliPlus/pages/member_home/view.dart';
import 'package:PiliPlus/pages/member_pgc/view.dart';
import 'package:PiliPlus/pages/member_season_series/view.dart';
import 'package:PiliPlus/pages/member_shop/view.dart';
import 'package:PiliPlus/pages/member_video_web/archive/view.dart';
import 'package:PiliPlus/pages/member_video_web/season_series/view.dart';
import 'package:PiliPlus/utils/android/android_helper.dart';
import 'package:PiliPlus/utils/cache_manager.dart';
import 'package:PiliPlus/utils/date_utils.dart';
import 'package:PiliPlus/utils/extension/context_ext.dart';
import 'package:PiliPlus/utils/extension/string_ext.dart';
import 'package:PiliPlus/utils/num_utils.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:extended_nested_scroll_view/extended_nested_scroll_view.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class MemberPage extends StatefulWidget {
  const MemberPage({super.key, this.mid});

  /// 桌面端就地承载（例如私信页右侧半屏抽屉）时显式传入 mid；
  /// 为空时沿用原有路由查询参数 `/member?mid=…`，路由行为与之前完全一致。
  final int? mid;

  @override
  State<MemberPage> createState() => _MemberPageState();
}

class _MemberPageState extends State<MemberPage> {
  late final int _mid;
  late final String _heroTag;
  late final MemberController _userController;
  PageController? _headerController;
  PageController getHeaderController() =>
      _headerController ??= PageController();

  @override
  void initState() {
    super.initState();
    _mid = widget.mid ?? int.tryParse(Get.parameters['mid']!) ?? -1;
    _heroTag = Utils.makeHeroTag(_mid);
    _userController = Get.put(
      MemberController(mid: _mid),
      tag: _heroTag,
    );
  }

  @override
  void dispose() {
    _headerController?.dispose();
    _headerController = null;
    _cacheFollowTime = null;
    _cacheMedalData = null;
    super.dispose();
  }

  /// 桌面端布局阈值（内容区可用宽度）：>= 该值时个人主页走宽屏布局
  /// （静态横排信息区 + 左对齐页签 + 多列内容），否则沿用手机/平板布局。
  /// 取 700 与 `MainLayout` 侧栏下的最小正文宽（960 − 216 = 744）同量级，
  /// 保证正常窗口即进入桌面布局，而窄抽屉/半屏承载时不会挤压手机布局。
  static const double _kDesktopMinWidth = 700;

  /// 桌面端页签行高度（TabBar 45 + 上下留白 1），与 `pinnedHeaderSliverHeightBuilder`
  /// 配套使用，避免内容区顶部被页签遮挡。
  static const double _kDesktopTabsHeight = 46;

  /// 桌面端正文最大宽度 = 全桌面唯一来源（`Style.contentMaxWidth` = 1480）。
  /// 只用于**超宽屏**上限，不做手机式收窄：宽度不够时正文照常铺满可用空间。
  static const double _kDesktopContentMaxWidth = DesktopTokens.contentWidth;

  @override
  Widget build(BuildContext context) {
    // 手机 / 平板：完全沿用原布局（下面 _buildMobile 内是原 build 的逐字内容）。
    // `MediaQuery.removePadding` 保持原 build 的返回值形状（原 build 末尾正是
    // 这个包裹），因此非桌面端视觉零变化的同时，桌面端不会重复扣减 viewPadding。
    final mobile = Builder(
      builder: (_) => MediaQuery.removePadding(
        context: context,
        child: _buildMobile(context),
      ),
    );
    if (!PlatformUtils.isDesktop) {
      return mobile;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth ||
            constraints.maxWidth < _kDesktopMinWidth) {
          return mobile;
        }
        final theme = Theme.of(context).colorScheme;
        return Material(
          color: theme.surface,
          child: Obx(
            () => switch (_userController.loadingState.value) {
              Loading() => m3eLoading,
              Success(:final response) => _buildDesktopBody(
                context,
                theme,
                response,
              ),
              Error(:final errMsg) => scrollErrorWidget(
                errMsg: errMsg,
                onReload: _userController.onReload,
              ),
            },
          ),
        );
      },
    );
  }

  /// 桌面端个人主页：单个外层滚动容器（[ExtendedNestedScrollView]）承载
  /// 「顶部操作栏 → 个人信息区 → 页签 → 当前 Tab 内容」四段，各段排列方式：
  ///
  /// * 顶部操作栏：固定 56 高的 `AppBar`（用户名 + 原有 actions），滚动时吸顶，
  ///   不占用额外垂直空间（无手机端 135 高头图占位）；
  /// * 个人信息区：`UserInfoCard` 的**横排**布局（头像 + 身份/签名/数据一行 +
  ///   统计与关注按钮），左对齐贴在最大 1480 的内容宽度内；
  /// * 页签：`SliverPinnedHeader` + `TabBar`，`isScrollable` + `TabAlignment.start`
  ///   ⇒ 横向排列、整体左对齐、不平均铺满；选中态沿用 BoxDecoration 胶囊
  ///   （secondaryContainer + onSecondaryContainer，桌面端口径）；
  /// * 内容区：`_buildBody` 原样复用（各 Tab 自己的多列网格，随可用宽度自适应列数）。
  ///
  /// 路由、点击逻辑、数据与交互全部复用既有实现，未新增任何业务分支。
  Widget _buildDesktopBody(
    BuildContext context,
    ColorScheme theme,
    SpaceData? response,
  ) {
    return ExtendedNestedScrollView(
      onlyOneScrollInBody: true,
      key: _userController.scrollKey,
      scrollBehavior: const NoOverscrollIndicator(),
      // 桌面端不吸顶「个人信息区」：钉住的高度只 = 顶部操作栏
      // （`DynamicSliverAppBar` 的折叠高度 = topPadding + kToolbarHeight + 1）
      pinnedHeaderSliverHeightBuilder: () =>
          MediaQuery.viewPaddingOf(context).top + kToolbarHeight + 1,
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          if (response != null)
            DynamicSliverAppBar.medium(
              // 桌面端不使用折叠头图：flexibleSpace 必须是一个「不索取尺寸」的占位。
              //
              // 注意：这里**不能**用 `SizedBox.expand()`。`SliverPinnedHeader._rawLayout`
              // 以无界高度（`constraints.asBoxConstraints()`）测量 AppBar，AppBar 内部
              // Stack 会把 `0 ≤ h ≤ Infinity` 传给 flexibleSpace；`SizedBox.expand()`
              // 要求「尽可能大」⇒ `Size(w, Infinity)` ⇒
              // `RenderConstrainedBox object was given an infinite size during layout`
              // ⇒ 首页首帧布局断言、整页黑屏（2026-10-05 修复）。
              // `SizedBox.shrink()` 在两种约束下都安全地取 0，AppBar 高度自然收敛为
              // 折叠高度（topPadding + kToolbarHeight + 1）。
              flexibleSpace: const SizedBox.shrink(),
              actions: _actions(theme),
              title: Text(
                _userController.username ?? '',
                style: const TextStyle(
                  fontSize: DesktopTokens.fontPageTitle,
                ),
              ),
            )
          else
            SliverAppBar(
              pinned: true,
              actions: _actions(theme),
              title: GestureDetector(
                onTap: _userController.onReload,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  _userController.username ?? '',
                  style: const TextStyle(
                    fontSize: DesktopTokens.fontPageTitle,
                  ),
                ),
              ),
            ),
          if (response != null)
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: _kDesktopContentMaxWidth,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      DesktopTokens.padPage,
                      DesktopTokens.gap8,
                      DesktopTokens.padPage,
                      DesktopTokens.gap12,
                    ),
                    child: UserInfoCard(
                      isOwner:
                          _userController.mid == _userController.account.mid,
                      relation: _userController.relation.value,
                      card: response.card!,
                      images: response.images!,
                      onFollow: () => _userController.onFollow(context),
                      live: _userController.live,
                      silence: _userController.silence,
                      headerControllerBuilder: getHeaderController,
                      showLiveMedalWall: _showLiveMedalWall,
                      charges: _userController.charges,
                      chargeCount: _userController.chargeCount,
                      guards: _userController.guards,
                      guardCount: _userController.guardCount,
                    ),
                  ),
                ),
              ),
            ),
          if ((_userController.tab2?.length ?? 0) > 1)
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: _kDesktopContentMaxWidth,
                  ),
                  child: SizedBox(
                    height: _kDesktopTabsHeight,
                    child: TabBar(
                      controller: _userController.tabController,
                      tabs: _userController.tabs,
                      onTap: _userController.onTapTab,
                      // 横向排列、整体左对齐、不平均铺满整页宽度
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      dividerColor: Colors.transparent,
                      dividerHeight: 0,
                      splashBorderRadius: BorderRadius.circular(20),
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicatorPadding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 8,
                      ),
                      indicator: BoxDecoration(
                        color: theme.secondaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      labelStyle: const TextStyle(
                        fontSize: DesktopTokens.fontRowTitle,
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: DesktopTokens.fontRowTitle,
                      ),
                      labelColor: theme.onSecondaryContainer,
                      unselectedLabelColor: theme.outline,
                    ),
                  ),
                ),
              ),
            ),
        ];
      },
      // 内容区：各 Tab 自己的多列网格原样复用；仅在超宽屏时按桌面统一内容宽度
      // 居中，避免卡片被无限拉宽（窄窗 / 半屏承载时 ConstrainedBox 不生效）。
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: _kDesktopContentMaxWidth,
          ),
          child: _buildBody,
        ),
      ),
    );
  }

  /// 手机 / 平板布局（原实现逐字保留：折叠头图 + 信息卡 + 45 高页签 + 内容）。
  Widget _buildMobile(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    final padding = MediaQuery.viewPaddingOf(context);
    return Material(
      color: theme.surface,
      child: Obx(
        () => switch (_userController.loadingState.value) {
          Loading() => m3eLoading,
          Success(:final response) => ExtendedNestedScrollView(
            onlyOneScrollInBody: true,
            key: _userController.scrollKey,
            scrollBehavior: const NoOverscrollIndicator(),
            pinnedHeaderSliverHeightBuilder: () =>
                kToolbarHeight + MediaQuery.viewPaddingOf(context).top,
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              if (response != null) {
                return [
                  DynamicSliverAppBar.medium(
                    actions: _actions(theme),
                    title: Text(_userController.username ?? ''),
                    flexibleSpace: Obx(
                      () => UserInfoCard(
                        isOwner:
                            _userController.mid == _userController.account.mid,
                        relation: _userController.relation.value,
                        card: response.card!,
                        images: response.images!,
                        onFollow: () => _userController.onFollow(context),
                        live: _userController.live,
                        silence: _userController.silence,
                        headerControllerBuilder: getHeaderController,
                        showLiveMedalWall: _showLiveMedalWall,
                        charges: _userController.charges,
                        chargeCount: _userController.chargeCount,
                        guards: _userController.guards,
                        guardCount: _userController.guardCount,
                      ),
                    ),
                  ),
                ];
              }
              return [
                SliverAppBar(
                  pinned: true,
                  actions: _actions(theme),
                  title: GestureDetector(
                    onTap: _userController.onReload,
                    behavior: HitTestBehavior.opaque,
                    child: Text(_userController.username ?? ''),
                  ),
                ),
              ];
            },
            body: _userController.tab2?.isNotEmpty == true
                ? Padding(
                    padding: .only(left: padding.left, right: padding.right),
                    child: Column(
                      children: [
                        if ((_userController.tab2?.length ?? 0) > 1)
                          SizedBox(
                            height: 45,
                            child: TabBar(
                              labelPadding: .zero,
                              controller: _userController.tabController,
                              tabs: _userController.tabs,
                              onTap: _userController.onTapTab,
                              dividerColor: theme.outline.withValues(
                                alpha: 0.2,
                              ),
                            ),
                          ),
                        Expanded(child: _buildBody),
                      ],
                    ),
                  )
                : scrollableError,
          ),
          Error(:final errMsg) => scrollErrorWidget(
            errMsg: errMsg,
            onReload: _userController.onReload,
          ),
        },
      ),
    );
  }

  Widget _reserveBtn(List<ReservationCardItem> list, ColorScheme theme) {
    return IconButton(
      tooltip: '预约',
      onPressed: () => _showReserveList(list),
      icon: ReserveButton(
        count: list.length,
        color: theme.onSurfaceVariant,
        child: const Icon(Icons.notifications_none),
      ),
    );
  }

  void _showReserveList(List<ReservationCardItem> list) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      enableDrag: !PlatformUtils.isDesktop,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxWidth: math.min(640, context.mediaQueryShortestSide),
        // 桌面端补统一最大高度；移动端 double.infinity 即原「不限高」行为
        maxHeight: PlatformUtils.isDesktop
            ? DesktopTokens.sheetMaxHeight
            : double.infinity,
      ),
      builder: (context) {
        final scheme = ColorScheme.of(context);
        return Padding(
          padding: .only(bottom: MediaQuery.viewPaddingOf(context).bottom + 30),
          child: Column(
            mainAxisSize: .min,
            children: [
              InkWell(
                onTap: Get.back,
                borderRadius: Style.bottomSheetRadius,
                child: SizedBox(
                  height: 35,
                  child: Center(
                    child: Container(
                      width: 32,
                      height: 3,
                      decoration: BoxDecoration(
                        color: scheme.outline,
                        borderRadius: const .all(.circular(1.5)),
                      ),
                    ),
                  ),
                ),
              ),
              ...list.map((e) {
                return Builder(
                  builder: (context) {
                    Widget trailing = FilledButton.tonal(
                      onPressed: () async {
                        final isFollow = e.isFollow;
                        final res = await UserHttp.spaceReserve(
                          sid: e.sid!,
                          isFollow: isFollow,
                        );
                        if (res.isSuccess) {
                          e
                            ..total += isFollow ? -1 : 1
                            ..isFollow = !isFollow;
                          if (!context.mounted) return;
                          (context as Element).markNeedsBuild();
                        } else {
                          res.toast();
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: e.isFollow
                            ? scheme.onInverseSurface
                            : null,
                        foregroundColor: e.isFollow ? scheme.outline : null,
                        tapTargetSize: .shrinkWrap,
                        minimumSize: const Size(68, 40),
                        padding: const .symmetric(horizontal: 10),
                        visualDensity: const .new(horizontal: -2, vertical: -3),
                        shape: const RoundedRectangleBorder(
                          borderRadius: .all(.circular(6)),
                        ),
                      ),
                      child: Text(
                        '${e.isFollow ? '已' : ''}预约',
                        style: const TextStyle(fontSize: 13),
                      ),
                    );
                    if (e.dynamicId?.isNotEmpty ?? false) {
                      trailing = Row(
                        spacing: 8,
                        mainAxisSize: .min,
                        children: [
                          iconButton(
                            tooltip: '预约动态',
                            size: 32,
                            iconSize: 20,
                            iconColor: scheme.outline,
                            icon: const Icon(Icons.open_in_browser),
                            onPressed: () => PageUtils.pushDynFromId(
                              id: e.dynamicId,
                            ),
                          ),
                          trailing,
                        ],
                      );
                    }
                    return ListTile(
                      dense: true,
                      title: Text(
                        e.name!,
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Padding(
                        padding: const .only(top: 2.0),
                        child: Text.rich(
                          style: TextStyle(fontSize: 12, color: scheme.outline),
                          TextSpan(
                            children: [
                              TextSpan(
                                text:
                                    '${e.descText1 == null ? '' : '${e.descText1}  '}'
                                    '${NumUtils.numFormat(e.total)}人预约',
                              ),
                              if (e.lotteryPrizeInfo case final lottery?) ...[
                                const TextSpan(text: '\n'),
                                WidgetSpan(
                                  alignment: .middle,
                                  child: Icon(
                                    size: 15,
                                    Icons.card_giftcard,
                                    color: scheme.primary,
                                  ),
                                ),
                                TextSpan(
                                  text: ' ${lottery.text}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.primary,
                                  ),
                                  recognizer:
                                      lottery.jumpUrl?.isNotEmpty == true
                                      ? (NoDeadlineTapGestureRecognizer()
                                          ..onTap = () => Get.toNamed(
                                            '/webview',
                                            parameters: {
                                              'url': lottery.jumpUrl!,
                                            },
                                          ))
                                      : null,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      trailing: trailing,
                    );
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _actions(ColorScheme theme) => [
    if (_userController.reserves?.isNotEmpty ?? false)
      _reserveBtn(_userController.reserves!, theme),
    IconButton(
      tooltip: '搜索',
      onPressed: () => Get.toNamed(
        '/memberSearch?mid=$_mid&uname=${_userController.username}',
      ),
      icon: const Icon(Icons.search_outlined),
    ),
    PopupMenuButton(
      icon: const Icon(Icons.more_vert),
      itemBuilder: (_) => <PopupMenuEntry>[
        if (_userController.account.isLogin &&
            _userController.account.mid != _mid) ...[
          PopupMenuItem(
            onTap: () => _userController.blockUser(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.block, size: 19),
                const SizedBox(width: 10),
                Text(
                  _userController.relation.value != 128 ? '加入黑名单' : '移除黑名单',
                ),
              ],
            ),
          ),
          if (_userController.isFollowed == 1)
            PopupMenuItem(
              onTap: _userController.onRemoveFan,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.remove_circle_outline_outlined, size: 19),
                  SizedBox(width: 10),
                  Text('移除粉丝'),
                ],
              ),
            ),
        ],
        PopupMenuItem(
          onTap: _userController.shareUser,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.share_outlined, size: 19),
              const SizedBox(width: 10),
              Text(
                _userController.account.mid != _mid ? '分享UP主' : '分享我的主页',
              ),
            ],
          ),
        ),
        if (PlatformUtils.isMobile)
          PopupMenuItem(
            onTap: _createShortcut,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_box_outlined, size: 19),
                SizedBox(width: 10),
                Text('添加至桌面'),
              ],
            ),
          ),
        // if (_userController.hasCharge)
        //   PopupMenuItem(
        //     onTap: () => UpowerRankPage.toUpowerRank(
        //       mid: _userController.mid,
        //       name: _userController.username ?? '',
        //       count: _userController.chargeCount,
        //     ),
        //     child: const Row(
        //       mainAxisSize: MainAxisSize.min,
        //       children: [
        //         Icon(Icons.electric_bolt, size: 19),
        //         SizedBox(width: 10),
        //         Text('充电排行榜'),
        //       ],
        //     ),
        //   ),
        // if (_userController.hasGuard)
        //   PopupMenuItem(
        //     onTap: () => MemberGuard.toMemberGuard(
        //       mid: _userController.mid,
        //       name: _userController.username ?? '',
        //       count: _userController.guardCount,
        //     ),
        //     child: const Row(
        //       mainAxisSize: MainAxisSize.min,
        //       children: [
        //         Icon(Icons.anchor, size: 19),
        //         SizedBox(width: 10),
        //         Text('大航海舰队'),
        //       ],
        //     ),
        //   ),
        if (Get.isRegistered<MemberContributeCtr>(tag: _heroTag))
          PopupMenuItem(
            onTap: _toWebArchive,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.extension_outlined, size: 19),
                SizedBox(width: 10),
                Text('网页投稿'),
              ],
            ),
          ),
        if (_userController.account.isLogin)
          if (_userController.mid == _userController.account.mid) ...[
            if ((_userController
                        .loadingState
                        .value
                        .dataOrNull
                        ?.card
                        ?.vip
                        ?.status ??
                    0) >
                0)
              PopupMenuItem(
                onTap: _userController.vipExpAdd,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.upcoming_outlined, size: 19),
                    SizedBox(width: 10),
                    Text('大会员经验'),
                  ],
                ),
              ),
            PopupMenuItem(
              onTap: () => Get.to(const LoginDevicesPage()),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.devices, size: 18),
                  SizedBox(width: 10),
                  Text('登录设备'),
                ],
              ),
            ),
            PopupMenuItem(
              onTap: () => Get.to(
                const LogPage(),
                arguments: LoginLogController(),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.login, size: 18),
                  SizedBox(width: 10),
                  Text('登录记录'),
                ],
              ),
            ),
            PopupMenuItem(
              onTap: () => Get.to(
                const LogPage(),
                arguments: CoinLogController(),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FontAwesomeIcons.b, size: 16),
                  SizedBox(width: 10),
                  Text('硬币记录'),
                ],
              ),
            ),
            PopupMenuItem(
              onTap: () => Get.to(
                const LogPage(),
                arguments: ExpLogController(),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.linear_scale, size: 18),
                  SizedBox(width: 10),
                  Text('经验记录'),
                ],
              ),
            ),
            PopupMenuItem(
              onTap: () => Get.toNamed('/spaceSetting'),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.settings_outlined, size: 19),
                  SizedBox(width: 10),
                  Text('空间设置'),
                ],
              ),
            ),
          ] else ...[
            if (_userController.isFollow)
              PopupMenuItem(
                onTap: _showFollowTime,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.more_time_outlined, size: 19),
                    SizedBox(width: 10),
                    Text('关注时间'),
                  ],
                ),
              ),
            const PopupMenuDivider(),
            PopupMenuItem(
              onTap: () => showMemberReportDialog(
                context,
                name: _userController.username,
                mid: _mid,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 19,
                    color: theme.error,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '举报',
                    style: TextStyle(color: theme.error),
                  ),
                ],
              ),
            ),
          ],
      ],
    ),
    const SizedBox(width: 4),
  ];

  Widget get _buildBody => tabBarView(
    hitTestBehavior: .translucent,
    controller: _userController.tabController,
    children: _userController.tab2!.map((item) {
      return switch (item.param!) {
        'home' => MemberHome(heroTag: _heroTag),
        'dynamic' => MemberDynamicsPage(mid: _mid),
        'contribute' => Obx(
          () => MemberContribute(
            heroTag: _heroTag,
            initialIndex: _userController.contributeInitialIndex.value,
            mid: _mid,
          ),
        ),
        'bangumi' => MemberBangumi(
          heroTag: _heroTag,
          mid: _mid,
        ),
        'favorite' => MemberFavorite(
          heroTag: _heroTag,
          mid: _mid,
        ),
        'cheese' => MemberCheese(
          heroTag: _heroTag,
          mid: _mid,
        ),
        'shop' => MemberShop(
          heroTag: _heroTag,
          mid: _mid,
        ),
        // 个人主页一级 Tab「合集和系列」：直接复用既有 member_season_series
        // （SeasonSeriesPage → SeasonSeriesController → MemberHttp.seasonSeriesList
        //  → SeasonSeriesCard 自适应网格），未新增任何数据/接口实现。
        // heroTag 传 null：页面自身不使用 heroTag，且「投稿」Tab 内的
        // `全部合集/列表` 子页签会用同一个 _heroTag 注册同类型的
        // SeasonSeriesController，传 null 可彻底避免 Getx 同 tag 重复注册冲突。
        'ugcSeason' => SeasonSeriesPage(mid: _mid),
        _ => Center(child: Text(item.title ?? '')),
      };
    }).toList(),
  );

  String? _cacheFollowTime;
  Future<void> _showFollowTime() async {
    void onShow() {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(_userController.username ?? ''),
          content: Text(_cacheFollowTime!),
          actions: [
            TextButton(
              onPressed: Get.back,
              child: Text(
                '关闭',
                style: TextStyle(color: ColorScheme.of(context).outline),
              ),
            ),
          ],
        ),
      );
    }

    if (_cacheFollowTime != null) {
      onShow();
      return;
    }
    final res = await UserHttp.userRelation(_mid);
    if (res case Success(:final response)) {
      if (response.mtime == null) return;
      _cacheFollowTime =
          '关注时间: ${DateFormatUtils.longFormatDs.format(
            DateTime.fromMillisecondsSinceEpoch(response.mtime! * 1000),
          )}';
      onShow();
    } else {
      res.toast();
    }
  }

  MedalWallData? _cacheMedalData;
  Future<void> _showLiveMedalWall() async {
    void onShow() {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => MedalWall(response: _cacheMedalData!),
      );
    }

    if (_cacheMedalData != null) {
      onShow();
      return;
    }
    SmartDialog.showLoading();
    final res = await LiveHttp.liveMedalWall(mid: _mid);
    SmartDialog.dismiss();
    if (res case Success(:final response)) {
      _cacheMedalData = response;
      onShow();
    } else {
      res.toast();
    }
  }

  void _toWebArchive() {
    try {
      final ctr = Get.find<MemberContributeCtr>(tag: _heroTag);
      final item = ctr.items?[ctr.tabController?.index ?? 0];
      if (item != null) {
        final id = item.seasonId ?? item.seriesId;
        if (id != null) {
          MemberSSWeb.toMemberSSWeb(
            type: item.seasonId != null ? .season : .series,
            id: id,
            mid: _mid,
            name: _userController.username ?? '',
          );
          return;
        }
      }
      MemberVideoWeb.toMemberVideoWeb(
        mid: _mid,
        name: _userController.username ?? '',
      );
    } catch (e) {
      SmartDialog.showToast(e.toString());
    }
  }

  void _createShortcut() {
    if (Platform.isIOS) {
      PageUtils.launchURL(
        'https://www.bilibili.com/blackboard/disablelink/go-to-up-space.html?mid=$_mid',
      );
    } else if (Platform.isAndroid) {
      _createShortcutAndroid();
    }
  }

  Future<void> _createShortcutAndroid() async {
    try {
      SmartDialog.showLoading();
      final file = (await CacheManager.manager.getSingleFile(
        '${_userController.userAvatar!}@200w_200h.webp'.http2https,
      ));
      SmartDialog.dismiss();
      PiliAndroidHelper.createShortcut(
        _userController.mid.toString(),
        'bilibili://space/${_userController.mid}',
        _userController.username!,
        file.path,
      );
    } catch (e) {
      SmartDialog.showToast(e.toString());
    }
  }
}
