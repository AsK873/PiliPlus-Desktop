import 'package:flutter/gestures.dart'
    show
        ScaleGestureRecognizer,
        RecognizerCallback,
        GestureRecognizer,
        PointerEvent,
        PointerMoveEvent,
        PointerDownEvent,
        PointerDeviceKind,
        GestureDisposition;

mixin PlayerGestureMixin on GestureRecognizer {
  bool isPosAllowed = true;

  @override
  T? invokeCallback<T>(
    String name,
    RecognizerCallback<T> callback, {
    String Function()? debugReport,
  }) {
    if (!isPosAllowed) return null;
    return super.invokeCallback(name, callback, debugReport: debugReport);
  }
}

/// 播放器的缩放/拖动识别器（`MouseInteractiveViewer` 用）。
///
/// 额外要求「精确指针（鼠标 / 触控板）」先真正拖动一小段距离，才允许它赢下竞技场；
/// 在这之前若 Flutter 判定它该 accept，就改为主动 reject（放弃这次手势）。
///
/// 根因：本识别器与「点击」识别器同场竞技，而 `ScaleGestureRecognizer` 判定
/// accept 的口径是 `focalPointDelta > computePanSlop(kind, gestureSettings)`；
/// `computePanSlop` 对 mouse / trackpad 返回 `kPrecisePointerPanSlop = 2.0`。
/// 也就是说鼠标只要移动 2 逻辑像素，缩放识别器就会 accept 并**reject 掉同场所有
/// 其它识别器**（含点击识别器），于是这次点击连同其 `PointerUp` 一起消失 ——
/// 正是「鼠标点击偶尔无反应」。
///
/// 阈值取 [kPrecisePointerMinDragDistance]：远大于点击抖动、远小于一次有意的
/// 缩放/拖动；触屏（touch / stylus 等）沿用 Flutter 原有判定，移动端行为不变。
class PlayerScaleGestureRecognizer extends ScaleGestureRecognizer
    with PlayerGestureMixin {
  PlayerScaleGestureRecognizer({
    super.debugOwner,
    super.supportedDevices,
    super.allowedButtonsFilter,
    super.dragStartBehavior,
    super.trackpadScrollCausesScale,
    super.trackpadScrollToScaleFactor,
  });

  /// 精确指针（鼠标 / 触控板）起手必须真正拖动的距离，才允许本识别器赢下竞技场。
  static const double kPrecisePointerMinDragDistance = 10.0;

  PointerDownEvent? _downEvent;

  /// 当前手势相对按下点的位移（只在精确指针路径上使用）。
  double _currentDragDistance = 0;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _downEvent = event;
    _currentDragDistance = 0;
    super.addAllowedPointer(event);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _downEvent = null;
    _currentDragDistance = 0;
    super.didStopTrackingLastPointer(pointer);
  }

  bool get _isPrecisePointer {
    final event = _downEvent;
    return event != null &&
        (event.kind == PointerDeviceKind.mouse ||
            event.kind == PointerDeviceKind.trackpad);
  }

  @override
  void resolve(GestureDisposition disposition) {
    // 精确指针且还没真正拖动起来：不允许本识别器 accept。
    // 这里改判为 rejected，让同场的点击 / 双击识别器能正常拿到这次手势。
    if (disposition == GestureDisposition.accepted &&
        _isPrecisePointer &&
        _currentDragDistance < kPrecisePointerMinDragDistance) {
      super.resolve(GestureDisposition.rejected);
      return;
    }
    super.resolve(disposition);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      final down = _downEvent;
      if (down != null) {
        _currentDragDistance = (event.position - down.position).distance;
      }
    }
    super.handleEvent(event);
  }
}
