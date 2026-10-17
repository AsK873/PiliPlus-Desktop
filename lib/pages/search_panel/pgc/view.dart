import 'package:PiliPlus/common/skeleton/media_bangumi.dart';
import 'package:PiliPlus/common/sliver_single_child_delegate.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/desktop/desktop_content.dart';
import 'package:PiliPlus/models/search/result.dart';
import 'package:PiliPlus/pages/search_panel/controller.dart';
import 'package:PiliPlus/pages/search_panel/pgc/widgets/item.dart';
import 'package:PiliPlus/pages/search_panel/view.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart'
    hide SliverGridDelegateWithMaxCrossAxisExtent;

class SearchPgcPanel extends CommonSearchPanel {
  const SearchPgcPanel({
    super.key,
    required super.keyword,
    required super.tag,
    required super.searchType,
  });

  @override
  State<SearchPgcPanel> createState() => _SearchPgcPanelState();
}

class _SearchPgcPanelState
    extends
        CommonSearchPanelState<
          SearchPgcPanel,
          SearchPgcData,
          SearchPgcItemModel
        > {
  @override
  late final SearchPanelController<SearchPgcData, SearchPgcItemModel>
  controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(
      SearchPanelController<SearchPgcData, SearchPgcItemModel>(
        keyword: widget.keyword,
        searchType: widget.searchType,
        tag: widget.tag,
      ),
      tag: widget.searchType.name + widget.tag,
    );
  }

  /// 桌面端与首页同一算式（动态列数 + 整卡同比，见 [CardGridDelegate]）；
  /// 非桌面端逐字沿用原口径（`baseCardWidth` = 原 `maxCrossAxisExtent`）。
  /// 固定行高卡片：整卡高 = `158 · scale`，卡片内封面按行高等比（见 SearchPgcItem）。
  late final gridDelegate = CardGridDelegate(
    baseCardWidth: Grid.smallCardWidth * 2,
    baseMainAxisExtent: 158,
    baseContentExtent: 158,
    childAspectRatio: Style.aspectRatio16x9,
    mainAxisSpacing: 0,
    crossAxisSpacing: 0,
  );

  @override
  Widget buildList(List<SearchPgcItemModel> list) {
    // 与首页网格同一几何：卡片网格不限宽（铺满 Sidebar 右侧可用宽度），
    // 列数按可用宽度动态决定、卡片整卡同比缩放。
    return desktopLimitSliver(
      SliverGrid.builder(
        gridDelegate: gridDelegate,
        itemBuilder: (BuildContext context, int index) {
          if (index == list.length - 1) {
            controller.onLoadMore();
          }
          // gridDelegate.scaled = 卡片文字随本列实际列宽同比（非桌面端原样返回）
          return gridDelegate.scaled(SearchPgcItem(item: list[index]));
        },
        itemCount: list.length,
      ),
      maxWidth: double.infinity,
    );
  }

  @override
  Widget get buildLoading => SliverGrid(
    gridDelegate: gridDelegate,
    delegate: const SliverSingleChildDelegate(
      count: 10,
      child: MediaPgcSkeleton(),
    ),
  );
}
