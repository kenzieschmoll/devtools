// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

part of 'preferences.dart';

class MemoryPreferencesController extends DisposableController
    with AutoDisposeControllerMixin {
  /// If true, android chart will be shown in addition to
  /// dart chart.
  final androidCollectionEnabled = ValueNotifier<bool>(false);
  static const _androidCollectionEnabledStorageId =
      'memory.androidCollectionEnabled';

  /// If false, mamory chart will be collapsed.
  final showChart = ValueNotifier<bool>(true);
  static const _showChartStorageId = 'memory.showChart';

  /// Number of references to request from vm service,
  /// when browsing references in console.
  final refLimitTitle = 'Limit for number of requested live instances.';
  final refLimit = ValueNotifier<int>(_defaultRefLimit);
  static const _defaultRefLimit = 100000;
  static const _refLimitStorageId = 'memory.refLimit';

  @override
  Future<void> init() async {
    addAutoDisposeListener(androidCollectionEnabled, () {
      safeUnawaited(
        storage.setValue(
          _androidCollectionEnabledStorageId,
          androidCollectionEnabled.value.toString(),
        ),
      );
      if (androidCollectionEnabled.value) {
        ga.select(gac.memory, gac.MemoryEvents.androidChart.name);
      }
    });
    androidCollectionEnabled.value = await boolValueFromStorage(
      _androidCollectionEnabledStorageId,
      defaultsTo: false,
    );

    addAutoDisposeListener(showChart, () {
      safeUnawaited(
        storage.setValue(_showChartStorageId, showChart.value.toString()),
      );

      ga.select(
        gac.memory,
        showChart.value
            ? gac.MemoryEvents.showChart.name
            : gac.MemoryEvents.hideChart.name,
      );
    });
    showChart.value = await boolValueFromStorage(
      _showChartStorageId,
      defaultsTo: true,
    );

    addAutoDisposeListener(refLimit, () {
      safeUnawaited(
        storage.setValue(_refLimitStorageId, refLimit.value.toString()),
      );

      ga.select(gac.memory, gac.MemoryEvents.browseRefLimit.name);
    });
    refLimit.value =
        int.tryParse(await storage.getValue(_refLimitStorageId) ?? '') ??
        _defaultRefLimit;
  }
}
