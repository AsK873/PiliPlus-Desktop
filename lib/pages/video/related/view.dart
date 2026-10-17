import 'package:PiliPlus/common/skeleton/skeleton.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/badge.dart';
import 'package:PiliPlus/common/widgets/desktop/desktop_tokens.dart';
import 'package:PiliPlus/common/widgets/image/image_save.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/progress_bar/video_progress_indicator.dart';
import 'package:PiliPlus/common/widgets/stat/stat.dart';
import 'package:PiliPlus/common/widgets/video_card/video_card_h.dart';
import 'package:PiliPlus/common/widgets/video_popup_menu.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/model_hot_video_item.dart';
import 'package:PiliPlus/pages/episode_panel/view.dart';
import 'package:PiliPlus/pages/video/related/controller.dart';
import 'package:PiliPlus/utils/date_utils.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// 桌面右栏相关推荐 —— 横向卡片尺寸（单一来源）
///
/// 这里**不再单独定义一套尺寸**：每一项都是「设计基准值 ×
/// [DesktopTokens.sidePanelScale]」，与右栏顶部（UP 主头像 / 标题 / 统计 / 操作栏）
/// 用的**同一个系数**，所以右栏从上到下是一起变大的。
///
/// 设计基准值（1.00 档，即未统一放大前的原始尺寸）：
/// - 缩略图 128×72（16:9）
/// - 卡片内边距 8 / 图文间距 12 / 卡片间距 8
/// - 缩略图圆角 10
/// - 标题 15 / 行高 1.2；元信息（UP 主 / 播放量 / 弹幕）13
/// - 时长角标 11 号 + 2×3 内边距
///
/// 卡片结构不变：仍是单列「左缩略图 + 右信息」横向卡；只做同步放大。
const double _kThumbWidth = 128 * DesktopTokens.sidePanelScale;
const double _kThumbHeight = 72 * DesktopTokens.sidePanelScale;

/// 缩略图圆角（基准 10）。
final double _kThumbRadius = DesktopTokens.sidePanelSp(10);

/// 卡片内边距（基准 8）。
/// 卡片内边距（基准 8）。
final double _kCardPadding = DesktopTokens.sidePanelSp(8);

/// 播放列表条目「缩略图 ↔ 标题」的水平间距（与 `EpisodePanel` 的
/// `Row(spacing: 10)` 一致），用于反推标题左内缩量。
const double _kPlaylistThumbTextGap = 10;

/// 标题相对于「内容左缘」的左内缩量，使本条目标题左缘与播放列表标题左缘一致：
/// `_kThumbGap(14.4) − (10 + 缩略图宽) + 缩略图宽 = _kThumbGap − 10`。
final double _kTitleInset = _kThumbGap - _kPlaylistThumbTextGap;

/// 缩略图与右侧信息之间的水平间距（基准 12）。
final double _kThumbGap = DesktopTokens.sidePanelSp(12);

/// 卡片之间的垂直外边距（基准 8）。
final double _kCardGap = DesktopTokens.sidePanelSp(8);

/// 卡片高度 = 缩略图 + 上下内边距（骨架与真卡共用同一算式）。
final double _kCardHeight = _kThumbHeight + _kCardPadding * 2;

/// 元信息行之间的垂直间距（基准 1 → 放大后取整到 1）；仅骨架使用，
/// 真卡的文字规格与间距改为直接复用播放列表条目的规格。
final double _kMetaGap = DesktopTokens.sidePanelSp(1);

/// 元信息（播放量 / 弹幕）字号：与播放列表条目次级信息同号（12），
/// 不再使用右栏放大字号，保证两条列表视觉一致。
const double _kMetaFontSize = 12;

/// 时长标签（及其它缩略图角标）字号（基准 11）、内边距（基准 2×3）
/// 与贴边距离（基准 6）：随缩略图一起放大，
/// 时长文字（如 `12:34` / `01:02:03`）完整显示、不被裁切。
final double _kBadgeFontSize = DesktopTokens.sidePanelFs(11);
final EdgeInsets _kBadgePadding = EdgeInsets.symmetric(
  vertical: DesktopTokens.sidePanelSp(2),
  horizontal: DesktopTokens.sidePanelSp(3),
);
final double _kBadgeOffset = DesktopTokens.sidePanelSp(6);

