import 'package:PiliPlus/utils/extension/selectable_region_ext.dart';
import 'package:material_ui/material_ui.dart';

class SelectionText extends StatelessWidget {
  const SelectionText(
    String this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.contextMenuBuilder = openUrlMenuBuilder,
    this.maxLines,
    this.overflow,
  }) : textSpan = null;

  const SelectionText.rich(
    InlineSpan this.textSpan, {
    super.key,
    this.style,
    this.textAlign,
    this.contextMenuBuilder = openUrlMenuBuilder,
    this.maxLines,
    this.overflow,
  }) : data = null;

  final String? data;
  final InlineSpan? textSpan;
  final TextStyle? style;
  final TextAlign? textAlign;
  final SelectableRegionContextMenuBuilder? contextMenuBuilder;

  /// 与 [Text.maxLines] 同义：为 null 时不限制行数（原行为，移动端/平板不变）。
  final int? maxLines;

  /// 与 [Text.overflow] 同义：为 null 时沿用 [Text] 默认值。
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      contextMenuBuilder: contextMenuBuilder,
      child: Text.rich(
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        TextSpan(
          text: data,
          children: textSpan != null ? <InlineSpan>[textSpan!] : null,
        ),
      ),
    );
  }
}

Widget openUrlMenuBuilder(_, SelectableRegionState state) {
  final buttonItems = state.contextMenuButtonItems;
  state.addLaunchMenuIfNeeded(buttonItems, index: 3);
  return AdaptiveTextSelectionToolbar.buttonItems(
    buttonItems: buttonItems,
    anchors: state.contextMenuAnchors,
  );
}
