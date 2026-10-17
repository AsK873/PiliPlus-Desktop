import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

class ImmediateTapGestureRecognizer extends OneSequenceGestureRecognizer {
  ImmediateTapGestureRecognizer({
    super.debugOwner,
    super.supportedDevices,
    super.allowedButtonsFilter = _defaultButtonAcceptBehavior,
    this.onTapDown,
    this.onTapUp,
    this.onTapCancel,
    this.onTap,
  });

  static bool _defaultButtonAcceptBehavior(int buttons) =>
      buttons == kPrimaryButton;

  GestureTapDownCallback? onTapDown;

  GestureTapUpCallback? onTapUp;

  GestureTapCancelCallback? onTapCancel;

  GestureTapCallback? onTap;

  PointerUpEvent? _up;
  int? _activePointer;
  bool _sentTapDown = false;
  bool _wonArena = false;
  Offset? _initialPosition;

  /// 判定「仍是点击」的最大允许漂移（逻辑像素）。
  ///
  /// 取 Flutter 的标准点击容差 [kTouchSlop]（18），与 `TapGestureRecognizer` 在
  /// 无 gestureSettings 时的默认口径一致：「按下到抬起之间指针漂移不超过一个标准
  /// 点击容差，就还算一次点击」。
  ///
  /// 修复前这里写的是 `distanceSquared > 4.0`，即**从按下点起的累计位移**超过
  /// 2 逻辑像素就直接 reject。这个量级最初（a2d5ecc51）是用来判断**单个
  /// PointerMove 事件的位移**（`event.delta.distanceSquared`）的，923af32c9 改成
  /// 累计位移后量级被放大成「整段点击」，于是鼠标点击时手部 2 像素以上的自然
  /// 抖动都会被判成「拖动」，`resolve(rejected)` + `stopTrackingPointer()` 之后
  /// 本次手势出局，抬起时不再触发 `onTapUp` —— 即「点击偶尔无反应」。
  static const double _kMaxTapDrift = kTouchSlop;

  static bool _withinTapDrift(Offset? initial, Offset current) {
    if (initial == null) {
      return true;
    }
    return (current - initial).distance <= _kMaxTapDrift;
  }

  @override
  bool isPointerPanZoomAllowed(PointerPanZoomStartEvent event) => false;

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      _activePointer == null && super.isPointerAllowed(event);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _reset(event.pointer);
    _handleTapDown(event);
    _initialPosition = event.position;
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != _activePointer) {
      resolvePointer(event.pointer, GestureDisposition.rejected);
      stopTrackingPointer(event.pointer);
      return;
    }

    if (event is PointerMoveEvent) {
      _handlePointerMove(event);
    } else if (event is PointerUpEvent) {
      _up = event;
      _handlePointerUp(event);
    } else if (event is PointerCancelEvent) {
      resolve(GestureDisposition.rejected);
    }

    stopTrackingIfPointerNoLongerDown(event);
  }

  void _handleTapDown(PointerDownEvent event) {
    if (_sentTapDown) return;
    _sentTapDown = true;

    if (onTapDown != null) {
      final details = TapDownDetails(
        globalPosition: event.position,
        localPosition: event.localPosition,
        kind: event.kind,
      );
      invokeCallback<void>('onTapDown', () => onTapDown!(details));
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    // 与 Flutter `TapGestureRecognizer` 的容差口径一致：从按下点起的累计漂移
    // 超过一个标准点击容差（kTouchSlop）才认为「这不是点击」。
    // 注意这里是**累计**位移（不是单个 move 事件的 delta），且阈值必须是点击
    // 容差量级，否则鼠标点击时的手部抖动会被误判成拖动（见 [_kMaxTapDrift]）。
    if (!_withinTapDrift(_initialPosition, event.position)) {
      resolve(GestureDisposition.rejected);
      stopTrackingPointer(event.pointer);
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_wonArena) {
      _handleTapUp(event);
    }
  }

  void _handleTapUp(PointerUpEvent event) {
    if (onTapUp != null) {
      final details = TapUpDetails(
        globalPosition: event.position,
        localPosition: event.localPosition,
        kind: event.kind,
      );
      invokeCallback<void>('onTapUp', () => onTapUp!(details));
    }

    if (onTap != null) {
      invokeCallback<void>('onTap', onTap!);
    }

    _reset();
  }

  void _cancelGesture(String reason) {
    if (_sentTapDown && onTapCancel != null) {
      invokeCallback<void>('onTapCancel: $reason', onTapCancel!);
    }
    _reset();
  }

  void _reset([int? pointer]) {
    _activePointer = pointer;
    _up = null;
    _sentTapDown = false;
    _wonArena = false;
  }

  @override
  void acceptGesture(int pointer) {
    super.acceptGesture(pointer);

    if (pointer == _activePointer) {
      _wonArena = true;

      if (_up != null) {
        _handleTapUp(_up!);
      }
    }
  }

  @override
  void rejectGesture(int pointer) {
    super.rejectGesture(pointer);

    if (pointer == _activePointer) {
      _cancelGesture('gesture rejected by arena');
      stopTrackingPointer(pointer);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _initialPosition = null;
  }

  @override
  void resolve(GestureDisposition disposition) {
    if (_wonArena && disposition == GestureDisposition.rejected) {
      _cancelGesture('spontaneous');
    }
    super.resolve(disposition);
  }

  @override
  String get debugDescription => 'immediate tap';

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(IntProperty('activePointer', _activePointer))
      ..add(
        FlagProperty(
          'sentTapDown',
          value: _sentTapDown,
          ifTrue: 'has sentTapDown',
        ),
      )
      ..add(FlagProperty('wonArena', value: _wonArena, ifTrue: 'wonArena'))
      ..add(
        DiagnosticsProperty<PointerUpEvent>(
          'pointerUpEvent',
          _up,
          defaultValue: null,
        ),
      );
  }
}
