import 'dart:math';

import 'package:PiliPlus/common/widgets/fractionally_sized_box.dart';
import 'package:PiliPlus/common/widgets/image_viewer/gallery_viewer.dart';
import 'package:PiliPlus/common/widgets/image_viewer/hero_dialog_route.dart';
import 'package:PiliPlus/grpc/im.dart';
import 'package:PiliPlus/http/dynamics.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/search.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models/common/image_preview_type.dart';
import 'package:PiliPlus/models/common/video/video_type.dart';
import 'package:PiliPlus/models/dynamics/result.dart';
import 'package:PiliPlus/models_new/pgc/pgc_info_model/episode.dart';
import 'package:PiliPlus/models_new/video/video_detail/data.dart';
import 'package:PiliPlus/models_new/video/video_detail/dimension.dart';
import 'package:PiliPlus/pages/common/common_intro_controller.dart';
import 'package:PiliPlus/pages/common/publish/publish_route.dart';
import 'package:PiliPlus/pages/contact/view.dart';
import 'package:PiliPlus/pages/fav_panel/popover.dart';
import 'package:PiliPlus/pages/fav_panel/view.dart';
import 'package:PiliPlus/pages/share/view.dart';
import 'package:PiliPlus/utils/android/android_helper.dart';
import 'package:PiliPlus/utils/app_scheme.dart';
import 'package:PiliPlus/utils/extension/context_ext.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:PiliPlus/utils/extension/size_ext.dart';
import 'package:PiliPlus/utils/extension/string_ext.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/id_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/url_utils.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

abstract final class PageUtils {
  static RelativeRect menuPosition(Offset offset) {
    return .fromLTRB(offset.dx, offset.dy, offset.dx, 0);
  }

  static Future<void> imageView({
    int initialPage = 0,
    required List<SourceModel> imgList,
    int? quality,
    ValueChanged<int>? onPageChanged,
    String tag = '',
  }) {
    return Get.key.currentState!.push<void>(
      HeroDialogRoute(
        pageBuilder: (context, animation, secondaryAnimation) => GalleryViewer(
          sources: imgList,
          initIndex: initialPage,
          quality: quality ?? GlobalData().imgQuality,
          onPageChanged: onPageChanged,
          tag: tag,
        ),
      ),
    );
  }

  static Future<void> pmShare(
    BuildContext context, {
    required Map content,
  }) async {
    // if (kDebugMode) debugPrint(content.toString());

    List<UserModel> userList = <UserModel>[];

    final res = await ImGrpc.shareList(size: 5);
    if (res case Success(:final response)) {
      if (response.sessionList.isNotEmpty) {
        userList.addAll(
          response.sessionList.map<UserModel>(
            (item) => UserModel(
              mid: item.talkerId.toInt(),
              name: item.talkerUname,
              avatar: item.talkerIcon,
            ),
          ),
        );
      }
    }

    if (userList.isEmpty && context.mounted) {
      final UserModel? userModel = await Navigator.of(context).push(
        GetPageRoute(page: () => const ContactPage()),
      );
      if (userModel != null) {
        userList.add(userModel);
      }
    }

    if (context.mounted) {
      showModalBottomSheet(
        context: context,
        builder: (context) => SharePanel(
          content: content,
          userList: userList,
        ),
        useSafeArea: true,
        enableDrag: false,
        isScrollControlled: true,
      );
    }
  }

  static Future<void> pushDynFromId({
    String? id,
    Object? rid,
    bool off = false,
    Object? type,
  }) async {
    assert(id != null || rid != null);
    SmartDialog.showLoading();
    final res = await DynamicsHttp.dynamicDetail(
      id: id,
      rid: rid,
      type: rid != null ? 2 : null,
    );
    SmartDialog.dismiss();
    if (res case Success(:final response)) {
      if (response.basic?.commentType == 12) {
        toDupNamed(
          '/articlePage',
          parameters: {
            'id': id!,
            'type': 'opus',
          },
          off: off,
        );
      } else {
        toDupNamed(
          '/dynamicDetail',
          arguments: {
            'item': response,
          },
          off: off,
        );
      }
    } else {
      SmartDialog.showToast('${type != null ? 'type: $type ' : ''}$res');
    }
  }

