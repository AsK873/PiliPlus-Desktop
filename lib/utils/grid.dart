import 'dart:math';

import 'package:PiliPlus/common/skeleton/video_card_h.dart';
import 'package:PiliPlus/common/sliver_single_child_delegate.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/desktop/desktop_card_scale.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

mixin GridMixin {
  /// 桌面端为 [CardGridDelegate]（动态列数 + 整卡同比），非桌面端行为与改动前逐字一致。
  late final gridDelegate = Grid.videoCardHDelegate();

  Widget get gridSkeleton => SliverGrid(
    gridDelegate: gridDelegate,
    delegate: const SliverSingleChildDelegate(
      count: 10,
      child: VideoCardHSkeleton(),
    ),
  );
}

abstract final class Grid {
  static final double smallCardWidth = Pref.smallCardWidth;

  /// 横向卡片（VideoCardH 家族）网格的**设计基准行高**（= 原 `mainAxisExtent`）。
  static const double videoCardHMainAxisExtent = 110;

  /// 横向卡片网格的**设计基准卡宽**（= 原 `maxCrossAxisExtent`
  /// = `smallCardWidth * 2` = 480）。也是整卡同比缩放的基准：
  /// `scale = 实际列宽 / videoCardHBaseWidth`。
  static double get videoCardHBaseWidth => smallCardWidth * 2;

  /// 横向卡片（VideoCardH 家族）网格 delegate：热门、排行、搜索视频、
  /// 历史 / 稍后再看 / 收藏 / 订阅、投稿列表、专栏 / 音频 / 漫画行等共用。
  ///
  /// 桌面端由 [CardGridDelegate] 接管（**与首页 `_HomeGridDelegate` 同一算式**：
  /// 动态列数 → 列宽均分 → `scale = 列宽 / videoCardHBaseWidth` →
  /// 行高 `= videoCardHMainAxisExtent · scale` → 文字同比）；
  /// 非桌面端在 [CardGridDelegate.getLayout] 里逐字沿用旧口径
  /// （`maxCrossAxisExtent` 类型：ceil 列数 + 固定行高），几何零变化。
  /// 原参数 `mainAxisSpacing: 2` / `crossAxisSpacing: 0` 保持不变。
  static CardGridDelegate videoCardHDelegate({
    double mainAxisExtent = videoCardHMainAxisExtent,
  }) => CardGridDelegate(
    baseCardWidth: videoCardHBaseWidth,
    baseMainAxisExtent: mainAxisExtent,
    // 固定行高卡片用不到 childAspectRatio / baseContentExtent，仅为满足基类构造。
    baseContentExtent: mainAxisExtent,
    childAspectRatio: Style.aspectRatio16x9,
    mainAxisSpacing: 2,
    crossAxisSpacing: 0,
  );
}

/// 卡片网格 delegate：**与首页 `_HomeGridDelegate` 同一套算式**（本类是它的参数化
/// 泛化，不做第二套设计）。桌面端：
///
/// **列数** `n = max(1, round((W + G) / (columnPitch + G)))`，W = 网格可用宽度、
/// G = [crossAxisSpacing]；[columnPitch] 默认 `baseCardWidth × [kCardColumnPitchRatio]`
/// = `baseCardWidth × 246/206`，即与首页 206 → 246 同一比值。
///
/// **卡宽** `cardWidth = (W − G·(n − 1)) / n`：选完列数后剩余宽度在 n 列之间均分，
/// **不再受 `maxCrossAxisExtent` 封顶**（旧口径的「卡宽上限」会把卡宽长期锁死，
/// 窗口再宽卡片也不变大）；最后一列右缘正好落在网格右缘。
///
/// **整卡同比** `scale = cardWidth / baseCardWidth`：
/// - 缩略图 + 信息区卡片：[mainAxisExtent] = `cardWidth / childAspectRatio
///   + baseContentExtent · scale`（缩略图高与信息区高**同时**同比）；
/// - 固定行高卡片：[baseMainAxisExtent] 非空时 = `baseMainAxisExtent · scale`；
/// 两种形态都不对高度做任何 min/max 修正，卡片始终是一个整体缩放单位。
///
/// **文字**：调用方用 [scaled] 包住卡片根节点即可拿到同一个 scale
/// （[DesktopCardScaleBox] 内部按 item 的实际列宽复算，口径与这里一致）。
///
/// **非桌面端**（[desktopAdaptive] 为 false）：[getLayout] 直接走父类
/// [SliverGridDelegateWithExtentAndRatio] 的旧口径，[scaled] 也原样返回子节点，
/// 因此 Mobile / Tablet 的列数、行高、字号与改动前逐字一致。
class CardGridDelegate extends SliverGridDelegateWithExtentAndRatio {
  CardGridDelegate({
    required this.baseCardWidth,
    required this.baseContentExtent,
    required super.childAspectRatio,
    this.baseMainAxisExtent,
    super.mainAxisSpacing = Style.cardSpace,
    super.crossAxisSpacing = Style.cardSpace,
    double? columnPitch,
    bool? desktopAdaptive,
  }) : columnPitch = columnPitch ?? baseCardWidth * kCardColumnPitchRatio,
       desktopAdaptive = desktopAdaptive ?? PlatformUtils.isDesktop,
       super(
         // 仅用于满足父类构造；桌面分支的 getLayout 用 [baseCardWidth] 作缩放基准。
         maxCrossAxisExtent: baseCardWidth,
         mainAxisExtent: baseMainAxisExtent ?? baseContentExtent,
       );

