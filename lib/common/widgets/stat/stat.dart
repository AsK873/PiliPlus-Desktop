import 'package:PiliPlus/models/common/stat_type.dart';
import 'package:PiliPlus/utils/num_utils.dart';
import 'package:material_ui/material_ui.dart';

class StatWidget extends StatelessWidget {
  final StatType type;
  final dynamic value;
  final Color? color;
  final double iconSize;

  /// 数值文字字号（默认 12，与改动前的取值一致）。
  ///
  /// 供桌面右栏「整体放大」的卡片按新的元信息基准传入（见
  /// `pages/video/related/view.dart`）；不传即保持原样，移动端零变化。
  final double fontSize;

  const StatWidget({
    super.key,
    required this.type,
    required this.value,
    this.color,
    this.iconSize = 13,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    Color color =
        this.color ??
        Theme.of(context).colorScheme.outline.withValues(alpha: 0.8);
    return Row(
      spacing: 2,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          type.iconData,
          semanticLabel: type.label,
          size: iconSize,
          color: color,
        ),
        Text(
          NumUtils.numFormat(value),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: fontSize, color: color),
        ),
      ],
    );
  }
}
