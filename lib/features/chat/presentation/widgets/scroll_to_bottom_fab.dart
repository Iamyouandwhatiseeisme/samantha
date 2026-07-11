import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:samantha/features/chat/presentation/widgets/scroll_to_bottom_button.dart';

class ScrollToBottomFab extends StatelessWidget {
  const ScrollToBottomFab({
    required this.showScrollToBottom,
    required this.onPressed,
    super.key,
  });

  final ValueListenable<bool> showScrollToBottom;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: showScrollToBottom,
      builder: (_, show, _) => AnimatedCrossFade(
        duration: const Duration(milliseconds: 200),
        crossFadeState: show ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        firstChild: const SizedBox(height: 40, width: 180),
        secondChild: ScrollToBottomButton(onPressed: onPressed),
      ),
    );
  }
}