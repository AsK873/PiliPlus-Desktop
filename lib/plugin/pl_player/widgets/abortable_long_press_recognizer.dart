import 'package:flutter/gestures.dart';

/// 可中止的长按识别器。
///
/// [LongPressGestureRecognizer] 的 deadline 定时器只在
/// `didStopTrackingLastPointer`（pointer up / cancel）、`rejectGesture`、
/// `acceptGesture` 或 `dispose` 时才会被取消
/// （`PrimaryPointerGestureRecognizer._stopTimer()`）；**窗口 resize / 最大化
/// 不会触发其中任何一个**。因此当某次按压的 up 在窗口状态切换中丢失时，
/// 定时器仍会在之后到点并直接执行 `didExceedDeadline()` →
/// `_checkLongPressStart()`（Flutter 侧没有状态守卫），造成「没有任何真实长按
/// 却进入长按倍速并长期停留」（实测 3×，只有鼠标移出才恢复）。
///
/// [abort] 用于在「手势边界」事件（窗口尺寸变化等）上**真正终止本次 pointer
/// tracking**：它走 recognizer 自己的 rejected 生命周期，从而
/// `stopTrackingPointer` → `didStopTrackingLastPointer` → `_stopTimer()`，
/// 从源头取消 deadline 定时器，而不是只在业务层拦截结果。
///
/// [abort] 是幂等的，且对「无 active pointer / 已 rejected / 已 accepted /
/// 已 dispose / 重复调用」都安全。
class AbortableLongPressRecognizer extends LongPressGestureRecognizer {
  AbortableLongPressRecognizer({super.duration, super.debugOwner});

  bool _disposed = false;

  /// 是否仍在跟踪 pointer（为 true 时仍可能有 deadline 定时器存活）。
  ///
  /// 注意用 [state] 而不是 `primaryPointer`：`PrimaryPointerGestureRecognizer`
  /// 在停止跟踪后不会清空 `_primaryPointer`，只看它会把「已结束」误判为「进行中」。
  bool get hasActivePointer =>
      !_disposed && state == GestureRecognizerState.possible;

  /// 中止当前这次长按跟踪。
  void abort() {
    if (_disposed) {
      return;
    }
    final pointer = primaryPointer;
    if (pointer == null) {
      return;
    }
    // 已 accepted（已进入长按）时 `resolve(rejected)` 走 `_reset()`，
    // 尚未 accepted 时会触发 `onLongPressCancel`；
    // 随后 `stopTrackingPointer` 让状态回到 ready 并 `_stopTimer()`。
    resolve(GestureDisposition.rejected);
    stopTrackingPointer(pointer);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