const int _kSkeletonCount = 6;

class RelatedVideoPanel extends StatefulWidget {
  const RelatedVideoPanel({super.key, required this.heroTag});
  final String heroTag;
  @override
  State<RelatedVideoPanel> createState() => _RelatedVideoPanelState();
}

class _RelatedVideoPanelState extends State<RelatedVideoPanel> with GridMixin {
  late final RelatedController _relatedController;

  @override
  void initState() {
    super.initState();
    _relatedController = Get.putOrFind(
      RelatedController.new,
      tag: widget.heroTag,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      // 列表顶部留白随右栏整体系数放大，底部留白是滚动余量（不参与视觉尺寸）
      padding: EdgeInsets.only(
        top: DesktopTokens.sidePanelSp(7),
        bottom: 100,
      ),
      sliver: Obx(() => _buildBody(_relatedController.loadingState.value)),
    );
  }

  Widget _buildBody(LoadingState<List<HotVideoItemModel>?> loadingState) {
    // 桌面端右栏用单列横向卡片（不限宽、不随窗口放大列数）；
    // 移动端/平板保持原有网格 + [VideoCardH]，不改动。
    if (PlatformUtils.isDesktop) {
      return switch (loadingState) {
        Loading() => SliverList.builder(
          itemCount: _kSkeletonCount,
          itemBuilder: (context, index) => const _DesktopRelatedSkeleton(),
        ),
        Success(:final response) => response != null && response.isNotEmpty
            ? SliverList.builder(
                itemCount: response.length,
                itemBuilder: (context, index) {
                  return _DesktopRelatedCard(
                    key: ValueKey('${response[index].bvid}_$index'),
                    videoItem: response[index],
                    onRemove: () => _relatedController.loadingState
                      ..value.data!.removeAt(index)
                      ..refresh(),
                  );
                },
              )
            : const SliverToBoxAdapter(),
        Error(:final errMsg) => HttpError(
          errMsg: errMsg,
          onReload: _relatedController.onReload,
        ),
      };
    }
    return switch (loadingState) {
      Loading() => gridSkeleton,
      Success(:final response) =>
        response != null && response.isNotEmpty
            ? SliverGrid.builder(
                gridDelegate: gridDelegate,
                itemBuilder: (context, index) {
                  return VideoCardH(
                    videoItem: response[index],
                    onRemove: () => _relatedController.loadingState
                      ..value.data!.removeAt(index)
                      ..refresh(),
                  );
                },
                itemCount: response.length,
              )
            : const SliverToBoxAdapter(),
      Error(:final errMsg) => HttpError(
        errMsg: errMsg,
        onReload: _relatedController.onReload,
      ),
    };
  }
}

