/*
 * This file is part of PiliPlus
 *
 * PiliPlus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * PiliPlus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:math' as math;

import 'package:PiliPlus/common/widgets/desktop/desktop_tokens.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/image_grid/image_grid_view.dart'
    show ImageModel;
import 'package:PiliPlus/utils/image_utils.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:material_ui/material_ui.dart';

/// 评论区图片的「当前页面临时预览层」。
///
/// 与全局 [GalleryViewer]（`PageUtils.imageView`，全屏黑色 HeroDialogRoute）
/// 完全独立：不改动全局预览的任何默认行为，只在评论区按需叠加本层。
///
/// 规格：
/// * 遮罩：`Colors.grey` @ 50% 不透明度，铺满整个当前可视区域；底下评论页仍可见；
/// * 图片：居中，**面积 ≈ 可视区域的 50%**，严格等比、不拉伸、不裁剪；
///   同时限制不超过可视区域（含安全边距）；
/// * 交互：点图片不关闭（吞掉点击，不冒泡到遮罩）；点图片以外遮罩关闭；
///   系统返回键同样关闭；
/// * 保存（仅 Desktop）：鼠标悬停图片右上角淡入轻量「保存图片」按钮；
///   在图片上右键弹出项目既有的图片右键菜单（保存图片 / 复制链接 / 网页打开）。
///   两者都直接复用既有 `ImageUtils.downloadImg`（下载**原图**），
///   不截图、不保存带遮罩的预览图，保存后预览保持打开。
///   Mobile / Tablet 不新增悬停按钮，原有保存方式（长按缩略图菜单）不受影响。

/// 遮罩：灰色 @ 50% 半透明（要求「灰色、50% 透明度」）
final Color commentPreviewMaskColor = Colors.grey.withValues(alpha: 0.5);

/// 图片总面积目标占可视区域面积的比例
const double _kTargetAreaRatio = 0.5;

/// 图片与可视区域边缘的安全边距
const double _kMargin = 24;

/// 根据「可视区域尺寸 + 图片原始宽高比」计算显示尺寸：
///
/// `targetArea = viewportW × viewportH × 0.5`
/// `displayW = sqrt(targetArea × aspect)`，`displayH = displayW / aspect`
///
/// 再按可视区域（含 [_kMargin] 边距）双向裁剪，保证等比且不超出可视区域。
/// 横图 / 竖图 / 正方形共用同一公式（面积恒定、比例由 aspect 决定）。
({double width, double height}) commentPreviewImageSize({
  required double viewportWidth,
  required double viewportHeight,
  required double aspectRatio,
}) {
  if (!viewportWidth.isFinite ||
      !viewportHeight.isFinite ||
      viewportWidth <= 0 ||
      viewportHeight <= 0) {
    return (width: 0, height: 0);
  }
  final double aspect = (aspectRatio.isFinite && aspectRatio > 0)
      ? aspectRatio
      : 1.0;
  final double targetArea = viewportWidth * viewportHeight * _kTargetAreaRatio;
  // 面积恒定 ⇒ 宽 = sqrt(area × aspect)，高 = 宽 / aspect
  double width = math.sqrt(targetArea * aspect);
  double height = width / aspect;

  final double maxWidth = math.max(0.0, viewportWidth - _kMargin * 2);
  final double maxHeight = math.max(0.0, viewportHeight - _kMargin * 2);
  // 仅做「限制最大」的等比收窄，绝不单独拉伸某一维
  final double scale = math.min(
    1.0,
    math.min(maxWidth / width, maxHeight / height),
  );
  width *= scale;
  height *= scale;
  return (width: width, height: height);
}

/// 打开评论区图片预览层（当前页面 Overlay，不推路由）。
void showCommentImagePreview(
  BuildContext context, {
  required List<ImageModel> picArr,
  required int initialIndex,
}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => CommentImagePreview(
      images: picArr,
      initialIndex: initialIndex,
      onDismiss: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}

class CommentImagePreview extends StatefulWidget {
  const CommentImagePreview({
    super.key,
    required this.images,
    this.initialIndex = 0,
    required this.onDismiss,
  });

  final List<ImageModel> images;
  final int initialIndex;
  final VoidCallback onDismiss;

  @override
  State<CommentImagePreview> createState() => _CommentImagePreviewState();
}

class _CommentImagePreviewState extends State<CommentImagePreview> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  bool _dismissed = false;

  /// 鼠标是否悬停在预览图片上（仅 Desktop 使用 ⇒ 控制保存按钮淡入淡出）
  bool _hovering = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      // 保留系统返回关闭预览的能力
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _dismiss();
      },
      child: PageView.builder(
        controller: _controller,
        itemCount: widget.images.length,
        itemBuilder: (context, index) =>
            _buildPage(context, widget.images[index]),
      ),
    );
  }

  /// 单张图片的预览页：**遮罩在下、图片在上**。
  ///
  /// 遮罩必须放在 `PageView` 的每个 page 内部（而不是与 `PageView` 同级放在
  /// 它下面）：`PageView` 的 `RenderViewport.hitTestChildren` 在命中子节点时
  /// 会直接 `add` 自身并返回 true，同级更下层的遮罩收不到点击。
  Widget _buildPage(BuildContext context, ImageModel item) {
    final size = MediaQuery.sizeOf(context);
    final display = commentPreviewImageSize(
      viewportWidth: size.width,
      viewportHeight: size.height,
      aspectRatio: _aspectOf(item),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        // ① 遮罩：铺满可视区域；点它（图片以外区域）关闭预览
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _dismiss,
          child: ColoredBox(color: commentPreviewMaskColor),
        ),
        // ② 图片：居中、严格等比、面积 ≈ 50%；自身吞掉点击（不关闭）
        Center(
          child: _buildImage(context, item, display),
        ),
      ],
    );
  }

  /// 图片本体 + Desktop 保存入口。
  ///
  /// `MouseRegion` 只包裹图片，因此悬停判定严格等于「鼠标在图片上」；
  /// 保存按钮用 `Positioned` 叠在图片右上角，**不参与图片尺寸计算**，
  /// 图片尺寸/位置/比例与遮罩均不受影响。
  Widget _buildImage(
    BuildContext context,
    ImageModel item,
    ({double width, double height}) display,
  ) {
    return MouseRegion(
      // 仅 Desktop 需要悬停入口；Mobile / Tablet 保持原交互不变
      onEnter: PlatformUtils.isDesktop ? (_) => _setHover(true) : null,
      onExit: PlatformUtils.isDesktop ? (_) => _setHover(false) : null,
      child: GestureDetector(
        // 空回调刻意「吃掉」图片区域内的点击 ⇒ 点图片不关闭预览
        onTap: () {},
        // Desktop：图片上右键 = 项目既有的图片右键菜单
        // （与 GalleryViewer._showDesktopMenu 同一套动作与实现方式）
        onSecondaryTapUp: PlatformUtils.isDesktop
            ? (details) => _showDesktopMenu(details.globalPosition, item)
            : null,
        child: SizedBox(
          width: display.width,
          height: display.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: NetworkImgLayer(
                  src: item.url,
                  fit: BoxFit.contain,
                  width: display.width,
                  height: display.height,
                ),
              ),
              // ③ 悬停保存按钮：位于图片右上角，淡入淡出（120ms / fastOutSlowIn），
              //    只在 Desktop 悬停时出现，不改变图片尺寸与位置。
              if (PlatformUtils.isDesktop)
                Positioned(
                  top: 4,
                  right: 4,
                  child: AnimatedOpacity(
                    opacity: _hovering ? 1 : 0,
                    duration: DesktopTokens.hoverDuration,
                    curve: DesktopTokens.curve,
                    child: _buildSaveButton(item),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _setHover(bool value) {
    if (_hovering == value) return;
    setState(() => _hovering = value);
  }

  /// 轻量圆形「保存图片」按钮：复用既有 `ImageUtils.downloadImg`（保存原图）。
  /// 保存流程结束后**不关闭预览**（按钮自身不调用任何关闭逻辑）。
  Widget _buildSaveButton(ImageModel item) {
    final colorScheme = ColorScheme.of(context);
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 18,
        tooltip: '保存图片',
        onPressed: () => ImageUtils.downloadImg([item.url]),
        icon: const Icon(Icons.download),
        style: IconButton.styleFrom(
          backgroundColor: colorScheme.secondaryContainer,
          foregroundColor: colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }

  /// Desktop 图片右键菜单：与 `GalleryViewer._showDesktopMenu` 保持一致的动作集，
  /// 复用既有保存 / 复制 / 打开实现，不新增下载逻辑。
  void _showDesktopMenu(Offset globalPosition, ImageModel item) {
    showMenu(
      context: context,
      position: PageUtils.menuPosition(globalPosition),
      items: [
        PopupMenuItem(
          height: 42,
          onTap: () => ImageUtils.downloadImg([item.url]),
          child: const Text('保存图片', style: TextStyle(fontSize: 14)),
        ),
        PopupMenuItem(
          height: 42,
          onTap: () => Utils.copyText(item.url),
          child: const Text('复制链接', style: TextStyle(fontSize: 14)),
        ),
        PopupMenuItem(
          height: 42,
          onTap: () => PageUtils.launchURL(item.url),
          child: const Text('网页打开', style: TextStyle(fontSize: 14)),
        ),
      ],
    );
  }

  /// 图片原始宽高比（API 提供的原始宽高；缺失/非法时回退 1:1）
  double _aspectOf(ImageModel item) {
    final double w = item.width.toDouble();
    final double h = item.height.toDouble();
    if (!w.isFinite || !h.isFinite || w <= 0 || h <= 0) return 1.0;
    return w / h;
  }
}