  /// 该卡片族的设计基准卡宽（= 原 `maxCrossAxisExtent`），`scale` 的唯一来源。
  final double baseCardWidth;

  /// 基准卡宽下的**信息区高度**（原 delegate 的 `mainAxisExtent`，例如
  /// `textScaler.scale(90)`）；随卡宽同比缩放。固定行高卡片下不参与计算。
  final double baseContentExtent;

  /// 非空时表示这是**固定行高卡片**（例如横向视频卡）：整卡高
  /// = `baseMainAxisExtent · scale`，而不是由缩略图比例 + 信息区推出来。
  final double? baseMainAxisExtent;

  /// 选列数用的列节距，默认 `baseCardWidth × 246/206`（与首页同一比值）。
  final double columnPitch;

  /// 是否启用桌面端「动态列数 + 整卡同比」；非桌面端恒为 false ⇒ 旧口径。
  final bool desktopAdaptive;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    if (!desktopAdaptive) {
      // 移动端 / 平板：逐字沿用父类实现（ceil 列数 + 固定行高 + 自带缓存）。
      return super.getLayout(constraints);
    }
    final crossAxisExtent = constraints.crossAxisExtent;
    // 与父类一样缓存：member_video 等页面会读 gridDelegate.layoutCache 做定位。
    if (layoutCache != null && crossAxisExtent == crossAxisExtentCache) {
      return layoutCache!;
    }
    crossAxisExtentCache = crossAxisExtent;
    final g = crossAxisSpacing;
    // ① 列数：按列节距折算后四舍五入（Dart 的 round 在 .5 处远离零进位）。
    final crossAxisCount = max(
      1,
      ((crossAxisExtent + g) / (columnPitch + g)).round(),
    );
    // ② 卡宽：剩余宽度在 n 列之间均分（不再有 baseCardWidth 上限）。
    final columnWidth =
        max(0.0, crossAxisExtent - g * (crossAxisCount - 1)) / crossAxisCount;
    // ③ 整卡同比：同一个 scale 同时作用于缩略图高、信息区高与卡片文字。
    final scale = columnWidth / baseCardWidth;
    final mainAxisExtent = baseMainAxisExtent == null
        ? columnWidth / childAspectRatio + baseContentExtent * scale
        : baseMainAxisExtent! * scale;
    return layoutCache = SliverGridRegularTileLayout(
      crossAxisCount: crossAxisCount,
      mainAxisStride: mainAxisExtent + mainAxisSpacing,
      crossAxisStride: columnWidth + g,
      childMainAxisExtent: mainAxisExtent,
      childCrossAxisExtent: columnWidth,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(
    covariant SliverGridDelegateWithExtentAndRatio oldDelegate,
  ) {
    final flag =
        super.shouldRelayout(oldDelegate) ||
        oldDelegate is! CardGridDelegate ||
        oldDelegate.baseCardWidth != baseCardWidth ||
        oldDelegate.baseContentExtent != baseContentExtent ||
        oldDelegate.baseMainAxisExtent != baseMainAxisExtent ||
        oldDelegate.columnPitch != columnPitch ||
        oldDelegate.desktopAdaptive != desktopAdaptive;
    if (flag) layoutCache = null;
    return flag;
  }

  /// 与 [getLayout] 同一套算式（列数 → 均分宽度）算出的本卡片宽度与文字缩放系数，
  /// 供调用方在不复刻列数算法的前提下使用；`textScale = cardWidth / baseCardWidth`。
  ({double cardWidth, double textScale}) widthFor(double crossAxisExtent) {
    final g = crossAxisSpacing;
    final n = max(1, ((crossAxisExtent + g) / (columnPitch + g)).round());
    final cardWidth = max(0.0, crossAxisExtent - g * (n - 1)) / n;
    return (cardWidth: cardWidth, textScale: cardWidth / baseCardWidth);
  }

  /// 把卡片包成「整卡同比缩放」的桌面卡片：内部所有文字随卡片实际列宽同比放大，
  /// 非桌面端 / 宽度无限 / `scale == 1` 时原样返回（零额外布局层）。
  Widget scaled(Widget card) =>
      DesktopCardScaleBox(baseCardWidth: baseCardWidth, child: card);
}

class SliverGridDelegateWithExtentAndRatio extends SliverGridDelegate {
  /// Creates a delegate that makes grid layouts with tiles that have a maximum
  /// cross-axis extent.
  ///
  /// The [maxCrossAxisExtent], [mainAxisExtent], [mainAxisSpacing],
  /// and [crossAxisSpacing] arguments must not be negative.
  /// The [childAspectRatio] argument must be greater than zero.
  SliverGridDelegateWithExtentAndRatio({
    required this.maxCrossAxisExtent,
    this.mainAxisSpacing = 0.0,
    this.crossAxisSpacing = 0.0,
    this.childAspectRatio = 1.0,
    this.mainAxisExtent = 0.0,
  }) : assert(maxCrossAxisExtent > 0),
       assert(mainAxisSpacing >= 0),
       assert(crossAxisSpacing >= 0),
       assert(childAspectRatio > 0);

