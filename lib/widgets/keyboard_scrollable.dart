import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// اسکرول ایبل مواد کو کی بورڈ کے اوپر/نیچے تیر اور Page Up/Down سے بھی
/// اسکرول کے قابل بناتا ہے — ماؤس/ٹریک پیڈ کے ساتھ ساتھ۔ [controller] وہی
/// ہونا چاہیے جو اندر موجود ListView/CustomScrollView استعمال کر رہا ہو۔
class KeyboardScrollable extends StatelessWidget {
  final ScrollController controller;
  final Widget child;

  const KeyboardScrollable({
    super.key,
    required this.controller,
    required this.child,
  });

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

    if (!controller.hasClients) return KeyEventResult.ignored;
    final position = controller.position;
    final target = (controller.offset + delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    controller.animateTo(
      target,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: child,
    );
  }
}
