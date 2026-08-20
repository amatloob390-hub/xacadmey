import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// اسکرول ایبل مواد کو کی بورڈ کے اوپر/نیچے تیر اور Page Up/Down سے بھی
/// اسکرول کے قابل بناتا ہے — ماؤس/ٹریک پیڈ کے ساتھ ساتھ۔ [controller] وہی
/// ہونا چاہیے جو اندر موجود ListView/CustomScrollView استعمال کر رہا ہو۔
///
/// خود اپنا FocusNode رکھتا ہے اور مواد پر کوئی بھی pointer-down پر focus
/// دوبارہ حاصل کرتا ہے — تاکہ زبان بدلنے (RTL/LTR rebuild) یا کسی dialog/
/// بٹن کے focus لے جانے کے بعد بھی تیر کی کیز کام کرتی رہیں۔
class KeyboardScrollable extends StatefulWidget {
  final ScrollController controller;
  final Widget child;

  const KeyboardScrollable({
    super.key,
    required this.controller,
    required this.child,
  });

  @override
  State<KeyboardScrollable> createState() => _KeyboardScrollableState();
}

class _KeyboardScrollableState extends State<KeyboardScrollable> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'KeyboardScrollable');

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    double delta;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      delta = 60;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      delta = -60;
    } else if (event.logicalKey == LogicalKeyboardKey.pageDown) {
      delta = 400;
    } else if (event.logicalKey == LogicalKeyboardKey.pageUp) {
      delta = -400;
    } else {
      return KeyEventResult.ignored;
    }

    if (!widget.controller.hasClients) return KeyEventResult.ignored;
    final position = widget.controller.position;
    final target = (widget.controller.offset + delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    widget.controller.animateTo(
      target,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) {
          if (!_focusNode.hasFocus) _focusNode.requestFocus();
        },
        child: widget.child,
      ),
    );
  }
}
