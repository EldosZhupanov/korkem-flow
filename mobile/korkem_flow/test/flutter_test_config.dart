import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Applies to every test under `test/`, automatically — `flutter_test_config.dart`
/// is discovered by the test runner, not imported.
///
/// It loads the real fonts. Without this the test renderer substitutes Ahem,
/// whose every glyph is a filled rectangle, and a golden file would then prove
/// nothing about typography, line breaking, or Cyrillic coverage — the three
/// things Inter was chosen for. Icons come from a separate font and fail the
/// same way: unloaded, every icon renders as an empty square.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  await _loadFont('Inter', File('assets/fonts/Inter-Variable.ttf'));

  // Fonts shipped inside a package are addressed by a prefixed family name —
  // the same rewrite Flutter applies to `IconData.fontPackage` at render time.
  final symbols = _packageFile(
    'material_symbols_icons',
    'fonts/MaterialSymbolsRounded.ttf',
  );
  if (symbols != null) {
    await _loadFont(
      'packages/material_symbols_icons/MaterialSymbolsRounded',
      symbols,
    );
  }

  // Flutter's own glyphs — back arrows, the dropdown caret, checkmarks — come
  // from MaterialIcons, which widgets reference without going through AppIcons.
  final materialIcons = _materialIconsFile();
  if (materialIcons != null) {
    await _loadFont('MaterialIcons', materialIcons);
  }

  await testMain();
}

/// Resolves a file inside a dependency by reading the generated package config.
///
/// `Isolate.resolvePackageUri` is unimplemented in the flutter_test runtime,
/// and hard-coding a `~/.pub-cache` path would pin the dependency version.
File? _packageFile(String package, String relativeToLib) {
  final config = File('.dart_tool/package_config.json');
  if (!config.existsSync()) return null;

  final packages =
      (jsonDecode(config.readAsStringSync())
              as Map<String, dynamic>)['packages']
          as List<dynamic>;

  for (final entry in packages.cast<Map<String, dynamic>>()) {
    if (entry['name'] != package) continue;
    // Uri.resolve replaces the final segment unless the base ends in a slash,
    // which would silently drop the package directory itself.
    final root = config.parent.uri.resolve(_asDirectory(entry['rootUri']));
    final lib = root.resolve(_asDirectory(entry['packageUri']));
    return File.fromUri(lib.resolve(relativeToLib));
  }
  return null;
}

String _asDirectory(Object? value) {
  final path = value! as String;
  return path.endsWith('/') ? path : '$path/';
}

/// `FLUTTER_ROOT` is not exported to every runner, so fall back to deriving it
/// from the Dart executable, which always lives at
/// `<flutter>/bin/cache/dart-sdk/bin/dart`.
File? _materialIconsFile() {
  const relative =
      'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';

  final roots = <String>[
    ?Platform.environment['FLUTTER_ROOT'],
    Directory(
      Platform.resolvedExecutable,
    ).parent.parent.parent.parent.parent.path,
  ];

  for (final root in roots) {
    final file = File('$root/$relative');
    if (file.existsSync()) return file;
  }
  return null;
}

Future<void> _loadFont(String family, File file) async {
  final bytes = await file.readAsBytes();
  await (FontLoader(
    family,
  )..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
}
