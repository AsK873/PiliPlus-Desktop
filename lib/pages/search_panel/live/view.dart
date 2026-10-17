import 'package:PiliPlus/common/skeleton/video_card_v.dart';
import 'package:PiliPlus/common/sliver_single_child_delegate.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/desktop/desktop_content.dart';
import 'package:PiliPlus/models/search/result.dart';
import 'package:PiliPlus/pages/search_panel/controller.dart';
import 'package:PiliPlus/pages/search_panel/live/widgets/item.dart';
import 'package:PiliPlus/pages/search_panel/view.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class SearchLivePanel extends CommonSearchPanel {
  const SearchLivePanel({
    super.key,
    required super.keyword,
    required super.tag,
    required super.searchType,
  });

  @override
  State<SearchLivePanel> createState() => _SearchLivePanelState();
}

class _SearchLivePanelState
    extends
        CommonSearchPanelState<
          SearchLivePanel,
          SearchLiveData,
          SearchLiveItemModel
        > {
  @override
  late final SearchPanelController<SearchLiveData, SearchLiveItemModel>
  controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(
      SearchPanelController<SearchLiveData, SearchLiveItemModel>(
        keyword: widget.keyword,
        searchType: widget.searchType,
        tag: widget.tag,
      ),
      tag: widget.searchType.name + widget.tag,
    );
  }

  /// 桌面端与首页同一算式（动态列数 + 整卡同比，见 [CardGridDelegate]）；
  /// 非桌面端逐字沿用原口径（`baseCardWidth` = 原 `maxCrossAxisExtent`）。
  late final gridDelegate = CardGridDelegate(
    baseCardWidth: Grid.smallCardWidth,
    baseContentExtent: MediaQuery.textScalerOf(context).scale(80),
    crossAxisSpacing: Style.cardSpace,
    mainAxisSpacing: Style.cardSpace,
    childAspectRatio: Style.aspectRatio,
  );

  @override
  Widget buildList(List<SearchLiveItemModel> list) {
    // 与首页网格同一几何：卡片网格不限宽（铺满 Sidebar 右侧可用宽度），
    // 列数按可用宽度动态决定、卡片整卡同比缩放。
    return desktopLimitSliver(
      SliverPadding(
        padding: const .only(left: Style.safeSpace, right: Style.safeSpace),
        sliver: SliverGrid.builder(
          gridDelegate: gridDelegate,
          itemBuilder: (context, index) {
            if (index == list.length - 1) {
              controller.onLoadMore();
            }
            // gridDelegate.scaled = 卡片文字随本列实际列宽同比（非桌面端原样返回）
            return gridDelegate.scaled(LiveItem(liveItem: list[index]));
          },
          itemCount: list.length,
        ),
      ),
      maxWidth: double.infinity,
    );
  }

  @override
  Widget get buildLoading => SliverPadding(
    padding: const .only(left: Style.safeSpace, right: Style.safeSpace),
    sliver: SliverGrid(
      gridDelegate: gridDelegate,
      delegate: const SliverSingleChildDelegate(
        count: 10,
        child: VideoCardVSkeleton(),
      ),
    ),
  );
}
