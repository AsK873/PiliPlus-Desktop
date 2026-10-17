import 'package:PiliPlus/common/skeleton/msg_feed_top.dart';
import 'package:PiliPlus/common/skeleton/video_card_v.dart';
import 'package:PiliPlus/common/sliver_single_child_delegate.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/live/live_search_type.dart';
import 'package:PiliPlus/pages/live_search/child/controller.dart';
import 'package:PiliPlus/pages/live_search/widgets/live_search_room.dart';
import 'package:PiliPlus/pages/live_search/widgets/live_search_user.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart'
    hide SliverGridDelegateWithMaxCrossAxisExtent;

class LiveSearchChildPage extends StatefulWidget {
  const LiveSearchChildPage({
    super.key,
    required this.controller,
    required this.searchType,
  });

  final LiveSearchChildController controller;
  final LiveSearchType searchType;

  @override
  State<LiveSearchChildPage> createState() => _LiveSearchChildPageState();
}

class _LiveSearchChildPageState extends State<LiveSearchChildPage>
    with AutomaticKeepAliveClientMixin {
  LiveSearchChildController get _controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    double padding = widget.searchType == LiveSearchType.room ? 12 : 0;
    return refreshIndicator(
      onRefresh: _controller.onRefresh,
      child: CustomScrollView(
        controller: _controller.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.only(
              top: padding,
              left: padding,
              right: padding,
              bottom: MediaQuery.viewPaddingOf(context).bottom + 100,
            ),
            sliver: Obx(() => _buildBody(_controller.loadingState.value)),
          ),
        ],
      ),
    );
  }

  Widget get _buildLoading {
    return switch (widget.searchType) {
      LiveSearchType.room => SliverGrid(
        gridDelegate: roomDelegate,
        delegate: const SliverSingleChildDelegate(
          count: 10,
          child: VideoCardVSkeleton(),
        ),
      ),
      LiveSearchType.user => SliverGrid(
        gridDelegate: userDelegate,
        delegate: const SliverSingleChildDelegate(
          count: 12,
          child: MsgFeedTopSkeleton(),
        ),
      ),
    };
  }

  /// 桌面端与首页同一算式（动态列数 + 整卡同比，见 [CardGridDelegate]）；
  /// 非桌面端逐字沿用原口径（`baseCardWidth` = 原 `maxCrossAxisExtent`）。
  /// [userDelegate] 是用户行（固定 60 高的横排列表行），不属于卡片网格，保持原样。
  late final roomDelegate = CardGridDelegate(
    baseCardWidth: Grid.smallCardWidth,
    baseContentExtent: MediaQuery.textScalerOf(context).scale(60),
    mainAxisSpacing: Style.cardSpace,
    crossAxisSpacing: Style.cardSpace,
    childAspectRatio: Style.aspectRatio,
  );

  late final userDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: Grid.smallCardWidth * 2,
    mainAxisExtent: 60,
  );

  Widget _buildBody(LoadingState<List?> loadingState) {
    return switch (loadingState) {
      Loading() => _buildLoading,
      Success(:final response) =>
        response != null && response.isNotEmpty
            ? Builder(
                builder: (context) {
                  return switch (widget.searchType) {
                    LiveSearchType.room => SliverGrid.builder(
                      gridDelegate: roomDelegate,
                      itemBuilder: (context, index) {
                        if (index == response.length - 1) {
                          _controller.onLoadMore();
                        }
                        // roomDelegate.scaled = 卡片文字随本列实际列宽同比（非桌面端原样返回）
                        return roomDelegate.scaled(
                          LiveCardVSearch(
                            item: response[index],
                          ),
                        );
                      },
                      itemCount: response.length,
                    ),
                    LiveSearchType.user => SliverGrid.builder(
                      gridDelegate: userDelegate,
                      itemBuilder: (context, index) {
                        if (index == response.length - 1) {
                          _controller.onLoadMore();
                        }
                        return LiveSearchUserItem(
                          item: response[index],
                        );
                      },
                      itemCount: response.length,
                    ),
                  };
                },
              )
            : HttpError(onReload: _controller.onReload),
      Error(:final errMsg) => HttpError(
        errMsg: errMsg,
        onReload: _controller.onReload,
      ),
    };
  }

  @override
  bool get wantKeepAlive => true;
}
