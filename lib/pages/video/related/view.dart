import 'package:PiliPlus/common/skeleton/video_card_h.dart';
import 'package:PiliPlus/common/widgets/badge.dart';
import 'package:PiliPlus/common/widgets/desktop/desktop_card.dart';
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
/// 缩略图 128×72（16:9，落在 120～135 的建议区间）；
/// 卡片 = 缩略图 72 + 上下内边距 8×2 = 88，落在 80～90 的目标区间；
/// 卡片之间由 [RelatedVideoPanel] 的 8px 外边距拉开。
const double _kThumbWidth = 128;
const double _kThumbHeight = 72;
const double _kCardVPadding = DesktopTokens.gap8;
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
      padding: const EdgeInsets.only(top: 7, bottom: 100),
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

class _DesktopRelatedSkeleton extends StatelessWidget {
  const _DesktopRelatedSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(
        DesktopTokens.gap12,
        0,
        DesktopTokens.gap12,
        DesktopTokens.gap8,
      ),
      child: SizedBox(
        height: _kThumbHeight + _kCardVPadding * 2,
        child: VideoCardHSkeleton(),
      ),
    );
  }
}

/// 桌面右栏相关推荐卡片：左侧固定 128×72 缩略图，右侧标题 2 行 + UP 主/播放/
/// 弹幕；卡片高度由缩略图撑到 88（内容超出时按内容增高，不裁切文字）。
/// 复用 Desktop UI Kit 的 [DesktopCard]（底色 + 描边 + 圆角 + 悬停反馈）。
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
      child: DesktopCard(
        margin: const EdgeInsets.fromLTRB(
          DesktopTokens.gap12,
          0,
          DesktopTokens.gap12,
          DesktopTokens.gap8,
        ),
        padding: const EdgeInsets.all(_kCardVPadding),
        onTap: () => pushVideoH(videoItem),
        child: Row(
          crossAxisAlignment: .start,
          children: [
            _thumb(context),
            const SizedBox(width: DesktopTokens.gap12),
            Expanded(child: _content(context)),
          ],
        ),
      ),
    );
  }

  Widget _thumb(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final progress = videoItem.progress;
    final duration = videoItem.duration;
    return SizedBox(
      width: _kThumbWidth,
      height: _kThumbHeight,
      child: Stack(
        clipBehavior: .none,
        children: [
          Positioned.fill(
            child: NetworkImgLayer(
              src: videoItem.cover,
              width: _kThumbWidth,
              height: _kThumbHeight,
            ),
          ),
          if (videoItem.badge case final badge?)
            PBadge(
              text: badge,
              top: 4,
              right: 4,
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
              right: 4,
              bottom: 4,
              type: .gray,
            ),
            Positioned(
              left: 0,
              bottom: 0,
              right: 0,
              child: VideoProgressIndicator(
                color: colorScheme.primary,
                backgroundColor: colorScheme.secondaryContainer,
                progress: progress == -1 ? 1 : progress / duration,
              ),
            ),
          ] else if (duration > 0)
            PBadge(
              text: DurationUtils.formatDuration(duration),
              right: 4,
              bottom: 4,
              type: .gray,
            ),
        ],
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
    // 桌面右栏卡片文字层级（统一走 Desktop UI Kit 字号阶）：
    //   标题 = 行标题档 15 + 主文字色；元信息 = 次级信息档 13 + 次级文字色。
    // 显式行高让内容高度仍小于 128×72 缩略图，卡片总高保持 88（Hover 不改几何）。
    final titleStyle = TextStyle(
      fontSize: DesktopTokens.fontRowTitle,
      height: 1.2,
      color: DesktopTokens.titleColor(colorScheme),
    );
    final metaStyle = TextStyle(
      fontSize: DesktopTokens.fontSecondary,
      height: 1.2,
      color: DesktopTokens.subtitleColor(colorScheme),
    );
    return Column(
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
                          ? titleStyle.copyWith(color: colorScheme.primary)
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
        const SizedBox(height: 1),
        Text(
          owner,
          maxLines: 1,
          overflow: .ellipsis,
          style: metaStyle,
        ),
        if (videoItem.isLive != true) ...[
          const SizedBox(height: 1),
          Row(
            spacing: DesktopTokens.gap8,
            children: [
              StatWidget(
                type: .play,
                value: videoItem.stat.view,
                color: DesktopTokens.subtitleColor(colorScheme),
              ),
              StatWidget(
                type: .danmaku,
                value: videoItem.stat.danmu,
                color: DesktopTokens.subtitleColor(colorScheme),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
