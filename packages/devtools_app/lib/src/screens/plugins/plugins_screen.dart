// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/common_widgets.dart';
import '../../shared/plugins/embedded_plugin_view/embedded_plugin_view.dart';
import '../../shared/plugins/plugins_model.dart';
import '../../shared/primitives/auto_dispose.dart';
import '../../shared/primitives/listenable.dart';
import '../../shared/primitives/simple_items.dart';
import '../../shared/screen.dart';
import '../../shared/theme.dart';
import '../../shared/utils.dart';
import 'plugins_screen_controller.dart';

// TODO(kenz): re-implement this UI so that each plugin has its own screen
// instead of every plugin being on one screen.

class PluginsScreen extends Screen {
  PluginsScreen()
      : super.conditional(
          id: id,
          title: ScreenMetaData.plugins.title,
          icon: Icons.extension_outlined,
        );

  static final id = ScreenMetaData.plugins.id;

  @override
  ValueListenable<bool> get showIsolateSelector =>
      const FixedValueListenable<bool>(true);

  @override
  Widget build(BuildContext context) => const PluginsScreenBody();
}

class PluginsScreenBody extends StatefulWidget {
  const PluginsScreenBody({super.key});

  @override
  State<PluginsScreenBody> createState() => _PluginsScreenBodyState();
}

class _PluginsScreenBodyState extends State<PluginsScreenBody>
    with
        AutoDisposeMixin,
        ProvidedControllerMixin<PluginsScreenController, PluginsScreenBody> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    initController();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: controller.selectedPluginIndex,
      builder: (context, selectedIndex, _) {
        return Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: controller.selectPluginAtIndex,
              destinations: [
                for (final plugin in controller.plugins)
                  NavigationRailDestination(
                    label: Text(plugin.name),
                    icon: Icon(plugin.icon),
                  ),
              ],
            ),
            Expanded(
              child: PluginView(
                controller: controller,
                index: selectedIndex,
              ),
            ),
          ],
        );
      },
    );
  }
}

class PluginView extends StatelessWidget {
  PluginView({super.key, required this.controller, required this.index});

  final PluginsScreenController controller;

  final int index;

  // TODO actually hook this up.
  final ValueNotifier<bool> pluginActivated = ValueNotifier(false);

  var messageIterator = 0;
  final messages = [
    'hi',
    'hello',
    'how are you',
    'greetings',
    'hola',
    'hey',
  ];

  @override
  Widget build(BuildContext context) {
    final selectedPlugin = controller.selectedPluginNotifier.value!;
    return RoundedOutlinedBorder(
      clip: true,
      child: Column(
        children: [
          PluginViewHeader(
            selectedPlugin: selectedPlugin,
            pluginActivated: pluginActivated,
            onPostTapped: () {
              final message = messages[messageIterator++ % messages.length];
              controller.pluginWebViewController.postMessage(message);
            },
          ),
          Expanded(
            child: IndexedStack(
              index: index,
              children: [
                for (final plugin in controller.plugins)
                  ValueListenableBuilder(
                    valueListenable: pluginActivated,
                    builder: (context, activated, _) {
                      if (activated) {
                        return KeepAliveWrapper(
                          child: Center(
                            child: EmbeddedPluginView(
                              pluginController:
                                  controller.pluginWebViewController,
                            ),
                          ),
                        );
                      }
                      return ActivationView(
                        pluginName: plugin.name,
                        onActivated: () => pluginActivated.value = true,
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PluginViewHeader extends StatelessWidget {
  const PluginViewHeader({
    super.key,
    required this.selectedPlugin,
    required this.pluginActivated,
    required this.onPostTapped,
  });

  final DevToolsPluginConfig selectedPlugin;

  // TODO actually hook this up.
  final ValueNotifier<bool> pluginActivated;

  final VoidCallback onPostTapped;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedPluginName = selectedPlugin.name.toLowerCase();
    return AreaPaneHeader(
      title: RichText(
        text: TextSpan(
          text: 'DevTools plugin: package:$selectedPluginName',
          style: theme.regularTextStyle.copyWith(fontWeight: FontWeight.bold),
          children: [
            TextSpan(
              text: ' (v${selectedPlugin.version})',
              style: theme.subtleTextStyle,
            ),
          ],
        ),
      ),
      includeTopBorder: false,
      roundedTopBorder: false,
      actions: [
        TextButton(
          onPressed: onPostTapped,
          child: const Text('Post message to iFrame'),
        ),
        const SizedBox(width: defaultSpacing),
        Padding(
          padding: const EdgeInsets.only(right: densePadding),
          child: RichText(
            text: LinkTextSpan(
              link: Link(
                display: 'Report an issue',
                url: selectedPlugin.issueTrackerLink,
                gaScreenName: gac.plugins,
                gaSelectedItemDescription:
                    gac.pluginFeedback(selectedPluginName),
              ),
              context: context,
            ),
          ),
        ),
        ValueListenableBuilder(
          valueListenable: pluginActivated,
          builder: (context, activated, _) {
            return DevToolsButton.iconOnly(
              icon: Icons.block,
              outlined: false,
              tooltip: 'Deactivate plugin',
              gaScreen: gac.plugins,
              gaSelection: gac.pluginDeactivate(selectedPluginName),
              onPressed: activated ? () => pluginActivated.value = false : null,
            );
          },
        ),
      ],
    );
  }
}

class ActivationView extends StatelessWidget {
  const ActivationView({
    super.key,
    required this.pluginName,
    required this.onActivated,
  });

  final String pluginName;
  final VoidCallback onActivated;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'The $pluginName plugin has not been activated yet. '
            'Activate to use the tool.',
          ),
          const SizedBox(height: defaultSpacing),
          ElevatedButton(
            onPressed: () {
              ga.select(gac.plugins, gac.pluginActivate(pluginName));
              onActivated();
            },
            child: const Text('Activate plugin'),
          ),
        ],
      ),
    );
  }
}
