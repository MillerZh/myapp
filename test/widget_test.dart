import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:stock/main.dart';
import 'package:stock/services/app_state.dart';
import 'package:stock/services/stock_api_service.dart';

void main() {
  testWidgets('应用可启动并显示信号页', (tester) async {
    final config = StockApiConfig(source: StockDataSource.mock);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(apiConfig: config),
        child: const StockApp(),
      ),
    );
    await tester.pump();
    expect(find.textContaining('信号'), findsWidgets);
  });
}