  /// The maximum extent of tiles in the cross axis.
  ///
  /// This delegate will select a cross-axis extent for the tiles that is as
  /// large as possible subject to the following conditions:
  ///
  ///  - The extent evenly divides the cross-axis extent of the grid.
  ///  - The extent is at most [maxCrossAxisExtent].
  ///
  /// For example, if the grid is vertical, the grid is 500.0 pixels wide, and
  /// [maxCrossAxisExtent] is 150.0, this delegate will create a grid with 4
  /// columns that are 125.0 pixels wide.
  final double maxCrossAxisExtent;

  /// The number of logical pixels between each child along the main axis.
  final double mainAxisSpacing;

  /// The number of logical pixels between each child along the cross axis.
  final double crossAxisSpacing;

  /// The ratio of the cross-axis to the main-axis extent of each child.
  final double childAspectRatio;

  /// The extent of each tile in the main axis. If provided, it would add
  /// after [childAspectRatio] is used.
  final double mainAxisExtent;

  bool _debugAssertIsValid(double crossAxisExtent) {
    assert(crossAxisExtent > 0.0);
    assert(maxCrossAxisExtent > 0.0);
    assert(mainAxisSpacing >= 0.0);
    assert(crossAxisSpacing >= 0.0);
    assert(childAspectRatio > 0.0);
    return true;
  }

  SliverGridLayout? layoutCache;
  double? crossAxisExtentCache;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    // invoked before each frame
    assert(_debugAssertIsValid(constraints.crossAxisExtent));
    if (layoutCache != null &&
        constraints.crossAxisExtent == crossAxisExtentCache) {
      return layoutCache!;
    }
    crossAxisExtentCache = constraints.crossAxisExtent;
    int crossAxisCount =
        ((constraints.crossAxisExtent - crossAxisSpacing) /
                (maxCrossAxisExtent + crossAxisSpacing))
            .ceil();
    // Ensure a minimum count of 1, can be zero and result in an infinite extent
    // below when the window size is 0.
    crossAxisCount = max(1, crossAxisCount);
    final double usableCrossAxisExtent = max(
      0.0,
      constraints.crossAxisExtent - crossAxisSpacing * (crossAxisCount - 1),
    );
    final double childCrossAxisExtent = usableCrossAxisExtent / crossAxisCount;
    final double childMainAxisExtent =
        childCrossAxisExtent / childAspectRatio + mainAxisExtent;
    return layoutCache = SliverGridRegularTileLayout(
      crossAxisCount: crossAxisCount,
      mainAxisStride: childMainAxisExtent + mainAxisSpacing,
      crossAxisStride: childCrossAxisExtent + crossAxisSpacing,
      childMainAxisExtent: childMainAxisExtent,
      childCrossAxisExtent: childCrossAxisExtent,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(SliverGridDelegateWithExtentAndRatio oldDelegate) {
    final flag =
        oldDelegate.maxCrossAxisExtent != maxCrossAxisExtent ||
        oldDelegate.mainAxisSpacing != mainAxisSpacing ||
        oldDelegate.crossAxisSpacing != crossAxisSpacing ||
        oldDelegate.childAspectRatio != childAspectRatio ||
        oldDelegate.mainAxisExtent != mainAxisExtent;
    if (flag) layoutCache = null;
    return flag;
  }
}

class SliverGridDelegateWithMaxCrossAxisExtent extends SliverGridDelegate {
  /// Creates a delegate that makes grid layouts with tiles that have a maximum
  /// cross-axis extent.
  ///
  /// The [maxCrossAxisExtent], [mainAxisExtent], [mainAxisSpacing],
  /// and [crossAxisSpacing] arguments must not be negative.
  /// The [childAspectRatio] argument must be greater than zero.
  SliverGridDelegateWithMaxCrossAxisExtent({
    required this.maxCrossAxisExtent,
    this.mainAxisSpacing = 0.0,
    this.crossAxisSpacing = 0.0,
    this.childAspectRatio = 1.0,
    this.mainAxisExtent,
  }) : assert(maxCrossAxisExtent > 0),
       assert(mainAxisSpacing >= 0),
       assert(crossAxisSpacing >= 0),
       assert(childAspectRatio > 0),
       assert(mainAxisExtent == null || mainAxisExtent >= 0);

