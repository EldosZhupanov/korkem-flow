import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/design/theme/app_theme.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/navigation/adaptive_shell.dart';
import 'package:korkem_flow/core/navigation/app_destinations.dart';
import 'package:korkem_flow/core/navigation/tab_back_handler.dart';
import 'package:korkem_flow/features/assistant/application/threads_controller.dart';
import 'package:korkem_flow/features/assistant/domain/chat_thread.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// What Android's back gesture does to the shell.
///
/// ## Why these tests watch a platform channel
///
/// On `targetSdk 36` back is *predictive*: Android does not hand the gesture to
/// the app and see what happens. It asks in advance — Flutter reports through
/// `SystemNavigator.setFrameworkHandlesBack` whether it intends to consume the
/// next back — and if the answer is no, Android closes the activity itself
/// without the app ever hearing about it.
///
/// So whether back is the app's is decided *before* any gesture, by which
/// `PopScope`s are registered with `canPop: false`. Delivering a `popRoute`
/// message directly, the way one naturally would in a test, skips that
/// negotiation entirely: the sidebar closed there even in a build that had
/// already told Android it would not be handling back — and that build left to
/// the launcher on a real device. That false pass is why [_BackSpy] asserts on
/// both signals.
///
/// Stub screens rather than the real ones on purpose: this is a test about
/// navigation dispatch, and pulling in the assistant, dashboard and sales
/// screens would mean stubbing a dozen providers to assert nothing about them.
/// The pieces under test — `AdaptiveShell`, `AppSidebar`, `AppScreen` and
/// `TabBackHandler` — are the real ones.
void main() {
  testWidgets('back closes the sidebar instead of leaving the app', (
    tester,
  ) async {
    final spy = await _pumpShell(tester);

    await tester.tap(find.byTooltip('Меню'));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsOneWidget);

    expect(
      spy.frameworkHandlesBack,
      isTrue,
      reason: 'with the sidebar open, Android must route back to the app',
    );

    await spy.pressBack(tester);

    expect(find.byType(Drawer), findsNothing);
    expect(find.text('screen /chat'), findsOneWidget);
    expect(spy.exits, isEmpty, reason: 'the app must not have asked to close');
  });

  testWidgets('back from a secondary tab returns to the assistant', (
    tester,
  ) async {
    final spy = await _pumpShell(tester);

    await tester.tap(find.byTooltip('Меню'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Задачи'));
    await tester.pumpAndSettle();
    expect(find.text('screen /tasks'), findsOneWidget);
    expect(spy.frameworkHandlesBack, isTrue);

    await spy.pressBack(tester);

    expect(find.text('screen /chat'), findsOneWidget);
    expect(spy.exits, isEmpty);
  });

  testWidgets('back from the assistant, with nothing open, leaves the app', (
    tester,
  ) async {
    final spy = await _pumpShell(tester);

    // Asserted so the two fixes above cannot be implemented by swallowing back
    // altogether, which would trap people inside the app.
    expect(spy.frameworkHandlesBack, isFalse);

    await spy.pressBack(tester);
    expect(spy.exits, hasLength(1));
  });

  testWidgets('the sidebar closes on back after being reopened', (
    tester,
  ) async {
    // Whether the sidebar is open is state on the shell; a value left stale at
    // `true` would let a later back close a sidebar that is not there, and
    // swallow the gesture.
    final spy = await _pumpShell(tester);

    for (var attempt = 0; attempt < 2; attempt++) {
      await tester.tap(find.byTooltip('Меню'));
      await tester.pumpAndSettle();
      expect(spy.frameworkHandlesBack, isTrue);

      await spy.pressBack(tester);
      expect(find.byType(Drawer), findsNothing);
    }

    expect(spy.frameworkHandlesBack, isFalse);
    expect(spy.exits, isEmpty);
  });

  testWidgets('the wide layout has a permanent sidebar and no menu button', (
    tester,
  ) async {
    await _pumpShell(tester, size: const Size(1100, 900));

    expect(find.byTooltip('Меню'), findsNothing);
    expect(find.text('Задачи'), findsOneWidget);

    await tester.tap(find.text('Задачи'));
    await tester.pumpAndSettle();

    expect(find.text('screen /tasks'), findsOneWidget);
    // Still there afterwards: a permanent panel does not dismiss itself.
    expect(find.text('Задачи'), findsOneWidget);
  });
}

/// Stands in for Android on the far side of the platform channel: it hears what
/// the app claims about back, and it delivers the gesture accordingly.
class _BackSpy {
  /// The most recent value reported through
  /// `SystemNavigator.setFrameworkHandlesBack`. False means Android will take
  /// the next back itself — closing the activity — without asking again.
  bool frameworkHandlesBack = false;

  /// One entry per `SystemNavigator.pop`: the app asking to be closed.
  final exits = <String>[];

  void record(MethodCall call) {
    switch (call.method) {
      case 'SystemNavigator.setFrameworkHandlesBack':
        frameworkHandlesBack = call.arguments as bool;
      case 'SystemNavigator.pop':
        exits.add(call.method);
    }
  }

  /// Delivers the gesture the way the engine does — but only when the app has
  /// said it wants it. Otherwise the activity is simply gone and no message is
  /// sent at all, which is the case a naive test quietly turns into a pass.
  Future<void> pressBack(WidgetTester tester) async {
    if (!frameworkHandlesBack) {
      exits.add('SystemNavigator.pop');
      return;
    }
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          'flutter/navigation',
          const JSONMessageCodec().encodeMessage(<String, dynamic>{
            'method': 'popRoute',
          }),
          (_) {},
        );
    await tester.pumpAndSettle();
  }
}

Future<_BackSpy> _pumpShell(
  WidgetTester tester, {
  Size size = const Size(390, 844),
}) async {
  final spy = _BackSpy();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        ..setMockMethodCallHandler(SystemChannels.platform, (call) async {
          spy.record(call);
          return null;
        });
  addTearDown(
    () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );

  // `WidgetsApp` refuses to report to the platform while the lifecycle state is
  // null — "avoid updating the engine when the app isn't ready" — and in a test
  // binding it is null until something says otherwise. Without this the app
  // looks like it never handles back, and every assertion below passes or fails
  // for the wrong reason.
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

  tester.view
    ..physicalSize = size * 2
    ..devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: appDestinations.first.path,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            AdaptiveShell(navigationShell: shell),
        branches: [
          for (final destination in appDestinations)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: destination.path,
                  builder: (context, state) =>
                      TabBackHandler(child: _StubScreen(destination.path)),
                ),
              ],
            ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [threadsControllerProvider.overrideWith(_NoThreads.new)],
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light(),
        locale: const Locale('ru'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return spy;
}

/// Stands in for a branch root — but built with the real [AppScreen], because
/// its inner `Scaffold` is exactly what hides the shell's drawer from
/// `Scaffold.of`, and its menu button is one of the things under test.
class _StubScreen extends StatelessWidget {
  const _StubScreen(this.path);

  final String path;

  @override
  Widget build(BuildContext context) => AppScreen(
    title: path,
    body: Center(child: Text('screen $path')),
  );
}

class _NoThreads extends ThreadsController {
  @override
  List<ChatThread> build() => const [];
}
