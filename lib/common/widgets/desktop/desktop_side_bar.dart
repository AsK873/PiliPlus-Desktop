// =============================================================
// PiliPlus Windows PC 化 · M2 主壳导航（UI 呈现层，2026-09-05）
// 桌面专用扩展侧栏（图标+文字）：
//   - 主入口：首页 / 动态 / 我的（顺序、显隐仍尊重用户 navBarSort）
//   - 快捷区：历史/稍后再看/收藏/订阅/消息（搜索改由顶栏搜索框就地展开）
//   - 2026-10-03：快捷区下方（设置上方）新增「深色模式 / 浅色模式」快捷切换，
//     图标与悬停提示随当前模式变化；点击写入同一 Pref.themeType，与设置页「主题模式」同源。
//   - 2026-10-04：导航行的构建抽出为公开的 [DesktopNavTile]（本文件内 private 的 _tile
//     改为直接转发它），侧栏与「我的」页快捷入口共用同一实现 → 鼠标手势/悬停/按压/
//     圆角/cursor/Tooltip 天然一致；侧栏本体的外观与行为逐像素不变。
//   - 2026-10-04：Windows 100% 缩放下文字/图标偏小，侧栏文字与图标整体等比放大：
//     主文字 14→15.5、分组头 12→13、账号区 14/12→15.5/13、导航图标 20→22、
//     账号图标 20→22；图标 +2 由 tilePad.vertical 5→4 相抵，行节距仍为 32
//     （守 960x640 上限，侧栏整体布局不变）；宽度 216、tileRadius 8 未变。
//   - 2026-10-04：侧栏入口精简为「主导航 / 内容功能 / 私信 / 底部两项」+ 个人区，
//     不显示分组标题、层级只由组间距表达；移除侧栏内的「无痕模式 / 切换账号 /
//     主题 / 评论记录」四个入口（这些功能本身未删除，仍由设置页、移动端顶栏等原有
//     入口提供，`/myReply` 等路由保留）。两档固定尺寸：
//     普通窗口 行高 32 / 图标 22 / 文字 15.5 / 组内 0 / 组间 20；
//     最大化窗口 行高 38 / 图标 25 / 文字 17 / 组内 2 / 组间 22 —— 只放大菜单项
//     本身，不靠加大项目间距撑高度；剩余高度作为「弹性剩余空间」只留在「私信」
//     与底部两项之间，底部两项（深色/浅色模式切换、设置）同段同间距，
//     设置与个人区固定 5px，个人区始终位于最底部。
//     点击逻辑 / 路由 / 侧栏宽度 216 / 圆角 / 移动端均未改动。
//   - 底部：账号入口（未登录=登录）
// 行为全部复用现有 MainController.setIndex / Get.toNamed / 未读角标逻辑，
// 不含任何业务/数据改动；移动/平板分支不受影响（桌面端只要 PlatformUtils.isDesktop
// 为真就启用本侧栏，没有宽度阈值——窄窗同样用图标+文字侧栏，不再回退移动布局）。
// 2026-10-01 曾把宽度收紧到 180（行距/内边距/图标同步收小）；该次收紧已于
// 2026-10-03 回退，现行宽度见 [_Dimens.width] = 216，全部度量集中在 [_Dimens]，
// 仅影响本侧栏，不触碰其它 UI。
// 2026-10-03 桌面 UI 正式迁移到 uiScale = 1.00（第一批，四项）：
//   1) 宽度 180→216（[_Dimens.width] 单点，[DesktopSideBar.width] 复用同一常量）；
//   2) 字号/图标回到 1.00 正式尺寸：图标 18→20、主文字 12.5→14、
//      分组头 10.5→12、账号区 12.5/10.5→14/12、账号图标 18→20；
//   3) 导航行节距 30→32 由「tileMargin 1 + tilePad.vertical 5 + icon 20 +
//      tilePad.vertical 5 + tileMargin 1」自然得出（tilePad 保持 5，不为凑高度加 padding）；
//   4) 侧栏导航列表改用覆盖式滚动条（[OverlayScrollbarBehavior]，不再预留 10px 车道）：
//      修复「药丸实际宽 = 侧栏宽 − 16 − 10」的错误缩进，药丸宽 = 侧栏宽 − 16
//      （216 − 16 = 200），左右内边距 8/8 对称。滚动条本体与滚动行为不变。
// 层级结构、hover/selected/点击逻辑、快捷入口结构、底部主题/设置功能均未改动。
// =============================================================
import 'package:PiliPlus/common/assets.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/scroll_behavior.dart'
    show OverlayScrollbarBehavior;