  /// The maximum extent of tiles in the cross axis.
  ///
  /// This delegate will select a cross-axis extent for the tiles that is as
  /// large as possible subject to the following conditions:
  ///
  ///  - The extent evenly divides the cross-axis extent of the grid.
  ///  - The extent is at most [maxCrossAxisExtent].
  ///
  /// For example, if the grid is vertical, the grid is 500.0 pixels wide, and
  /// [maxCrossAxisExtent] is 150.0, this delegate will create a grid with 4
  /// columns that are 125.0 pixels wide.
  final double maxCrossAxisExtent;

  /// The number of logical pixels between each child along the main axis.
  final double mainAxisSpacing;

  /// The number of logical pixels between each child along the cross axis.
  final double crossAxisSpacing;

  /// The ratio of the cross-axis to the main-axis extent of each child.
  final double childAspectRatio;

  /// The extent of each tile in the main axis. If provided it would define the
  /// logical pixels taken by each tile in the main-axis.
  ///
  /// If null, [childAspectRatio] is used instead.
  final double? mainAxisExtent;

  bool _debugAssertIsValid(double crossAxisExtent) {
    assert(crossAxisExtent > 0.0);
    assert(maxCrossAxisExtent > 0.0);
    assert(mainAxisSpacing >= 0.0);
    assert(crossAxisSpacing >= 0.0);
    assert(childAspectRatio > 0.0);
    return true;
  }

  SliverGridLayout? layoutCache;
  double? crossAxisExtentCache;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    assert(_debugAssertIsValid(constraints.crossAxisExtent));
    if (layoutCache != null &&
        constraints.crossAxisExtent == crossAxisExtentCache) {
      return layoutCache!;
    }
    crossAxisExtentCache = constraints.crossAxisExtent;
    int crossAxisCount =
        (constraints.crossAxisExtent / (maxCrossAxisExtent + crossAxisSpacing))
            .ceil();
    // Ensure a minimum count of 1, can be zero and result in an infinite extent
    // below when the window size is 0.
    crossAxisCount = max(1, crossAxisCount);
    final double usableCrossAxisExtent = max(
      0.0,
      constraints.crossAxisExtent - crossAxisSpacing * (crossAxisCount - 1),
    );
    final double childCrossAxisExtent = usableCrossAxisExtent / crossAxisCount;
    final double childMainAxisExtent =
        mainAxisExtent ?? childCrossAxisExtent / childAspectRatio;
    return layoutCache = SliverGridRegularTileLayout(
      crossAxisCount: crossAxisCount,
      mainAxisStride: childMainAxisExtent + mainAxisSpacing,
      crossAxisStride: childCrossAxisExtent + crossAxisSpacing,
      childMainAxisExtent: childMainAxisExtent,
      childCrossAxisExtent: childCrossAxisExtent,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(SliverGridDelegateWithMaxCrossAxisExtent oldDelegate) {
    final flag =
        oldDelegate.maxCrossAxisExtent != maxCrossAxisExtent ||
        oldDelegate.mainAxisSpacing != mainAxisSpacing ||
        oldDelegate.crossAxisSpacing != crossAxisSpacing ||
        oldDelegate.childAspectRatio != childAspectRatio ||
        oldDelegate.mainAxisExtent != mainAxisExtent;
    if (flag) layoutCache = null;
    return flag;
  }
}
