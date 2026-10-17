// =============================================================
// PiliPlus Windows 桌面化 · 桌面组件 token（仅服务 desktop_* 新组件）
// 数值与既有实现保持一致，只做「单一来源」集中：
//   WinUi（winui_section.dart）  → 间距/内边距/圆角/行高/图标尺寸
//   HoverCard（hover_card.dart） → 悬停提亮/细边透明度、动效时长与曲线
//   FluentCard（winui_section.dart）→ 卡片描边透明度
// 说明：本文件不修改、不替换上述既有实现，仅被
//   DesktopCard / DesktopListTile / DesktopSection 引用。
// =============================================================
import 'package:PiliPlus/common/widgets/desktop/winui_section.dart'
    show WinUi;
import 'package:material_ui/material_ui.dart';

abstract final class DesktopTokens {
  // ===== 栅格间距（4px 栅格，沿用 WinUi） =====
  static const double gap4 = WinUi.gap4;
  static const double gap8 = WinUi.gap8;
  static const double gap12 = WinUi.gap12;
  static const double gap16 = WinUi.gap16;
  static const double gap24 = WinUi.gap24;

  /// 卡片内边距 / 列表行左右内边距
  static const double pad = WinUi.pad;

  /// 页面外边距（供调用方排版使用）
  static const double padPage = WinUi.padPage;

  /// 大卡片 / 分组区块 / 主容器圆角（10）；小控件档 8 见
  /// `DesktopSearchPanel` 的搜索历史条目（本值 − 2）
  static const double radius = WinUi.radius;

  /// 列表行高（48）
  static const double rowHeight = WinUi.rowHeight;

  /// 行内图标尺寸（20）
  static const double iconSize = WinUi.iconSize;

  /// 内容限宽（**唯一来源** = [WinUi.contentWidth] = `Style.contentMaxWidth`
  /// = 1480；2026-10-05 由 1080 收敛而来）
  static const double contentWidth = WinUi.contentWidth;

  // ===== 桌面字号阶（整数 px；单一来源 = WinUi，见 winui_section.dart）=====

  /// 分组 / 卡片 / Tab 标题（16）
  static const double fontSectionTitle = WinUi.fontSectionTitle;

  /// 列表行主标题 / 行内正文（15）
  static const double fontRowTitle = WinUi.fontRowTitle;

  /// 次要信息（副标题、统计标签，13）
  static const double fontSecondary = WinUi.fontSecondary;

  /// 输入框文字（桌面搜索框，14）
  static const double fontInput = WinUi.fontInput;

  /// 桌面页面标题（AppBar，18）
  static const double fontPageTitle = WinUi.fontPageTitle;

  // ===== 描边 =====

  /// 卡片描边透明度（与 FluentCard 一致）
  static const double cardBorderAlpha = .55;

  /// 行末分隔线透明度（与 WinUiRow 一致）
  static const double dividerAlpha = .45;

  /// 悬停细边（不透明度 1，仅切换颜色）
  static const double hoverBorderAlpha = 1;

  // ===== 交互反馈 =====

  /// 悬停底色透明度（HoverCard：surfaceContainerHighest @ .5）
  static const double hoverAlpha = .5;

  /// 选中行底色透明度（desktop_side_bar 选中态同一观感：secondaryContainer @ .55）
  static const double selectedAlpha = .55;

  /// 悬停/选中态过渡时长与曲线（HoverCard：120ms fastOutSlowIn）
  static const Duration hoverDuration = Duration(milliseconds: 120);
  static const Curve curve = Curves.fastOutSlowIn;

  // ===== 语义色（只取 ColorScheme，天然兼容纯黑主题覆写） =====

  /// 卡片/面板底色
  static Color surface(ColorScheme cs) => cs.surfaceContainer;

  /// 悬停提亮底色
  static Color hoverSurface(ColorScheme cs) =>
      cs.surfaceContainerHighest.withValues(alpha: hoverAlpha);

  /// 选中行底色
  static Color selectedSurface(ColorScheme cs) =>
      cs.secondaryContainer.withValues(alpha: selectedAlpha);

  /// 卡片/控件描边
  static Color border(ColorScheme cs) =>
      cs.outlineVariant.withValues(alpha: cardBorderAlpha);

  /// 行末分隔线
  static Color divider(ColorScheme cs) =>
      cs.outlineVariant.withValues(alpha: dividerAlpha);

  /// 主文字
  static Color titleColor(ColorScheme cs, {bool selected = false}) =>
      selected ? cs.onSecondaryContainer : cs.onSurface;

  /// 次级文字（副标题、未选中图标）
  static Color subtitleColor(ColorScheme cs, {bool selected = false}) =>
      selected ? cs.onSecondaryContainer : cs.onSurfaceVariant;