import 'package:PiliPlus/models/common/dynamic/dynamic_badge_mode.dart';
import 'package:PiliPlus/models/common/image_type.dart';
import 'package:PiliPlus/models/common/nav_bar_config.dart';
import 'package:PiliPlus/models/common/theme/theme_type.dart';
import 'package:PiliPlus/pages/login/controller.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/pages/mine/controller.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/theme_utils.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:window_manager/window_manager.dart';

/// 侧栏度量（uiScale = 1.00 下的正式尺寸）。
/// 注意：本组数值**不全是 4px 栅格成员**（含 6 / 5 / 10 / 1 等），
/// 历史上「4px 栅格」的表述与实际取值并不一致，以本类取值为准。
abstract final class _Dimens {
  /// 侧栏宽度（uiScale = 1.00：216；历史：216 → 180 → 216，现行值 216）
  static const double width = 216;

  /// 侧栏左右内边距基准
  static const double pad = 8;

  /// 品牌区
  static const double logo = 20;
  static const EdgeInsets brandPad = EdgeInsets.fromLTRB(12, 10, 8, 8);
  static const double brandGap = 8;
  static const double brandFont = 14;

  /// 主入口 / 快捷入口列表
  static const double navPadV = 6;

  /// 组间距：侧栏不显示分组标题，层级只由间距表达（普通窗口 20 / 最大化 22）
  static const double groupGap = 20;
  /// 分组分隔线块的固定高度：上下内边距各 6 + 1px 线（参与弹性空间计算）
  static const double sectionDividerHeight = 13;
  /// 分隔线 / 分组头的上下内边距（沿用原有取值）
  static const double shortcutHeaderGap = 6;

  /// 导航行外边距（单边值）；行高 = [tileMarginV]×2 + [tilePadV]×2 + [icon]
  static const double tileMarginV = 1;
  static const EdgeInsets tileMargin = EdgeInsets.symmetric(
    horizontal: pad,
    vertical: tileMarginV,
  );

  /// 导航行内边距（单边值；普通窗口档 8 / 4，最大化档见 [_ItemMetrics.maximized]）
  static const double tilePadH = 8;
  static const double tilePadV = 4;

  /// 导航行（药丸）圆角（8）：与桌面小控件档（列表行 / 按钮 / 输入控件）一致，
  /// 第三批由 6 收敛而来；侧栏自身的间距/内边距不是 4px 栅格成员。
  static const double tileRadius = 8;

  /// 普通窗口档行高 = tileMarginV 1×2 + tilePadV 4×2 + icon 22 = 32；
  /// 最大化档（行高 38 / 图标 25 / 文字 17）见 [_ItemMetrics.maximized] ——
  /// 两档都只放大菜单项本身，不靠加大项目间距撑高度。
  static const double icon = 22;
  static const double iconGap = 10;
  static const double labelFont = 15.5;

  /// 底部账号区（个人区）。top 由 8 收为 4：导航列表底部不加内边距，
  /// 与个人区上方的 1px 分隔线合计 = 设置与「我的主页」之间 5px。
  static const EdgeInsets accountPad = EdgeInsets.fromLTRB(10, 4, 10, 10);
  static const double avatar = 30;
  static const double accountGap = 8;
  static const double accountFont = 15.5;
  static const double accountSubFont = 13;
  static const double accountIcon = 22;
}

/// 桌面导航实体（与主壳数据同源，仅 UI 组装）。
class DesktopNavEntry {
  const DesktopNavEntry(this.label, this.route, {this.icon, this.selectedIcon});
  final String label;
  final String route;
  final IconData? icon;
  final IconData? selectedIcon;
}

