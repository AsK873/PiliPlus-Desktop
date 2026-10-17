import 'dart:async';
import 'dart:math';

import 'package:PiliPlus/common/assets.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/badge.dart';
import 'package:PiliPlus/common/widgets/button/icon_button.dart';
import 'package:PiliPlus/common/widgets/image/image_save.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/keep_alive_wrapper.dart';
import 'package:PiliPlus/common/widgets/scroll_physics.dart'
    show tabBarScrollPhysics;
import 'package:PiliPlus/common/widgets/stat/stat.dart';
import 'package:PiliPlus/http/fav.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models/common/episode_panel_type.dart';
import 'package:PiliPlus/models/common/stat_type.dart';
import 'package:PiliPlus/models_new/pgc/pgc_info_model/episode.dart' as pgc;
import 'package:PiliPlus/models_new/video/video_detail/episode.dart' as ugc;
import 'package:PiliPlus/models_new/video/video_detail/page.dart';
import 'package:PiliPlus/pages/common/slide/common_slide_page.dart';
import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/controller.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/widgets/page.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/date_utils.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/utils/extension/num_ext.dart';
import 'package:PiliPlus/utils/extension/scroll_controller_ext.dart';
import 'package:PiliPlus/utils/id_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class EpisodePanel extends CommonSlidePage {
  const EpisodePanel({
    super.key,
    super.enableSlide,
    required this.ugcIntroController,
    required this.heroTag,
    required this.type,
    // required this.count,
    // required this.name,
    required this.aid,
    required this.bvid,
    required this.cid,
    required this.cover,
    this.showTitle = true,
    required this.list,
    this.seasonId,
    this.initialTabIndex = 0,
    this.isSupportReverse,
    this.isReversed,
    this.onReverse,
    required this.onChangeEpisode,
    this.onClose,
    this.bottomPadding,
  }) : assert(type == EpisodeType.pgc || ugcIntroController != null);

  final UgcIntroController? ugcIntroController;
  final String heroTag;
  final EpisodeType type;
  // final int count;
  // final String name;
  final int? aid;
  final String bvid;
  final int cid;
  final String? cover;
  final bool showTitle;
  final List list;
  final int? seasonId;
  final int initialTabIndex;
  final bool? isSupportReverse;
  final bool? isReversed;
  final Future<bool> Function(ugc.BaseEpisodeItem) onChangeEpisode;
  final VoidCallback? onReverse;
  final VoidCallback? onClose;

  /// 列表底部留白；为空时沿用弹层口径（viewPadding.bottom + 100）。
  /// 右栏内嵌的「固定高度播放列表」用它收紧留白，避免小视口被底部空白占满。
  final double? bottomPadding;

  /// 播放列表条目**标题**的视觉规格（单一来源）。
  ///
  /// 桌面右栏「相关推荐」的视频标题直接复用本规格，保证两者字号 / 字体 /
  /// 行高 / 字距完全一致；不再单独定义另一套字号。
  static TextStyle? itemTitleStyle(
    ThemeData theme, {
    bool isCurrentIndex = false,
    Color? highlightColor,
  }) => TextStyle(
    fontSize: theme.textTheme.bodyMedium!.fontSize,
    height: 1.42,
    letterSpacing: 0.3,
    fontWeight: isCurrentIndex ? FontWeight.bold : null,
    color: isCurrentIndex ? highlightColor : null,
  );

  /// 播放列表条目**次级信息**（日期 / 数据）的视觉规格（单一来源）。
  static TextStyle? itemMetaStyle(ThemeData theme) => TextStyle(
    fontSize: 12,
    height: 1,
    color: theme.colorScheme.outline,
    overflow: TextOverflow.clip,
  );

  @override
  State<EpisodePanel> createState() => _EpisodePanelState();
}

