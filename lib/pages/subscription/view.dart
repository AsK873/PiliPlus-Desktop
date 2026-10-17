import 'package:PiliPlus/common/widgets/desktop/desktop_content.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/common/widgets/view_sliver_safe_area.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/sub/sub/list.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/pages/subscription/controller.dart';
import 'package:PiliPlus/pages/subscription/widgets/item.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class SubPage extends StatefulWidget {
  const SubPage({
    super.key,
    this.desktopEmbedded = false,
    this.onBack,
    this.hideAppBar = false,
  });

  /// 桌面端：由主壳「主内容区」就地承载（与侧栏并排），而非独立路由页。
  final bool desktopEmbedded;

  /// 桌面嵌入时的「离开本页」回调（由主壳收起内容页 → 恢复进入前的主 Tab）
  final VoidCallback? onBack;

  /// 桌面端「我的」页快捷入口**内嵌**时置 true：省略 AppBar（页面标题 /
  /// 返回按钮），只渲染主体内容。默认 false，移动端、路由方式与主壳
  /// 内容区嵌入（[desktopEmbedded]）均不受影响。
  final bool hideAppBar;

  @override
  State<SubPage> createState() => _SubPageState();
}

class _SubPageState extends State<SubPage> with GridMixin {
  final SubController _subController = Get.put(SubController());

  /// 返回按钮（桌面嵌入）：本页没有内部二级状态（无搜索 / 多选 / 内层详情），
  /// 离开时由主壳收起内容页，主 Tab 索引沿用 MainController.selectedIndex
  /// （进入时未改动）；路由方式退回原有 Get.back()。
  void _handleBack() {
    final onBack = widget.onBack;
    if (onBack != null) {
      onBack();
    } else {
      Get.back();
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.desktopEmbedded) {
      // 接入主壳既有的鼠标返回侧键机制（main.dart 的 BackDetector → _onBack），
      // 复用同一个返回，不新增全局监听
      Get.find<MainController>().desktopContentBackHandler = _handleBack;
    }
  }

  @override
  void dispose() {
    if (widget.desktopEmbedded && Get.isRegistered<MainController>()) {
      final mainController = Get.find<MainController>();
      // 仅在本实例仍是注册者时清空，避免覆盖后进入实例的注册
      if (mainController.desktopContentBackHandler == _handleBack) {
        mainController.desktopContentBackHandler = null;
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SimpleScaffold(
      // 「我的」页内嵌（hideAppBar）→ 整块顶栏（标题 / 返回按钮）都不嵌入，
      // 只渲染主体内容；
      // 桌面嵌入：标题左侧为返回按钮；标题在原有间距上再左移 10px（36 → 26）
      appBar: widget.hideAppBar ? null : AppBar(
        leading: widget.desktopEmbedded
            ? BackButton(onPressed: _handleBack)
            : null,
        titleSpacing: widget.desktopEmbedded ? 26 : null,
        title: const Text('我的订阅'),
      ),
      body: refreshIndicator(
        onRefresh: _subController.onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            ViewSliverSafeArea(
              sliver: Obx(
                () => _buildBody(_subController.loadingState.value),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(LoadingState<List<SubItemModel>?> loadingState) {
    return switch (loadingState) {
      Loading() => gridSkeleton,
      Success(:final response) =>
        response != null && response.isNotEmpty
            // 与首页网格一致：卡片网格不限宽、列数按可用宽度动态决定
            ? desktopLimitSliver(
                SliverGrid.builder(
                  gridDelegate: gridDelegate,
                  itemBuilder: (context, index) {
                    if (index == response.length - 1) {
                      _subController.onLoadMore();
                    }
                    final item = response[index];
                    // gridDelegate.scaled = 卡片文字随本列实际列宽同比（非桌面端原样返回）
                    return gridDelegate.scaled(
                      desktopCard(
                        SubItem(
                          item: item,
                          cancelSub: () => _subController.cancelSub(item),
                        ),
                      ),
                    );
                  },
                  itemCount: response.length,
                ),
                maxWidth: double.infinity,
              )
            : HttpError(onReload: _subController.onReload),
      Error(:final errMsg) => HttpError(
        errMsg: errMsg,
        onReload: _subController.onReload,
      ),
    };
  }
}
