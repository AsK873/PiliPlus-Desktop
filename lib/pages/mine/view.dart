import 'dart:async';

import 'package:PiliPlus/common/assets.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/desktop/desktop_card.dart';
import 'package:PiliPlus/common/widgets/desktop/desktop_search_box.dart';
import 'package:PiliPlus/common/widgets/desktop/desktop_section.dart';
import 'package:PiliPlus/common/widgets/desktop/desktop_side_bar.dart';
import 'package:PiliPlus/common/widgets/desktop/desktop_top_bar.dart';
import 'package:PiliPlus/common/widgets/desktop/winui_section.dart';
import 'package:PiliPlus/common/widgets/flutter/list_tile.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/player_bar.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/nav_bar_config.dart';
import 'package:PiliPlus/models_new/fav/fav_folder/list.dart';
import 'package:PiliPlus/pages/common/common_page.dart';
import 'package:PiliPlus/pages/fav/view.dart';
import 'package:PiliPlus/pages/history/view.dart';
import 'package:PiliPlus/pages/home/view.dart';
import 'package:PiliPlus/pages/later/view.dart';
import 'package:PiliPlus/pages/login/controller.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/pages/mine/controller.dart';
import 'package:PiliPlus/pages/mine/widgets/item.dart';
import 'package:PiliPlus/pages/subscription/view.dart';
import 'package:PiliPlus/pages/whisper/view.dart';
import 'package:PiliPlus/utils/bili_utils.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:PiliPlus/utils/extension/num_ext.dart';
import 'package:PiliPlus/utils/extension/theme_ext.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart' hide ListTile;

class MinePage extends StatefulWidget {
  const MinePage({super.key, this.showBackBtn = false, this.onSelectShortcut});

  final bool showBackBtn;

  /// 桌面端快捷入口的点击回调（由桌面主壳传入，与侧栏 [DesktopSideBar] 用
  /// 同一个闭包 → 在右侧主内容区就地打开）。为空 / 返回 false 时回退为
  /// 原有 `Get.toNamed(entry.route)` 行为；移动端不传，行为不变。
  final bool Function(DesktopNavEntry entry)? onSelectShortcut;

  @override
  State<MinePage> createState() => _MediaPageState();
}

