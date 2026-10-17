// =============================================================
// PiliPlus Windows 桌面化 · 卡片「整卡等比例缩放」共用底座（纯 UI）
//
// 与首页 lib/pages/rcmd/view.dart 的 `_HomeGridDelegate` 是**同一套算式**
// （本文件 + utils/grid.dart 的 CardGridDelegate 是它的参数化泛化，不做第二套设计）：
//
//   ① 列数   n          = max(1, round((W + G) / (columnPitch + G)))
//   ② 列宽   cardWidth  = (W − G·(n − 1)) / n     （W = 网格可用宽度、G = 横向间距）
//   ③ 缩放   scale      = cardWidth / baseCardWidth
//   ④ 行高   mainAxisExtent
//            · 缩略图 + 信息区卡片：cardWidth / childAspectRatio + baseContentExtent · scale
//            · 固定行高卡片（横向卡）：baseMainAxisExtent · scale
//   ⑤ 文字   textScale   = scale（局部 MediaQuery.textScaler，只作用于卡片根节点）
//
// 卡片是**一个整体缩放单位**：缩略图、信息区高度、标题/UP 主/统计/日期/角标文字
// 由同一个 scale 驱动，不会出现「缩略图变大但字体不变」或「卡宽变大但信息区固定」。
//
// 仅桌面端生效：非桌面端的 delegate 逐字复刻旧口径（utils/grid.dart 的 ceil 列数 +
// 固定行高），[DesktopCardScaleBox] 直接返回子节点，因此 Mobile / Tablet 零变化。
// =============================================================
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:material_ui/material_ui.dart';

/// 列节距 / 设计基准卡宽 = `246 / 206`。
///
/// 取自首页：`Pref.recommendCardWidth` = 206（设计基准卡宽）→
/// `_HomeGridDelegate.columnPitch` = 246，即「一列连同它的间距约按
/// 设计基准卡宽的 1.194 倍折算」。其余卡片族沿用**同一比值**换算自己的列节距，
/// 所以列数策略与首页完全一致（不是另一套算法）。
const double kCardColumnPitchRatio = 246 / 206;

/// 把环境 [TextScaler]（系统 / 用户字号设置）再乘一个固定系数。
///
/// 与 `VideoCardV._ScaledTextScaler` 同一实现（那边保持逐字不动，避免影响首页
/// 既有基准实现）：最终字号 = 原字号 × 用户字号系数 × [factor]，只叠加不替换环境
/// 缩放，因此用户字号设置仍然生效；字体、maxLines、ellipsis、文字内容都不参与。
class ScaledTextScaler extends TextScaler {
  const ScaledTextScaler(this.ambient, this.factor);

  final TextScaler ambient;
  final double factor;

  @override
  double scale(double fontSize) => ambient.scale(fontSize) * factor;

  /// [TextScaler] 契约里的「估算值」：本类只做线性叠加，故直接相乘即可。
  /// 该成员自 v3.12 起废弃，但仍是抽象接口的一部分，必须实现。
  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => ambient.textScaleFactor * factor;

  @override
  String toString() => 'ScaledTextScaler($ambient, $factor)';
}

/// 桌面端「卡片整体同比缩放」的文字载体：以 [baseCardWidth] 为该卡片族的设计基准宽
/// （= 该网格原来的 `maxCrossAxisExtent`），按**本卡片实际宽度**求
/// `scale = 实际宽度 / baseCardWidth`，再用局部 [MediaQuery.textScaler] 作用到卡片
/// 内部**全部**文字（标题 / UP 主 / 播放量 / 弹幕 / 日期 / 角标一起变，不会只变一个）。
///
/// 口径：网格给 item 的是 tight 约束，`constraints.maxWidth` 就是 delegate 算出的
/// 列宽，因此这里与 [CardGridDelegate] 的 `scale` 是同一个值，不需要调用方复刻列数算法。
///
/// - 只包**卡片根节点**，不改页面 / 全局 MediaQuery；
/// - 非桌面端、约束非有限（卡片不在网格里，例如放在 SliverToBoxAdapter 中）、
///   `scale == 1` 时**原样返回**，不插入任何额外布局层；
/// - 卡片自身高度由 delegate 的 `mainAxisExtent` 同比给出（信息区高度随之缩放）。
class DesktopCardScaleBox extends StatelessWidget {
  const DesktopCardScaleBox({
    super.key,
    required this.baseCardWidth,
    required this.child,
  }) : assert(baseCardWidth > 0);

  /// 该卡片族的设计基准宽（= 网格原来的 `maxCrossAxisExtent`）。
  final double baseCardWidth;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!PlatformUtils.isDesktop) {
      return child;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        if (!maxWidth.isFinite || maxWidth <= 0) {
          return child;
        }
        final scale = maxWidth / baseCardWidth;
        if (scale == 1.0) {
          return child;
        }
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: ScaledTextScaler(
              MediaQuery.textScalerOf(context),
              scale,
            ),
          ),
          child: child,
        );
      },
    );
  }
}
