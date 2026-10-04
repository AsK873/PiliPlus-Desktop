import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/badge.dart';
import 'package:PiliPlus/common/widgets/image/image_save.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/stat/stat.dart';
import 'package:PiliPlus/common/widgets/video_popup_menu.dart';
import 'package:PiliPlus/http/search.dart';
import 'package:PiliPlus/models/home/rcmd/result.dart';
import 'package:PiliPlus/models/model_rec_video_item.dart';
import 'package:PiliPlus/models_new/video/video_detail/dimension.dart';
import 'package:PiliPlus/utils/app_scheme.dart';
import 'package:PiliPlus/utils/date_utils.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/utils/extension/dimension_ext.dart';
import 'package:PiliPlus/utils/id_utils.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

// 视频卡片 - 垂直布局
class VideoCardV extends StatelessWidget {
  final BaseRcmdVideoItemModel videoItem;
  final VoidCallback? onRemove;

  /// 卡片整体缩放系数（= 卡片宽度 / 206 设计基准），由调用方按实际列宽算出
  /// （见 `pages/rcmd/view.dart` 的 `_HomeGridDelegate.widthFor`）。
  ///
  /// 只作用于**文字**：通过 [MediaQuery.textScaler] 与系统/用户字号设置
  /// （ambient [TextScaler]）**相乘**，因此标题、UP 主、播放量、弹幕、日期、
  /// 角标文字的字号一起随卡片同比放大，而字体、maxLines、ellipsis、文字内容、
  /// 卡片内部布局逻辑与缩略图比例都不参与、不受影响。
  ///
  /// 默认 1.0 ⇒ 不引入任何额外布局层，其它调用方（搜索面板等）行为完全不变。
  final double textScale;

  const VideoCardV({
    super.key,
    required this.videoItem,
    this.onRemove,
    this.textScale = 1.0,
  }) : assert(textScale > 0, 'textScale 必须为正数');

  Future<void> onPushDetail() async {
    switch (videoItem.goto) {
      case 'bangumi':
        PageUtils.viewPgc(epId: videoItem.param!);
        break;
      case 'av':
        var bvid = videoItem.bvid ?? IdUtils.av2bv(videoItem.aid!);
        var cid = videoItem.cid;
        bool isVertical = false;
        Dimension? dimension;
        if (videoItem is RcmdVideoItemAppModel) {
          if (videoItem.uri case final uri?) {
            isVertical = uri.isVerticalFromUri;
          }
        }
        if (cid == null) {
          if (await SearchHttp.ab2cWithDimension(aid: videoItem.aid, bvid: bvid)
              case final res?) {
            cid = res.cid;
            dimension = res.dimension;
          }
        }
        if (cid != null) {
          PageUtils.toVideoPage(
            aid: videoItem.aid,
            bvid: bvid,
            cid: cid,
            cover: videoItem.cover,
            title: videoItem.title,
            isVertical: isVertical,
            dimension: dimension,
          );
        }
        break;
      // 动态
      case 'picture':
        try {
          PiliScheme.routePushFromUrl(videoItem.uri!);
        } catch (err) {
          SmartDialog.showToast(err.toString());
        }
        break;
      default:
        if (videoItem.uri?.isNotEmpty == true) {
          PiliScheme.routePushFromUrl(videoItem.uri!);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = _card(context);
    if (textScale == 1.0) {
      return card;
    }
    // 文字随卡片同比放大：与用户字号设置相乘，不改任何 TextStyle / 字体 /
    // maxLines / ellipsis / 文字内容，也不触碰卡片内部布局与缩略图比例。
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: _ScaledTextScaler(
          MediaQuery.textScalerOf(context),
          textScale,
        ),
      ),
      child: card,
    );
  }