/// 桌面导航行（**单一实现**：侧栏主入口 / 快捷入口 / 深色模式切换 与
/// 「我的」页快捷入口全部走这里）。
///
/// 由侧栏原有的 private `_tile` 原样抽出，度量取自本文件的 [_Dimens]：
/// `Padding(8,1)` → `Material`（选中底色 secondaryContainer@0.55 / 否则透明）
/// → `InkWell`（圆角 8 = [_Dimens.tileRadius]，自带悬停提亮、按压 highlight 与默认水波纹）
/// → `Padding(8,4)` → `[图标 22] — 10 — [文字 15.5]`（度量由 [_NavItemStyle] 给出：
/// 普通窗口 = [_ItemMetrics.compact]，最大化 = [_ItemMetrics.maximized]，
/// 只放大图标 / 文字 / item 内部尺寸，行与行之间不加空隙）。
/// 未显式设置 cursor，沿用 InkWell/InkResponse 在 onTap 非空时的
/// 手型指针（SystemMouseCursors.click）——与侧栏改动前完全一致。
///
/// [trailing] 为行尾控件：侧栏不使用（传 null 时 Row 子项与抽取前逐像素相同，
/// 不产生任何额外间距）；「我的」页用它保留原有的行尾箭头。
class DesktopNavTile extends StatelessWidget {
  const DesktopNavTile({
    super.key,
    required this.colorScheme,
    required this.selected,
    required this.onTap,
    required this.leading,
    required this.label,
    this.trailing,
    this.tooltip,
  });

  final ColorScheme colorScheme;

  /// 选中态：secondaryContainer@0.55 底色 + onSecondaryContainer 文字，w600
  final bool selected;

  final VoidCallback onTap;

  /// 行首控件（统一为 20px / 选中 onSecondaryContainer、否则 onSurfaceVariant）
  final Widget leading;

  final String label;

  /// 行尾控件（可选；为空时不占位、不加间距）
  final Widget? trailing;

