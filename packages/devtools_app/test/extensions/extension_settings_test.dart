// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/extensions/extension_settings.dart';
import 'package:devtools_app/src/shared/development_helpers.dart';
import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_extensions.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../test_infra/matchers/matchers.dart';

void main() {
  late ExtensionSettingsDialog dialog;

  group('$ExtensionSettingsDialog', () {
    setUp(() async {
      setTestMode();

      setGlobal(IdeTheme, IdeTheme());
      setGlobal(PreferencesController, PreferencesController());
      final mockServiceConnection = createMockServiceConnectionWithDefaults();
      final mockServiceManager =
          mockServiceConnection.serviceManager as MockServiceManager;
      when(
        mockServiceManager.connectedState,
      ).thenReturn(ValueNotifier(const ConnectedState(true)));
      setGlobal(ServiceConnectionManager, mockServiceConnection);

      setGlobal(
        ExtensionService,
        ExtensionService(
          fixedAppRoot: Uri.parse('file:///Users/me/package_root_1'),
        ),
      );
      await extensionService.initialize();
      expect(extensionService.staticExtensions.length, 4);
      expect(extensionService.runtimeExtensions.length, 3);
      expect(extensionService.availableExtensions.length, 5);

      dialog = ExtensionSettingsDialog(
        extensions: extensionService.availableExtensions,
      );
    });

    tearDown(() {
      resetDevToolsExtensionEnabledStates();
    });

    testWidgets('builds dialog with no available extensions', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(const ExtensionSettingsDialog(extensions: [])),
      );
      await tester.pumpAndSettle();
      expect(find.text('DevTools Extensions'), findsOneWidget);
      expect(
        find.textContaining('Extensions are provided by the pub packages'),
        findsOneWidget,
      );
      expect(find.text('No extensions available.'), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
      expect(find.byType(ExtensionSetting), findsNothing);
    });

    testWidgets('builds dialog with available extensions', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(dialog));
      await tester.pumpAndSettle();
      expect(find.text('DevTools Extensions'), findsOneWidget);
      expect(
        find.textContaining('Extensions are provided by the pub packages'),
        findsOneWidget,
      );
      expect(find.text('No extensions available.'), findsNothing);
      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(ExtensionSetting), findsNWidgets(5));
      await expectLater(
        find.byWidget(dialog),
        matchesDevToolsGolden(
          '../test_infra/goldens/extensions/settings_state_none.png',
        ),
      );
    });

    testWidgets(
      'pressing toggle buttons makes calls to the $ExtensionService',
      (WidgetTester tester) async {
        await tester.pumpWidget(wrap(dialog));
        await tester.pumpAndSettle();

        expect(
          extensionService
              .enabledStateListenable(StubDevToolsExtensions.barExtension.name)
              .value,
          ExtensionEnabledState.none,
        );
        expect(
          extensionService
              .enabledStateListenable(StubDevToolsExtensions.bazExtension.name)
              .value,
          ExtensionEnabledState.none,
        );
        expect(
          extensionService
              .enabledStateListenable(StubDevToolsExtensions.fooExtension.name)
              .value,
          ExtensionEnabledState.none,
        );
        expect(
          extensionService
              .enabledStateListenable(
                StubDevToolsExtensions.providerExtension.name,
              )
              .value,
          ExtensionEnabledState.none,
        );
        expect(
          extensionService
              .enabledStateListenable(
                StubDevToolsExtensions.someToolExtension.name,
              )
              .value,
          ExtensionEnabledState.none,
        );

        final barSetting = tester
            .widgetList<ExtensionSetting>(find.byType(ExtensionSetting))
            .where(
              (setting) => setting.extension.name.caseInsensitiveEquals('bar'),
            )
            .first;
        final bazSetting = tester
            .widgetList<ExtensionSetting>(find.byType(ExtensionSetting))
            .where(
              (setting) => setting.extension.name.caseInsensitiveEquals('baz'),
            )
            .first;
        final fooSetting = tester
            .widgetList<ExtensionSetting>(find.byType(ExtensionSetting))
            .where(
              (setting) => setting.extension.name.caseInsensitiveEquals('foo'),
            )
            .first;
        final providerSetting = tester
            .widgetList<ExtensionSetting>(find.byType(ExtensionSetting))
            .where(
              (setting) =>
                  setting.extension.name.caseInsensitiveEquals('provider'),
            )
            .first;
        final someToolSetting = tester
            .widgetList<ExtensionSetting>(find.byType(ExtensionSetting))
            .where(
              (setting) =>
                  setting.extension.name.caseInsensitiveEquals('some_tool'),
            )
            .first;

        // Disable the 'bar' extension.
        await tester.tap(
          find.descendant(
            of: find.byWidget(barSetting),
            matching: find.text('Disabled'),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          extensionService
              .enabledStateListenable(StubDevToolsExtensions.barExtension.name)
              .value,
          ExtensionEnabledState.disabled,
        );

        // Disable the 'baz' extension.
        await tester.tap(
          find.descendant(
            of: find.byWidget(bazSetting),
            matching: find.text('Disabled'),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          extensionService
              .enabledStateListenable(StubDevToolsExtensions.bazExtension.name)
              .value,
          ExtensionEnabledState.disabled,
        );

        // Enable the 'foo' extension.
        await tester.tap(
          find.descendant(
            of: find.byWidget(fooSetting),
            matching: find.text('Enabled'),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          extensionService
              .enabledStateListenable(StubDevToolsExtensions.fooExtension.name)
              .value,
          ExtensionEnabledState.enabled,
        );

        // Enable the 'provider' extension.
        await tester.tap(
          find.descendant(
            of: find.byWidget(providerSetting),
            matching: find.text('Enabled'),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          extensionService
              .enabledStateListenable(
                StubDevToolsExtensions.providerExtension.name,
              )
              .value,
          ExtensionEnabledState.enabled,
        );

        // Enable the 'some_tool' extension.
        await tester.tap(
          find.descendant(
            of: find.byWidget(someToolSetting),
            matching: find.text('Enabled'),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          extensionService
              .enabledStateListenable(
                StubDevToolsExtensions.someToolExtension.name,
              )
              .value,
          ExtensionEnabledState.enabled,
        );

        await tester.pumpWidget(wrap(dialog));
        await tester.pumpAndSettle();
        await expectLater(
          find.byWidget(dialog),
          matchesDevToolsGolden(
            '../test_infra/goldens/extensions/settings_state_modified.png',
          ),
        );
      },
    );

    testWidgets('toggle buttons update for changes to value notifiers', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(dialog));
      await tester.pumpAndSettle();
      await expectLater(
        find.byWidget(dialog),
        matchesDevToolsGolden(
          '../test_infra/goldens/extensions/settings_state_none.png',
        ),
      );

      await extensionService.setExtensionEnabledState(
        StubDevToolsExtensions.barExtension,
        enable: false,
      );
      await extensionService.setExtensionEnabledState(
        StubDevToolsExtensions.bazExtension,
        enable: false,
      );
      await extensionService.setExtensionEnabledState(
        StubDevToolsExtensions.fooExtension,
        enable: true,
      );
      await extensionService.setExtensionEnabledState(
        StubDevToolsExtensions.providerExtension,
        enable: true,
      );
      await extensionService.setExtensionEnabledState(
        StubDevToolsExtensions.someToolExtension,
        enable: true,
      );

      await tester.pumpWidget(wrap(dialog));
      await tester.pumpAndSettle();
      await expectLater(
        find.byWidget(dialog),
        matchesDevToolsGolden(
          '../test_infra/goldens/extensions/settings_state_modified.png',
        ),
      );
    });
  });
}