  /// 卡片本体（缩略图 + 信息区 + 全部交互）。相较改动前逐字未变，只是从
  /// [build] 抽出：便于外层按 [textScale] 包裹 [MediaQuery]，且右下角 ⋮ 菜单
  /// （桌面端本就不渲染）不受文字缩放影响。
  Widget _card(BuildContext context) {
    void onLongPress() => imageSaveDialog(
      title: videoItem.title,
      cover: videoItem.cover,
      bvid: videoItem.bvid,
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Card(
          child: InkWell(
            onTap: onPushDetail,
            // 桌面端（含 Windows）：长按 = 无动作 —— 既不开图片/操作菜单，也不需要
            // 空处理器去挡手势；`null` ⇒ LongPressGestureRecognizer 不参与手势竞争，
            // 按住后松手仍是普通点击；触屏长按（保存/查看封面）保持不变。
            // 鼠标右键菜单由下方 onSecondaryTapDown 提供，不受影响。
            onLongPress: PlatformUtils.isMobile ? onLongPress : null,
            // M3：桌面右键=卡片操作菜单（与 ⋮ 同一动作集）+「查看图片」。
            onSecondaryTap: null,
            onSecondaryTapDown: PlatformUtils.isMobile
                ? null
                : (details) => showVideoContextMenu(
                    context,
                    globalPos: details.globalPosition,
                    videoItem: videoItem,
                    onRemove: onRemove,
                    extraItems: [
                      PopupMenuItem<dynamic>(
                        height: 40,
                        // 复用既有实现（与触屏长按同一入口），不新增图片查看器。
                        onTap: onLongPress,
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
            borderRadius: const .all(.circular(12)),
            child: Column(
              crossAxisAlignment: .start,
              children: [
                AspectRatio(
                  aspectRatio: Style.aspectRatio,
                  child: LayoutBuilder(
                    builder: (context, boxConstraints) {
                      double maxWidth = boxConstraints.maxWidth;
                      double maxHeight = boxConstraints.maxHeight;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          NetworkImgLayer(
                            src: videoItem.cover,
                            width: maxWidth,
                            height: maxHeight,
                            borderRadius: const .vertical(top: .circular(12)),
                          ),
                          if (videoItem.duration > 0)
                            PBadge(
                              bottom: 6,
                              right: 7,
                              size: .small,
                              type: .gray,
                              text: DurationUtils.formatDuration(
                                videoItem.duration,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                content(context),
              ],
            ),
          ),
        ),
        if (videoItem.goto == 'av')
          Positioned(
            right: -5,
            bottom: -2,
            width: 29,
            height: 29,
            child: VideoPopupMenu(
              iconSize: 17,
              videoItem: videoItem,
              onRemove: onRemove,
            ),
          ),
      ],
    );
  }

  Widget content(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Padding(
        padding: const .fromLTRB(6, 5, 6, 5),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            Expanded(
              child: Text(
                videoItem.title,
                maxLines: 2,
                overflow: .ellipsis,
                style: const TextStyle(height: 1.38),
              ),
            ),
            videoStat(theme),
            Row(
              spacing: 2,
              children: [
                if (videoItem.goto == 'bangumi')
                  PBadge(
                    text: videoItem.pgcBadge,
                    isStack: false,
                    size: .small,
                    type: .line_primary,
                    fontSize: 9,
                  ),
                if (videoItem.rcmdReason != null)
                  PBadge(
                    text: videoItem.rcmdReason,
                    isStack: false,
                    size: .small,
                    type: .secondary,
                  ),
                if (videoItem.goto == 'picture')
                  const PBadge(
                    text: '动态',
                    isStack: false,
                    size: .small,
                    type: .line_primary,
                    fontSize: 9,
                  ),
                if (videoItem.isFollowed)
                  const PBadge(
                    text: '已关注',
                    isStack: false,
                    size: .small,
                    type: .secondary,
                  ),
                Expanded(
                  flex: 1,
                  child: Text(
                    videoItem.owner.name.toString(),
                    maxLines: 1,
                    overflow: .clip,
                    semanticsLabel: 'UP：${videoItem.owner.name}',
                    style: TextStyle(
                      height: 1.5,
                      fontSize: theme.textTheme.labelMedium!.fontSize,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
                if (videoItem.goto == 'av') const SizedBox(width: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static final shortFormat = DateFormat('M-d');
  static final longFormat = DateFormat('yy-M-d');

  Widget videoStat(ThemeData theme) {
    return Row(
      children: [
        StatWidget(
          type: .play,
          value: videoItem.stat.view,
        ),
        if (videoItem.goto != 'picture') ...[
          const SizedBox(width: 4),
          StatWidget(
            type: .danmaku,
            value: videoItem.stat.danmu,
          ),
        ],
        if (videoItem is RcmdVideoItemModel) ...[
          const Spacer(),
          Text.rich(
            maxLines: 1,
            TextSpan(
              style: TextStyle(
                fontSize: theme.textTheme.labelSmall!.fontSize,
                color: theme.colorScheme.outline.withValues(alpha: 0.8),
              ),
              text: DateFormatUtils.dateFormat(
                videoItem.pubdate,
                short: shortFormat,
                long: longFormat,
              ),
            ),
          ),
          const SizedBox(width: 2),
        ],
      ],
    );
  }
}

/// 把环境 [TextScaler]（系统/用户字号设置）再乘一个固定系数，用于「文字随卡片
/// 宽度同比放大」：最终字号 = 原字号 × 用户字号系数 × [factor]。
///
/// 只叠加、不替换环境缩放，因此用户字号设置仍然生效；字号、字体、maxLines、
/// ellipsis、文字内容都不需要改动，全部 Text（含 [StatWidget]、未显式传
/// textScaler 的 PBadge 角标）自然跟随。
class _ScaledTextScaler extends TextScaler {
  const _ScaledTextScaler(this.ambient, this.factor);

  final TextScaler ambient;
  final double factor;

  @override
  double scale(double fontSize) => ambient.scale(fontSize) * factor;

  /// [TextScaler] 契约里的「估算值」：本类只做线性叠加，故直接相乘即可。
  /// 该成员自 v3.12 起废弃，但仍是抽象接口的一部分，必须实现。
  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => ambient.textScaleFactor * factor;

  @override
  String toString() => '_ScaledTextScaler($ambient, $factor)';
}
