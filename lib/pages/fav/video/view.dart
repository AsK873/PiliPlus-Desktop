import 'package:PiliPlus/common/widgets/desktop/desktop_content.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/fav/fav_folder/list.dart';
import 'package:PiliPlus/pages/fav/video/controller.dart';
import 'package:PiliPlus/pages/fav/video/widgets/item.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class FavVideoPage extends StatefulWidget {
  const FavVideoPage({super.key, this.instanceSuffix = ''});

  /// GetX 实例命名空间后缀：由宿主（[FavPage] 的视频 tab）下发。
  /// 「我的」页内嵌预览实例为 `@preview`；移动端 / 路由方式 / 主壳内容区
  /// 嵌入为 `''`（与改动前的 key 逐字一致）。
  /// 必须与宿主 `Get.put(FavController(), tag: ...)` 使用同一后缀，
  /// 否则会查找不到 / 串到另一个实例。
  final String instanceSuffix;

  @override
  State<FavVideoPage> createState() => _FavVideoPageState();
}

class _FavVideoPageState extends State<FavVideoPage>
    with AutomaticKeepAliveClientMixin, GridMixin {
  late final FavController _favController = Get.find<FavController>(
    tag: widget.instanceSuffix,
  );

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return refreshIndicator(
      onRefresh: _favController.onRefresh,
      child: CustomScrollView(
        controller: _favController.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.only(
              top: 7,
              bottom: 100 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            // 与首页网格一致：卡片网格不限宽、列数按可用宽度动态决定
            sliver: desktopLimitSliver(
              Obx(
                () => _buildBody(_favController.loadingState.value),
              ),
              maxWidth: double.infinity,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(LoadingState<List<FavFolderInfo>?> loadingState) {
    return switch (loadingState) {
      Loading() => gridSkeleton,
      Success(:final response) =>
        response != null && response.isNotEmpty
            ? SliverGrid.builder(
                gridDelegate: gridDelegate,
                itemBuilder: (BuildContext context, int index) {
                  if (index == response.length - 1) {
                    _favController.onLoadMore();
                  }
                  final item = response[index];
                  String heroTag = Utils.makeHeroTag(item.fid);
                  // gridDelegate.scaled = 卡片文字随本列实际列宽同比（非桌面端原样返回）
                  return gridDelegate.scaled(
                    FavVideoItem(
                      heroTag: heroTag,
                      item: item,
                      onTap: () async {
                        final res = await Get.toNamed(
                          '/favDetail',
                          arguments: item,
                          parameters: {
                            'heroTag': heroTag,
                            'mediaId': item.id.toString(),
                          },
                        );
                        if (res == true) {
                          _favController.loadingState
                            ..value.data!.removeAt(index)
                            ..refresh();
                        }
                      },
                    ),
                  );
                },
                itemCount: response.length,
              )
            : HttpError(onReload: _favController.onReload),
      Error(:final errMsg) => HttpError(
        errMsg: errMsg,
        onReload: _favController.onReload,
      ),
    };
  }
}