/// 加载骨架：与真卡**同一份尺寸常量**（外边距、内边距、缩略图 160×90、
/// 右侧 2 行标题 + 1 行 UP 主 + 1 行统计的占位），只换颜色不换几何，
/// 因此加载中与加载完成的卡片位置、高度完全一致，不会有跳动。
class _DesktopRelatedSkeleton extends StatelessWidget {
  const _DesktopRelatedSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = ColorScheme.of(context).onInverseSurface;
    Widget bar(double width) => Container(
      width: width,
      height: DesktopTokens.sidePanelSp(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(DesktopTokens.sidePanelSp(4)),
      ),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        DesktopTokens.gap12,
        0,
        DesktopTokens.gap12,
        _kCardGap,
      ),
      child: SizedBox(
        height: _kCardHeight,
        child: Skeleton(
          child: Padding(
            padding: EdgeInsets.all(_kCardPadding),
            child: Row(
              crossAxisAlignment: .start,
              children: [
                Container(
                  width: _kThumbWidth,
                  height: _kThumbHeight,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(_kThumbRadius),
                  ),
                ),
                SizedBox(width: _kThumbGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      bar(double.infinity),
                      SizedBox(height: DesktopTokens.sidePanelSp(6)),
                      bar(DesktopTokens.sidePanelSp(120)),
                      SizedBox(height: _kMetaGap),
                      bar(DesktopTokens.sidePanelSp(96)),
                      SizedBox(height: _kMetaGap),
                      Row(
                        spacing: DesktopTokens.sidePanelSp(
                          DesktopTokens.gap8,
                        ),
                        children: [
                          bar(DesktopTokens.sidePanelSp(56)),
                          bar(DesktopTokens.sidePanelSp(56)),
                        ],
                      ),
                    ],
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

/// 桌面右栏相关推荐卡片：左侧缩略图（`128×72 × sidePanelScale`，16:9），
/// 右侧标题最多 2 行 + UP 主 / 播放 / 弹幕；所有尺寸都由
/// [DesktopTokens.sidePanelScale] 派生，与右栏顶部同一系数。
/// 不套卡片容器（无底色 / 描边 / 圆角 / 悬停提亮），只保留缩略图与文字，
/// 让缩略图与左侧播放列表的缩略图左缘对齐；样式简化不改任何字号与信息层级。
class _DesktopRelatedCard extends StatelessWidget {
  const _DesktopRelatedCard({
    super.key,
    required this.videoItem,
    this.onRemove,
  });

  final HotVideoItemModel videoItem;
  final VoidCallback? onRemove;

  void _showCover() => imageSaveDialog(
    bvid: videoItem.bvid,
    title: videoItem.title,
    cover: videoItem.cover,
  );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // 与其它桌面卡片一致：右键 = 卡片操作菜单（含「查看图片」）
      onSecondaryTapDown: (details) => showVideoContextMenu(
        context,
        globalPos: details.globalPosition,
        videoItem: videoItem,
        onRemove: onRemove,
        extraItems: [
          PopupMenuItem<dynamic>(
            height: 40,
            onTap: _showCover,
            child: const Row(
              children: [
                Icon(Icons.image_outlined, size: 20),
                SizedBox(width: 6),
                Text('查看图片', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
      // 相关推荐条目：**完全去掉卡片容器**（无底色 / 描边 / 圆角 / 悬停卡片背景），
      // 只保留缩略图 + 文字；文字规格与左侧播放列表条目共用
      // [EpisodePanel.itemTitleStyle] / [EpisodePanel.itemMetaStyle]。
      //
      // 左对齐口径（与播放列表条目逐项对齐，不改动任何现有卡片尺寸）：
      //   播放列表条目内容左缘 = Style.safeSpace(12)；
      //   播放列表标题左缘       = 12 + 缩略图宽 + 10（Row spacing）。
      // 本条目内容左缘取同一个 12，标题左缘再由内容左缘 + `_kTitleInset` 得到：
      //   _kTitleInset = (缩略图宽 + 间距) − (10 + 缩略图宽) = 间距 − 10
      // 于是「推荐视频标题左缘」== 「播放列表视频标题左缘」。
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Style.safeSpace,
          0,
          Style.safeSpace,
          _kCardGap,
        ),
        child: GestureDetector(
          onTap: () => pushVideoH(videoItem),
          child: Row(
            crossAxisAlignment: .start,
            children: [
              // 缩略图宽度 = 设计基准 128 × 右栏整体系数（与顶部同一系数）；
              // 右栏内容宽约 391，放大后仍有余量，不横向溢出。
              _thumb(context),
              // 右侧 [Expanded] 内再左内缩 `_kTitleInset`，让标题左缘与播放列表
              // 标题左缘对齐；文字 2 行 + 省略号，不横向溢出。
              Expanded(child: _content(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumb(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final progress = videoItem.progress;
    final duration = videoItem.duration;
    // 缩略图圆角 + 角标字号/内边距都跟着右栏整体系数放大，
    // 时长文字完整显示、不被裁切。
    return SizedBox(
      width: _kThumbWidth,
      height: _kThumbHeight,
      child: AspectRatio(
        aspectRatio: _kThumbWidth / _kThumbHeight,
        child: Stack(
          clipBehavior: .none,
          children: [
            Positioned.fill(
              child: NetworkImgLayer(
                src: videoItem.cover,
                width: _kThumbWidth,
                height: _kThumbHeight,
                // 保持原视频缩略图比例（16:9 盒 + 默认 BoxFit.cover），只放大不改裁切口径
                borderRadius: BorderRadius.circular(_kThumbRadius),
              ),
            ),
            if (videoItem.badge case final badge?)
              PBadge(
                text: badge,
                top: _kBadgeOffset,
                right: _kBadgeOffset,
                fontSize: _kBadgeFontSize,
                padding: _kBadgePadding,
                type: switch (badge) {
                  '充电专属' => .error,
                  _ => .primary,
                },
              ),
            if (progress != null && progress != 0) ...[
              PBadge(
                text: progress == -1
                    ? '已看完'
                    : '${DurationUtils.formatDuration(progress)}/${DurationUtils.formatDuration(duration)}',
                right: _kBadgeOffset,
                bottom: _kBadgeOffset,
                fontSize: _kBadgeFontSize,
                padding: _kBadgePadding,
                type: .gray,
              ),
              Positioned(
                left: 0,
                bottom: 0,
                right: 0,
                child: VideoProgressIndicator(
                  color: colorScheme.primary,
                  backgroundColor: colorScheme.secondaryContainer,
                  radius: DesktopTokens.sidePanelSp(12),
                  height: DesktopTokens.sidePanelSp(4),
                  progress: progress == -1 ? 1 : progress / duration,
                ),
              ),
            ] else if (duration > 0)
              PBadge(
                text: DurationUtils.formatDuration(duration),
                right: _kBadgeOffset,
                bottom: _kBadgeOffset,
                fontSize: _kBadgeFontSize,
                padding: _kBadgePadding,
                type: .gray,
              ),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final pubdate = videoItem.pubdate;
    final ownerName = videoItem.owner.name ?? '';
    final owner = pubdate == null
        ? ownerName
        : '${DateFormatUtils.dateFormat(pubdate)}  $ownerName';
    // 文字规格**直接复用播放列表条目的规格**（单一来源，不再单独定义一套字号）：
    //   标题 = EpisodePanel.itemTitleStyle（字号 / 行高 1.42 / 字距 0.3 / 主文字色）
    //   次级 = EpisodePanel.itemMetaStyle（12 / 行高 1 / outline 色）
    // 这样「推荐视频」与「播放列表」视觉一致，且信息层级不高于播放列表。
    final titleStyle = EpisodePanel.itemTitleStyle(
      theme,
    )?.copyWith(color: DesktopTokens.titleColor(colorScheme));
    final metaStyle = EpisodePanel.itemMetaStyle(theme);
    return Padding(
      // 左内缩 `_kTitleInset`：让标题左缘与播放列表条目标题左缘严格对齐
      padding: EdgeInsets.only(left: _kTitleInset),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        children: [
        // 标题最多 2 行，超出省略
        if (videoItem.titleList?.isNotEmpty == true)
          Text.rich(
            TextSpan(
              children: videoItem.titleList!
                  .map(
                    (e) => TextSpan(
                      text: e.text,
                      style: e.isEm
                          ? titleStyle?.copyWith(color: colorScheme.primary)
                          : titleStyle,
                    ),
                  )
                  .toList(),
            ),
            maxLines: 2,
            overflow: .ellipsis,
          )
        else
          Text(
            videoItem.title,
            maxLines: 2,
            overflow: .ellipsis,
            style: titleStyle,
          ),
        const SizedBox(height: 2),
        Text(
          owner,
          maxLines: 1,
          overflow: .ellipsis,
          style: metaStyle,
        ),
        if (videoItem.isLive != true) ...[
          // 与播放列表条目的「日期 → 数据」间距一致（2），字号沿用播放列表
          // 次级规格；不额外放大图标，避免相关推荐比播放列表更复杂。
          const SizedBox(height: 2),
          Row(
            spacing: 8,
            children: [
              StatWidget(
                type: .play,
                value: videoItem.stat.view,
                color: DesktopTokens.subtitleColor(colorScheme),
                fontSize: _kMetaFontSize,
              ),
              StatWidget(
                type: .danmaku,
                value: videoItem.stat.danmu,
                color: DesktopTokens.subtitleColor(colorScheme),
                fontSize: _kMetaFontSize,
              ),
            ],
          ),
        ],
      ],
      ),
    );
  }
}