  /// 悬停提示（可选；为空时不包 Tooltip）
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    // 菜单项度量：普通窗口 = 紧凑档（行高 32 / 图标 22 / 文字 15.5），
    // 最大化 = 放大档（行高 38 / 图标 25 / 文字 17）；两档都只放大 item 本身，
    // 行与行之间不加空隙 ⇒ 排列密度一致、每项仍是紧凑的视觉单元。
    final metrics = _NavItemStyle.of(context);
    final radius = BorderRadius.circular(metrics.radius);
    final tilePad = EdgeInsets.symmetric(
      horizontal: metrics.padH,
      vertical: metrics.padV,
    );
    final Widget tile = Padding(
      padding: _Dimens.tileMargin,
      child: Material(
        color: selected
            ? colorScheme.secondaryContainer.withValues(alpha: 0.55)
            : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: tilePad,
            child: Row(
              children: [
                IconTheme(
                  data: IconThemeData(
                    color: selected
                        ? colorScheme.onSecondaryContainer
                        : colorScheme.onSurfaceVariant,
                    size: metrics.icon,
                  ),
                  child: leading,
                ),
                SizedBox(width: metrics.iconGap),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: metrics.font,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected
                          ? colorScheme.onSecondaryContainer
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  SizedBox(width: metrics.iconGap),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
    // 未传提示时不包 Tooltip（与抽取前一致：只有深色模式切换带提示）
    if (tooltip == null) return tile;
    return Tooltip(message: tooltip, child: tile);
  }
}

class DesktopSideBar extends StatelessWidget {
  const DesktopSideBar({
    super.key,
    required this.mainController,
    required this.colorScheme,
    required this.onSelect,
    this.onSelectShortcut,
    this.onSelectMsg,
  });

  final MainController mainController;
  final ColorScheme colorScheme;
  final ValueChanged<int> onSelect;

  /// 快捷入口回调：宿主在桌面主内容区就地显示后返回 true（不走路由）；
  /// 返回 false / 未提供时，回退为原有 `Get.toNamed(entry.route)` 行为。
  final bool Function(DesktopNavEntry entry)? onSelectShortcut;

  /// 账号区「消息」铃铛回调：宿主可改为「就地滑出面板」而不跳完整页面。
  /// 未提供时保持原有 `Get.toNamed('/whisper')` 行为（移动端等不受影响）。
  final VoidCallback? onSelectMsg;

  static const double width = _Dimens.width;

  @override
  Widget build(BuildContext context) {
    // 依赖 Theme：深浅色切换（[_themeToggleItem]）后本侧栏随之重建，
    // 图标/文字/悬停提示与当前模式保持同步。
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 品牌区
          _brand(),
          const Divider(height: 1),
          // 主入口
          // 覆盖式滚动条：全局 CustomScrollBehavior 会为滚动条预留右侧 10px
          // 「车道」，导航行（药丸）可用宽因此比分隔线窄 10px（左右内边距
          // 8/18 不对称）。这里只对侧栏导航列表改用 OverlayScrollbarBehavior：
          // 滚动条仍常显、仍画在右缘 8px 外边距内，只是不再让视口内缩
          // ⇒ 药丸宽 = 侧栏宽 − 16（216 − 16 = 200），左右对称。
          // 作用域 = 本 Expanded（侧栏里唯一的滚动视口），其它页面不受影响。
          Expanded(
            // 导航视口高度（Expanded 内即已定界）：用它把「弹性剩余空间」
            // 精确留在「私信」与「深色/浅色模式切换」之间，使末两项
            // （深色/浅色模式切换、设置）贴近侧栏底部（约束驱动，不写死像素）。
            child: LayoutBuilder(
              builder: (context, constraints) => _MaximizeAware(
                builder: (context, maximized) => ScrollConfiguration(
                  behavior: const OverlayScrollbarBehavior(),
                  child: _primaryNav(
                    context: context,
                    isDark: isDark,
                    viewportHeight: constraints.maxHeight,
                    maximized: maximized,
                  ),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          // 底部账号区
          _accountArea(context),
        ],
      ),
    );
  }

  Widget _brand() {
    return Padding(
      padding: _Dimens.brandPad,
      child: Row(
        children: [
          Image.asset(
            Assets.logo,
            width: _Dimens.logo,
            height: _Dimens.logo,
            errorBuilder: (context, error, stack) => Icon(
              Icons.play_circle_fill,
              size: _Dimens.logo,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: _Dimens.brandGap),
          Text(
            'PiliPlus',
            style: TextStyle(
              fontSize: _Dimens.brandFont,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  /// 侧栏入口按「主导航 / 内容功能（历史记录…订阅、私信）/ 分隔线＋我的页功能入口
  /// （评论记录、进入无痕模式、切换账号）/ 底部两项」四段排列，
  /// **不显示分组标题**，层级只由组间距表达；个人区（我的主页 / 查看资料与空间）
  /// 始终在最底部。底部两项依次为「深色/浅色模式切换」「设置」——两者同属一段，
  /// 间距就是普通项目间距（[_ItemMetrics.intraGap]：普通 0 / 最大化 2），
  /// 不额外拉大间距。
  ///
  /// 普通窗口 = [_ItemMetrics.compact]（行高 32 / 图标 22 / 文字 15.5 / 组内 0 / 组间 20）；
  /// 最大化窗口 = [_ItemMetrics.maximized]（行高 38 / 图标 25 / 文字 17 / 组内 2 / 组间 22）。
  /// 两档**都只放大菜单项本身**：剩余高度不摊到菜单项之间，只作为「弹性剩余空间」
  /// 留在「私信」与底部两项之间 ⇒ 底部两项贴近侧栏底部、不出现项目之间的空隙。
  Widget _primaryNav({
    required BuildContext context,
    required bool isDark,
    required double viewportHeight,
    required bool maximized,
  }) {
    return Obx(() {
      final selected = mainController.selectedIndex.value;
      // 桌面内容页（如历史记录）展开时，选中态归内容页入口，主 Tab 不显示选中
      final hasContentPage = mainController.desktopContentRoute.value != null;

      // ① 主导航（每行的 icon / label / 点击 / 选中逻辑与改动前逐字一致）
      final mainRows = <Widget>[
        for (var i = 0; i < mainController.navigationBars.length; i++)
          _navItem(
            icon: mainController.navigationBars[i].icon,
            selectedIcon: mainController.navigationBars[i].selectIcon,
            label: mainController.navigationBars[i].label,
            selected: !hasContentPage && i == selected,
            showDynamicBadge:
                mainController.navigationBars[i] == NavigationBarType.dynamics,
            onTap: () => onSelect(i),
          ),
      ];
      // ② 内容功能（沿用 _shortcutItem → openShortcut 的点击逻辑）
      //    私信与订阅同组：直接使用 shortcuts 源顺序（…订阅、私信），
      //    两者之间只有同组项目间距，不再有分隔/组间间距。
      final contentRows = <Widget>[
        for (final entry in shortcuts) _shortcutItem(entry),
      ];
      // ③ 分隔线之下的「我的」页功能入口：评论记录 / 进入无痕模式 / 切换账号
      //    （图标、文字、点击行为均沿用项目原有实现）
      final mineRows = <Widget>[
        for (final entry in mineEntries) _entryItem(entry),
        Obx(
          () => _tile(
            selected: false,
            onTap: MineController.onChangeAnonymity,
            leading: Icon(
              MineController.anonymity.value
                  ? MdiIcons.incognito
                  : MdiIcons.incognitoOff,
            ),
            label: '${MineController.anonymity.value ? '退出' : '进入'}无痕模式',
          ),
        ),
        _tile(
          selected: false,
          onTap: () => LoginPageController.switchAccountDialog(context),
          leading: const Icon(Icons.switch_account_outlined),
          label: '切换账号',
        ),
      ];
      // ④ 底部两项：深色/浅色模式切换（紧贴设置上方，同段同间距）+ 设置
      final systemRows = <Widget>[
        _themeToggleItem(isDark),
        _shortcutItem(_setting),
      ];

      final metrics = _navMetrics(
        viewportHeight: viewportHeight,
        maximized: maximized,
        groupSizes: [
          mainRows.length,
          contentRows.length,
          mineRows.length,
          systemRows.length,
        ],
      );

      // 覆盖式滚动条：见 build() 里 ScrollConfiguration(OverlayScrollbarBehavior)
      // 的说明 —— 本列表不得让全局 10px 滚动条车道缩窄行宽。
      // 底部不留内边距：设置与个人区之间的间距在 build() 侧统一为 5px。
      // [_NavItemStyle] 只作用于本列表内的行，个人区 / 品牌区不受影响。
      return _NavItemStyle(
        metrics: metrics.metrics,
        child: ListView(
          padding: const EdgeInsets.only(top: _Dimens.navPadV),
          children: [
            ..._withIntraGap(mainRows, metrics.metrics.intraGap),
            SizedBox(height: metrics.metrics.groupGap),
            ..._withIntraGap(contentRows, metrics.metrics.intraGap),
            // 分隔线：区分「订阅 / 私信」所在的内容功能组与其下的「我的」页功能入口
            const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: _Dimens.shortcutHeaderGap,
              ),
              child: Divider(height: 1),
            ),
            ..._withIntraGap(mineRows, metrics.metrics.intraGap),
            // 弹性剩余空间：吸收「切换账号」与底部两项之间的余量（不摊到菜单项之间）
            SizedBox(height: metrics.elastic),
            ..._withIntraGap(systemRows, metrics.metrics.intraGap),
          ],
        ),
      );
    });
  }

  /// 同组内相邻两项之间插入固定间距（普通窗口 0、最大化 2）：
  /// 只表达「同组项目间距」，不用于撑满高度。
  static List<Widget> _withIntraGap(List<Widget> rows, double gap) => gap <= 0
      ? rows
      : [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) SizedBox(height: gap),
            rows[i],
          ],
        ];

  /// 菜单项度量 + 弹性剩余空间。
  ///
  /// 两档度量都是固定值（不随窗口高度无级缩放）：普通窗口 [_ItemMetrics.compact]、
  /// 最大化 [_ItemMetrics.maximized]。[elastic] = 视口高度 −（行高合计 + 组内间距 +
  /// 组间距 + 列表顶部内边距），只留在「私信」与「设置」之间；内容放不下时为 0
  /// （列表照常可滚动）。
  static _NavMetrics _navMetrics({
    required double viewportHeight,
    required bool maximized,
    required List<int> groupSizes,
  }) {
    final metrics = maximized ? _ItemMetrics.maximized : _ItemMetrics.compact;
    final rows = groupSizes.fold(0, (sum, n) => sum + n);
    // 同组内相邻项之间的间距：每组 n 项有 n−1 处
    final intraGaps =
        groupSizes.fold(0, (sum, n) => sum + (n > 1 ? n - 1 : 0));
    final used = _Dimens.navPadV +
        rows * metrics.rowHeight +
        intraGaps * metrics.intraGap +
        2 * metrics.groupGap + // 主导航↔内容功能 的固定组间距（底部由弹性空间分隔）
        _Dimens.sectionDividerHeight; // 分隔线块（私信 → 评论记录 之间）
    final elastic = viewportHeight - used;
    return _NavMetrics(metrics: metrics, elastic: elastic > 0 ? elastic : 0);
  }

  /// 快捷入口（单一数据源：侧栏与「我的」页共用同一份 label / route / icon）
  static final List<DesktopNavEntry> shortcuts = [
    const DesktopNavEntry('历史记录', '/history', icon: Icons.history_outlined),
    const DesktopNavEntry('稍后再看', '/later', icon: Icons.schedule_outlined),
    const DesktopNavEntry('我的收藏', '/fav', icon: Icons.star_border_outlined),
    const DesktopNavEntry('订阅', '/subscription', icon: Icons.subscriptions_outlined),
    const DesktopNavEntry('私信', '/whisper', icon: Icons.chat_bubble_outline),
  ];

  /// 分隔线之下的「我的」页功能入口（静态项）：评论记录。
  /// 点击逻辑沿用项目原有实现（`Get.toNamed(entry.route)`）。
  static final List<DesktopNavEntry> mineEntries = [
    const DesktopNavEntry('评论记录', '/myReply', icon: Icons.message_outlined),
  ];

  /// 内容功能组（侧栏分组）= [shortcuts] 全量（历史记录 / 稍后再看 / 我的收藏 /
  /// 订阅 / 私信）；私信与订阅同组、紧接其下。只做侧栏呈现层的分组，
  /// [shortcuts] 本身（「我的」页快捷入口共用）未做任何改动。

  /// 快捷入口共用的点击逻辑（侧栏与「我的」页同一套）：
  /// 先交给宿主在桌面主内容区就地显示（返回 true 表示已处理，不走路由）；
  /// 未处理 / 未接入时回退为原有 `Get.toNamed(entry.route)`，行为不变。
  static bool openShortcut(
    DesktopNavEntry entry,
    bool Function(DesktopNavEntry entry)? onSelectShortcut,
  ) {
    if (onSelectShortcut?.call(entry) ?? false) {
      return true;
    }
    Get.toNamed(entry.route);
    return false;
  }

  /// 深色模式快捷切换：浅色模式显示月亮（→深色），深色模式显示太阳（→浅色）。
  /// 与「设置」同属底部一段、紧贴其上方，间距即普通项目间距（不额外拉开）。
  Widget _themeToggleItem(bool isDark) {
    return _tile(
      selected: false,
      onTap: () => _toggleThemeMode(isDark),
      leading: Icon(
        isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
      ),
      label: isDark ? '浅色模式' : '深色模式',
      tooltip: isDark ? '切换至浅色模式' : '切换至深色模式',
    );
  }

  /// 写入与设置页「主题模式」相同的 Pref，立即生效（无需重启）
  void _toggleThemeMode(bool isDark) {
    final next = isDark ? ThemeType.light : ThemeType.dark;
    try {
      Get.find<MineController>().themeType.value = next;
    } catch (_) {}
    GStorage.setting.put(SettingBoxKey.themeMode, next.index);
    Get.changeThemeMode(ThemeUtils.themeMode = next.toThemeMode);
  }

  /// 设置：底部两项中的最后一项（点击逻辑仍走快捷入口那套 → `/setting`）
  static const DesktopNavEntry _setting = DesktopNavEntry(
    '设置',
    '/setting',
    icon: Icons.settings_outlined,
  );

  /// 「我的」页功能入口的静态行（见 [mineEntries]）：点击逻辑沿用原有实现
  /// （`Get.toNamed(entry.route)`，不走快捷入口的 openShortcut）。
  Widget _entryItem(DesktopNavEntry entry) {
    return _tile(
      selected: false,
      onTap: () => Get.toNamed(entry.route),
      leading: Icon(entry.icon ?? Icons.chevron_right),
      label: entry.label,
    );
  }

  Widget _navItem({
    required Icon icon,
    required Icon selectedIcon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool showDynamicBadge = false,
  }) {
    return _tile(
      selected: selected,
      onTap: onTap,
      leading: showDynamicBadge
          ? Obx(() {
              final count = mainController.dynCount.value;
              final show = count > 0 &&
                  mainController.dynamicBadgeMode != DynamicBadgeMode.hidden;
              return Badge(
                isLabelVisible: show,
                label: Text(count > 99 ? '99+' : '$count'),
                child: selected ? selectedIcon : icon,
              );
            })
          : (selected ? selectedIcon : icon),
      label: label,
    );
  }

  Widget _shortcutItem(DesktopNavEntry entry) {
    return _tile(
      // 该入口正在主内容区就地显示时，侧栏定位到它（与主 Tab 选中态互斥）
      selected: mainController.desktopContentRoute.value == entry.route,
      onTap: () {
        // 与「我的」页快捷入口共用同一套点击逻辑
        openShortcut(entry, onSelectShortcut);
      },
      leading: Icon(entry.icon ?? Icons.chevron_right),
      label: entry.label,
    );
  }

  /// 行构建统一走 [DesktopNavTile]（抽取前这里是该控件的实现本体，
  /// 抽取后仅为转发，调用点与外观/行为均不变）。
  Widget _tile({
    required bool selected,
    required VoidCallback onTap,
    required Widget leading,
    required String label,
    String? tooltip,
  }) {
    return DesktopNavTile(
      colorScheme: colorScheme,
      selected: selected,
      onTap: onTap,
      leading: leading,
      label: label,
      tooltip: tooltip,
    );
  }

  /// 底部账号区「我的主页」入口（本侧栏仅桌面端构建，移动端没有该入口）：
  /// 与侧栏主导航里的「我的」走**完全同一条**既有路径 —— [onSelect]
  /// （壳层 `closeDesktopContentPage()` + `MainController.setIndex(...)`），
  /// 不再走 `MainController.toMinePage`（它在本页不是主 Tab 时 `Get.to(MinePage)`），
  /// 因此**不 push 任何路由**，也不写 `desktopShortcutPreview` /
  /// `desktopShortcutLastRoute` —— 「我的」页记住的上一次预览选项原样保留。
  ///
  /// 索引按用户自定义后的实际导航栏顺序取（`navigationBars.indexOf`），
  /// 不硬编码数字（用户可能改过排序，也可能把「我的」隐藏掉）。
  /// 兜底：找不到「我的」时导航栏里没有可切换的目标，桌面端也不为此新开页面
  /// （保持「不 push 路由」），就地提示一句，不改动任何导航状态。
  void _toMineTab(BuildContext context) {
    final index = mainController.navigationBars.indexOf(NavigationBarType.mine);
    if (index >= 0) {
      onSelect(index);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('导航栏中未显示「我的」，可在「设置 · Navbar编辑」中恢复')),
    );
  }

  Widget _accountArea(BuildContext context) {
    return Obx(() {
      final accountService = mainController.accountService;
      final isLogin = accountService.isLogin.value;
      final unread = mainController.msgUnReadCount.value;
      return Padding(
        padding: _Dimens.accountPad,
        child: Row(
          children: [
            if (isLogin)
              ClipOval(
                child: NetworkImgLayer(
                  type: ImageType.avatar,
                  width: _Dimens.avatar,
                  height: _Dimens.avatar,
                  src: accountService.face.value,
                ),
              )
            else
              CircleAvatar(
                radius: _Dimens.avatar / 2,
                backgroundColor: colorScheme.onInverseSurface,
                child: Icon(
                  Icons.person_rounded,
                  // 未登录占位头像的人像与账号区图标同尺寸（原为写死的 18）
                  size: _Dimens.accountIcon,
                  color: colorScheme.primary,
                ),
              ),
            const SizedBox(width: _Dimens.accountGap),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(_Dimens.tileRadius),
                onTap: () => _toMineTab(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLogin ? '我的主页' : '点击登录',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: _Dimens.accountFont,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (isLogin)
                      Text(
                        '查看资料与空间',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: _Dimens.accountSubFont,
                          color: colorScheme.outline,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (isLogin)
              IconButton(
                tooltip: '消息',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  // 未标记已读的处理两个入口一致；呈现方式由宿主决定：
                  // 桌面宿主改为就地滑出面板（与「私信」同一个面板），
                  // 未提供回调时保持原有的完整页面跳转。
                  mainController
                    ..clearUnreadMsg()
                    ..lastCheckUnreadAt = DateTime.now().millisecondsSinceEpoch;
                  if (onSelectMsg != null) {
                    onSelectMsg!();
                  } else {
                    Get.toNamed('/whisper');
                  }
                },
                icon: Badge(
                  isLabelVisible:
                      mainController.msgBadgeMode != DynamicBadgeMode.hidden &&
                          unread != null,
                  child: const Icon(
                    Icons.notifications_none,
                    size: _Dimens.accountIcon,
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}

/// 菜单项度量（普通窗口 / 最大化窗口两档固定值，不随窗口高度无级缩放）。
///
/// 行高 = [tileMargin] 的上下外边距 + [padV]×2 + [icon]：
/// 普通窗口 = (1+1) + 4+4 + 22 = 32；最大化 = (1+1) + 5.5+5.5 + 25 = 38。
class _ItemMetrics {
  const _ItemMetrics({
    required this.icon,
    required this.font,
    required this.padH,
    required this.padV,
    required this.radius,
    required this.iconGap,
    required this.intraGap,
    required this.groupGap,
  });

  /// 图标尺寸
  final double icon;

  /// 文字字号
  final double font;

  /// item 内部左右 padding（单边值）
  final double padH;

  /// item 内部上下 padding（单边值）
  final double padV;

  /// 选中背景（药丸）圆角
  final double radius;

  /// 图标与文字之间的间距
  final double iconGap;

  /// 同组内相邻两项之间的间距
  final double intraGap;

  /// 组间距
  final double groupGap;

  /// 行高（派生值，便于核对：普通 32 / 最大化 38）
  double get rowHeight => _Dimens.tileMarginV * 2 + padV * 2 + icon;

  /// 普通窗口：紧凑基准（行高 32 / 图标 22 / 文字 15.5 / 组内 0 / 组间 20）
  static const compact = _ItemMetrics(
    icon: _Dimens.icon,
    font: _Dimens.labelFont,
    padH: _Dimens.tilePadH,
    padV: _Dimens.tilePadV,
    radius: _Dimens.tileRadius,
    iconGap: _Dimens.iconGap,
    intraGap: 0,
    groupGap: _Dimens.groupGap,
  );

  /// 最大化窗口：只放大「图标 + 文字 + item 本身」，间距密度基本不变
  /// （行高 38 / 图标 25 / 文字 17 / 组内 2 / 组间 22）
  static const maximized = _ItemMetrics(
    icon: 25,
    font: 17,
    padH: 9,
    padV: 5.5,
    radius: 9,
    iconGap: 11,
    intraGap: 2,
    groupGap: 22,
  );
}

/// 菜单项度量的作用域（仅本文件）：导航列表内的行读取它；
/// 个人区（我的主页 / 查看资料与空间）与品牌区不在其中 ⇒ 不受影响。
class _NavItemStyle extends InheritedWidget {
  const _NavItemStyle({required this.metrics, required super.child});

  final _ItemMetrics metrics;

  static _ItemMetrics of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_NavItemStyle>()?.metrics ??
      _ItemMetrics.compact;

  @override
  bool updateShouldNotify(_NavItemStyle oldWidget) =>
      oldWidget.metrics != metrics;
}

/// 菜单项度量 + 弹性剩余空间（只留在「私信」与「设置」之间，不摊到菜单项之间）。
class _NavMetrics {
  const _NavMetrics({required this.metrics, required this.elastic});

  final _ItemMetrics metrics;

  /// 剩余高度（普通窗口与最大化都只在中间留出；内容放不下时为 0）
  final double elastic;
}

/// 最大化状态桥接（仅本文件使用）。
///
/// [DesktopSideBar] 本体保持 const / Stateless，这里用一个小 Stateful 桥接
/// `window_manager` 的最大化事件：只有最大化状态真正变化时才重建导航区。
/// 初值取持久化的 [SettingBoxKey.isWindowMaximized]（与 `main.dart` 启动时
/// 恢复最大化同源），故启动首帧即按正确布局渲染；随后用 `isMaximized()`
/// 校准一次，并靠 [onWindowMaximize] / [onWindowUnmaximize] 保持同步。
/// 仅桌面端会构建本侧栏，移动端不受影响。
class _MaximizeAware extends StatefulWidget {
  const _MaximizeAware({required this.builder});

  /// 最大化状态 → 导航区（true = 启用纵向均匀延伸）
  final Widget Function(BuildContext context, bool maximized) builder;

  @override
  State<_MaximizeAware> createState() => _MaximizeAwareState();
}

class _MaximizeAwareState extends State<_MaximizeAware> with WindowListener {
  /// 持久化值：与 main.dart 启动时 `if (Pref.isWindowMaximized) maximize()` 同源，
  /// 避免首帧先按窗口模式渲染、再跳到最大化布局。
  bool _maximized = GStorage.setting.get(
    SettingBoxKey.isWindowMaximized,
    defaultValue: false,
  );

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    // 校准一次：上次异常退出时持久化值可能已过期。
    windowManager.isMaximized().then((value) {
      if (mounted && value != _maximized) {
        setState(() => _maximized = value);
      }
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    if (mounted && !_maximized) {
      setState(() => _maximized = true);
    }
  }

  @override
  void onWindowUnmaximize() {
    if (mounted && _maximized) {
      setState(() => _maximized = false);
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _maximized);
}
