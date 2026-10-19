import 'package:flutter_test/flutter_test.dart';
import 'package:project/app_widget.dart';

void main() {
  testWidgets('App abre na tela de login', (tester) async {
    await tester.pumpWidget(const AppWidget());
    expect(find.text('Bem-vindo!'), findsOneWidget);
  });
}
