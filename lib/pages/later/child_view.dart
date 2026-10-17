import 'package:PiliPlus/common/widgets/desktop/desktop_content.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/later_view_type.dart';
import 'package:PiliPlus/models/common/video/source_type.dart';
import 'package:PiliPlus/models_new/later/list.dart';
import 'package:PiliPlus/pages/later/base_controller.dart';
import 'package:PiliPlus/pages/later/controller.dart';
import 'package:PiliPlus/pages/later/widgets/video_card_h_later.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class LaterViewChildPage extends StatefulWidget {
  const LaterViewChildPage({
    super.key,
    required this.laterViewType,
    this.instanceSuffix = '',
  });

  final LaterViewType laterViewType;

  /// GetX 实例命名空间后缀：由宿主（[LaterPage] / `LaterViewType.page`）逐级
  /// 下发。「我的」页内嵌预览实例为 `@preview`；移动端 / 路由方式 / 主壳内容区
  /// 嵌入为 `''`（与改动前的 key 逐字一致）。
  final String instanceSuffix;

  @override
  State<LaterViewChildPage> createState() => _LaterViewChildPageState();
}

class _LaterViewChildPageState extends State<LaterViewChildPage>
    with AutomaticKeepAliveClientMixin, GridMixin {
  late final LaterController _laterController;
  late final _baseCtr = Get.putOrFind(
    LaterBaseController.new,
    tag: widget.instanceSuffix,
  );

  @override
  void initState() {
    super.initState();
    _laterController = Get.put(
      LaterController(
        widget.laterViewType,
        instanceSuffix: widget.instanceSuffix,
      ),
      tag: '${widget.laterViewType.type}${widget.instanceSuffix}',
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return refreshIndicator(
      onRefresh: _laterController.onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        controller: _laterController.scrollController,
        slivers: [
          SliverPadding(
            padding: EdgeInsets.only(
              top: 7,
              bottom: PlatformUtils.isDesktop
                  ? 24
                  : MediaQuery.viewPaddingOf(context).bottom + 85,
            ),
            // 与首页网格一致：卡片网格不限宽、列数按可用宽度动态决定
            sliver: desktopLimitSliver(
              Obx(
                () => _buildBody(_laterController.loadingState.value),
              ),
              maxWidth: double.infinity,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(LoadingState<List<LaterItemModel>?> loadingState) {
    return switch (loadingState) {
      Loading() => gridSkeleton,
      Success(:final response) =>
        response != null && response.isNotEmpty
            ? SliverGrid.builder(
                gridDelegate: gridDelegate,
                itemBuilder: (context, index) {
                  if (index == response.length - 1) {
                    _laterController.onLoadMore();
                  }
                  final videoItem = response[index];
                  // gridDelegate.scaled = 卡片文字随本列实际列宽同比（非桌面端原样返回）
                  return gridDelegate.scaled(
                    desktopCard(
                      VideoCardHLater(
                        index: index,
                        videoItem: videoItem,
                        ctr: _laterController,
                        onViewLater: (cid) {
                          PageUtils.toVideoPage(
                            bvid: videoItem.bvid,
                            cid: cid,
                            cover: videoItem.pic,
                            title: videoItem.title,
                            dimension: videoItem.dimension,
                            extraArguments: _baseCtr.isPlayAll.value
                                ? {
                                    'oid': videoItem.aid,
                                    'sourceType': SourceType.watchLater,
                                    'count': _laterController
                                        .baseCtr
                                        .counts[LaterViewType.all.index],
                                    'favTitle': '稍后再看',
                                    'mediaId': _laterController.mid,
                                    'desc': _laterController.asc.value,
                                    'isContinuePlaying': index != 0,
                                  }
                                : const {'viewLater': true},
                          );
                        },
                      ),
                    ),
                  );
                },
                itemCount: response.length,
              )
            : HttpError(onReload: _laterController.onReload),
      Error(:final errMsg) => HttpError(
        errMsg: errMsg,
        onReload: _laterController.onReload,
      ),
    };
  }

  @override
  bool get wantKeepAlive => true;
}
