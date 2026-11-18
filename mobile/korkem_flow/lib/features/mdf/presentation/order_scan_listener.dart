import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/auth/session_controller.dart';
import 'package:korkem_flow/core/design/tokens/motion.dart';
import 'package:korkem_flow/features/mdf/domain/order_scan.dart';
import 'package:korkem_flow/features/mdf/presentation/order_scan_sheet.dart';

/// A handheld scanner on the shop's computer types the sticker as a burst
/// of keys ending in Enter. Read by the keys' places, not their letters: the
/// keyboard may be in Russian, where the scanner's «K» arrives as «Л».
class ScanBurst {
  ScanBurst({this.gap = AppDuration.scanKeyGap});

  /// The longest pause inside one burst.
  final Duration gap;

  final _buffer = StringBuffer();
  Duration? _last;

  static final _name = RegExp(r'^[A-Z]{2,}-[A-Z]{2,}-\d{4}-\d+$');

  /// One key pressed at [at]. Returns what was scanned when Enter closes a
  /// burst that reads as an order's sticker; null otherwise.
  String? key(
    PhysicalKeyboardKey key, {
    required bool shift,
    required Duration at,
  }) {
    final last = _last;
    _last = at;
    if (last != null && at - last > gap) _buffer.clear();
    if (key == PhysicalKeyboardKey.enter ||
        key == PhysicalKeyboardKey.numpadEnter) {
      final text = _buffer.toString();
      _buffer.clear();
      _last = null;
      if (text.startsWith(orderQrPrefix) &&
          text.length > orderQrPrefix.length) {
        return text;
      }
      return _name.hasMatch(text) ? text : null;
    }
    final char = _charOf(key, shift: shift);
    if (char == null) {
      _buffer.clear();
    } else {
      _buffer.write(char);
    }
    return null;
  }

  static final Map<PhysicalKeyboardKey, String> _letters = {
    PhysicalKeyboardKey.keyA: 'A',
    PhysicalKeyboardKey.keyB: 'B',
    PhysicalKeyboardKey.keyC: 'C',
    PhysicalKeyboardKey.keyD: 'D',
    PhysicalKeyboardKey.keyE: 'E',
    PhysicalKeyboardKey.keyF: 'F',
    PhysicalKeyboardKey.keyG: 'G',
    PhysicalKeyboardKey.keyH: 'H',
    PhysicalKeyboardKey.keyI: 'I',
    PhysicalKeyboardKey.keyJ: 'J',
    PhysicalKeyboardKey.keyK: 'K',
    PhysicalKeyboardKey.keyL: 'L',
    PhysicalKeyboardKey.keyM: 'M',
    PhysicalKeyboardKey.keyN: 'N',
    PhysicalKeyboardKey.keyO: 'O',
    PhysicalKeyboardKey.keyP: 'P',
    PhysicalKeyboardKey.keyQ: 'Q',
    PhysicalKeyboardKey.keyR: 'R',
    PhysicalKeyboardKey.keyS: 'S',
    PhysicalKeyboardKey.keyT: 'T',
    PhysicalKeyboardKey.keyU: 'U',
    PhysicalKeyboardKey.keyV: 'V',
    PhysicalKeyboardKey.keyW: 'W',
    PhysicalKeyboardKey.keyX: 'X',
    PhysicalKeyboardKey.keyY: 'Y',
    PhysicalKeyboardKey.keyZ: 'Z',
  };

  static final Map<PhysicalKeyboardKey, String> _digits = {
    PhysicalKeyboardKey.digit0: '0',
    PhysicalKeyboardKey.digit1: '1',
    PhysicalKeyboardKey.digit2: '2',
    PhysicalKeyboardKey.digit3: '3',
    PhysicalKeyboardKey.digit4: '4',
    PhysicalKeyboardKey.digit5: '5',
    PhysicalKeyboardKey.digit6: '6',
    PhysicalKeyboardKey.digit7: '7',
    PhysicalKeyboardKey.digit8: '8',
    PhysicalKeyboardKey.digit9: '9',
    PhysicalKeyboardKey.numpad0: '0',
    PhysicalKeyboardKey.numpad1: '1',
    PhysicalKeyboardKey.numpad2: '2',
    PhysicalKeyboardKey.numpad3: '3',
    PhysicalKeyboardKey.numpad4: '4',
    PhysicalKeyboardKey.numpad5: '5',
    PhysicalKeyboardKey.numpad6: '6',
    PhysicalKeyboardKey.numpad7: '7',
    PhysicalKeyboardKey.numpad8: '8',
    PhysicalKeyboardKey.numpad9: '9',
  };

  static final _shifts = <PhysicalKeyboardKey>{
    PhysicalKeyboardKey.shiftLeft,
    PhysicalKeyboardKey.shiftRight,
  };

  /// What the key types on an English keyboard; '' for Shift itself, which
  /// keeps the burst going; null for anything a sticker never has.
  static String? _charOf(PhysicalKeyboardKey key, {required bool shift}) {
    if (_shifts.contains(key)) return '';
    final letter = _letters[key];
    if (letter != null) return shift ? letter : letter.toLowerCase();
    if (!shift && _digits.containsKey(key)) return _digits[key];
    if (key == PhysicalKeyboardKey.minus ||
        key == PhysicalKeyboardKey.numpadSubtract) {
      return shift ? null : '-';
    }
    if (key == PhysicalKeyboardKey.semicolon) return shift ? ':' : null;
    return null;
  }
}

/// Listens for a scanner's burst on any screen, signed in, and opens the
/// order it read (owner, 18.11.2026).
class OrderScanListener extends ConsumerStatefulWidget {
  const OrderScanListener({
    required this.navigatorKey,
    required this.child,
    super.key,
  });

  /// The router's navigator — the order opens above whatever it shows.
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  ConsumerState<OrderScanListener> createState() => _OrderScanListenerState();
}

class _OrderScanListenerState extends ConsumerState<OrderScanListener> {
  final _burst = ScanBurst();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final code = _burst.key(
      event.physicalKey,
      shift: HardwareKeyboard.instance.isShiftPressed,
      at: event.timeStamp,
    );
    if (code == null) return false;
    final signedIn = ref.read(sessionProvider).value?.isAuthenticated ?? false;
    final navigator = widget.navigatorKey.currentContext;
    if (!signedIn || navigator == null) return false;
    unawaited(showOrderScan(navigator, code));
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