class _EpisodePanelState extends State<EpisodePanel>
    with TickerProviderStateMixin, CommonSlideMixin {
  // tab
  late final TabController _tabController;
  late final RxInt _currentTabIndex = _tabController.index.obs;

  late final showTitle = widget.showTitle;

  List<ugc.BaseEpisodeItem> get _getCurrEpisodes =>
      widget.type == EpisodeType.season
      ? widget.list[_currentTabIndex.value].episodes
      : widget.list[_currentTabIndex.value];

  // item
  late int _currentItemIndex;
  int get _findCurrentItemIndex => max(
    0,
    _getCurrEpisodes.indexWhere((item) => item.cid == widget.cid),
  );

  late final List<bool> _isReversed;
  late final List<ScrollController> _itemScrollController;

  // fav
  Rx<LoadingState<bool>>? _favState;

  void listener() {
    _currentTabIndex.value = _tabController.index;
  }

  @override
  void didUpdateWidget(EpisodePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (showTitle) {
      return;
    }

    @pragma('vm:notify-debugger-on-exception')
    void jumpToCurrent() {
      final newItemIndex = _findCurrentItemIndex;
      if (_currentItemIndex != newItemIndex) {
        _currentItemIndex = newItemIndex;
        try {
          _itemScrollController[_currentTabIndex.value].jumpTo(
            _calcItemOffset(newItemIndex),
          );
        } catch (e, s) {
          Utils.reportError(e, s);
        }
      }
    }

    // jump to current
    if (_currentTabIndex.value != widget.initialTabIndex) {
      _tabController.animateTo(
        widget.initialTabIndex,
        duration: const Duration(milliseconds: 200),
      );
      Timer(const Duration(milliseconds: 300), jumpToCurrent);
    } else {
      jumpToCurrent();
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      initialIndex: widget.initialTabIndex,
      length: widget.list.length,
      vsync: this,
    )..addListener(listener);

    _currentItemIndex = _findCurrentItemIndex;
    _itemScrollController = List.generate(
      widget.list.length,
      (i) => ScrollController(
        initialScrollOffset: i == widget.initialTabIndex
            ? _currentItemIndex == 0
                  ? 0
                  : _calcItemOffset(_currentItemIndex)
            : 0,
      ),
      growable: false,
    );
    _isReversed = List.filled(widget.list.length, false);

    if (widget.type == EpisodeType.season && Accounts.main.isLogin) {
      final favState =
          widget.ugcIntroController?.seasonFavState[widget.seasonId];
      if (favState != null) {
        _favState = Success(favState).obs;
      } else {
        _favState = LoadingState<bool>.loading().obs;
        VideoHttp.videoRelation(bvid: widget.bvid).then(
          (result) {
            if (!mounted) return;
            if (result case Success(:final response)) {
              final seasonFav = response.seasonFav ?? false;
              _favState!.value = Success(seasonFav);
              widget.ugcIntroController?.seasonFavState[widget.seasonId] =
                  seasonFav;
            }
          },
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(listener)
      ..dispose();
    _favState?.close();
    for (final e in _itemScrollController) {
      e.dispose();
    }
    super.dispose();
  }

  late final _isMulti =
      widget.type == EpisodeType.season && widget.list.length > 1;

  @override
  Widget buildPage(ThemeData theme) {
    return Material(
      color: showTitle ? theme.colorScheme.surface : null,
      type: showTitle ? MaterialType.canvas : MaterialType.transparency,
      child: Column(
        children: [
          _buildToolbar(theme),
          if (_isMulti)
            TabBar(
              controller: _tabController,
              padding: const EdgeInsets.only(right: 60),
              isScrollable: true,
              tabs: widget.list.map((item) => Tab(text: item.title)).toList(),
              dividerHeight: 1,
              dividerColor: theme.dividerColor.withValues(alpha: 0.1),
            ),
          Expanded(child: enableSlide ? slideList(theme) : buildList(theme)),
        ],
      ),
    );
  }

  @override
  Widget buildList(ThemeData theme) {
    if (_isMulti) {
      return TabBarView(
        controller: _tabController,
        physics: tabBarScrollPhysics,
        horizontalDragGestureRecognizer: horizontalDragGestureRecognizer,
        children: List.generate(
          widget.list.length,
          (index) => _buildBody(
            theme,
            index,
            widget.list[index].episodes,
          ),
        ),
      );
    }
    return _buildBody(theme, 0, _getCurrEpisodes);
  }

  double _calcItemOffset(int index) {
    if (showTitle) {
      final episodes = _getCurrEpisodes;
      double offset = 0;
      for (var i = 0; i < index; i++) {
        offset += _calcItemHeight(episodes[i]);
      }
      return offset + 7;
    } else {
      return index * 112 + 7;
    }
  }

  double _calcItemHeight(ugc.BaseEpisodeItem episode) {
    if (episode is ugc.EpisodeItem && episode.pages!.length > 1) {
      return 167; // 110 + 2 + 10 + 45
    }
    return 112;
  }

  Widget _buildBody(
    ThemeData theme,
    int tabIndex,
    List<ugc.BaseEpisodeItem> episodes,
  ) {
    final isCurrTab = tabIndex == widget.initialTabIndex;
    return KeepAliveWrapper(
      child: CustomScrollView(
        reverse: _isReversed[tabIndex],
        physics: const AlwaysScrollableScrollPhysics(),
        controller: _itemScrollController[tabIndex],
        slivers: [
          SliverPadding(
            padding: EdgeInsets.only(
              top: 7,
              bottom: widget.bottomPadding ??
                  MediaQuery.viewPaddingOf(context).bottom + 100,
            ),
            sliver: showTitle
                ? SliverVariedExtentList.builder(
                    itemCount: episodes.length,
                    itemBuilder: (context, index) {
                      final episode = episodes[index];
                      final isCurrItem = isCurrTab
                          ? index == _currentItemIndex
                          : false;
                      Widget episodeItem = _buildEpisodeItem(
                        theme: theme,
                        episode: episode,
                        index: index,
                        length: episodes.length,
                        isCurrentIndex: isCurrItem,
                      );
                      if (episode is ugc.EpisodeItem &&
                          episode.pages!.length > 1) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            episodeItem, // 110
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ), // 10
                              child: PagesPanel(
                                // 45
                                list: isCurrTab && isCurrItem
                                    ? null
                                    : episode.pages,
                                cover: episode.arc?.pic,
                                heroTag: widget.heroTag,
                                ugcIntroController: widget.ugcIntroController!,
                                bvid:
                                    episode.bvid ?? IdUtils.av2bv(episode.aid!),
                              ),
                            ),
                          ],
                        );
                      }
                      return episodeItem;
                    },
                    itemExtentBuilder: (index, _) =>
                        _calcItemHeight(episodes[index]),
                  )
                : SliverFixedExtentList.builder(
                    itemCount: episodes.length,
                    itemBuilder: (context, index) {
                      final episode = episodes[index];
                      final isCurrItem = isCurrTab
                          ? index == _currentItemIndex
                          : false;
                      return _buildEpisodeItem(
                        theme: theme,
                        episode: episode,
                        index: index,
                        length: episodes.length,
                        isCurrentIndex: isCurrItem,
                      );
                    },
                    itemExtent: 112,
                  ),
          ),
        ],
      ),
    );
  }

  late final int? vipStatus = Pref.userInfoCache?.vipStatus;

  /// 播放列表简约菜单尺寸（宽约 160~175、行高约 36~40）。
  static const double _kPlaylistMenuWidth = 172;
  static const double _kPlaylistMenuRowHeight = 38;

  Widget _buildEpisodeItem({
    required ThemeData theme,
    required ugc.BaseEpisodeItem episode,
    required int index,
    required int length,
    required bool isCurrentIndex,
  }) {
    late String title;
    String? cover;
    String? bvid;
    num? duration;
    int? pubdate;
    int? view;
    int? danmaku;
    bool? isCharging;
    bool? cacheWidth;

    switch (episode) {
      case Part part:
        cover = part.firstFrame ?? widget.cover;
        title = part.part!;
        duration = part.duration;
        pubdate = part.ctime;
        cacheWidth = part.dimension?.cacheWidth;
        break;
      case ugc.EpisodeItem item:
        title = item.title!;
        bvid = item.bvid;
        if (item.arc case final arc?) {
          cover = arc.pic;
          duration = arc.duration;
          pubdate = arc.pubdate;
          if (arc.stat case final stat?) {
            view = stat.view;
            danmaku = stat.danmaku;
          }
          cacheWidth = arc.dimension?.cacheWidth;
        }
        if (item.attribute == 8) {
          isCharging = true;
        }
        break;
      case pgc.EpisodeItem item:
        bvid = item.bvid;
        title = item.showTitle ?? item.title!;
        cover = item.cover;
        if (item.from == 'pugv') {
          duration = item.duration;
          view = item.play;
        } else {
          duration = item.duration == null ? null : item.duration! ~/ 1000;
        }
        pubdate = item.pubTime;
        cacheWidth = item.dimension?.cacheWidth;
        break;
    }
    late final Color primary = theme.colorScheme.primary;

    void onLongPress() {
      if (cover?.isNotEmpty == true) {
        imageSaveDialog(title: title, cover: cover, bvid: bvid);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: SizedBox(
        height: 110,
        child: Material(
          type: .transparency,
          child: InkWell(
            onTap: () {
              if (isCurrentIndex) return;
              if (episode.badge == "会员" &&
                  Accounts.mainEqVideo &&
                  vipStatus != 1) {
                SmartDialog.showToast('需要大会员');
                // return;
              }
              SmartDialog.showToast('切换到：$title');
              widget.onClose?.call();

              widget.onChangeEpisode(episode).then((res) {
                if (res) {
                  if (!showTitle) {
                    _currentItemIndex = index;
                  }
                  if (widget.type == EpisodeType.season) {
                    try {
                      Get.find<VideoDetailController>(
                        tag: widget.ugcIntroController!.heroTag,
                      ).seasonCid = episode.cid;
                    } catch (_) {
                      if (kDebugMode) rethrow;
                    }
                  }
                }
              });
            },
            onLongPress: PlatformUtils.isMobile ? onLongPress : null,
            onSecondaryTap: PlatformUtils.isMobile ? null : onLongPress,
            child: Padding(
              padding: const .symmetric(
                horizontal: Style.safeSpace,
                vertical: 5,
              ),
              child: Row(
                spacing: 10,
                children: [
                  if (cover?.isNotEmpty == true)
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        NetworkImgLayer(
                          src: cover,
                          width: 160,
                          height: 100,
                          cacheWidth: cacheWidth,
                        ),
                        if (duration != null && duration > 0)
                          PBadge(
                            text: DurationUtils.formatDuration(duration),
                            right: 6.0,
                            bottom: 6.0,
                            type: .gray,
                          ),
                        if (widget.type == .part)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              padding: const .symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondaryContainer,
                                borderRadius: const .only(
                                  bottomLeft: .circular(4),
                                  topRight: Style.imgRadius,
                                ),
                              ),
                              child: Text(
                                (index + 1).toString(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ),
                          )
                        else if (isCharging == true)
                          const PBadge(
                            text: '充电专属',
                            top: 6,
                            right: 6,
                            type: .error,
                          )
                        else if (episode.badge != null)
                          PBadge(
                            text: episode.badge,
                            top: 6,
                            right: 6,
                            type: switch (episode.badge) {
                              '预告' => .gray,
                              '限免' => .free,
                              _ => .primary,
                            },
                          ),
                      ],
                    )
                  else if (isCurrentIndex)
                    Image.asset(
                      Assets.livingStatic,
                      color: primary,
                      height: 12,
                      cacheHeight: 12.cacheSize(context),
                      semanticLabel: "正在播放：",
                    ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            textAlign: TextAlign.start,
                            // 与「相关推荐」视频标题共用同一份规格
                            style: EpisodePanel.itemTitleStyle(
                              theme,
                              isCurrentIndex: isCurrentIndex,
                              highlightColor: primary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (pubdate != null)
                          Text(
                            DateFormatUtils.format(pubdate),
                            maxLines: 1,
                            style: EpisodePanel.itemMetaStyle(theme),
                          ),
                        if (view != null) ...[
                          const SizedBox(height: 2),
                          Row(
                            spacing: 8,
                            children: [
                              StatWidget(
                                value: view,
                                type: StatType.play,
                              ),
                              if (danmaku != null)
                                StatWidget(
                                  value: danmaku,
                                  type: StatType.danmaku,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 跳至顶部 / 跳至底部（原工具栏两个按钮的实现）
  void _animToTopOrBottom({bool top = true}) {
    final tabIndex = _currentTabIndex.value;
    _itemScrollController[tabIndex].animTo(
      top ^ _isReversed[tabIndex]
          ? 0
          : _calcItemOffset(_getCurrEpisodes.length),
      duration: const Duration(milliseconds: 200),
    );
  }

  /// 订阅 / 取消订阅（原工具栏订阅按钮的实现；现由 `⋮` 菜单调用）
  Future<void> _toggleSeasonFav(bool subscribed) async {
    final res = await FavHttp.seasonFav(
      isFav: subscribed,
      seasonId: widget.seasonId,
    );
    if (res.isSuccess) {
      SmartDialog.showToast('${subscribed ? '取消' : ''}订阅成功');
      _favState?.value = Success(!subscribed);
      widget.ugcIntroController?.seasonFavState[widget.seasonId] =
          !subscribed;
    } else {
      res.toast();
    }
  }

  /// 播放列表菜单按钮：保留原「排序/视图」按钮的位置，图标改为 `⋮`。
  Widget get _menuButton => Builder(
    builder: (btnContext) => iconButton(
      iconSize: 22,
      tooltip: '播放列表菜单',
      icon: const Icon(Icons.more_vert),
      onPressed: () => _showPlaylistMenu(btnContext),
    ),
  );

  /// 简约风 Context Menu（复用工程现有 `showMenu` + `PopupMenuItem` 体系）：
  ///
  /// - 以按钮**右缘**为锚点，向左展开（菜单整体落在右栏内）；
  /// - 宽 172（约 160~175）、行高 38、纯文字（无图标 / 分割线 / 标题 / 数量 / 箭头）；
  /// - Hover 只用 [PopupMenuItem] 自带的淡背景；圆角与轻微阴影由主题负责；
  /// - 点击菜单外或选中任一项即关闭（`showMenu` 默认行为）。
  ///
  /// 菜单项**只列当前真正可用的能力**（复用既有实现，不新增业务逻辑）：
  /// 订阅（仅合集）/ 顺序·倒序（播放列表内视图顺序）/ 跳至顶部 / 跳至当前。
  Future<void> _showPlaylistMenu(BuildContext btnContext) async {
    if (!mounted) {
      return;
    }
    final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
    final button = btnContext.findRenderObject();
    if (overlay is! RenderBox || button is! RenderBox) {
      return;
    }
    // 按钮右缘（全局坐标）→ 叠加层坐标，作为菜单右边界：菜单向左展开
    final anchor = overlay.globalToLocal(button.localToGlobal(Offset.zero));
    final right = anchor.dx;
    final tabIndex = _currentTabIndex.value;
    await showMenu<void>(
      context: context,
      position: RelativeRect.fromLTRB(
        right - _kPlaylistMenuWidth,
        anchor.dy,
        right,
        anchor.dy,
      ),
      constraints: const BoxConstraints.tightFor(width: _kPlaylistMenuWidth),
      items: [
        for (final item in _playlistMenuItems(tabIndex))
          PopupMenuItem<void>(
            height: _kPlaylistMenuRowHeight,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            onTap: item.onTap,
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
      ],
    );
  }

  /// 菜单项 = 原工具栏 6 个功能的**完全替代**（不是追加）：
  ///
  /// 1. 订阅 / 取消订阅（仅合集；原 `_buildFavBtn` 的实现）
  /// 2. 跳至顶部（原「跳至顶部」按钮）
  /// 3. 跳至底部（原「跳至底部」按钮）
  /// 4. 跳至当前（原「跳至当前」按钮）
  /// 5. 正序播放（原「正序/倒序播放」按钮：`widget.onReverse`）
  /// 6. 倒序播放（同上，同一份 `widget.isReversed` 状态）
  /// 7. 顺序 / 倒序（原最右侧「排序/视图」按钮：`_isReversed[tab]`）
  ///
  /// 只在原工具栏**确实渲染该按钮**时才出现同一条目，逻辑 / 状态 / 点击行为
  /// 全部复用原有实现，仅入口位置从工具栏移到本菜单。
  List<({String label, VoidCallback onTap})> _playlistMenuItems(int tabIndex) {
    final items = <({String label, VoidCallback onTap})>[];
    // 1) 订阅 / 取消订阅（原 `_buildFavBtn`：仅合集有 `_favState`）
    if (_favState case final favState?) {
      final subscribed = favState.value is Success;
      items.add((
        label: subscribed ? '取消订阅' : '订阅',
        onTap: () => _toggleSeasonFav(subscribed),
      ));
    }
    // 2)~4) 跳至顶部 / 跳至底部 / 跳至当前（原三个 iconButton）
    items
      ..add((label: '跳至顶部', onTap: _animToTopOrBottom))
      ..add((
        label: '跳至底部',
        onTap: () => _animToTopOrBottom(top: false),
      ))
      ..add((label: '跳至当前', onTap: _jumpToCurrent));
    // 5)~6) 正序 / 倒序播放（原 `_buildReverseBtn`：与原工具栏同一渲染条件）
    if (widget.isSupportReverse == true &&
        tabIndex == widget.initialTabIndex) {
      items
        ..add((label: '正序播放', onTap: () => _setReversePlay(false)))
        ..add((label: '倒序播放', onTap: () => _setReversePlay(true)));
    }
    // 7) 顺序 / 倒序（原最右侧「排序/视图」按钮：切换 `_isReversed`）
    items.add((
      label: _isReversed[tabIndex] ? '倒序（当前）' : '顺序（当前）',
      onTap: () => setState(() {
        _isReversed[tabIndex] = !_isReversed[tabIndex];
      }),
    ));
    return items;
  }

  /// 正序 / 倒序播放（原「正序/倒序播放」按钮：只在状态不同时调用 `onReverse`）
  void _setReversePlay(bool reversed) {
    if ((widget.isReversed == true) == reversed) {
      return;
    }
    widget.onReverse?.call();
  }

  /// 跳至当前（复用原工具栏按钮的实现）
  Future<void> _jumpToCurrent() async {
    final currentTabIndex = _currentTabIndex.value;
    if (currentTabIndex != widget.initialTabIndex) {
      _tabController.animateTo(widget.initialTabIndex);
      await Future.pause(const Duration(milliseconds: 225));
    }
    if (!mounted) {
      return;
    }
    _itemScrollController[widget.initialTabIndex].animTo(
      _calcItemOffset(_currentItemIndex),
      duration: const Duration(milliseconds: 200),
    );
  }

  Widget _buildToolbar(ThemeData theme) => Container(
    height: 45,
    padding: EdgeInsets.symmetric(horizontal: showTitle ? 14 : 6),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(
          color: theme.dividerColor.withValues(alpha: 0.1),
        ),
      ),
    ),
    child: Row(
      children: [
        if (showTitle)
          Text(
            widget.type.title,
            style: theme.textTheme.titleMedium,
          ),
        // 左侧文字入口：「选集 当前序号/总数」。
        // 序号取当前选中的选集/分P（`_currentItemIndex`），总数取当前实际
        // 选集数量（`_getCurrEpisodes.length`），均非写死；
        // 用 Obx 跟随页签切换与选集更新时重建。
        Obx(
          () => Text(
            '选集 ${_currentItemIndex + 1}/${_getCurrEpisodes.length}',
            style: theme.textTheme.bodyMedium,
          ),
        ),
        // 说明：原工具栏左侧的 5 个功能按钮（订阅 / 跳至顶部 / 跳至底部 /
        // 跳至当前 / 正序·倒序播放）与最右侧的排序视图按钮，**全部收进右侧
        // `⋮` 菜单**（见 [_playlistMenuItems]），入口位置不变、逻辑与状态原样复用。
        const Spacer(),
        _menuButton,
        if (widget.onClose != null)
          iconButton(
            iconSize: 22,
            tooltip: '关闭',
            icon: const Icon(Icons.close),
            onPressed: widget.onClose,
          ),
      ],
    ),
  );
}
