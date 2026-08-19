// Basic sanity tests that don't require Firebase to be initialized.
//
// A full widget test of IsTakipApp would need Firebase.initializeApp()
// mocked (e.g. via firebase_core_platform_interface test doubles), which
// isn't set up in this project yet — see CLAUDE.md.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:is_takip/app/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AppTheme.light() and AppTheme.dark() build valid ThemeData', () {
    final light = AppTheme.light();
    final dark = AppTheme.dark();

    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.extension<AppColors>(), isNotNull);
    expect(dark.extension<AppColors>(), isNotNull);
  });
}
