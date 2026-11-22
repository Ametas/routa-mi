import 'package:fl_clash/views/dashboard/widgets/hero_orb.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host({required bool animate, bool disableAnimations = false}) =>
      MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox.square(
            dimension: 88,
            child: HeroOrb(
              color: const Color(0xFFA78BFA),
              opacity: 1,
              animate: animate,
            ),
          ),
        ),
      );

  testWidgets('a still orb asks for no frames', (tester) async {
    await tester.pumpWidget(host(animate: false));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('reduced motion keeps the orb still', (tester) async {
    await tester.pumpWidget(host(animate: true, disableAnimations: true));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('a hidden orb paints nothing', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: HeroOrb(color: Color(0xFFA78BFA), opacity: 0, animate: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CustomPaint), findsNothing);
  });
}