  // ===== 桌面右栏「简介 + 相关推荐」整体尺寸基准（单一来源） =====
  //
  // 右栏（右栏顶部 UP 主区域 → 标题/展开 → 播放量/弹幕/日期 → 操作栏
  //       → 「相关推荐」→ 推荐卡片）**共用同一个缩放系数**：
  //
  //   最终尺寸 = 右栏设计基准尺寸 × [sidePanelScale]
  //
  // 设计基准即「按右栏设计截图标注的 1.00 尺寸」（avatar 44 / 图标 26 /
  // 行高 64 / 标题 22 / 次级文字 13）。乘一个统一系数后，右栏从上到下
  // 一起变大，不会出现「上面放大、相关推荐另立一套尺寸」的情况。
  //
  // 固定值，不随窗口宽度变化：普通窗口与最大化窗口取值完全相同。
  //
  // 调整口径只需改这一个数：`sidePanel*` 系列与右栏 `_build*` 里的
  // `sidePanelSp()` / `sidePanelFs()` 全部由它派生。

  /// 右栏整体缩放系数（唯一来源）。
  static const double sidePanelScale = 1.2;

  /// 右栏栅格：把 4px 基准间距按右栏系数放大（12 → 14、16 → 19 …）。
  static double sidePanelSp(double base) => (base * sidePanelScale).roundToDouble();

  /// 右栏字号：把设计基准字号按右栏系数放大（13 → 16、18 → 22 …）。
  static double sidePanelFs(double base) => (base * sidePanelScale).roundToDouble();

  /// UP 主头像直径（基准 44 → 53）。
  static final double sidePanelAvatarSize = sidePanelSp(44);

  /// UP 主头像徽标（VIP / 认证）（基准 18 → 22）。
  static final double sidePanelAvatarBadgeSize = sidePanelSp(18);

  /// 操作栏（赞/币/藏/再看/分享）图标尺寸（基准 26 → 31）。
  static final double sidePanelActionIconSize = sidePanelSp(26);

  /// 操作栏图标占位 / 三连进度环尺寸（基准 36 → 43）。
  static final double sidePanelActionIconBoxSize = sidePanelSp(36);

  /// 操作栏行高：图标 + 标签 + 上下留白，保证不被裁切（基准 64 → 77）。
  static final double sidePanelActionRowHeight = sidePanelSp(64);

  /// 右栏主标题（视频标题 / 「相关推荐」）字号与行高（基准 18 / 26，固定不变：
  /// 该档在上一轮已按截图定稿，本轮不再二次放大）。
  static const double sidePanelTitleFontSize = 18;
  static const double sidePanelTitleLineHeight = 26;

  /// 右栏主标题字重（Medium；比正文重、比粗体轻）。
  static const FontWeight sidePanelTitleFontWeight = FontWeight.w500;

  /// 右栏 UP 主名称字号（基准 15 → 18）。
  static final double sidePanelNameFontSize = sidePanelFs(15);

  /// 右栏次级信息（播放量 / 弹幕 / 日期 / 关注数 / 操作栏标签）字号（基准 13 → 16）。
  static final double sidePanelSecondaryFontSize = sidePanelFs(13);

  /// 右栏「评论区」普通文字字号 —— 与右栏「数据」区域**同一基准**
  /// （= [sidePanelSecondaryFontSize]，基准 13 → 16）。
  ///
  /// 评论组件（主评论 / 楼中楼 / 回复列表 / 排序栏 / 列表尾部提示）里的**普通文字**
  /// 统一走 [replyTextFs]：右栏（桌面横屏）取本值，其它形态（移动 / 平板 / 竖屏）
  /// 沿用各自原有字号，避免影响移动端既有排版。
  static final double sidePanelReplyFontSize = sidePanelSecondaryFontSize;

  /// 评论区普通文字字号：右栏用统一基准，其它形态回落到原字号 [fallback]。
  ///
  /// [fallback] 传该处**原有**的 `fontSize`（可为 null＝沿用主题默认），
  /// 因此非右栏形态逐字不变。
  static double? replyTextFs(bool isSidePanel, double? fallback) =>
      isSidePanel ? sidePanelReplyFontSize : fallback;

  // ===== BottomSheet（桌面弹层，见 theme_utils 的 bottomSheetTheme） =====

  /// 桌面 BottomSheet 最大宽度
  /// （与既有调用点 `min(640, shortestSide)` 同值，保证新旧调用点宽窄一致）
  static const double sheetMaxWidth = 640;

  /// 桌面 BottomSheet 最大高度（超过则浮层内部滚动）
  static const double sheetMaxHeight = 640;

  /// 桌面 BottomSheet 尺寸约束（由 theme_utils 统一注入主题，无需逐个调用点传参）
  static const BoxConstraints sheetConstraints = BoxConstraints(
    maxWidth: sheetMaxWidth,
    maxHeight: sheetMaxHeight,
  );

  /// 桌面 BottomSheet 内容推荐内边距
  /// （新写的 sheet 统一沿用；存量 sheet 的水平边距已由子组件自身达成，不强制回填）
  static const EdgeInsets sheetContentPadding = EdgeInsets.symmetric(
    horizontal: gap16,
    vertical: gap8,
  );
}