  /// 收藏夹选择面板入口（收藏按钮统一走这里）。
  ///
  /// - **桌面端**：一律走锚定收藏按钮的 [showFavPanel]（Popover），
  ///   **不会再进入 [showModalBottomSheet]**，因此桌面上不存在旧底部面板；
  /// - **移动端**：保持原有底部面板（`FavPanel`）的布局、拖动与关闭行为不变。
  ///
  /// [anchorContext] 为收藏按钮自身的 `BuildContext`（由按钮外层 `Builder` 提供），
  /// 仅桌面端 Popover 定位使用；为空时回退到 [context] 所在渲染对象。
  static void showFavBottomSheet({
    required BuildContext context,
    required FavMixin ctr,
    BuildContext? anchorContext,
  }) {
    if (PlatformUtils.isDesktop) {
      showFavPanel(
        context: context,
        anchorContext: anchorContext ?? context,
        ctr: ctr,
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      // 移动端保持原有宽度约束不变
      constraints: BoxConstraints(maxWidth: min(640, context.mediaQueryShortestSide)),
      builder: (BuildContext context) {
        final maxChildSize = context.mediaQuerySize.isPortrait ? 0.7 : 1.0;
        return DraggableScrollableSheet(
          minChildSize: 0,
          maxChildSize: 1,
          snap: true,
          expand: false,
          snapSizes: [maxChildSize],
          initialChildSize: maxChildSize,
          builder: (BuildContext context, ScrollController scrollController) {
            return FavPanel(
              ctr: ctr,
              scrollController: scrollController,
            );
          },
        );
      },
    );
  }

  /// 桌面端：锚定收藏按钮的收藏夹 Popover。
  ///
  /// 定位与尺寸全部按下列规则**在每次布局时**重新计算（`showMenu` 的
  /// `positionBuilder` 由框架在布局期调用，见 `material_ui/src/popup_menu.dart`
  /// 的 `LayoutBuilder` → `_PopupMenuRouteLayout` 链路），因此窗口最大化 /
  /// 还原 / 缩放、以及简介展开收起导致的锚点漂移都能自动跟随：
  /// - 锚点：按钮在 **Overlay 坐标系**下的矩形。两个 RenderBox 只在打开时
  ///   捕获一次（与 vendored `_positionBuilder` 的官方做法一致），但每次
  ///   布局都用 `globalToLocal` 重新求当前矩形，避免使用过期坐标；
  /// - 方向：优先向下展开；下方放不下「可用最小高度」时改为向上（贴按钮上缘）；
  /// - 高度：`min(目标高度, 该方向实际可用高度)`，随窗口高度变化；
  /// - 宽度：目标 320，且不超过窗口宽度 − 2×安全边距，随窗口宽度变化；
  /// - 水平：以按钮左缘为基准，`showMenu` 在靠右时自动改为向左展开贴右缘；
  /// - 关闭：点击面板外部 / Esc 由 `showMenu` 的路由处理；「取消」= `Get.back()`；
  ///   「完成」= `actionFavVideo()`（内部提交成功后 `Get.back()`）。
  static void showFavPanel({
    required BuildContext context,
    required BuildContext anchorContext,
    required FavMixin ctr,
  }) {
    final overlayState = Overlay.maybeOf(context);
    final overlayBox = overlayState?.context.findRenderObject();
    final anchorBox = anchorContext.findRenderObject();
    if (overlayState == null ||
        overlayBox is! RenderBox ||
        anchorBox is! RenderBox ||
        !anchorBox.hasSize) {
      return;
    }

    // 打开瞬间的布局：用于本次约束与 FavPopover 的高度。
    // 注意 FavPopover 的高度必须**显式给定**：`showMenu` 会把菜单内容包进
    // `SingleChildScrollView`，否则 `Column` + `Expanded` 拿到的是无界高度约束
    // （表现为 RenderFlex 报错且内容塌陷为 0）。
    final initial = _favPanelLayout(overlayBox, anchorBox);

    showMenu<void>(
      context: context,
      // 传 positionBuilder 而**不是** position：两者互斥（同时传会命中
      // assert((position != null) != (positionBuilder != null))），
      // 且只有 builder 会在每次布局更新时被重新调用。
      positionBuilder: (_, _) => _favPanelLayout(overlayBox, anchorBox).rect,
      // 宽度：`showMenu` 的 `constraints` 在路由创建时固定（vendored
      // `_PopupMenu` 用它覆盖默认 min/max 宽，见 `popup_menu.dart:770-773`），
      // 框架没有提供「每次布局重新求宽度」的入口，故这里只能是打开时刻的值。
      // 该冻结值不会长期失真：`FavPopover` 在窗口指标（尺寸/DPI）变化时会主动
      // 收起面板（见 `fav_panel/popover.dart` 的 `didChangeMetrics`），重新打开
      // 即按新窗口计算。高度不再冻结，见下面的 `preferredHeight`。
      constraints: BoxConstraints.tightFor(width: initial.width),
      items: [
        PopupMenuItem<void>(
          enabled: false,
          padding: EdgeInsets.zero,
          // 不使用 PopupMenuItem.height 参数，避免与 FavPopover 内部定高重复
          child: FavPopover(
            ctr: ctr,
            // 兜底高度（打开时刻的值）：仅在 preferredHeight 不可用时使用
            height: initial.height,
            // 期望高度**每次布局**重算（与 positionBuilder 同源），
            // 避免窗口变高后面板仍被打开时刻的高度冻结（只减不增）。
            preferredHeight: () => _favPanelLayout(overlayBox, anchorBox).height,
          ),
        ),
      ],
    );
  }

  /// 收藏夹 Popover 在**当前窗口尺寸 + 当前按钮位置**下的布局结果。
  ///
  /// 每次布局期都会被调用（`positionBuilder`），因此必须只依赖**当次**读到的
  /// 实时尺寸，不得缓存任何一帧的 overlay 尺寸或锚点坐标。
  static ({bool below, double width, double height, RelativeRect rect})
  _favPanelLayout(RenderBox overlayBox, RenderBox anchorBox) {
    // 按钮可能在本面板存续期间被销毁（例如切换视频）：失配时退化为
    // 「贴窗口左上角」，由 showMenu 自身钳制，避免对已 detach 的 RenderBox 取值。
    if (!anchorBox.attached || !overlayBox.attached || !anchorBox.hasSize) {
      return (
        below: true,
        width: 320,
        height: 240,
        rect: const RelativeRect.fromLTRB(0, 0, 320, 0),
      );
    }

    final overlaySize = overlayBox.size;
    final anchorRect =
        overlayBox.globalToLocal(anchorBox.localToGlobal(Offset.zero)) &
        anchorBox.size;

    const double safeGap = 8; // 与窗口边缘的安全间距
    const double anchorGap = 6; // 面板与按钮之间的间距
    const double targetWidth = 320;
    const double targetHeight = 420;
    const double minHeight = 220;

    // 上下两侧实际可用高度
    final double below =
        overlaySize.height - anchorRect.bottom - safeGap - anchorGap;
    final double above = anchorRect.top - safeGap - anchorGap;

    // 优先向下：下方能放下「可用最小高度」就向下；否则选上下空间更大的一侧
    final bool showBelow = below >= minHeight
        ? true
        : (above > below ? false : below >= above);

    final double available = max(0, showBelow ? below : above);
    // 高度：不超目标高度，也不超该方向实际可用高度
    final double height = min(targetHeight, available);
    // 宽度：不超目标宽度，也不超窗口宽度（留出两侧安全间距）
    final double width = min(targetWidth, overlaySize.width - 2 * safeGap);

    // `RelativeRect` 的四个分量都是「距对应边缘的距离」，**不是绝对坐标**。
    // 消费方 `_PopupMenuRouteLayout.getPositionForChild`（vendored
    // `material_ui/src/popup_menu.dart:866-895`）的实际用法是：
    //   left / right → 选择水平展开方向并由 `size.width - right - childWidth`
    //                  或 `left` 求出 x，随后由 `_fitInsideScreen` 贴边钳制；
    //   top          → **直接作为 y**；
    //   bottom       → 不被读取（仅 `toRect().center` 用于就近选择子屏）。
    // 因此这里给出语义正确的四个分量，并把「向上展开」的 y 落在按钮上缘之上
    // （此前该分支固定传 0，会把面板顶到窗口最上方，与上方注释所述意图不符）。
    final double panelTop = showBelow
        ? anchorRect.bottom + anchorGap
        : max(safeGap, anchorRect.top - anchorGap - height);
    final RelativeRect rect = RelativeRect.fromLTRB(
      anchorRect.left,
      panelTop,
      overlaySize.width - (anchorRect.left + width),
      overlaySize.height - (panelTop + height),
    );

    return (below: showBelow, width: width, height: height, rect: rect);
  }

  static void reportVideo(int aid) {
    Get.toNamed(
      '/webview',
      parameters: {'url': 'https://www.bilibili.com/appeal/?avid=$aid'},
    );
  }

  static bool _fitsInAndroidRequirements(int width, int height) {
    final aspectRatio = width / height;
    const min = 1 / 2.39;
    const max = 2.39;
    return (min <= aspectRatio) && (aspectRatio <= max);
  }

  static void enterPip({
    int? width,
    int? height,
    bool autoEnter = false,
    required bool isLive,
    required bool isPlaying,
  }) {
    if (width != null &&
        height != null &&
        !_fitsInAndroidRequirements(width, height)) {
      if (height > width) {
        width = 9;
        height = 16;
      } else {
        width = 16;
        height = 9;
      }
    }
    PiliAndroidHelper.enterPip(
      width ?? 16,
      height ?? 9,
      autoEnter: autoEnter,
      isLive: isLive,
      isPlaying: isPlaying,
    );
  }

  static Future<void> pushDynDetail(
    DynamicItemModel item, {
    bool isPush = false,
    bool viewComment = false,
  }) async {
    feedBack();

    void push() {
      if (item.basic?.commentType == 12) {
        toDupNamed(
          '/articlePage',
          parameters: {
            'id': item.idStr,
            'type': 'opus',
          },
        );
      } else {
        if (item.linkFolded) {
          pushDynFromId(id: item.idStr);
          return;
        }
        toDupNamed(
          '/dynamicDetail',
          arguments: {
            'item': item,
            if (viewComment) 'viewComment': true,
          },
        );
      }
    }

    /// 点击评论action 直接查看评论
    if (isPush) {
      push();
      return;
    }

    // if (kDebugMode) debugPrint('pushDynDetail: ${item.type}');

    switch (item.type) {
      case 'DYNAMIC_TYPE_AV':
        final archive = item.modules.moduleDynamic!.major!.archive!;
        // pgc
        if (archive.type == 2) {
          // jumpUrl
          if (archive.jumpUrl case final jumpUrl?) {
            if (viewPgcFromUri(jumpUrl)) {
              return;
            }
          }
          // redirectUrl from intro
          final res = await VideoHttp.videoIntro(bvid: archive.bvid!);
          if (res.dataOrNull?.redirectUrl case final redirectUrl?) {
            if (viewPgcFromUri(redirectUrl)) {
              return;
            }
          }
          // redirectUrl from jumpUrl
          if (await UrlUtils.parseRedirectUrl(archive.jumpUrl.http2https, false)
              case final redirectUrl?) {
            if (viewPgcFromUri(redirectUrl)) {
              return;
            }
          }
        }

        try {
          String bvid = archive.bvid!;
          String cover = archive.cover!;
          final res = await SearchHttp.ab2cWithDimension(bvid: bvid);
          final cid = res?.cid;
          if (cid != null) {
            toVideoPage(
              bvid: bvid,
              cid: cid,
              cover: cover,
              dimension: res!.dimension,
              title: archive.title,
            );
          }
        } catch (err) {
          SmartDialog.showToast(err.toString());
        }
        break;

      /// 专栏文章查看
      case 'DYNAMIC_TYPE_ARTICLE':
        toDupNamed(
          '/articlePage',
          parameters: {
            'id': item.idStr,
            'type': 'opus',
          },
        );
        break;

      case 'DYNAMIC_TYPE_PGC':
        // if (kDebugMode) debugPrint('番剧');
        SmartDialog.showToast('暂未支持的类型，请联系开发者');
        break;

      case 'DYNAMIC_TYPE_LIVE':
        final liveRcmd = item.modules.moduleDynamic!.major!.live!;
        toLiveRoom(liveRcmd.id);
        break;

      case 'DYNAMIC_TYPE_LIVE_RCMD':
        final liveRcmd = item.modules.moduleDynamic!.major!.liveRcmd!;
        toLiveRoom(liveRcmd.roomId);
        break;

      case 'DYNAMIC_TYPE_SUBSCRIPTION_NEW':
        final live = item
            .modules
            .moduleDynamic!
            .major!
            .subscriptionNew!
            .liveRcmd!
            .content!
            .livePlayInfo!;
        toLiveRoom(live.roomId);
        break;

      /// 合集查看
      case 'DYNAMIC_TYPE_UGC_SEASON':
        final ugcSeason = item.modules.moduleDynamic!.major!.ugcSeason!;
        int aid = ugcSeason.aid!;
        String bvid = IdUtils.av2bv(aid);
        String cover = ugcSeason.cover!;
        final res = await SearchHttp.ab2cWithDimension(bvid: bvid);
        final cid = res?.cid;
        if (cid != null) {
          toVideoPage(
            aid: aid,
            bvid: bvid,
            cid: cid,
            cover: cover,
            dimension: res!.dimension,
            title: ugcSeason.title,
          );
        }
        break;

      /// 番剧查看
      case 'DYNAMIC_TYPE_PGC_UNION':
        // if (kDebugMode) debugPrint('DYNAMIC_TYPE_PGC_UNION 番剧');
        final pgc = item.modules.moduleDynamic!.major!.pgc!;
        if (pgc.epid != null) {
          viewPgc(epId: pgc.epid);
        }
        break;

      case 'DYNAMIC_TYPE_MEDIALIST':
        if (item.modules.moduleDynamic?.major?.medialist
            case final medialist?) {
          final String? url = medialist.jumpUrl;
          if (url != null) {
            if (url.contains('medialist/detail/ml')) {
              Get.toNamed(
                '/favDetail',
                parameters: {
                  'heroTag': '${medialist.cover}',
                  'mediaId': '${medialist.id}',
                },
              );
            } else {
              handleWebview(url.http2https);
            }
          }
        }
        break;

      case 'DYNAMIC_TYPE_COURSES_SEASON':
        PageUtils.viewPugv(
          seasonId: item.modules.moduleDynamic!.major!.courses!.id,
        );
        break;

      // 纯文字动态查看
      // case 'DYNAMIC_TYPE_WORD':
      // # 装扮/剧集点评/普通分享
      // case 'DYNAMIC_TYPE_COMMON_SQUARE':
      // 转发的动态
      // case 'DYNAMIC_TYPE_FORWARD':
      // 图文动态查看
      // case 'DYNAMIC_TYPE_DRAW':
      default:
        push();
        break;
    }
  }

  static void inAppWebview(
    String url, {
    bool off = false,
  }) {
    if (Pref.openInBrowser) {
      launchURL(url);
    } else {
      Get.offOrToNamed(
        '/webview',
        parameters: {'url': url},
        arguments: const {'inApp': true},
        off: off,
      );
    }
  }

  static Future<void> launchURL(
    String url, {
    LaunchMode mode = LaunchMode.externalApplication,
  }) async {
    try {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: mode)) {
        SmartDialog.showToast('Could not launch $url');
      }
    } catch (e) {
      SmartDialog.showToast(e.toString());
    }
  }

  static Future<void> handleWebview(
    String url, {
    bool inApp = false,
    Map? parameters,
  }) async {
    if (!inApp && Pref.openInBrowser) {
      if (!await PiliScheme.routePushFromUrl(url, selfHandle: true)) {
        launchURL(url);
      }
    } else {
      PiliScheme.routePushFromUrl(url, parameters: parameters);
    }
  }

  static Future<void>? showVideoBottomSheet(
    BuildContext context, {
    required Widget child,
    ValueGetter<EdgeInsets>? padding,
    double maxWidth = 500,
  }) {
    if (!context.mounted) {
      return null;
    }
    return Get.key.currentState!.push(
      PublishRoute(
        pageBuilder: (context, animation, secondaryAnimation) {
          final isPortrait = context.isPortrait;
          return SafeArea(
            child: CustomFractionallySizedBox(
              maxWidth: maxWidth,
              widthFactor: isPortrait ? 1.0 : 0.5,
              heightFactor: isPortrait ? 0.7 : 1.0,
              alignment: isPortrait ? .bottomCenter : .centerRight,
              child: Padding(
                padding: isPortrait ? padding?.call() ?? .zero : .zero,
                child: child,
              ),
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          final begin = context.isPortrait
              ? const Offset(0.0, 1.0)
              : const Offset(1.0, 0.0);
          return SlideTransition(
            position: animation.drive(
              Tween<Offset>(
                begin: begin,
                end: Offset.zero,
              ).chain(CurveTween(curve: Curves.easeInOut)),
            ),
            child: child,
          );
        },
        settings: RouteSettings(arguments: Get.arguments),
      ),
    );
  }

  static void toLiveRoom(
    int? roomId, {
    bool off = false,
  }) {
    if (roomId == null) {
      return;
    }
    Get.offOrToNamed(
      '/liveRoom',
      arguments: roomId,
      off: off,
      preventDuplicates: off,
    );
  }

  /// 桌面端卡片悬停预取：只预取「视频详情」（标题/简介/分P 等），
  /// 不预取播放地址，避免带宽与风控风险。
  /// 同一个 bvid 只会保有一个在途请求；容量满时按插入顺序淘汰最早的。
  static final Map<String, Future<LoadingState<VideoDetailData>>>
  _videoDetailPrefetch = {};
  static const int _videoDetailPrefetchMax = 8;

  /// 预取视频详情（幂等；仅桌面端悬停触发时调用）
  static void prefetchVideoDetail(String bvid) {
    if (bvid.isEmpty || _videoDetailPrefetch.containsKey(bvid)) {
      return;
    }
    if (_videoDetailPrefetch.length >= _videoDetailPrefetchMax) {
      _videoDetailPrefetch.remove(_videoDetailPrefetch.keys.first);
    }
    _videoDetailPrefetch[bvid] = VideoHttp.videoIntro(bvid: bvid);
  }

  /// 取走预取结果（一次性消费；未预取时返回 null）
  static Future<LoadingState<VideoDetailData>>? takeVideoDetailPrefetch(
    String bvid,
  ) => _videoDetailPrefetch.remove(bvid);

  static Future<void>? toVideoPage({
    VideoType videoType = VideoType.ugc,
    int? aid,
    String? bvid,
    required int cid,
    int? seasonId,
    int? epId,
    int? pgcType,
    String? cover,
    String? title,
    int? progress, // milliseconds
    Map? extraArguments,
    bool off = false,
    bool isVertical = false,
    Dimension? dimension,
  }) {
    final arguments = {
      'aid': aid ?? IdUtils.bv2av(bvid!),
      'bvid': bvid ?? IdUtils.av2bv(aid!),
      'cid': cid,
      'seasonId': ?seasonId,
      'epId': ?epId,
      'pgcType': ?pgcType,
      'cover': ?cover,
      'title': ?title,
      'progress': ?progress,
      'videoType': videoType,
      'isVertical': dimension?.isVertical ?? isVertical,
      'heroTag': Utils.makeHeroTag(cid),
      ...?extraArguments,
    };
    return PageUtils.toDupNamed('/videoV', arguments: arguments, off: off);
  }

  static final _pgcRegex = RegExp(r'(ep|ss)(\d+)');
  static bool viewPgcFromUri(
    String uri, {
    bool isPgc = true,
    int? progress, // milliseconds
    int? aid,
    bool off = false,
  }) {
    RegExpMatch? match = _pgcRegex.firstMatch(uri);
    if (match != null) {
      bool isSeason = match.group(1) == 'ss';
      String id = match.group(2)!;
      if (isPgc) {
        viewPgc(
          seasonId: isSeason ? id : null,
          epId: isSeason ? null : id,
          progress: progress,
          off: off,
        );
      } else {
        viewPugv(
          seasonId: isSeason ? id : null,
          epId: isSeason ? null : id,
          aid: aid,
          progress: progress,
          off: off,
        );
      }
      return true;
    }
    return false;
  }

  static EpisodeItem findEpisode(
    List<EpisodeItem> episodes, {
    dynamic epId,
    bool isPgc = true,
  }) {
    // epId episode -> progress episode -> first episode
    EpisodeItem? episode;
    if (epId != null) {
      epId = epId.toString();
      episode = episodes.firstWhereOrNull(
        (item) => (isPgc ? item.epId : item.id).toString() == epId,
      );
    }
    return episode ?? episodes.first;
  }

  static Future<void> viewPgc({
    dynamic seasonId,
    dynamic epId,
    int? progress, // milliseconds
    bool off = false,
  }) async {
    try {
      SmartDialog.showLoading(msg: '资源获取中');
      final res = await SearchHttp.pgcInfo(seasonId: seasonId, epId: epId);
      SmartDialog.dismiss();
      if (res case Success(:final response)) {
        final episodes = response.episodes;
        final hasEpisode = episodes != null && episodes.isNotEmpty;

        EpisodeItem? episode;

        void viewSection(EpisodeItem episode) {
          toVideoPage(
            videoType: VideoType.ugc,
            bvid: episode.bvid!,
            cid: episode.cid!,
            seasonId: response.seasonId,
            epId: episode.epId,
            cover: episode.cover,
            title: episode.title,
            progress: progress,
            extraArguments: {
              'pgcApi': true,
              'pgcItem': response,
            },
            off: off,
          );
        }

        if (epId != null) {
          epId = epId.toString();
          if (hasEpisode) {
            episode = episodes.firstWhereOrNull(
              (item) => item.epId.toString() == epId,
            );
          }

          // find section
          if (episode == null) {
            final sections = response.section;
            if (sections != null && sections.isNotEmpty) {
              for (final section in sections) {
                final episodes = section.episodes;
                if (episodes != null && episodes.isNotEmpty) {
                  for (final episode in episodes) {
                    if (episode.epId.toString() == epId) {
                      // view as ugc
                      viewSection(episode);
                      return;
                    }
                  }
                }
              }
            }
          }
        }

        if (hasEpisode) {
          episode ??= findEpisode(
            episodes,
            epId: response.userStatus?.progress?.lastEpId,
          );
          toVideoPage(
            videoType: VideoType.pgc,
            bvid: episode.bvid!,
            cid: episode.cid!,
            seasonId: response.seasonId,
            epId: episode.epId,
            pgcType: response.type,
            cover: episode.cover,
            progress: progress,
            extraArguments: {
              'pgcItem': response,
            },
            off: off,
          );
          return;
        } else {
          episode ??= response.section?.firstOrNull?.episodes?.firstOrNull;
          if (episode != null) {
            viewSection(episode);
            return;
          }
        }

        SmartDialog.showToast('资源加载失败');
      } else {
        res.toast();
      }
    } catch (e) {
      SmartDialog.dismiss();
      SmartDialog.showToast('$e');
      if (kDebugMode) debugPrint('$e');
    }
  }

  static Future<void> viewPugv({
    dynamic seasonId,
    dynamic epId,
    int? aid,
    int? progress, // milliseconds
    bool off = false,
  }) async {
    try {
      SmartDialog.showLoading(msg: '资源获取中');
      final res = await SearchHttp.pugvInfo(seasonId: seasonId, epId: epId);
      SmartDialog.dismiss();
      if (res case Success(:final response)) {
        final episodes = response.episodes;
        if (episodes != null && episodes.isNotEmpty) {
          EpisodeItem? episode;
          if (aid != null) {
            episode = episodes.firstWhereOrNull((e) => e.aid == aid);
          }
          episode ??= findEpisode(
            episodes,
            epId: epId ?? response.userStatus?.progress?.lastEpId,
            isPgc: false,
          );
          toVideoPage(
            videoType: VideoType.pugv,
            aid: episode.aid!,
            cid: episode.cid!,
            seasonId: response.seasonId,
            epId: episode.id,
            cover: episode.cover,
            progress: progress,
            extraArguments: {
              'pgcItem': response,
            },
            off: off,
          );
        } else {
          SmartDialog.showToast('资源加载失败');
        }
      } else {
        res.toast();
      }
    } catch (e) {
      SmartDialog.dismiss();
      SmartDialog.showToast(e.toString());
    }
  }

  @pragma('vm:prefer-inline')
  static Future<T?>? toDupNamed<T>(
    String page, {
    dynamic arguments,
    Map<String, String>? parameters,
    bool off = false,
  }) => Get.offOrToNamed(
    page,
    arguments: arguments,
    parameters: parameters,
    preventDuplicates: false,
    off: off,
  );
}
