import 'package:PiliPlus/common/widgets/desktop/desktop_content.dart';
import 'package:PiliPlus/models_new/history/data.dart';
import 'package:PiliPlus/models_new/history/list.dart';
import 'package:PiliPlus/pages/common/search/common_search_page.dart';
import 'package:PiliPlus/pages/history/widgets/item.dart';
import 'package:PiliPlus/pages/history_search/controller.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class HistorySearchPage extends StatefulWidget {
  const HistorySearchPage({super.key});

  @override
  State<HistorySearchPage> createState() => _HistorySearchPageState();
}

class _HistorySearchPageState
    extends
        CommonSearchPageState<HistorySearchPage, HistoryData, HistoryItemModel>
    with GridMixin {
  @override
  final HistorySearchController controller = Get.put(
    HistorySearchController(),
    tag: Utils.generateRandomString(8),
  );

  @override
  Widget buildList(List<HistoryItemModel> list) {
    return desktopLimitSliver(
      SliverGrid.builder(
        gridDelegate: gridDelegate,
        itemBuilder: (context, index) {
          if (index == list.length - 1) {
            controller.onLoadMore();
          }
          final item = list[index];
          // gridDelegate.scaled = 卡片文字随本列实际列宽同比（非桌面端原样返回）
          return gridDelegate.scaled(
            desktopCard(
              HistoryItem(
                item: item,
                ctr: controller,
                onDelete: (kid, business) =>
                    controller.onDelHistory(index, kid, business),
              ),
            ),
          );
        },
        itemCount: list.length,
      ),
      maxWidth: double.infinity,
    );
  }
}
