import 'package:PiliPlus/common/assets.dart';
import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/common/widgets/animated_height.dart';
import 'package:PiliPlus/common/widgets/desktop/desktop_tokens.dart';
import 'package:PiliPlus/common/widgets/dialog/dialog.dart';
import 'package:PiliPlus/common/widgets/expandable.dart';
import 'package:PiliPlus/common/widgets/gesture/tap_gesture_recognizer.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/pendant_avatar.dart';
import 'package:PiliPlus/common/widgets/scroll_physics.dart'
    show ReloadScrollPhysics;
import 'package:PiliPlus/common/widgets/selection_text.dart';
import 'package:PiliPlus/common/widgets/stat/stat.dart';
import 'package:PiliPlus/common/widgets/translucent_column.dart';
import 'package:PiliPlus/http/sponsor_block.dart';
import 'package:PiliPlus/models_new/video/video_ai_conclusion/model_result.dart';
import 'package:PiliPlus/models_new/video/video_detail/data.dart';
import 'package:PiliPlus/models_new/video/video_detail/desc_v2.dart';
import 'package:PiliPlus/models_new/video/video_detail/staff.dart';
import 'package:PiliPlus/models_new/video/video_detail/stat.dart';
import 'package:PiliPlus/models_new/video/video_tag/data.dart';
import 'package:PiliPlus/pages/mine/controller.dart';
import 'package:PiliPlus/pages/search/widgets/search_text.dart';
import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/controller.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/widgets/action_item.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/widgets/page.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/widgets/season.dart';
import 'package:PiliPlus/utils/app_scheme.dart';
import 'package:PiliPlus/utils/bili_colors.dart';
import 'package:PiliPlus/utils/date_utils.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:PiliPlus/utils/extension/num_ext.dart';
import 'package:PiliPlus/utils/extension/string_ext.dart';
import 'package:PiliPlus/utils/extension/theme_ext.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:PiliPlus/utils/id_utils.dart';
import 'package:PiliPlus/utils/num_utils.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/request_utils.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';

class UgcIntroPanel extends StatefulWidget {
  const UgcIntroPanel({
    super.key,
    required this.heroTag,
    required this.showAiBottomSheet,
    required this.showEpisodes,
    required this.onShowMemberPage,
    required this.isPortrait,
    required this.isHorizontal,
    this.seasonPlaylist,
  });
  final String heroTag;
  final Function showAiBottomSheet;
  final Function showEpisodes;
  final ValueChanged<int?> onShowMemberPage;
  final bool isPortrait;
  final bool isHorizontal;

  /// 桌面右栏的「播放列表」独立区域（固定高度 + 自身滚动），
  /// 由页面侧组装后传入，渲染位置固定在**三连下方、相关推荐上方**。
  /// 为 null 时不占位（移动端 / 平板 / 竖屏 / 无分P无合集）。
  final Widget? seasonPlaylist;

  @override
  State<UgcIntroPanel> createState() => _UgcIntroPanelState();
}

class _UgcIntroPanelState extends State<UgcIntroPanel> {
  late ColorScheme colorScheme;
  late final UgcIntroController introController;
  late final VideoDetailController videoDetailCtr =
      Get.find<VideoDetailController>(tag: widget.heroTag);

  @override
  void initState() {
    super.initState();
    introController = Get.putOrFind(
      UgcIntroController.new,
      tag: widget.heroTag,
    );
    // 桌面端信息区自带「展开 / 收起」入口，进入时统一为折叠态：
    // 「横屏自动展开视频简介」是面向移动/平板横屏（简介藏在一次点击之后）的设置，
    // 桌面信息区常驻可见，这里不再套用；「默认展开视频简介」是用户的显式选择，
    // 仍然生效。控制器的自动展开回调在 onInit 注册（先执行），本回调同帧复位。
    if (PlatformUtils.isDesktop &&
        !widget.isPortrait &&
        Pref.expandIntroPanelH &&
        !Pref.alwaysExpandIntroPanel) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && introController.expand.value) {
          introController.expand.value = false;
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    colorScheme = ColorScheme.of(context);
  }

