import 'dart:math' show max;

import 'package:PiliPlus/common/skeleton/video_card_v.dart';
import 'package:PiliPlus/common/sliver_single_child_delegate.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/desktop/desktop_content.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/video_card/video_card_v.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/pages/rcmd/controller.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/rendering.dart'
    show
        SliverConstraints,
        SliverGridLayout,
        SliverGridRegularTileLayout,
        axisDirectionIsReversed;
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class RcmdPage extends StatefulWidget {
  const RcmdPage({super.key});

  @override
  State<RcmdPage> createState() => _RcmdPageState();
}

class _RcmdPageState extends State<RcmdPage>
    with AutomaticKeepAliveClientMixin {
  final controller = Get.put(RcmdController());

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = ColorScheme.of(context);
    return Container(
      clipBehavior: .hardEdge,
      // 只保留左边距：让滚动视口右缘与其它页面一致，右侧滚动条专用车道才能对齐
      margin: const .only(left: Style.safeSpace),
      decoration: const BoxDecoration(borderRadius: Style.mdRadius),
      child: refreshIndicator(
        onRefresh: controller.onRefresh,
        child: CustomScrollView(
          controller: controller.scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const .only(top: Style.cardSpace, bottom: 100),
              // 桌面端首页不再做内容限宽：网格铺满侧栏右侧的全部可用宽度，
              // 左缘 = 正文左边距 Style.safeSpace（x = 12），列宽随可用宽度
              // 等比例放大（见 [_HomeGridDelegate]），最大化时两侧不留大面积空白。
              // 传 double.infinity ⇒ CenteredSliverConstrainedCrossAxis 直接沿用
              // 父级 crossAxisExtent（偏移 0），既去掉 1480 限宽又保持左对齐。
              //
              // 注意：首页 TabBar（pages/home/view.dart）的限宽/居中几何未改动，
              // 它仍按 Style.contentMaxWidth = 1480 居中，因此超宽屏下 TabBar
              // 与网格不再左右缘重合（本轮只调整首页视频区域布局）。
              sliver: desktopLimitSliver(
                Obx(
                  () => _buildBody(colorScheme, controller.loadingState.value),
                ),
                maxWidth: double.infinity,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 首页视频网格（仅桌面端生效，见 [_HomeGridDelegate]）。
  ///
  /// `baseCardWidth` 复用既有设置 `Pref.recommendCardWidth`（默认 206）作为
  /// **卡片宽度的设计基准**（`scale = 卡片宽 / baseCardWidth` 的唯一来源），
  /// 但不把它当作卡片宽度上限——上限会把卡宽长期锁死在 ~206-213（见下方注释）；
  /// `baseContentExtent` 复用改动前写死的 `textScaler.scale(90)`。
  late final gridDelegate = _HomeGridDelegate(
    spacing: Style.cardSpace,
    baseCardWidth: Pref.recommendCardWidth,
    childAspectRatio: Style.aspectRatio,
    baseContentExtent: MediaQuery.textScalerOf(context).scale(90),
  );

  Widget _buildBody(
    ColorScheme colorScheme,
    LoadingState<List<dynamic>?> loadingState,
  ) {
    return switch (loadingState) {
      Loading() => _buildSkeleton,
      Success(:final response) =>
        response != null && response.isNotEmpty
            ? SliverGrid.builder(
                gridDelegate: gridDelegate,
                itemBuilder: (context, index) {
                  if (index == response.length - 1) {
                    controller.onLoadMore();
                  }
                  if (controller.lastRefreshAt != null) {
                    if (controller.lastRefreshAt == index) {
                      return GestureDetector(
                        onTap: () => controller
                          ..animateToTop()
                          ..onRefresh(),
                        child: Card(
                          child: Container(
                            alignment: Alignment.center,
                            padding: const .symmetric(horizontal: 10),
                            child: Text(
                              '上次看到这里\n点击刷新',
                              textAlign: .center,
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    final actualIndex = index > controller.lastRefreshAt!
                        ? index - 1
                        : index;
                    return _buildCard(
                      response[actualIndex],
                      onRemove: () {
                        if (controller.lastRefreshAt != null &&
                            actualIndex < controller.lastRefreshAt!) {
                          controller.lastRefreshAt =
                              controller.lastRefreshAt! - 1;
                        }
                        controller.loadingState
                          ..value.data!.removeAt(actualIndex)
                          ..refresh();
                      },
                    );
                  } else {
                    return _buildCard(
                      response[index],
                      onRemove: () => controller.loadingState
                        ..value.data!.removeAt(index)
                        ..refresh(),
                    );
                  }
                },
                itemCount: controller.lastRefreshAt != null
                    ? response.length + 1
                    : response.length,
              )
            : HttpError(onReload: controller.onReload),
      Error(:final errMsg) => HttpError(
        errMsg: errMsg,
        onReload: controller.onReload,
      ),
    };
  }

  /// 构建一个首页视频卡片（含桌面 hover / 预取包装）。
  ///
  /// 这里用 [LayoutBuilder] 取网格分配到的**实际列宽**（= 卡片宽度），再按本页
  /// 唯一的列宽算式 [_HomeGridDelegate.widthFor] 求出文字缩放系数交给卡片，
  /// 因此调用方不需要复刻列数/列宽算法，也不会与 Grid 口径漂移：
  /// `textScale = 卡片宽 / 206`，与卡片高度用的 scale 是同一个值。
  ///
  /// 仅桌面端启用文字同比放大（[PlatformUtils.isDesktop]）：Mobile / Tablet 传
  /// 默认 1.0，卡片表现与改动前完全一致。
  Widget _buildCard(
    dynamic videoItem, {
    required VoidCallback onRemove,
  }) => LayoutBuilder(
    builder: (context, constraints) {
      final width = gridDelegate.widthFor(constraints.maxWidth);
      return desktopCard(
        VideoCardV(
          videoItem: videoItem,
          onRemove: onRemove,
          textScale: PlatformUtils.isDesktop ? width.textScale : 1.0,
        ),
        prefetchBvid: videoItem.bvid,
      );
    },
  );

  Widget get _buildSkeleton => SliverGrid(
    gridDelegate: gridDelegate,
    delegate: const SliverSingleChildDelegate(
      count: 10,
      child: VideoCardVSkeleton(),
    ),
  );
}

/// 首页（推荐流）视频网格 · 桌面端布局口径：**左对齐 + 可用宽度增加即整卡同比放大**。
///
/// 只重写 crossAxis 的分配方式；卡片内部（缩略图比例 / 标题 / UP / 数据）完全不参与，
/// 仍由 [VideoCardV] 自行渲染：
///
/// **列数**：`n = max(1, round((W + G) / (columnPitch + G)))`，等价于
/// `round(W / 254)`（W = 网格可用宽度，G = [spacing] = 8）—— 即「一列连同它的间距
/// 约按 254 逻辑像素折算」。这个档位只用于**选列数**。
///
/// **卡片宽度**：选完列数后，宽度按 `cardWidth = (W − G·(n − 1)) / n` 均分，
/// 不再受 [baseCardWidth]（≈206）封顶。这是本轮的关键修正：`maxCrossAxisExtent`
/// 式的「卡宽上限」会让卡宽长期被锁在 ~206-213（W = 1694 时 `floor((W+8)/214)`
/// 得 7 列 × 212.9），窗口再怎么拉宽卡片都不变大；改为「先定列数、再均分宽度」后
/// 卡宽跟随 W 持续放大，且最后一列右缘正好落在网格右缘上
/// （右缘空白 = `W − G·(n − 1) − n·cardWidth`，实测 0；余数部分由 `/n` 吸收）。
///
/// 列数档位用 `round` 而非 `floor`/`ceil`：`round` 的节距阈值让卡宽在一个档位内
/// 从约 1.14 → 1.36 倍基准连续增长（W = 718 → 234px、W = 1374 → 268px），
/// 只有在**列数 +1 的那一档**才回落——且回落后的档位下限随窗口单调抬高
/// （每列数档位的卡宽实测下限：3 列 228 / 4 列 214.5 / 5 列 220.8 / 6 列 225 /
/// 7 列 228 / 8 列 230.2 / 9 列 232px，除 3→4 列一档外不再低于基准 206），
/// 因此不会出现「窗口变大卡片反而明显变小」；旧口径（`floor` + 卡宽上限）才是
/// 每个档位都回落到 206 以下（实测 173.5 - 208.5）。
///
/// **卡片高度**：单一缩放系数 `scale = cardWidth / [baseCardWidth]`，
/// `mainAxisExtent = cardWidth / childAspectRatio + [baseContentExtent] · scale`，
/// 即缩略图高度与信息区高度**同时**同比，整卡宽高同比；不对高度做任何 min/max 修正。
///
/// 边界：`W` 极小时 `n` 至少为 1；`round` 在 .5 处按 Dart 语义「远离零」进位
/// （如 W = 858：(858+8)/254 = 3.4098 → 3 列 × 280.7）。
class _HomeGridDelegate extends SliverGridDelegateWithExtentAndRatio {
  _HomeGridDelegate({
    required this.spacing,
    required this.baseCardWidth,
    required super.childAspectRatio,
    required this.baseContentExtent,
  }) : super(
         mainAxisSpacing: spacing,
         crossAxisSpacing: spacing,
         // 仅用于满足父类构造；本类的 getLayout 不使用父类的列数/列宽计算。
         maxCrossAxisExtent: baseCardWidth,
         mainAxisExtent: baseContentExtent,
       );

  /// 统一间距：横纵都用它，列与列之间保持一致（= `Style.cardSpace` = 8）。
  final double spacing;

  /// 卡片宽度的设计基准（= `Pref.recommendCardWidth`，默认 206）：
  /// 只用于 `scale = cardWidth / baseCardWidth`，不是卡片宽度上限。
  final double baseCardWidth;

  /// 基准宽度下的卡片信息区高度（= `textScaler.scale(90)`）；随卡片宽度同比缩放。
  final double baseContentExtent;

  /// 选列数的「列节距」：`n = round((W + G) / (columnPitch + G))` = `round(W / 254)`。
  ///
  /// 由目标视觉密度反推（G = 8、W = 网格可用宽度）：
  ///   718 → 3 列（234px）、858 → 3 列（280.7px）、1054 → 4 列（257.5px）、
  ///   1174 → 5 列（228.4px）、1374 → 5 列（268.4px）、1694 → 7 列（235.1px）、
  ///   2334 → 9 列（252.2px，继续放大）。
  /// 即：可用宽度每增加约 254 逻辑像素就多容纳一列，卡宽在 211 → 282 之间随窗口
  /// 连续放大，1920 全屏卡宽 235.1px（旧口径 212.9px，+10.4%）。
  static const double columnPitch = 246.0;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    // ① 列数：按列节距折算后四舍五入（Dart 的 round 在 .5 处远离零进位）。
    int crossAxisCount = max(
      1,
      ((constraints.crossAxisExtent + spacing) / (columnPitch + spacing))
          .round(),
    );
    // ② 卡宽：剩余宽度在 n 列之间均分（不再有 baseCardWidth 上限）。
    final available = max(
      0.0,
      constraints.crossAxisExtent - spacing * (crossAxisCount - 1),
    );
    final columnWidth = available / crossAxisCount;
    // ③ 整卡同比：同一 scale 同时作用于缩略图高与信息区高，无任何 min/max 修正。
    final scale = columnWidth / baseCardWidth;
    final mainAxisExtent =
        columnWidth / childAspectRatio + baseContentExtent * scale;
    return SliverGridRegularTileLayout(
      crossAxisCount: crossAxisCount,
      mainAxisStride: mainAxisExtent + spacing,
      crossAxisStride: columnWidth + spacing,
      childMainAxisExtent: mainAxisExtent,
      childCrossAxisExtent: columnWidth,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(covariant SliverGridDelegateWithExtentAndRatio old) =>
      super.shouldRelayout(old) ||
      old is! _HomeGridDelegate ||
      old.spacing != spacing ||
      old.baseCardWidth != baseCardWidth ||
      old.baseContentExtent != baseContentExtent;

  /// 本 delegate 的卡片宽度与 [getLayout] 用的是**同一套算式**（列数 → 均分宽度），
  /// 供调用方把「卡片实际列宽」交给卡片自身做文字同比放大
  /// （[VideoCardV.textScale] = 卡片宽 / [baseCardWidth]），避免在调用方复刻列数
  /// 算法造成两处口径漂移。列数算法本身未因此改动。
  ({double cardWidth, double textScale}) widthFor(double crossAxisExtent) {
    final n = max(
      1,
      ((crossAxisExtent + spacing) / (columnPitch + spacing)).round(),
    );
    final cardWidth = max(0.0, crossAxisExtent - spacing * (n - 1)) / n;
    return (cardWidth: cardWidth, textScale: cardWidth / baseCardWidth);
  }
}
