import 'package:PiliPlus/models_new/fav/fav_folder/list.dart';
import 'package:PiliPlus/pages/common/common_intro_controller.dart';
import 'package:PiliPlus/utils/bili_utils.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// 收藏夹列表（底部面板与桌面 Popover **共用同一份实现**）。
///
/// 只负责展示与本地勾选：点击行 / 复选框仅切换 [FavFolderInfo.favState] 与
/// 计数，真正的提交仍由 [FavPanelActions] → [FavMixin.actionFavVideo] 完成，
/// 因此两种容器下的业务逻辑完全一致。
class FavFolderListView extends StatelessWidget {
  const FavFolderListView({
    super.key,
    required this.list,
    this.scrollController,
    this.dense = true,
  });

  final List<FavFolderInfo> list;
  final ScrollController? scrollController;

  /// 行密度：底部面板与 Popover 均为 true（保持原列表行观感）
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.zero,
      itemCount: list.length,
      itemBuilder: (context, index) {
        FavFolderInfo item = list[index];
        return Material(
          type: .transparency,
          child: Builder(
            builder: (context) {
              final isChecked = item.favState == 1;

              void onTap() {
                item
                  ..favState = isChecked ? 0 : 1
                  ..mediaCount += isChecked ? -1 : 1;
                (context as Element).markNeedsBuild();
              }

              return ListTile(
                onTap: onTap,
                dense: dense,
                leading: BiliUtils.isPublicFav(item.attr)
                    ? const Icon(Icons.folder_outlined)
                    : const Icon(Icons.lock_outline),
                minLeadingWidth: 0,
                title: Text(item.title),
                subtitle: Text(
                  '${item.mediaCount}个内容 . ${BiliUtils.isPublicFavText(item.attr)}',
                ),
                trailing: Transform.scale(
                  scale: 0.9,
                  child: Checkbox(
                    value: isChecked,
                    onChanged: (bool? checkValue) => onTap(),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// 底部面板的「取消 / 完成」操作区（原 `FavPanel` 底部区域原样迁出）。
class FavPanelActions extends StatelessWidget {
  const FavPanelActions({super.key, required this.ctr});

  final FavMixin ctr;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    return Padding(
      padding: .only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.viewPaddingOf(context).bottom + 12,
      ),
      child: Row(
        spacing: 25,
        mainAxisAlignment: .end,
        children: [
          FilledButton.tonal(
            onPressed: Get.back,
            style: FilledButton.styleFrom(
              visualDensity: .compact,
              foregroundColor: theme.outline,
              backgroundColor: theme.onInverseSurface,
            ),
            child: const Text('取消'),
          ),
          FilledButton.tonal(
            onPressed: () {
              feedBack();
              ctr.actionFavVideo();
            },
            style: const ButtonStyle(visualDensity: .compact),
            child: const Text('完成'),
          ),
        ],
      ),
    );
  }
}
