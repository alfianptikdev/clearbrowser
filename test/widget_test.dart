import 'package:cleanbrowser/browser/address_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AddressBar menampilkan URL dan mengirim input', (tester) async {
    final controller = TextEditingController(text: 'https://example.com');
    final focusNode = FocusNode();
    String? submitted;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: AddressBar(
            controller: controller,
            focusNode: focusNode,
            onSubmitted: (value) => submitted = value,
            onBack: () {},
            onForward: () {},
            onReload: () {},
            onStop: () {},
            canGoBack: true,
            canGoForward: false,
          ),
        ),
      ),
    );

    expect(find.text('https://example.com'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('address-bar-field')),
      'videy.co',
    );
    await tester.testTextInput.receiveAction(TextInputAction.go);

    expect(submitted, 'videy.co');
    expect(find.byType(AddressBar), findsOneWidget);
  });

  testWidgets('tombol back nonaktif saat tidak bisa kembali', (tester) async {
    final controller = TextEditingController(text: 'about:blank');
    final focusNode = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AddressBar(
            controller: controller,
            focusNode: focusNode,
            onSubmitted: (_) {},
            onBack: () {},
            onForward: () {},
            onReload: () {},
            onStop: () {},
          ),
        ),
      ),
    );

    final back = tester.widget<IconButton>(
      find.descendant(
        of: find.byKey(const Key('btn-back')),
        matching: find.byType(IconButton),
      ),
    );
    expect(back.onPressed, isNull);
  });
}
