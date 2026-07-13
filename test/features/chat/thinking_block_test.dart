import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samantha/app/theme.dart';
import 'package:samantha/features/chat/presentation/widgets/thinking_block.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(body: child),
      );

  const reasoning = 'The user said hey, which is a casual greeting.';
  const animationDuration = Duration(milliseconds: 200);

  group('ThinkingBlock', () {
    testWidgets('starts collapsed and shimmers while the model reasons',
        (tester) async {
      await tester.pumpWidget(wrap(
        const ThinkingBlock(text: reasoning, isThinking: true),
      ));

      expect(find.text('Thinking…'), findsOneWidget);
      expect(find.byType(ShimmerText), findsOneWidget);
      // Collapsed means the reasoning is not in the tree at all.
      expect(find.byType(SelectableText), findsNothing);
    });

    testWidgets('settles into a Thought label with the reasoning duration',
        (tester) async {
      await tester.pumpWidget(wrap(
        const ThinkingBlock(
          text: reasoning,
          isThinking: false,
          duration: Duration(milliseconds: 3210),
        ),
      ));

      expect(find.text('Thought for 3.2s'), findsOneWidget);
      expect(find.byType(ShimmerText), findsNothing);
    });

    testWidgets('falls back to a bare Thought label without a duration',
        (tester) async {
      await tester.pumpWidget(wrap(
        const ThinkingBlock(text: reasoning, isThinking: false),
      ));

      expect(find.text('Thought'), findsOneWidget);
    });

    testWidgets('tapping reveals the reasoning, tapping again hides it',
        (tester) async {
      await tester.pumpWidget(wrap(
        const ThinkingBlock(text: reasoning, isThinking: false),
      ));

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      expect(find.text(reasoning), findsOneWidget);

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      expect(find.text(reasoning), findsNothing);
    });

    // The shimmer loops forever, so pumpAndSettle would never return here.
    testWidgets('stays expanded as more reasoning streams in', (tester) async {
      await tester.pumpWidget(wrap(
        const ThinkingBlock(text: 'First thought.', isThinking: true),
      ));
      await tester.tap(find.byType(InkWell));
      await tester.pump(animationDuration);
      expect(find.text('First thought.'), findsOneWidget);

      await tester.pumpWidget(wrap(
        const ThinkingBlock(text: 'First thought. Second.', isThinking: true),
      ));
      await tester.pump(animationDuration);

      expect(find.text('First thought. Second.'), findsOneWidget);
    });

    testWidgets('renders a static label when animations are disabled',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const Scaffold(
            body: ThinkingBlock(text: reasoning, isThinking: true),
          ),
        ),
      ));

      expect(find.text('Thinking…'), findsOneWidget);
      expect(find.byType(ShaderMask), findsNothing);
    });
  });
}
