// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_extensions/api.dart';
import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

/// This widget shows an example of how you can call public APIs exposed by
/// [ExtensionManager].
///
/// * `extensionManager.postMessageToDevTools` - how to post an arbitrary
///   message to DevTools, though the use for this is limited to what DevTools
///   is setup to handle.
/// * `extensionManager.showNotification` - how to show a notification in
///   DevTools.
/// * `extensionManager.showBannerMessage` - how to show a banner message
///   warning in DevTools .
class CallingDevToolsExtensionsAPIsExample extends StatelessWidget {
  const CallingDevToolsExtensionsAPIsExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton(
          onPressed: () => extensionManager.postMessageToDevTools(
            DevToolsExtensionEvent(
              DevToolsExtensionEventType.unknown,
              data: {'foo': 'bar'},
            ),
          ),
          child: const Text('Send a message to DevTools'),
        ),
        const SizedBox(height: 16.0),
        ElevatedButton(
          onPressed: () =>
              extensionManager.showNotification('Yay, DevTools Extensions!'),
          child: const Text('Show DevTools notification'),
        ),
        const SizedBox(height: 16.0),
        ElevatedButton(
          onPressed: () => extensionManager.showBannerMessage(
            key: 'example_message_single_dismiss',
            type: 'warning',
            message: 'Warning: with great power, comes great '
                'responsibility. I\'m not going to tell you twice.\n'
                '(This message can only be shown once)',
            extensionName: 'foo',
          ),
          child: const Text(
            'Show DevTools warning (ignore if already dismissed)',
          ),
        ),
        const SizedBox(height: 16.0),
        ElevatedButton(
          onPressed: () => extensionManager.showBannerMessage(
            key: 'example_message_multi_dismiss',
            type: 'warning',
            message: 'Warning: with great power, comes great '
                'responsibility. I\'ll keep reminding you if you '
                'forget.\n(This message can be shown multiple times)',
            extensionName: 'foo',
            ignoreIfAlreadyDismissed: false,
          ),
          child: const Text(
            'Show DevTools warning (can show again after dismiss)',
          ),
        ),
        const SizedBox(height: 16.0),
        ElevatedButton(
          onPressed: () => extensionManager.copyToClipboard(
            'Some text I copied!',
            successMessage: 'Successfully copied text',
          ),
          child: const Text('Copy text to clipboard'),
        ),
      ],
    );
  }
}
