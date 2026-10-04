import 'package:PiliPlus/common/widgets/custom_arc.dart';
import 'package:PiliPlus/common/widgets/desktop/desktop_tokens.dart';
import 'package:PiliPlus/utils/extension/theme_ext.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:material_ui/material_ui.dart';

class ActionItem extends StatefulWidget {
  const ActionItem({
    super.key,
    required this.icon,
    this.selectIcon,
    this.onTap,
    this.onLongPress,
    this.text,
    this.selectStatus = false,
    required this.semanticsLabel,
    this.expand = true,
    this.animation,
    this.onStartTriple,
    this.onCancelTriple,
    this.desktopTokens = false,
  }) : assert(!selectStatus || selectIcon != null),
       _isThumbsUp = onStartTriple != null;

  final Icon icon;
  final Icon? selectIcon;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? text;
  final bool selectStatus;
  final String semanticsLabel;
  final bool expand;
  final Animation<double>? animation;
  final VoidCallback? onStartTriple;
  final void Function([bool])? onCancelTriple;
  final bool _isThumbsUp;

  /// 允许在桌面端使用 Desktop UI Kit 的配色与 Hover 反馈：
  /// 默认 icon / 文字 = 次级文字色，Hover 背景 = `DesktopTokens.hoverSurface`，
  /// Hover 后 = 主文字色（选中态仍用强调色）。
  ///
  /// 仅由桌面右栏操作栏等桌面版式传入；移动端 / 平板以及播放器全屏浮层不传，
  /// 保持原有配色与 InkWell 默认反馈，行为与视觉完全不变。
  final bool desktopTokens;

  @override
  State<ActionItem> createState() => _ActionItemState();
}

class _ActionItemState extends State<ActionItem> {
  bool _hover = false;

  /// 是否启用桌面 UI Kit 配色（移动端即使传入也不会生效）
  bool get _useDesktopTokens =>
      widget.desktopTokens && PlatformUtils.isDesktop;

  /// 未选中态的 icon / 文字色：桌面端跟着 Hover 从次级文字色提亮到主文字色
  Color _idleColor(ColorScheme colorScheme) => _useDesktopTokens
      ? (_hover
            ? DesktopTokens.titleColor(colorScheme)
            : DesktopTokens.subtitleColor(colorScheme))
      : colorScheme.outline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    late final primary = !widget.expand && colorScheme.isLight
        ? colorScheme.inversePrimary
        : colorScheme.primary;
    Widget child = Icon(
      widget.selectStatus ? widget.selectIcon!.icon! : widget.icon.icon,
      size: 18,
      color: widget.selectStatus
          ? primary
          : widget.icon.color ?? _idleColor(colorScheme),
      semanticLabel: widget.semanticsLabel,
    );

    if (widget.animation != null) {
      child = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: widget.animation!,
            builder: (context, child) => Arc(
              size: 28,
              color: primary,
              progress: -widget.animation!.value,
            ),
          ),
          child,
        ],
      );
    } else {
      child = SizedBox.square(dimension: 28, child: child);
    }

    child = Material(
      type: .transparency,
      child: InkWell(
        borderRadius: const .all(.circular(6)),
        // 桌面 UI Kit：Hover = surfaceContainerHighest @ .5（与 DesktopCard 同款），
        // 仅换颜色，不改变按钮尺寸与布局
        hoverColor: _useDesktopTokens
            ? DesktopTokens.hoverSurface(colorScheme)
            : null,
        onHover: _useDesktopTokens
            ? (value) => setState(() => _hover = value)
            : null,
        onTap: widget._isThumbsUp ? null : widget.onTap,
        onLongPress: widget._isThumbsUp ? null : widget.onLongPress,
        onSecondaryTap: PlatformUtils.isMobile || widget._isThumbsUp
            ? null
            : widget.onLongPress,
        onTapDown: widget._isThumbsUp ? (_) => widget.onStartTriple!() : null,
        onTapUp: widget._isThumbsUp
            ? (_) => widget.onCancelTriple!(true)
            : null,
        onTapCancel: widget._isThumbsUp ? widget.onCancelTriple : null,
        child: widget.expand
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [child, _buildText(theme)],
              )
            : child,
      ),
    );
    return widget.expand ? Expanded(child: child) : child;
  }

  Widget _buildText(ThemeData theme) {
    final hasText = widget.text != null;
    final child = Text(
      hasText ? widget.text! : '-',
      key: hasText ? ValueKey(widget.text!) : null,
      style: TextStyle(
        color: widget.selectStatus
            ? theme.colorScheme.primary
            : _idleColor(theme.colorScheme),
        fontSize: theme.textTheme.labelSmall!.fontSize,
      ),
    );
    if (hasText) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: child,
      );
    }
    return child;
  }
}
