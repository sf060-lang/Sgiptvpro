import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'screens/home.dart';
import 'screens/login.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(ChangeNotifierProvider(
    create: (_) => AppState(prefs),
    child: const IptvApp(),
  ));
}

class IptvApp extends StatefulWidget {
  const IptvApp({super.key});
  @override
  State<IptvApp> createState() => _IptvAppState();
}

class _IptvAppState extends State<IptvApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Uygulama arka plana alınınca yetişkin kilidi otomatik kapanır.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      context.read<AppState>().lockAdult();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IPTV Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3D5AFE),
          brightness: Brightness.dark,
        ),
      ),
      home: Selector<AppState, Account?>(
        selector: (_, s) => s.account,
        builder: (_, acc, __) => acc == null
            ? const LoginScreen()
            : HomeScreen(key: ValueKey(acc.key)),
      ),
    );
  }
}
