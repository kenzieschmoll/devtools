// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/globals.dart';
import '../../../../../shared/ui/common_widgets.dart';

/// The dialog keys for testing purposes.
@visibleForTesting
class MemorySettingDialogKeys {
  static const showAndroidChartCheckBox = ValueKey('showAndroidChart');
}

class MemorySettingsDialog extends StatelessWidget {
  const MemorySettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return DevToolsDialog(
      title: const DialogTitleText('Memory Settings'),
      includeDivider: false,
      content: SizedBox(
        width: defaultDialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxSetting(
              notifier: preferences.memory.androidCollectionEnabled,
              title:
                  'Show Android memory chart in addition to Dart memory chart',
              checkboxKey: MemorySettingDialogKeys.showAndroidChartCheckBox,
            ),
            const SizedBox(height: defaultSpacing),
            PositiveIntegerSetting(
              title: preferences.memory.refLimitTitle,
              subTitle: 'Used to explore live references in console.',
              notifier: preferences.memory.refLimit,
            ),
          ],
        ),
      ),
      actions: const [DialogCloseButton()],
    );
  }
}
