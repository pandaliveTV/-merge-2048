import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge2048/data/game_modes.dart';
import 'package:merge2048/data/strings.dart';
import 'package:merge2048/game/game_controller.dart';
import 'package:merge2048/screens/game_screen.dart';
import 'package:merge2048/screens/home_screen.dart';
import 'package:merge2048/screens/mode_select_screen.dart';
import 'package:merge2048/services/ad_service.dart';
import 'package:merge2048/services/audio_service.dart';
import 'package:merge2048/services/iap_service.dart';
import 'package:merge2048/services/storage_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> harness(
  Widget home, {
  Locale locale = const Locale('en'),
}) async {
  // Muted so no audio plugin is touched in tests.
  SharedPreferences.setMockInitialValues({'muted': true});
  final storage = StorageService();
  await storage.init();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: storage),
      ChangeNotifierProvider.value(value: IapService(storage)),
      Provider.value(value: AdService(storage)),
      Provider.value(value: AudioService(storage)),
    ],
    child: MaterialApp(
      locale: locale,
      supportedLocales: AppStrings.supported,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    ),
  );
}

void main() {
  for (final size in [
    const Size(360, 640),
    const Size(1080 / 2.6, 2400 / 2.6),
  ]) {
    testWidgets('game screen renders and reacts to swipes at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        await harness(const GameScreen(mode: GameModes.huge)),
      );
      await tester.pumpAndSettle();
      final state = tester.state(find.byType(GameScreen));
      expect(state, isNotNull);

      final controller = Provider.of<GameController>(
        tester.element(find.text('Score'.toUpperCase())),
        listen: false,
      );
      final before = controller.serial;
      for (final offset in const [
        Offset(-200, 0),
        Offset(0, -200),
        Offset(200, 0),
        Offset(0, 200),
      ]) {
        await tester.drag(find.byType(GameScreen), offset);
        await tester.pumpAndSettle();
      }
      expect(controller.serial, greaterThan(before));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('home and mode select render in Arabic (RTL)', (tester) async {
    await tester.pumpWidget(
      await harness(const HomeScreen(), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();
    expect(find.text('العب'), findsOneWidget);
    await tester.tap(find.text('العب'));
    await tester.pumpAndSettle();
    expect(find.byType(ModeSelectScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