class _MediaPageState extends CommonPageState<MinePage>
    with AutomaticKeepAliveClientMixin {
  final MineController controller = Get.putOrFind(MineController.new);
  late final MainController _mainController = Get.find<MainController>();

  /// 预览区一级标题行搜索框最近一次提交的请求（仅桌面端）：原样下发给
  /// **当前预览的那一项**，由该页复用自身既有的就地搜索实现；带 route
  /// 以免切换入口后把旧关键词串给别的预览页。
  DesktopInlineSearchRequest? _previewSearchRequest;

  @override
  bool get wantKeepAlive => true;

  bool get checkPage =>
      _mainController.navigationBars[0] != NavigationBarType.mine &&
      _mainController.selectedIndex.value == 0;

  /// 「我的」页当前就地预览的项（仅桌面端）：优先主壳正在预览的
  /// [MainController.desktopShortcutPreview]；它被主壳清空时（打开完整内容页：
  /// main.dart 的 `_openDesktopShortcut` / `didPushNext`）回落到记忆字段
  /// [MainController.desktopShortcutDefaultRoute] —— 即**上一次选中的那一项**，
  /// 从未选过则为默认的「历史记录」。
  ///
  /// 之所以在构建时（而不是 initState 里）解析：本页在主 Tab 的 PageView 中
  /// 常驻保活（[wantKeepAlive]），离开再回来不会重建 State，initState 只跑一次；
  /// 把回落写进状态又会在主壳刚清空时立刻重建出第二个页面实例（旧的
  /// GetX 控制器冲突问题，见 main.dart 的注释）。因此只读、不写状态。
  String get _desktopPreviewRoute {
    final preview = _mainController.desktopShortcutPreview.value;
    if (preview != null) {
      return preview;
    }
    return _mainController.desktopShortcutDefaultRoute;
  }

  @override
  bool onNotificationType1(UserScrollNotification notification) {
    if (checkPage) {
      return false;
    }
    return super.onNotificationType1(notification);
  }

  @override
  bool onNotificationType2(ScrollNotification notification) {
    if (checkPage) {
      return false;
    }
    return super.onNotificationType2(notification);
  }

  /// M5：桌面端内容限宽（正文可用宽 > [WinUi.contentWidth] = 1480 时两侧留白，
  /// 避免拉伸为超宽单列）。限宽值取全桌面唯一来源（= Style.contentMaxWidth），
  /// 与首页推荐流网格 / 历史 / 稍后 / 收藏 / 订阅 / 私信 / 设置同一限宽。
  ///
  /// 口径：桌面主壳的正文区 = 窗口宽 − 侧栏 [DesktopSideBar.width]（216），
  /// 其它页面的限宽（`desktopLimitSliver` / `desktopLimitBox`）作用在**正文区**
  /// 上；本页若按整窗宽算留白，`w > 1480` 时正文实际只有 1480 − 216 = 1264，
  /// 与其它页面不等宽。故这里先减掉侧栏宽，使正文限宽同样收敛到 1480
  /// （本页 ListView 自带的 [WinUi.padPage] 页面边距在限宽之内，
  /// 与其它页面「限宽 = 内容外框」的口径一致）。
  double _sidePad(BuildContext context) {
    if (!PlatformUtils.isDesktop) return 0;
    final double avail =
        MediaQuery.sizeOf(context).width - DesktopSideBar.width;
    return avail > WinUi.contentWidth ? (avail - WinUi.contentWidth) / 2 : 0;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.secondary;
    return Column(
      children: [
        // 桌面端：顶部那排设置/功能入口（评论记录 / 无痕模式 / 切换账号 /
        // 主题切换 / 设置）已搬到侧栏同一分组（见 desktop_side_bar.dart 的
        // `mineEntries`），此处整体移除、不再占高度；移动端原样保留。
        if (!PlatformUtils.isDesktop)
          Padding(
            padding: const .symmetric(vertical: 10),
            child: _buildHeaderActions,
          ),
        Expanded(
          child: Material(
            type: .transparency,
            child: refreshIndicator(
              onRefresh: controller.onRefresh,
              child: onBuild(
                // 桌面端：用 LayoutBuilder 取「页面正文的实际可用高度」，
                // 预览区高度由它推导（不再固定 420）⇒ 随窗口高度变化。
                PlatformUtils.isDesktop
                    ? LayoutBuilder(
                        builder: (context, constraints) =>
                            _buildDesktopList(theme, constraints.maxHeight),
                      )
                    : _buildMobileList(theme, secondary),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 移动端：保持原有排版不变。
  Widget _buildMobileList(ThemeData theme, Color secondary) {
    return ListView(
      padding: EdgeInsets.only(
        left: _sidePad(context),
        right: _sidePad(context),
        bottom: PlatformUtils.isDesktop ? 24 : 100,
      ),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _buildUserInfo(theme, secondary),
        _buildActions(secondary),
        Obx(
          () => controller.loadingState.value is Loading
              ? const SizedBox.shrink()
              : _buildFav(theme, secondary),
        ),
      ],
    );
  }

  Widget _buildActions(Color primary) {
    return Row(
      mainAxisAlignment: .spaceEvenly,
      children: controller.list
          .map(
            (e) => Flexible(
              child: InkWell(
                onTap: e.onTap,
                borderRadius: Style.mdRadius,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 80),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Column(
                      spacing: 6,
                      mainAxisSize: .min,
                      mainAxisAlignment: .center,
                      children: [
                        Icon(e.icon, color: primary),
                        Text(
                          e.title,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget get _buildHeaderActions {
    const iconSize = 22.0;
    const padding = EdgeInsets.all(8);
    const style = ButtonStyle(tapTargetSize: .shrinkWrap);
    return PlayerBar(
      children: [
        if (widget.showBackBtn)
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: BackButton(),
          )
        else
          const SizedBox.shrink(),
        Row(
          spacing: 5,
          mainAxisSize: .min,
          children: [
            // 桌面端不再提供 /search 入口：壳层顶栏搜索框是唯一的搜索入口
            if (!_mainController.hasHome && !PlatformUtils.isDesktop) ...[
              IconButton(
                iconSize: iconSize,
                padding: padding,
                style: style,
                tooltip: '搜索',
                onPressed: () => Get.toNamed('/search'),
                icon: const Icon(Icons.search),
              ),
              msgBadge(_mainController),
            ],
            if (GStorage.reply != null)
              IconButton(
                iconSize: iconSize,
                padding: padding,
                style: style,
                tooltip: '评论记录',
                onPressed: () => Get.toNamed('/myReply'),
                icon: const Icon(Icons.message_outlined),
              ),
            Obx(
              () {
                final anonymity = MineController.anonymity.value;
                return IconButton(
                  iconSize: iconSize,
                  padding: padding,
                  style: style,
                  tooltip: "${anonymity ? '退出' : '进入'}无痕模式",
                  onPressed: MineController.onChangeAnonymity,
                  icon: anonymity
                      ? const Icon(MdiIcons.incognito)
                      : const Icon(MdiIcons.incognitoOff),
                );
              },
            ),
            IconButton(
              iconSize: iconSize,
              padding: padding,
              style: style,
              tooltip: '切换账号',
              onPressed: () => LoginPageController.switchAccountDialog(context),
              icon: const Icon(Icons.switch_account_outlined),
            ),
            Obx(
              () => IconButton(
                iconSize: iconSize,
                padding: padding,
                style: style,
                tooltip: '切换至${controller.nextThemeType.label}主题',
                onPressed: controller.onChangeTheme,
                icon: controller.themeType.value.icon,
              ),
            ),
            IconButton(
              iconSize: iconSize,
              padding: padding,
              style: style,
              tooltip: '设置',
              onPressed: () =>
                  Get.toNamed('/setting', preventDuplicates: false),
              icon: const Icon(Icons.settings_outlined),
            ),
            const SizedBox(width: 16),
          ],
        ),
      ],
    );
  }

  Widget _buildUserInfo(ThemeData theme, Color secondary) {
    final style = TextStyle(
      fontSize: theme.textTheme.titleMedium!.fontSize,
      fontWeight: FontWeight.bold,
    );
    final labelStyle = theme.textTheme.labelMedium!.copyWith(
      color: theme.colorScheme.outline,
    );
    final coinLabelStyle = TextStyle(
      fontSize: theme.textTheme.labelMedium!.fontSize,
      color: theme.colorScheme.outline,
    );
    final coinValStyle = TextStyle(
      fontSize: theme.textTheme.labelMedium!.fontSize,
      fontWeight: FontWeight.bold,
      color: secondary,
    );
    return Obx(() {
      final userInfo = controller.userInfo.value;
      final levelInfo = userInfo.levelInfo;
      final hasLevel = levelInfo != null;
      final isVip = userInfo.vipStatus != null && userInfo.vipStatus! > 0;
      final userStat = controller.userStat.value;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: .opaque,
            onTap: controller.onLogin,
            // 桌面端长按 = 无动作（切换账号仍由下方右键 onSecondaryTap 提供）
            onLongPress: PlatformUtils.isMobile
                ? () {
                    Feedback.forLongPress(context);
                    controller.onLogin(true);
                  }
                : null,
            onSecondaryTap: PlatformUtils.isMobile
                ? null
                : () => controller.onLogin(true),
            child: Row(
              mainAxisSize: .min,
              children: [
                const SizedBox(width: 20),
                userInfo.face != null
                    ? Stack(
                        clipBehavior: .none,
                        children: [
                          NetworkImgLayer(
                            src: userInfo.face,
                            type: .avatar,
                            width: 55,
                            height: 55,
                          ),
                          if (isVip)
                            Positioned(
                              right: -1,
                              bottom: -2,
                              child: SvgPicture.asset(
                                Assets.vipIcon,
                                height: 19,
                                semanticsLabel: "大会员",
                              ),
                            ),
                        ],
                      )
                    : ClipOval(
                        child: Image.asset(
                          width: 55,
                          height: 55,
                          cacheHeight: 55.cacheSize(context),
                          Assets.avatarPlaceHolder,
                          semanticLabel: "默认头像",
                        ),
                      ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: .min,
                    mainAxisAlignment: .center,
                    crossAxisAlignment: .start,
                    children: [
                      Row(
                        spacing: 6,
                        children: [
                          Flexible(
                            child: Text(
                              userInfo.uname ?? '点击登录',
                              style: theme.textTheme.titleMedium!.copyWith(
                                height: 1,
                                color: isVip && userInfo.vipType == 2
                                    ? theme.colorScheme.vipColor
                                    : null,
                              ),
                              maxLines: 1,
                              overflow: .ellipsis,
                            ),
                          ),
                          BiliUtils.levelPicture(
                            levelInfo?.currentLevel ?? 0,
                            isSeniorMember: userInfo.isSeniorMember == 1,
                            height: 10,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '硬币 ',
                              style: coinLabelStyle,
                            ),
                            TextSpan(
                              text: userInfo.money?.toString() ?? '-',
                              style: coinValStyle,
                            ),
                            TextSpan(
                              text: "      经验 ",
                              style: coinLabelStyle,
                            ),
                            TextSpan(
                              text: levelInfo?.currentExp?.toString() ?? '-',
                              style: coinValStyle,
                            ),
                            TextSpan(
                              text: "/${levelInfo?.nextExp ?? '-'}",
                              style: coinLabelStyle,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 225),
                        child: LinearProgressIndicator(
                          minHeight: 2.25,
                          value: hasLevel
                              ? levelInfo.currentExp! / levelInfo.nextExp!
                              : 0,
                          backgroundColor: theme.colorScheme.outline.withValues(
                            alpha: 0.4,
                          ),
                          valueColor: AlwaysStoppedAnimation<Color>(secondary),
                          stopIndicatorColor: Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: .spaceEvenly,
            children: [
              _btn(
                count: userStat.dynamicCount,
                countStyle: style,
                name: '动态',
                labelStyle: labelStyle,
                onTap: () => controller.push('memberDynamics'),
              ),
              _btn(
                count: userStat.following,
                countStyle: style,
                name: '关注',
                labelStyle: labelStyle,
                onTap: () => controller.push('follow'),
              ),
              _btn(
                count: userStat.follower,
                countStyle: style,
                name: '粉丝',
                labelStyle: labelStyle,
                onTap: () => controller.push('fan'),
              ),
            ],
          ),
        ],
      );
    });
  }

  Widget _btn({
    required int? count,
    required TextStyle countStyle,
    required String name,
    required TextStyle? labelStyle,
    required VoidCallback onTap,
  }) {
    return Flexible(
      child: InkWell(
        onTap: onTap,
        borderRadius: Style.mdRadius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 80),
          child: AspectRatio(
            aspectRatio: 1,
            child: Column(
              spacing: 4,
              mainAxisSize: .min,
              mainAxisAlignment: .center,
              children: [
                Text(
                  count?.toString() ?? '-',
                  style: countStyle,
                ),
                Text(
                  name,
                  style: labelStyle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _autoRefresh() => Timer(
    const Duration(milliseconds: 150),
    () => controller.onRefresh(isManual: false),
  );

  Widget _buildFav(ThemeData theme, Color secondary) {
    return Column(
      children: [
        Divider(
          height: 20,
          color: theme.dividerColor.withValues(alpha: 0.1),
        ),
        ListTile(
          onTap: () => Get.toNamed('/fav')?.whenComplete(_autoRefresh),
          dense: true,
          title: Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '我的收藏  ',
                    style: TextStyle(
                      fontSize: theme.textTheme.titleMedium!.fontSize,
                      fontWeight: .bold,
                    ),
                  ),
                  if (controller.favFolderCount != null)
                    TextSpan(
                      text: "${controller.favFolderCount}  ",
                      style: TextStyle(
                        fontSize: theme.textTheme.titleSmall!.fontSize,
                        color: secondary,
                      ),
                    ),
                  WidgetSpan(
                    child: Icon(
                      Icons.arrow_forward_ios,
                      size: 18,
                      color: secondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          trailing: IconButton(
            tooltip: '刷新',
            onPressed: controller.onRefresh,
            icon: const Icon(Icons.refresh, size: 20),
          ),
        ),
        _buildFavBody(theme, secondary, controller.loadingState.value),
      ],
    );
  }

  Widget _buildFavBody(
    ThemeData theme,
    Color secondary,
    LoadingState loadingState,
  ) {
    return switch (loadingState) {
      Loading() => const SizedBox.shrink(),
      Success(:final response) => Builder(
        builder: (context) {
          List<FavFolderInfo>? favFolderList = response.list;
          if (favFolderList == null || favFolderList.isEmpty) {
            return const SizedBox.shrink();
          }
          bool flag = (controller.favFolderCount ?? 0) > favFolderList.length;
          return SizedBox(
            height: 200,
            child: ListView.separated(
              controller: controller.scrollController,
              padding: const .only(left: 20, top: 10, right: 20),
              itemCount: response.list.length + (flag ? 1 : 0),
              itemBuilder: (context, index) {
                if (flag && index == favFolderList.length) {
                  return Padding(
                    padding: const .only(bottom: 35),
                    child: Center(
                      child: IconButton(
                        tooltip: '查看更多',
                        style: ButtonStyle(
                          padding: const WidgetStatePropertyAll(.zero),
                          backgroundColor: WidgetStatePropertyAll(
                            theme.colorScheme.secondaryContainer.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        onPressed: () =>
                            Get.toNamed('/fav')?.whenComplete(_autoRefresh),
                        icon: Icon(
                          Icons.arrow_forward_ios,
                          size: 18,
                          color: secondary,
                        ),
                      ),
                    ),
                  );
                } else {
                  return FavFolderItem(
                    heroTag: Utils.generateRandomString(8),
                    item: response.list[index],
                    onPop: _autoRefresh,
                  );
                }
              },
              scrollDirection: .horizontal,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
            ),
          );
        },
      ),
      Error(:final errMsg) => SizedBox(
        height: 160,
        child: Center(
          child: Text(
            errMsg ?? '',
            textAlign: .center,
          ),
        ),
      ),
    };
  }

  // ===========================================================
  // 桌面端：WinUI(Fluent) 风格排版
  // 结构：用户卡片 → 「快捷入口」分组（纯文字选项卡 + 就地展开区）
  // 度量：4px 栅格 / 页面边距 24 / 卡片内边距 16 / 行高 48（以上为取值口径，
  // 描边与圆角由 desktop_* 组件自身负责：本页用户卡片走 DesktopCard 的大卡片
  // 圆角，见 winui_section.dart 的 WinUi.radius，本文件不再重复声明圆角值）。
  // 说明：仅桌面端生效，移动端走 _buildMobileList（原实现）。
  // ===========================================================

  /// 快捷入口就地展开区的**最小**高度（4px 栅格 420）：展开的是真实页面组件，
  /// 需要给定高度（页面内部普遍是 Column/Expanded + 滚动视图）才能布局；
  /// 小窗口下用它兜底，避免视频区被压得过小。
  /// 实际高度 = 页面正文可用高度 − [_previewTopReserve]（见 [build] 的
  /// LayoutBuilder）⇒ 普通/最大化窗口都会用满剩余垂直空间，不再固定 420
  /// （DPI 清理移除应用内 1.25 缩放后，固定值只占窗口约一半，底部出现大片空白）。
  static const double _previewMinHeight = 420;

  /// 预览区**之外**的固定高度合计（预览上方各块 + 列表上/下内边距）。
  /// 每一项都取自对应组件自身的固定尺寸，与窗口大小无关（不做窗口级估算）：
  ///   [_desktopTopGap] 20（列表顶部内边距）
  /// + 用户卡片 100（DesktopCard 内边距 WinUi.pad 16×2 + 卡片内容 68：
  ///     昵称行 ≈23 + gap8 + 硬币/经验行 ≈21 + gap12 + 经验条 4）
  /// + WinUi.gap24 24（卡片 → 「快捷入口」分组）
  /// + 分组标题行 ≈22 + DesktopTokens.gap8 8
  /// + 快捷入口选项卡 44（WinUi.gap8×2 + 文字行 ≈22 + 指示器 4+2）
  /// + WinUi.gap16 16（选项卡 → 预览标题行）
  /// + 预览标题行 36（DesktopTopBar.searchHeight）+ WinUi.gap8 + 1px 分隔线
  ///   + WinUi.gap12 = 57
  /// + 列表底部内边距 WinUi.padPage 24
  /// = 315
  /// 若上方内容因异常字号/换行变得更高，整页照常可滚动，不会溢出或裁切；
  /// 用户卡片走紧凑变体（窄窗）时同理。
  static const double _previewTopReserve = 315;

  /// 选项卡选中指示线粗细（Fluent Tab 固定 2px，不属于 4px 间距栅格）
  static const double _tabIndicatorWidth = 2;

  /// 桌面端主体顶部间距（20 = 4px 栅格 5 格）。WinUi 上只有 4/8/12/16/24，
  /// 故就近定义；用于「我的」页主体（用户卡片）与上方区域之间：
  /// 顶部那排设置/功能入口已搬到侧栏（见 desktop_side_bar.dart 的
  /// `mineEntries`），主体不再为它留位，统一按 20 起排。
  static const double _desktopTopGap = 20;

  Widget _buildDesktopList(ThemeData theme, double viewportHeight) {
    final double sidePad = _sidePad(context);
    // 预览区高度：页面正文实际可用高度（LayoutBuilder 的约束）− 预览区之外的
    // 固定高度；下限 [_previewMinHeight] 保证小窗口下视频区不会过小。
    final double previewHeight = (viewportHeight - _previewTopReserve)
        .clamp(_previewMinHeight, double.infinity);
    return ListView(
      padding: EdgeInsets.only(
        left: sidePad + WinUi.padPage,
        right: sidePad + WinUi.padPage,
        top: _desktopTopGap,
        bottom: WinUi.padPage,
      ),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _winuiUserCard(theme),
        const SizedBox(height: WinUi.gap24),
        DesktopSection(
          title: '快捷入口',
          // 选项卡与展开区自带排版，故分组不再套一层卡片、也不插行间分隔线
          card: false,
          showDividers: false,
          children: [
            Obx(() {
              // 记住上次选项：主壳清空 preview 时回落到记忆字段（见 _desktopPreviewRoute）
              final previewRoute = _desktopPreviewRoute;
              final previewEntry = _entryOfRoute(previewRoute);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 与侧栏「快捷入口」同一份数据（DesktopSideBar.shortcuts）
                  // + 同一套点击逻辑（DesktopSideBar.openShortcut，见 _onSelectShortcut）
                  _winuiShortcutTabs(
                    theme,
                    DesktopSideBar.shortcuts,
                    previewRoute,
                  ),
                  // 就地展开：该入口对应的**真实页面组件的主体内容**
                  // （构造时 hideAppBar: true → 不嵌入页面顶栏 / 标题 / 返回按钮；
                  //  desktopEmbedded 保持默认 false → 内嵌实例不注册主壳的
                  //  desktopContentBackHandler，鼠标侧键在本页不会产生「返回上一层」）
                  if (previewEntry != null) ...[
                    const SizedBox(height: WinUi.gap16),
                    _winuiShortcutPreview(theme, previewEntry, previewHeight),
                  ],
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  /// 快捷入口选项卡点击（「我的」页内唯一入口；数据与侧栏「快捷入口」共用
  /// [DesktopSideBar.shortcuts]）：
  /// - 宿主已接入桌面主内容区（`widget.onSelectShortcut != null`）：
  ///   点击即**就地展开**该入口对应的真实页面主体内容（选中该选项卡，
  ///   在选项卡下方显示），不 push 路由、不在主内容区另开完整页面；
  ///   重复点击已选中的入口不做任何动作（既不收起、也不进入完整页面）；
  /// - 宿主未接入（移动端不渲染桌面分支；桌面端 `toMinePage` 的抽屉变体）
  ///   → 维持原有直接跳转行为。
  /// 侧栏「快捷入口」进入完整页面的行为不受影响（见 main.dart 的
  /// `_openDesktopShortcut`）。
  void _onSelectShortcut(DesktopNavEntry entry) {
    final onSelectShortcut = widget.onSelectShortcut;
    if (onSelectShortcut == null) {
      DesktopSideBar.openShortcut(entry, onSelectShortcut);
      return;
    }
    if (_mainController.desktopShortcutPreview.value == entry.route) {
      return;
    }
    // 记住本次选择：主壳为打开完整页而清空 preview 后，本页仍能回到这一项
    _mainController
      ..desktopShortcutLastRoute = entry.route
      ..desktopShortcutPreview.value = entry.route;
  }

  /// 按 route 取回入口实体（数据仍为唯一的 [DesktopSideBar.shortcuts]）
  DesktopNavEntry? _entryOfRoute(String? route) {
    if (route == null) {
      return null;
    }
    for (final entry in DesktopSideBar.shortcuts) {
      if (entry.route == route) {
        return entry;
      }
    }
    return null;
  }

  /// 快捷入口的横向**纯文字选项卡**（仅「我的」页；侧栏布局与行为不受影响）：
  /// 无图标 / 无卡片底色 / 无描边 / 无阴影，选中项用主题强调色 + 下方短横线
  /// （未选中为普通文字色），悬停与按压沿用 InkWell 的默认反馈。
  ///
  /// 窄窗口策略：条目宽度由文字决定、横向排列，超出可用宽度时**横向滚动**
  /// （不换行，避免选项卡折成两行，也不会横向溢出）。Flutter 的 Scrollable
  /// 只在自身轴向能被该事件滚动时才认领滚轮事件（水平轴取 scrollDelta.dx），
  /// 因此纵向滚轮仍然滚动整页，不会被这一行吞掉。
  Widget _winuiShortcutTabs(
    ThemeData theme,
    List<DesktopNavEntry> entries,
    String? selectedRoute,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final entry in entries)
            _winuiShortcutTab(
              theme,
              entry,
              selected: entry.route == selectedRoute,
            ),
        ],
      ),
    );
  }

  /// 单个选项卡：只有文字 + 与文字等宽的短横线指示器（选中 primary，
  /// 未选中同宽透明 → 切换选中态时文字与行高都不跳动）。
  Widget _winuiShortcutTab(
    ThemeData theme,
    DesktopNavEntry entry, {
    required bool selected,
  }) {
    final colorScheme = theme.colorScheme;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(WinUi.radius),
        onTap: () => _onSelectShortcut(entry),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: WinUi.gap12,
            vertical: WinUi.gap8,
          ),
          child: Container(
            padding: const EdgeInsets.only(bottom: WinUi.gap4),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: selected ? colorScheme.primary : Colors.transparent,
                  width: _tabIndicatorWidth,
                ),
              ),
            ),
            child: Text(
              entry.label,
              maxLines: 1,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: WinUi.fontSectionTitle,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 就地展开区：仅承载该入口**真实页面组件的主体内容**
  /// （构造时 `hideAppBar: true`：页面自己省略顶栏 / 标题 / 返回按钮）。
  ///
  /// 不再套外框 / 卡片（原先的 DesktopCard 圆角、描边、底色、阴影全部去掉），
  /// 预览内容直接融入「我的」页主体；层级为
  /// 「一级标题行（左标题 + 右搜索框）→ 1px 分隔线 → [_ShortcutPreview](
  /// SizedBox([previewHeight], 真实页面)）」—— 定高组件只套一层必要的
  /// SizedBox，展开动画的承载者仍是这个 SizedBox，与改动前一致。
  /// [previewHeight] 由 [build] 的 LayoutBuilder 依据**页面正文实际可用高度**
  /// 算出（下限 [_previewMinHeight]）：窗口越高预览区越高，用满剩余垂直空间。
  /// 左右边距沿用本页 ListView 的自然边距（`sidePad + WinUi.padPage`，
  /// 与「快捷入口」分组标题同一左缘），不居中、不受外框限制。
  /// 页面内部普遍是 Column/Expanded + 滚动视图，故必须有这份有限高度才能布局；
  /// 展开区内的滚动由页面自身承担，不产生嵌套整页滚动。
  Widget _winuiShortcutPreview(
    ThemeData theme,
    DesktopNavEntry entry,
    double previewHeight,
  ) {
    final request = _previewSearchRequest;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _winuiPreviewHeader(theme, entry),
        const SizedBox(height: WinUi.gap8),
        Divider(
          height: 1,
          thickness: 1,
          color: theme.colorScheme.outlineVariant.withValues(alpha: .45),
        ),
        const SizedBox(height: WinUi.gap12),
        _ShortcutPreview(
          route: entry.route,
          child: SizedBox(
            height: previewHeight,
            child: _winuiShortcutPage(
              entry.route,
              // 只把「发给本预览项」的请求传下去：切换入口后不会串用旧关键词
              request?.route == entry.route ? request : null,
            ),
          ),
        ),
      ],
    );
  }

  /// 预览区**一级标题行**：左侧为当前预览项的标题（与侧栏快捷入口同一份
  /// [DesktopSideBar.shortcuts] 的 label，左对齐、跟随页面自然左边距），
  /// 右侧为该预览内容**自己的**搜索框（见 [_winuiPreviewSearchBox]）。
  /// 标题取桌面字号阶「分组/卡片标题」16。
  Widget _winuiPreviewHeader(ThemeData theme, DesktopNavEntry entry) {
    final searchBox = _winuiPreviewSearchBox(entry.route);
    return Row(
      children: [
        Expanded(
          child: Text(
            entry.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: WinUi.fontSectionTitle,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (searchBox != null) ...[
          const SizedBox(width: WinUi.gap16),
          searchBox,
        ],
      ],
    );
  }

  /// 当前预览内容自己的搜索框（复用桌面端统一的 [DesktopSearchBox]，
  /// 样式与壳层顶栏 / 各页就地搜索框完全一致）。占位提示随预览项同步切换，
  /// 提交由 [_onPreviewSearch] 下发给该页自身的就地搜索实现。
  ///
  /// 只有历史记录 / 稍后再看 / 我的收藏三页具备搜索能力（各自既有的搜索
  /// 控制器与结果视图）；订阅 / 私信**没有**搜索功能，故这里返回 null、
  /// 不渲染搜索框（既不做禁用态伪装，也不伪造搜索）。
  Widget? _winuiPreviewSearchBox(String route) {
    final hintText = switch (route) {
      '/history' => '搜索历史记录',
      '/later' => '搜索稍后再看',
      '/fav' => '搜索收藏',
      _ => null,
    };
    if (hintText == null) {
      return null;
    }
    return DesktopSearchBox(
      // 每个预览项一个全新的搜索框：切换选项卡时输入内容不残留
      key: ValueKey(route),
      active: true,
      width: DesktopTopBar.searchWidth,
      height: DesktopTopBar.searchHeight,
      hintText: hintText,
      onSubmit: _onPreviewSearch,
    );
  }

  /// 预览区搜索框提交：只把请求下发给**当前预览的内容**（不做全局搜索），
  /// 由该页复用自身既有的就地搜索实现；本页不新增、不复制任何搜索逻辑。
  /// 空关键词 = 该页退出搜索、回到原有列表。
  void _onPreviewSearch(String value) {
    setState(() {
      _previewSearchRequest = DesktopInlineSearchRequest(
        route: _desktopPreviewRoute,
        keyword: value,
      );
    });
  }

  /// 快捷入口 route → 真实页面组件（与主壳 `_openDesktopContentPage` 的
  /// switch 一一对应）。差异有两点，均为**内嵌展开**所必需：
  /// - `hideAppBar: true`：省略页面 AppBar（标题 / 返回按钮 / 顶栏操作），
  ///   只嵌入主体内容；
  /// - `desktopEmbedded` 保持默认 false：内嵌实例不注册主壳的
  ///   `desktopContentBackHandler`，也不显示桌面嵌入返回箭头。
  ///
  /// [request] 为一级标题行搜索框下发给**本页**的一次性搜索请求（可选，
  /// 默认 null）：页面据此复用自身既有的就地搜索实现，移动端 / 路由方式不受影响。
  Widget _winuiShortcutPage(
    String route,
    DesktopInlineSearchRequest? request,
  ) {
    return switch (route) {
      '/history' => HistoryPage(hideAppBar: true, searchRequest: request),
      '/later' => LaterPage(hideAppBar: true, searchRequest: request),
      '/fav' => FavPage(hideAppBar: true, searchRequest: request),
      '/subscription' => const SubPage(hideAppBar: true),
      '/whisper' => const WhisperPage(hideAppBar: true),
      _ => const SizedBox.shrink(),
    };
  }

  /// 用户卡「宽窗」与「紧凑」的断点（4px 栅格 800）：`LayoutBuilder` 拿到的
  /// **卡内内容宽**（卡片宽度 - 卡片内边距 32）不大于该值时切换为紧凑变体。
  ///
  /// 依据（100% 缩放实测：窗口 ≤ 限宽时卡内内容宽 = 窗口 - 296；
  /// 窗口 > 限宽时被内容限宽钉住）：
  /// - 宽窗变体卡内固定占宽 = 头像 64 + gap16 16 + gap24 24 + 竖线 1
  ///   + 统计 3x84 = 357，再加中间信息列里固定宽的经验条 240 ⇒ 中间信息列宽
  ///   = 卡内内容宽 - 597；「硬币 x 经验 y/z」整行约需 215（最窄可读）
  ///   ⇒ 宽窗至少需要 597 + 203(4px 栅格) = 800；
  /// - 断点取 800（4px 栅格）本身不变：它是「这一行实际拿到的水平约束」下的
  ///   可读下限，与限宽数值无关；
  /// - 2026-10-05 桌面化第二轮：本页内容限宽由 1080 收敛为
  ///   [WinUi.contentWidth] = 1480 ⇒ 被限宽钉住时卡内内容宽 = 1480 - 48 - 32
  ///   = 1400（原 804），远大于断点 800，因此宽窗变体在所有被限宽的场景下
  ///   都命中；未被限宽时卡内内容宽 = 窗口 - 296，故紧凑变体只在
  ///   窗口 ≲ 1104（≈1100）时出现（实测 1325 及更宽均为宽窗变体）。
  static const double _userCardWideBreakpoint = 800;

  /// 宽窗下中间信息列的最小宽度（4px 栅格 240）：硬币/经验行最窄可读宽，
  /// 作为异常约束（如超大 textScale）下的兜底；断点 800 下实际不生效。
  static const double _userCardMidMinWidth = 240;

  /// 用户卡片：头像 + 昵称/等级 + 硬币·经验 + 经验条，右侧三列统计。
  /// 窄窗（卡内内容宽 ≤ [_userCardWideBreakpoint]）走紧凑变体
  /// [_winuiUserCardCompact]，宽窗与既有实现逐像素一致。
  /// 判据用 LayoutBuilder 的「卡内内容宽」（≈ 窗口宽 - 216 侧栏 - 48 页面边距
  /// - 32 卡片内边距）而不是窗口宽，因为它正是这一行实际拿到的水平约束。
  Widget _winuiUserCard(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    // 桌面字号阶：标签走「次要信息」13、数值走「行主标题」15
    final labelStyle = theme.textTheme.bodySmall!.copyWith(
      fontSize: WinUi.fontSecondary,
      color: colorScheme.onSurfaceVariant,
    );
    final valueStyle = theme.textTheme.bodyMedium!.copyWith(
      fontSize: WinUi.fontRowTitle,
      fontWeight: FontWeight.w600,
      color: colorScheme.secondary,
    );
    return Obx(() {
      final userInfo = controller.userInfo.value;
      final levelInfo = userInfo.levelInfo;
      final isVip = userInfo.vipStatus != null && userInfo.vipStatus! > 0;
      final userStat = controller.userStat.value;
      final stats = [
        _winuiStat(
          theme,
          '动态',
          userStat.dynamicCount,
          () => controller.push('memberDynamics'),
        ),
        _winuiStat(
          theme,
          '关注',
          userStat.following,
          () => controller.push('follow'),
        ),
        _winuiStat(
          theme,
          '粉丝',
          userStat.follower,
          () => controller.push('fan'),
        ),
      ];
      final userArea = _winuiUserArea(
        child: _winuiUserCardInfo(
          theme,
          uname: userInfo.uname,
          vipType: userInfo.vipType,
          isVip: isVip,
          currentLevel: levelInfo?.currentLevel ?? 0,
          isSeniorMember: userInfo.isSeniorMember == 1,
          money: userInfo.money,
          currentExp: levelInfo?.currentExp,
          nextExp: levelInfo?.nextExp,
          labelStyle: labelStyle,
          valueStyle: valueStyle,
        ),
      );
      return DesktopCard(
        padding: const EdgeInsets.all(WinUi.pad),
        child: LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth >
                  _userCardWideBreakpoint
              // 宽窗：与既有实现逐像素一致（头像 64 + gap16 + 中间信息列
              // + gap24 + 1px 竖线 + 3x84 统计）
              ? Row(
                  children: [
                    _winuiUserArea(
                      child: _winuiUserCardAvatar(userInfo.face, isVip),
                    ),
                    const SizedBox(width: WinUi.gap16),
                    Expanded(
                      // 兜底：极端窄窗下不把中间信息列压到不可读
                      // （卡内内容宽 > 800 时该约束不生效，不影响原排版）
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: _userCardMidMinWidth,
                        ),
                        child: userArea,
                      ),
                    ),
                    const SizedBox(width: WinUi.gap24),
                    Container(
                      width: 1,
                      height: 44,
                      color: colorScheme.outlineVariant.withValues(alpha: .5),
                    ),
                    ...stats,
                  ],
                )
              // 窄窗：信息行在上、统计整行在下（各自等分），中间信息列
              // 独占剩余宽（= 卡内内容宽 - 80），不再被固定宽兄弟挤成「每行一个字」
              : _winuiUserCardCompact(
                  userInfo.face,
                  isVip,
                  userArea,
                  stats,
                  colorScheme,
                ),
        ),
      );
    });
  }

  /// 窄窗紧凑变体（仅卡内内容宽 ≤ [_userCardWideBreakpoint] 时构建）：
  /// 头像与信息行在上、统计三列在下（等分整行），纵向仅多出「统计行
  /// + gap12 + 1px 分隔线」，卡片自然变高，不重叠、不溢出、不产生横向滚动。
  /// 头像 / 昵称+LV / 硬币·经验 / 经验条 / 统计数字与分隔线颜色、卡片圆角与
  /// 背景、卡片内边距全部沿用原实现，仅调整[信息列, 统计列]的相对位置。
  Widget _winuiUserCardCompact(
    String? face,
    bool isVip,
    Widget userArea,
    List<Widget> stats,
    ColorScheme colorScheme,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _winuiUserArea(child: _winuiUserCardAvatar(face, isVip)),
            const SizedBox(width: WinUi.gap16),
            // Expanded：中间信息列独占剩余宽，文本超宽时由
            // 昵称（已有 ellipsis）与硬币/经验行（已补 maxLines/ellipsis）截断
            Expanded(child: userArea),
          ],
        ),
        const SizedBox(height: WinUi.gap12),
        // 原 44 高竖线在紧凑变体里改为整行横线，颜色/透明度保持一致
        Divider(
          height: 1,
          thickness: 1,
          color: colorScheme.outlineVariant.withValues(alpha: .5),
        ),
        const SizedBox(height: WinUi.gap12),
        Row(
          children: [
            for (final stat in stats) Expanded(child: stat),
          ],
        ),
      ],
    );
  }

  /// 用户卡头像（VIP 角标沿用原实现：right -1 / bottom -2 / 高 20）
  Widget _winuiUserCardAvatar(String? face, bool isVip) {
    return face != null
        ? Stack(
            clipBehavior: Clip.none,
            children: [
              NetworkImgLayer(
                src: face,
                type: .avatar,
                width: 64,
                height: 64,
              ),
              if (isVip)
                Positioned(
                  right: -1,
                  bottom: -2,
                  child: SvgPicture.asset(
                    Assets.vipIcon,
                    height: 20,
                    semanticsLabel: '大会员',
                  ),
                ),
            ],
          )
        : ClipOval(
            child: Image.asset(
              width: 64,
              height: 64,
              cacheHeight: 64.cacheSize(context),
              Assets.avatarPlaceHolder,
              semanticLabel: '默认头像',
            ),
          );
  }

  /// 用户卡中间信息列：昵称 + LV / 硬币·经验 / 经验条（宽窗与紧凑变体共用，
  /// 度量与原实现一致：gap8、经验条宽 240 高 4、间距 gap12）
  Widget _winuiUserCardInfo(
    ThemeData theme, {
    required String? uname,
    required int? vipType,
    required bool isVip,
    required int currentLevel,
    required bool isSeniorMember,
    required double? money,
    required int? currentExp,
    required int? nextExp,
    required TextStyle labelStyle,
    required TextStyle valueStyle,
  }) {
    final colorScheme = theme.colorScheme;
    final double expValue = (currentExp != null && nextExp != null)
        ? currentExp / nextExp
        : 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          spacing: 6,
          children: [
            Flexible(
              child: Text(
                uname ?? '点击登录',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium!.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isVip && vipType == 2
                      ? theme.colorScheme.vipColor
                      : null,
                ),
              ),
            ),
            BiliUtils.levelPicture(
              currentLevel,
              isSeniorMember: isSeniorMember,
              height: 10,
            ),
          ],
        ),
        const SizedBox(height: WinUi.gap8),
        Text.rich(
          // 截断保护（与页面其它文本一致）：窄窗下不再逐字折成多行
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          TextSpan(
            children: [
              TextSpan(text: '硬币 ', style: labelStyle),
              TextSpan(text: money?.toString() ?? '-', style: valueStyle),
              TextSpan(text: '    经验 ', style: labelStyle),
              TextSpan(
                text: currentExp?.toString() ?? '-',
                style: valueStyle,
              ),
              TextSpan(text: '/${nextExp ?? '-'}', style: labelStyle),
            ],
          ),
        ),
        const SizedBox(height: WinUi.gap12),
        SizedBox(
          width: 240,
          child: ClipRRect(
            borderRadius: const BorderRadius.all(
              Radius.circular(2),
            ),
            child: LinearProgressIndicator(
              minHeight: 4,
              value: expValue,
              backgroundColor: colorScheme.outlineVariant,
              valueColor: AlwaysStoppedAnimation<Color>(
                colorScheme.secondary,
              ),
              stopIndicatorColor: Colors.transparent,
            ),
          ),
        ),
      ],
    );
  }

  /// 用户卡片的可点击区域（行为与原实现一致：点击/长按/右键 → 登录页或空间页）。
  Widget _winuiUserArea({required Widget child}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: controller.onLogin,
      // 桌面端长按 = 无动作（切换账号仍由下方右键 onSecondaryTap 提供）
      onLongPress: PlatformUtils.isMobile
          ? () {
              Feedback.forLongPress(context);
              controller.onLogin(true);
            }
          : null,
      onSecondaryTap: () => controller.onLogin(true),
      child: child,
    );
  }

  /// 统计列：等宽、垂直居中，与左右各列共用 1px 竖分隔线。
  Widget _winuiStat(
    ThemeData theme,
    String label,
    int? count,
    VoidCallback onTap,
  ) {
    return SizedBox(
      width: 84,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(WinUi.radius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: WinUi.gap8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  count?.toString() ?? '-',
                  style: theme.textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: WinUi.gap4),
                Text(
                  label,
                  style: theme.textTheme.bodySmall!.copyWith(
                    fontSize: WinUi.fontSecondary,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 「我的」页快捷入口就地展开的过渡容器（仅桌面端构建）：
/// 与主壳内容区（_DesktopContentArea）**同一套**轻量动画 ——
/// FadeTransition（opacity 0 → 1）+ 自下方 6px 上移入位、180ms、
/// Curves.easeOutCubic、**无 Scale**；选项卡与左侧栏不在本容器内，因此不参与动画。
class _ShortcutPreview extends StatefulWidget {
  const _ShortcutPreview({required this.route, required this.child});

  /// 当前就地展开的入口 route（仅用于识别「展开对象是否切换」）
  final String route;

  final Widget child;

  @override
  State<_ShortcutPreview> createState() => _ShortcutPreviewState();
}

class _ShortcutPreviewState extends State<_ShortcutPreview>
    with SingleTickerProviderStateMixin {
  /// 过渡时长 ≈180ms，曲线 Curves.easeOutCubic
  static const Duration _duration = Duration(milliseconds: 180);

  /// 入场位移：+6px → 0px（用像素位移做到精确 6px）
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
  void initState() {
    super.initState();
    // 预览首次出现时同样播一次入场动画（切换入口时由 didUpdateWidget 重播）
    _controller.forward(from: 0.0);
  }

  @override
  void didUpdateWidget(covariant _ShortcutPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 只在预览对象发生切换时重播一次；同一入口的普通重建不重播
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

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _enter,
      child: AnimatedBuilder(
        animation: _enter,
        child: widget.child,
        builder: (context, child) => Transform.translate(
          offset: Offset(0.0, _offsetY * (1.0 - _enter.value)),
          child: child,
        ),
      ),
    );
  }
}
