import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/badge.dart';
import 'package:PiliPlus/common/widgets/image/image_save.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/models/search/result.dart';
import 'package:PiliPlus/utils/date_utils.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:material_ui/material_ui.dart';

class SearchPgcItem extends StatelessWidget {
  const SearchPgcItem({
    super.key,
    required this.item,
  });

  final SearchPgcItemModel item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    const TextStyle style = TextStyle(fontSize: 13);
    void onLongPress() => imageSaveDialog(
      title: item.title.map((item) => item.text).join(),
      cover: item.cover,
    );
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => PageUtils.viewPgc(seasonId: item.seasonId),
        onLongPress: PlatformUtils.isMobile ? onLongPress : null,
        onSecondaryTap: PlatformUtils.isMobile ? null : onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Style.safeSpace,
            vertical: 5,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 封面按「本卡可用行高」等比：桌面端整卡同比放大时封面一起放大
              // （行高 = 网格 mainAxisExtent = 158 · scale）；非桌面端行高仍是
              // 原来的 158 ⇒ 封面仍是 111×148，几何零变化。
              LayoutBuilder(
                builder: (context, constraints) {
                  final thumbHeight = constraints.maxHeight.isFinite
                      ? constraints.maxHeight
                      : 148.0;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      NetworkImgLayer(
                        width: thumbHeight * 111 / 148,
                        height: thumbHeight,
                        src: item.cover,
                      ),
                      PBadge(
                        text: item.seasonTypeName,
                        top: 6.0,
                        right: 6.0,
                        bottom: null,
                        left: null,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: item.title
                            .map(
                              (e) => TextSpan(
                                text: e.text,
                                style: TextStyle(
                                  color: e.isEm
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('评分:${item.mediaScore?['score']}', style: style),
                    Text.rich(
                      style: style,
                      TextSpan(
                        children: [
                          if (item.areas?.isNotEmpty == true)
                            TextSpan(text: '${item.areas!}  ·  '),
                          TextSpan(
                            text: DateFormatUtils.dateFormat(item.pubtime),
                          ),
                        ],
                      ),
                    ),
                    Text.rich(
                      style: style,
                      TextSpan(
                        children: [
                          if (item.styles?.isNotEmpty == true)
                            TextSpan(text: '${item.styles!}  ·  '),
                          if (item.indexShow?.isNotEmpty == true)
                            TextSpan(text: item.indexShow!),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