  @override
  Widget build(BuildContext context) {
    final isPortrait = widget.isPortrait;
    final isHorizontal = !isPortrait && widget.isHorizontal;
    return SliverPadding(
      padding: EdgeInsets.only(
        left: DesktopTokens.gap12,
        right: DesktopTokens.gap12,
        // 桌面右栏信息区：顶部留白按 4px 栅格收紧（移动端保持原值），
        // 并随右栏整体放大（gap8 → sidePanelSp(8)）
        top: PlatformUtils.isDesktop && !isPortrait
            ? DesktopTokens.sidePanelSp(DesktopTokens.gap8)
            : 10,
      ),
      sliver: Obx(
        () {
          final videoDetail = introController.videoDetail.value;
          final isLoading = videoDetail.bvid == null;
          return SliverToBoxAdapter(
            child: GestureDetector(
              onTap: () {
                if (isLoading) return;
                feedBack();
                introController.expand.toggle();
              },
              child: TranslucentColumn(
                crossAxisAlignment: .start,
                children: [
                  NoTranslucentArea(
                    child: _buildOwnerInfo(
                      isLoading,
                      isPortrait,
                      isHorizontal,
                      videoDetail,
                    ),
                  ),
                  SizedBox(height: DesktopTokens.sidePanelSp(8)),
                  _buildTitle(isLoading, isHorizontal, videoDetail),
                  SizedBox(height: DesktopTokens.sidePanelSp(8)),
                  Stack(
                    clipBehavior: .none,
                    children: [
                      _buildInfo(videoDetail.stat, videoDetail.pubdate),
                      if (introController.enableAi) _aiBtn,
                    ],
                  ),
                  if (introController.showArgueMsg)
                    if (videoDetail.argueInfo?.argueMsg case final argueMsg?
                        when argueMsg.isNotEmpty) ...[
                      SizedBox(height: DesktopTokens.sidePanelSp(2)),
                      _buildArgueInfo(argueMsg),
                    ],
                  // 桌面端两种布局（播放器下方信息区 / 右侧信息栏）统一走
                  // 「视频简介」标题行 + 可折叠正文：默认折叠，不进横向溢出
                  if (PlatformUtils.isDesktop && !isPortrait) ...[
                    SizedBox(height: DesktopTokens.sidePanelSp(8)),
                    Obx(
                      () => AnimatedHeightWidgetExt(
                        expand: introController.expand.value,
                        duration: const Duration(milliseconds: 300),
                        child: TranslucentColumn(
                          mainAxisSize: .min,
                          crossAxisAlignment: .start,
                          children: _infos(videoDetail),
                        ),
                      ),
                    ),
                  ] else if (isHorizontal && PlatformUtils.isDesktop)
                    ..._infos(videoDetail)
                  else
                    Obx(
                      () => AnimatedHeightWidgetExt(
                        expand: introController.expand.value,
                        duration: const Duration(milliseconds: 300),
                        child: TranslucentColumn(
                          mainAxisSize: .min,
                          crossAxisAlignment: .start,
                          children: _infos(videoDetail),
                        ),
                      ),
                    ),
                  Obx(
                    () => introController.status.value
                        ? const SizedBox.shrink()
                        : Center(
                            child: TextButton.icon(
                              icon: const Icon(Icons.refresh),
                              onPressed: () {
                                introController
                                  ..status.value = true
                                  ..queryVideoIntro();
                                if (videoDetailCtr.videoUrl.isNullOrEmpty &&
                                    !videoDetailCtr.isQuerying) {
                                  videoDetailCtr.queryVideoUrl();
                                }
                              },
                              label: const Text("点此重新加载"),
                            ),
                          ),
                  ),
                  // 点赞收藏转发 布局样式2
                  //
                  // 桌面右栏（!isHorizontal && 桌面 && 非竖屏）：这里的「数据 → 操作栏」
                  // 间距（8）删除，操作栏**紧贴**数据下方（该段空白不再补回）。
                  // 移动端 / 平板 / 竖屏保持原有的这段间距，行为不变。
                  if (!isHorizontal) ...[
                    if (!(PlatformUtils.isDesktop && !isPortrait))
                      const SizedBox(height: 8),
                    actionGrid(
                      context,
                      isLoading,
                      introController,
                      videoDetail.stat,
                    ),
                  ],
                  // 播放列表：独立固定高度区域，位于**三连下方、相关推荐上方**。
                  // 操作栏 → 播放列表 只保留**唯一一处**区块留白（常规间距，
                  // 不再叠加第二个 spacer）。
                  if (widget.seasonPlaylist case final playlist?) ...[
                    SizedBox(height: DesktopTokens.sidePanelSp(8)),
                    playlist,
                  ],
                  // 合集
                  if (!isLoading &&
                      videoDetail.ugcSeason != null &&
                      (isPortrait ||
                          !videoDetailCtr
                              .plPlayerController
                              .horizontalSeasonPanel))
                    Obx(
                      () => SeasonPanel(
                        key: ValueKey(introController.videoDetail.value),
                        heroTag: widget.heroTag,
                        showEpisodes: widget.showEpisodes,
                        ugcIntroController: introController,
                      ),
                    ),
                  if (!isLoading &&
                      videoDetail.pages != null &&
                      videoDetail.pages!.length > 1 &&
                      (isPortrait ||
                          !videoDetailCtr
                              .plPlayerController
                              .horizontalSeasonPanel))
                    Obx(
                      () => PagesPanel(
                        key: ValueKey(introController.videoDetail.value),
                        heroTag: widget.heroTag,
                        ugcIntroController: introController,
                        bvid: introController.bvid,
                        showEpisodes: widget.showEpisodes,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildArgueInfo(String argueMsg) {
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: .middle,
            child: Padding(
              padding: const .only(right: 2),
              child: Icon(
                size: 13,
                Icons.error_outline,
                color: DesktopTokens.subtitleColor(colorScheme),
              ),
            ),
          ),
          TextSpan(text: argueMsg),
        ],
      ),
      style: TextStyle(
        fontSize: 12,
        color: DesktopTokens.subtitleColor(colorScheme),
      ),
    );
  }

  /// 桌面端「展开 / 收起」按钮（原「视频简介」行右侧入口，现位于标题行右侧）。
  ///
  /// 折叠状态复用 [UgcIntroController.expand]，与简介区点击展开保持同一份状态。
  Widget _buildExpandButton() {
    return Obx(() {
      final expanded = introController.expand.value;
      return TextButton.icon(
        onPressed: introController.expand.toggle,
        style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(
            horizontal: DesktopTokens.sidePanelSp(6),
          ),
          minimumSize: Size.zero,
          tapTargetSize: .shrinkWrap,
          visualDensity: const VisualDensity(vertical: -2.5),
          foregroundColor: colorScheme.primary,
          // 右栏整体放大：展开/收起字号与右栏次级文字同一档
          textStyle: TextStyle(
            fontSize: DesktopTokens.sidePanelSecondaryFontSize,
          ),
        ),
        icon: Icon(
          expanded ? Icons.expand_less : Icons.expand_more,
          size: DesktopTokens.sidePanelSp(18),
        ),
        label: Text(expanded ? '收起' : '展开'),
      );
    });
  }

  /// 桌面端标题行：标题 + 右侧「展开 / 收起」（同一行，垂直居中）。
  ///
  /// - 标题 [Expanded] 优先占用剩余空间（自身仍最多 2 行 + 省略号），
  ///   长标题不会挤压按钮，也不会与按钮重叠；
  /// - 按钮不参与标题文本、不覆盖标题，始终完整显示；
  /// - 两者之间保留明显水平间距（[DesktopTokens.gap16]），不紧贴。
  Widget _buildTitleRow(Widget title) {
    return Row(
      crossAxisAlignment: .center,
      children: [
        Expanded(child: title),
        const SizedBox(width: DesktopTokens.gap16),
        _buildExpandButton(),
      ],
    );
  }

  Widget _buildTitle(
    bool isLoading,
    bool isHorizontal,
    VideoDetailData videoDetail,
  ) {
    if (isLoading) {
      return _buildVideoTitle(videoDetail);
    } else if (PlatformUtils.isDesktop && !isHorizontal) {
      // 桌面右栏信息区：标题默认固定 2 行 + 省略号；**展开后按实际内容自适应
      // 高度、完整显示全部文字**（与简介的展开状态同一个 `introController.expand`），
      // 收起后回到 2 行。字号 / 字体 / 行高 / 展开逻辑均不变；
      // 标题变高后由外层 Column 自然把简介、三连、播放列表、相关推荐整体下推，
      // 不会发生覆盖。
      return Obx(
        () => _buildTitleRow(
          _buildVideoTitle(
            videoDetail,
            isSelectable: true,
            isExpand: introController.expand.value,
          ),
        ),
      );
    } else if (isHorizontal && PlatformUtils.isDesktop) {
      return _buildTitleRow(_buildVideoTitle(videoDetail, isSelectable: true));
    }
    return Obx(
      () => ExpandablePanel(
        collapsed: _gestureVideoTitle(videoDetail),
        expanded: _gestureVideoTitle(videoDetail, isExpand: true),
        expand: introController.expand.value,
      ),
    );
  }

  Widget _gestureVideoTitle(
    VideoDetailData videoDetail, {
    bool isExpand = false,
  }) {
    return GestureDetector(
      // 桌面端长按 = 无动作（复制标题仍由既有右键/其它入口提供）；触屏长按保持不变。
      onLongPress: PlatformUtils.isMobile
          ? () {
              Feedback.forLongPress(context);
              Utils.copyText(videoDetail.title ?? '');
            }
          : null,
      child: _buildVideoTitle(videoDetail, isExpand: isExpand),
    );
  }

  List<Widget> _infos(VideoDetailData videoDetail) => [
    SizedBox(height: DesktopTokens.sidePanelSp(8), width: .infinity),
    GestureDetector(
      onTap: () => Utils.copyText('${videoDetail.bvid}'),
      child: Text(
        videoDetail.bvid ?? '',
        style: TextStyle(
          fontSize: DesktopTokens.sidePanelFs(14),
          color: colorScheme.secondary,
        ),
      ),
    ),
    if (videoDetail.descV2 case final descV2? when descV2.isNotEmpty) ...[
      SizedBox(height: DesktopTokens.sidePanelSp(8)),
      SelectionText.rich(
        buildDesc(descV2),
        // 桌面右栏：「简介展开后的正文」字号与上方「数据」区域同一基准
        // （sidePanelSecondaryFontSize，普通/最大化一致）；行高倍数与其余视觉
        // 属性保持原样，仅统一字号。移动端/平板沿用原有默认字号。
        style: TextStyle(
          height: 1.4,
          fontSize: PlatformUtils.isDesktop && !widget.isPortrait
              ? DesktopTokens.sidePanelSecondaryFontSize
              : null,
        ),
      ),
    ],
    NoTranslucentArea(
      child: Obx(() {
        final videoTags = introController.videoTags.value;
        if (videoTags == null || videoTags.isEmpty) {
          return const SizedBox.shrink();
        }
        return _buildTags(videoTags);
      }),
    ),
  ];

  WidgetSpan _labelWidget(String text, Color bgColor, Color textColor) {
    return WidgetSpan(
      alignment: .middle,
      child: Container(
        padding: const .symmetric(horizontal: 4, vertical: 3),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.all(Radius.circular(4)),
        ),
        child: Text(
          text,
          textScaler: TextScaler.noScaling,
          strutStyle: const StrutStyle(
            leading: 0,
            height: 1,
            fontSize: 12,
          ),
          style: TextStyle(
            height: 1,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
    );
  }

  /// 桌面右栏「简介」面板标题的**固定视觉规格**（以 426×1358 设计截图为准）：
  /// 字号 18、字重 500（Medium）、行高 26px（= 26 / 18）、主文字色沿用
  /// [DesktopTokens.titleColor]，最多 2 行 + 省略号；中文字距不额外压缩，
  /// 字体沿用工程现有 Desktop 字体体系（不设 fontFamily、不新增字体文件）。
  ///
  /// 数值本身已提到 [DesktopTokens.sidePanelTitle*] 这一**单一来源**：
  /// 右栏所有区块标题（本标题行、「相关推荐」）共用同一份规格，避免各写一套。
  /// 移动 / 平板与播放器下方信息区仍为 [DesktopTokens.fontSectionTitle]。
  /// 普通窗口与最大化窗口完全一致。
  Widget _buildVideoTitle(
    VideoDetailData videoDetail, {
    bool isExpand = false,
    bool isSelectable = false,
  }) {
    final isDesktopPanel = PlatformUtils.isDesktop && !widget.isPortrait;
    final titleStyle = TextStyle(
      fontSize: isDesktopPanel
          ? DesktopTokens.sidePanelTitleFontSize
          : DesktopTokens.fontSectionTitle,
      // 行高按 26px 目标值换算成倍数，保证两行整体高度 = 2 × 26px
      height: isDesktopPanel
          ? DesktopTokens.sidePanelTitleLineHeight /
                DesktopTokens.sidePanelTitleFontSize
          : null,
      fontWeight: isDesktopPanel
          ? DesktopTokens.sidePanelTitleFontWeight
          : null,
      color: DesktopTokens.titleColor(colorScheme),
    );
    Widget child() {
      final videoLabel = videoDetailCtr.videoLabel.value;
      final textSpan = TextSpan(
        children: [
          if (videoLabel.isNotEmpty) ...[
            WidgetSpan(
              alignment: .middle,
              child: Container(
                padding: const .symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                ),
                child: Row(
                  mainAxisSize: .min,
                  children: [
                    Stack(
                      clipBehavior: .none,
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 16,
                          color: colorScheme.onSecondaryContainer,
                        ),
                        Icon(
                          Icons.play_arrow_rounded,
                          size: 12,
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ],
                    ),
                    Text(
                      videoLabel,
                      textScaler: TextScaler.noScaling,
                      strutStyle: const StrutStyle(
                        leading: 0,
                        height: 1,
                        fontSize: 13,
                      ),
                      style: TextStyle(
                        height: 1,
                        fontSize: 13,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const TextSpan(text: ' '),
          ],
          if (videoDetail.isUpowerExclusive == true) ...[
            _labelWidget(
              '充电专属',
              colorScheme.isDark
                  ? colorScheme.error
                  : colorScheme.errorContainer,
              colorScheme.isDark
                  ? colorScheme.onError
                  : colorScheme.onErrorContainer,
            ),
            const TextSpan(text: ' '),
          ] else if (videoDetail.rights?.isSteinGate == 1) ...[
            _labelWidget(
              '互动视频',
              colorScheme.secondaryContainer,
              colorScheme.onSecondaryContainer,
            ),
            const TextSpan(text: ' '),
          ],
          TextSpan(text: videoDetail.title),
        ],
      );
      if (isSelectable) {
        return SelectionText.rich(
          textSpan,
          style: titleStyle,
          // 桌面右栏标题：支持鼠标选择复制，同时保持原有 2 行 + 省略号；
          // 展开态沿用不限行数的原逻辑。
          maxLines: isExpand ? null : 2,
          overflow: isExpand ? null : .ellipsis,
        );
      }
      return Text.rich(
        textSpan,
        maxLines: isExpand ? null : 2,
        overflow: isExpand ? null : .ellipsis,
        style: titleStyle,
      );
    }

    if (videoDetailCtr.plPlayerController.enableSponsorBlock) {
      return Obx(child);
    }
    return child();
  }

  Widget followButton(BuildContext context) {
    return Obx(
      () {
        int attr = introController.followStatus.value.attribute ?? 0;
        return TextButton(
          onPressed: () => introController.actionRelationMod(context),
          style: TextButton.styleFrom(
            tapTargetSize: .shrinkWrap,
            visualDensity: const VisualDensity(vertical: -2.8),
            foregroundColor: attr != 0
                ? colorScheme.outline
                : colorScheme.onSecondaryContainer,
            backgroundColor: attr != 0
                ? colorScheme.onInverseSurface
                : colorScheme.secondaryContainer,
          ),
          child: Text(
            switch (attr) {
              1 => '悄悄关注',
              2 => '已关注',
              4 || 6 => '已互关',
              128 => '已拉黑',
              -10 => '特别关注',
              _ => ' 关注 ',
            },
            // 右栏整体放大：关注按钮文字与右栏次级文字同一档
            style: TextStyle(fontSize: DesktopTokens.sidePanelSecondaryFontSize),
          ),
        );
      },
    );
  }

  Widget actionGrid(
    BuildContext context,
    bool isLoading,
    UgcIntroController introController,
    VideoStat? stat,
  ) {
    return SizedBox(
      // 桌面操作栏统一行高（Desktop UI Kit 的列表行高 token）；
      // 右栏放大时行高同比放大，避免图标/文字被行高挤出
      height: DesktopTokens.sidePanelActionRowHeight,
      child: Row(
        crossAxisAlignment: .start,
        children: [
          Obx(
            () => ActionItem(
              animation: introController.tripleAnimation,
              desktopTokens: true,
              icon: const Icon(FontAwesomeIcons.thumbsUp),
              selectIcon: const Icon(FontAwesomeIcons.solidThumbsUp),
              selectStatus: introController.hasLike.value,
              semanticsLabel: '点赞',
              text: !isLoading ? NumUtils.numFormat(stat!.like) : null,
              onStartTriple: introController.onStartTriple,
              onCancelTriple: introController.onCancelTriple,
            ),
          ),
          Obx(
            () => ActionItem(
              desktopTokens: true,
              icon: const Icon(FontAwesomeIcons.thumbsDown),
              selectIcon: const Icon(FontAwesomeIcons.solidThumbsDown),
              onTap: () => introController.handleAction(
                introController.actionDislikeVideo,
              ),
              selectStatus: introController.hasDislike.value,
              semanticsLabel: '点踩',
              text: "点踩",
            ),
          ),
          Obx(
            () => ActionItem(
              animation: introController.tripleAnimation,
              desktopTokens: true,
              icon: const Icon(FontAwesomeIcons.b),
              selectIcon: const Icon(FontAwesomeIcons.b),
              onTap: introController.actionCoinVideo,
              selectStatus: introController.hasCoin,
              semanticsLabel: '投币',
              text: !isLoading ? NumUtils.numFormat(stat!.coin) : null,
            ),
          ),
          Obx(
            () {
              // 响应式状态必须在 Obx 回调内读取（否则 Obx 追踪不到依赖会报
              // "improper use of a GetX"）；Builder 仅用于取按钮自身的
              // BuildContext 作为桌面端 Popover 的定位锚点。
              final hasFav = introController.hasFav.value;
              return Builder(
                builder: (btnContext) => ActionItem(
                  animation: introController.tripleAnimation,
                  desktopTokens: true,
                  icon: const Icon(FontAwesomeIcons.star),
                  selectIcon: const Icon(FontAwesomeIcons.solidStar),
                  // 短按：开启快速收藏时收藏至默认夹，否则打开收藏夹 Popover
                  onTap: () => introController.showFavBottomSheet(btnContext),
                  // 长按：仅在开启「快速收藏」时绑定 —— 此时长按打开收藏夹 Popover；
                  // 关闭时保持不绑定（长按不执行任何操作）。二者由 InkWell 的
                  // 手势竞技场互斥，不会同时触发。
                  onLongPress: introController.enableQuickFav
                      ? () => introController.showFavBottomSheet(
                          btnContext,
                          isLongPress: true,
                        )
                      : null,
                  selectStatus: hasFav,
                  semanticsLabel: '收藏',
                  text: !isLoading ? NumUtils.numFormat(stat!.favorite) : null,
                ),
              );
            },
          ),
          Obx(
            () => ActionItem(
              desktopTokens: true,
              icon: const Icon(FontAwesomeIcons.clock),
              selectIcon: const Icon(FontAwesomeIcons.solidClock),
              onTap: () =>
                  introController.handleAction(introController.viewLater),
              selectStatus: introController.hasLater.value,
              semanticsLabel: '再看',
              text: '再看',
            ),
          ),
          ActionItem(
            desktopTokens: true,
            icon: const Icon(FontAwesomeIcons.shareFromSquare),
            onTap: () => introController.actionShareVideo(context),
            selectStatus: false,
            semanticsLabel: '分享',
            text: !isLoading ? NumUtils.numFormat(stat!.share!) : null,
          ),
        ],
      ),
    );
  }

  static final RegExp urlRegExp = RegExp(
    Constants.urlRegex.pattern + r'|av\d+|bv[a-z\d]{10}|(?:\d+[:：])?\d+[:：]\d+',
    caseSensitive: false,
  );

  static final youtubeRegExp = RegExp(
    r'(?:youtube\.com\/(?:[^\/\n\s]+\/\S+\/|(?:v|e(?:mbed)?)\/|\S*?[?&]v=)|youtu\.be\/)([a-z0-9_\-]{11})',
    caseSensitive: false,
  );

  TextSpan buildDesc(List<DescV2> descV2) {
    // type
    // 1 普通文本
    // 2 @用户
    final List<TextSpan> spanChildren = descV2.map((currentDesc) {
      switch (currentDesc.type) {
        case 1:
          final List<InlineSpan> spanChildren = <InlineSpan>[];
          currentDesc.rawText?.splitMapJoin(
            urlRegExp,
            onMatch: (Match match) {
              final matchStr = match[0]!;
              final matchStrLowerCase = matchStr.toLowerCase();
              if (matchStrLowerCase.startsWith('http')) {
                spanChildren.add(
                  TextSpan(
                    text: matchStr,
                    style: TextStyle(color: colorScheme.primary),
                    recognizer: NoDeadlineTapGestureRecognizer()
                      ..onTap = () async {
                        if (videoDetailCtr
                            .plPlayerController
                            .enableSponsorBlock) {
                          final duration =
                              videoDetailCtr.data.timeLength ??
                              videoDetailCtr
                                  .plPlayerController
                                  .durationInMilliseconds;
                          if (duration > 0) {
                            final ytbId = youtubeRegExp
                                .firstMatch(matchStr)
                                ?.group(1);
                            if (ytbId != null) {
                              final bvid = videoDetailCtr.bvid;
                              final cid = videoDetailCtr.cid.value;

                              SmartDialog.showLoading();
                              final hasPortVideo =
                                  (await SponsorBlock.getPortVideo(
                                    bvid: bvid,
                                    cid: cid,
                                  )).dataOrNull ==
                                  ytbId;
                              SmartDialog.dismiss();

                              if (!mounted) return;
                              final confirmed = await showConfirmDialog(
                                context: context,
                                title: const Text('空降助手：搬运视频同步'),
                                content: Text(
                                  '${hasPortVideo ? "" : "是否将"}该视频${hasPortVideo ? "已" : ""}绑定到此YouTube视频($ytbId)',
                                ),
                              );
                              if (!hasPortVideo && confirmed) {
                                final res = await SponsorBlock.postPortVideo(
                                  bvid: bvid,
                                  cid: cid,
                                  ytbId: ytbId,
                                  videoDuration: (duration / 1000).round(),
                                );
                                SmartDialog.showToast(
                                  '提交搬运视频${res.isSuccess ? "成功" : "失败: $res"}',
                                );
                                return;
                              }
                            }
                          }
                        }
                        PageUtils.handleWebview(matchStr);
                      },
                  ),
                );
              } else if (matchStrLowerCase.startsWith('av')) {
                try {
                  int aid = int.parse(matchStr.substring(2));
                  IdUtils.av2bv(aid);
                  spanChildren.add(
                    TextSpan(
                      text: matchStr,
                      style: TextStyle(color: colorScheme.primary),
                      recognizer: NoDeadlineTapGestureRecognizer()
                        ..onTap = () => PiliScheme.videoPush(aid, null),
                    ),
                  );
                } catch (e) {
                  spanChildren.add(TextSpan(text: matchStr));
                }
              } else if (matchStrLowerCase.startsWith('bv')) {
                try {
                  IdUtils.bv2av(matchStr);
                  spanChildren.add(
                    TextSpan(
                      text: matchStr,
                      style: TextStyle(color: colorScheme.primary),
                      recognizer: NoDeadlineTapGestureRecognizer()
                        ..onTap = () => PiliScheme.videoPush(null, matchStr),
                    ),
                  );
                } catch (e) {
                  spanChildren.add(TextSpan(text: matchStr));
                }
              } else {
                spanChildren.add(
                  TextSpan(
                    text: matchStr,
                    style: TextStyle(color: colorScheme.primary),
                    recognizer: NoDeadlineTapGestureRecognizer()
                      ..onTap = () {
                        try {
                          Get.find<VideoDetailController>(
                            tag: widget.heroTag,
                          ).plPlayerController.seekTo(
                            Duration(
                              seconds: DurationUtils.parseDuration(matchStr),
                            ),
                            isSeek: false,
                          );
                        } catch (_) {}
                      },
                  ),
                );
              }
              return '';
            },
            onNonMatch: (String nonMatchStr) {
              spanChildren.add(TextSpan(text: nonMatchStr));
              return '';
            },
          );
          return TextSpan(children: spanChildren);
        case 2:
          final Color colorSchemePrimary = colorScheme.primary;
          return TextSpan(
            text: '@${currentDesc.rawText}',
            style: TextStyle(color: colorSchemePrimary),
            recognizer: NoDeadlineTapGestureRecognizer()
              ..onTap = () => Get.toNamed('/member?mid=${currentDesc.bizId}'),
          );
        default:
          return const TextSpan();
      }
    }).toList();
    return TextSpan(children: spanChildren);
  }

  Widget _buildOwnerInfo(
    bool isLoading,
    bool isPortrait,
    bool isHorizontal,
    VideoDetailData videoDetail,
  ) {
    final mid = videoDetail.owner?.mid;
    return Row(
      children: [
        if (videoDetail.staff case final staff? when staff.isNotEmpty)
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: .horizontal,
              hitTestBehavior: .translucent,
              physics: ReloadScrollPhysics(controller: introController),
              child: Row(
                spacing: 25,
                children: staff
                    .map((e) => _buildStaff(isPortrait, mid, e))
                    .toList(),
              ),
            ),
          )
        else ...[
          Expanded(
            child: Align(
              alignment: .centerLeft,
              child: _buildAvatar(
                () {
                  if (mid != null) {
                    feedBack();
                    if (!isPortrait && introController.horizontalMemberPage) {
                      widget.onShowMemberPage(mid);
                    } else {
                      Get.toNamed(
                        '/member?mid=$mid&from_view_aid=${videoDetailCtr.aid}',
                      );
                    }
                  }
                },
              ),
            ),
          ),
          followButton(context),
        ],
        if (isHorizontal) ...[
          const SizedBox(width: 10),
          Expanded(
            child: actionGrid(
              context,
              isLoading,
              introController,
              videoDetail.stat,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStaff(
    bool isPortrait,
    int? ownerMid,
    Staff item,
  ) {
    void onTap() => Get.toNamed(
      '/member?mid=${item.mid}&from_view_aid=${videoDetailCtr.aid}',
    );
    return GestureDetector(
      behavior: .opaque,
      onTap: () {
        if (item.mid == ownerMid &&
            !isPortrait &&
            introController.horizontalMemberPage) {
          widget.onShowMemberPage(ownerMid);
        } else {
          onTap();
        }
      },
      onSecondaryTap:
          PlatformUtils.isDesktop && introController.horizontalMemberPage
          ? onTap
          : null,
      child: Row(
        children: [
          Stack(
            clipBehavior: .none,
            children: [
              NetworkImgLayer(
                type: .avatar,
                src: item.face,
                width: 32,
                height: 32,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
              ),
              if (item.official?.type case final type? when type != -1)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: .circle,
                      color: colorScheme.surface,
                    ),
                    child: item.official?.type == 0
                        ? const Icon(
                            Icons.offline_bolt,
                            color: BiliColors.yellow,
                            size: 14,
                          )
                        : const Icon(
                            Icons.offline_bolt,
                            color: Colors.lightBlueAccent,
                            size: 14,
                          ),
                  ),
                ),
              Positioned(
                top: 0,
                right: -6,
                child: Obx(
                  () {
                    if (introController.staffRelations['status'] == true &&
                        introController.staffRelations['${item.mid}'] == null) {
                      return Material(
                        type: .circle,
                        color: colorScheme.secondaryContainer,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => RequestUtils.actionRelationMod(
                            context: context,
                            mid: item.mid,
                            isFollow: false,
                            afterMod: (val) =>
                                introController.staffRelations['${item.mid}'] =
                                    true,
                          ),
                          child: Padding(
                            padding: const .all(2),
                            child: Icon(
                              MdiIcons.plus,
                              size: 16,
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: .min,
            crossAxisAlignment: .start,
            children: [
              Text(
                item.name!,
                maxLines: 1,
                overflow: .ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: (item.vip?.status ?? 0) > 0 && item.vip?.type == 2
                      ? colorScheme.vipColor
                      : DesktopTokens.subtitleColor(colorScheme),
                ),
              ),
              Text(
                item.title!,
                style: TextStyle(
                  fontSize: 12,
                  color: DesktopTokens.subtitleColor(colorScheme),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(
    VoidCallback onPushMember,
  ) => GestureDetector(
    onTap: onPushMember,
    behavior: .opaque,
    onSecondaryTap:
        PlatformUtils.isDesktop && introController.horizontalMemberPage
        ? () => Get.toNamed(
            '/member?mid=${introController.userStat.value.card?.mid}&from_view_aid=${videoDetailCtr.aid}',
          )
        : null,
    child: Obx(
      () {
        final userStat = introController.userStat.value;
        final isVip = (userStat.card?.vip?.status ?? 0) > 0;
        return Row(
          spacing: DesktopTokens.sidePanelSp(8),
          mainAxisSize: .min,
          children: [
            PendantAvatar(
              userStat.card?.face,
              size: DesktopTokens.sidePanelAvatarSize,
              badgeSize: DesktopTokens.sidePanelAvatarBadgeSize,
              vipStatus: userStat.card?.vip?.status,
              officialType: userStat.card?.official?.type,
            ),
            Column(
              crossAxisAlignment: .start,
              children: [
                Text(
                  userStat.card?.name ?? "",
                  maxLines: 1,
                  overflow: .ellipsis,
                  style: TextStyle(
                    fontSize: DesktopTokens.sidePanelNameFontSize,
                    // 桌面右栏视觉层级：UP 主名称（主文字色 + w500）强于
                    // 统计 / 简介正文（次级文字色），弱于视频标题
                    fontWeight: PlatformUtils.isDesktop && !widget.isPortrait
                        ? .w500
                        : null,
                    color: isVip && userStat.card?.vip?.type == 2
                        ? colorScheme.vipColor
                        : PlatformUtils.isDesktop && !widget.isPortrait
                        ? DesktopTokens.titleColor(colorScheme)
                        : DesktopTokens.subtitleColor(colorScheme),
                  ),
                ),
                Text(
                  '${NumUtils.numFormat(userStat.follower)}粉丝    ${'${NumUtils.numFormat(userStat.archiveCount)}视频'}',
                  style: TextStyle(
                    fontSize: DesktopTokens.sidePanelSecondaryFontSize,
                    color: DesktopTokens.subtitleColor(colorScheme),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );

  Widget _buildInfo(VideoStat? stat, int? pubdate) {
    final subtitleColor = DesktopTokens.subtitleColor(colorScheme);
    return Row(
      spacing: DesktopTokens.sidePanelSp(10),
          children: [
            StatWidget(
              type: .play,
              value: stat?.view,
              color: subtitleColor,
              iconSize: DesktopTokens.sidePanelSp(13),
              fontSize: DesktopTokens.sidePanelSecondaryFontSize,
            ),
            StatWidget(
              type: .danmaku,
              value: stat?.danmaku,
              color: subtitleColor,
              iconSize: DesktopTokens.sidePanelSp(13),
              fontSize: DesktopTokens.sidePanelSecondaryFontSize,
            ),
            Text(
              DateFormatUtils.format(pubdate),
              style: TextStyle(
                fontSize: DesktopTokens.sidePanelSecondaryFontSize,
                color: subtitleColor,
              ),
            ),
            if (MineController.anonymity.value)
              Icon(
                MdiIcons.incognito,
                size: DesktopTokens.sidePanelSp(15),
                color: subtitleColor,
                semanticLabel: '无痕',
              ),
            if (introController.isShowOnlineTotal)
              Obx(
                () => Text(
                  '${introController.total.value}人在看',
                  style: TextStyle(
                    fontSize: DesktopTokens.sidePanelSecondaryFontSize,
                    color: subtitleColor,
                  ),
                ),
              ),
          ],
        );
  }

  Widget get _aiBtn => Positioned(
    right: 8,
    child: Center(
      child: GestureDetector(
        behavior: .opaque,
        onTap: () async {
          if (introController.aiConclusionResult == null) {
            await introController.aiConclusion();
          }
          if (introController.aiConclusionResult case AiConclusionResult(
            :final summary,
            :final outline,
          )) {
            if (summary?.isNotEmpty == true || outline?.isNotEmpty == true) {
              widget.showAiBottomSheet();
            } else {
              SmartDialog.showToast("当前视频不支持AI视频总结");
            }
          }
        },
        child: Image.asset(
          semanticLabel: 'AI总结',
          Assets.ai,
          height: 18,
          width: 18,
          cacheHeight: 18.cacheSize(context),
        ),
      ),
    ),
  );

  Widget _buildTags(List<VideoTagItem> tags) {
    return Padding(
      padding: const .only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: tags
            .map(
              (item) => SearchText(
                fontSize: 13,
                text: switch (item.tagType) {
                  'bgm' => item.tagName!.replaceFirst('发现', '♫ BGM：'),
                  'topic' => '#${item.tagName}',
                  _ => item.tagName!,
                },
                onTap: switch (item.tagType) {
                  'bgm' => (_) => Get.toNamed(
                    '/musicDetail',
                    parameters: {'musicId': item.musicId!},
                  ),
                  'topic' => (_) => Get.toNamed(
                    '/dynTopic',
                    parameters: {'id': item.tagId!.toString()},
                  ),
                  _ => (tagName) => Get.toNamed(
                    '/searchResult',
                    parameters: {'keyword': tagName},
                  ),
                },
                onLongPress: PlatformUtils.isMobile ? Utils.copyText : null,
              ),
            )
            .toList(),
      ),
    );
  }
}
