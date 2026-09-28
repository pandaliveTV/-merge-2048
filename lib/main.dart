import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/strings.dart';
import 'data/tile_themes.dart';
import 'screens/splash_screen.dart';
import 'services/ad_service.dart';
import 'services/audio_service.dart';
import 'services/iap_service.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final storage = StorageService();
  await storage.init();
  final ads = AdService(storage);
  final iap = IapService(storage);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: storage),
        ChangeNotifierProvider.value(value: iap),
        Provider.value(value: ads),
        Provider.value(value: AudioService(storage)),
      ],
      child: const Merge2048App(),
    ),
  );
  // Consent (UMP) + SDK init run in the background so the splash is not
  // blocked; no ad is requested before consent is resolved.
  ads.init();
  iap.init();
}

class Merge2048App extends StatelessWidget {
  const Merge2048App({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<StorageService>();
    final theme = TileThemes.byId(storage.tileTheme);
    final dark = theme.background.computeLuminance() < 0.3;
    return MaterialApp(
      onGenerateTitle: (c) => c.tr('appName'),
      debugShowCheckedModeBanner: false,
      locale: storage.language == 'system' ? null : Locale(storage.language),
      supportedLocales: AppStrings.supported,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: theme.tileColor(dark ? 16 : 32),
          brightness: dark ? Brightness.dark : Brightness.light,
        ),
        scaffoldBackgroundColor: theme.background,
        appBarTheme: AppBarTheme(
          backgroundColor: theme.background,
          centerTitle: true,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
