import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_shell.dart';
import 'services/app_state.dart';
import 'services/background_task_service.dart';
import 'services/notification_service.dart';
import 'services/stock_api_service.dart';
import 'theme/app_theme.dart';

class StockApp extends StatelessWidget {
  const StockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'A股纪律助手',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const HomeShell(),
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();
  await BackgroundTaskService.initialize();
  final config = StockApiConfig(source: StockDataSource.eastmoney);
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(apiConfig: config),
      child: const StockApp(),
    ),
  );
}
