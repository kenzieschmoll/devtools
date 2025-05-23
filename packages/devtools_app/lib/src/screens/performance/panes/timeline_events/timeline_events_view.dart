// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';

import '../../../../shared/analytics/constants.dart' as gac;
import '../../../../shared/globals.dart';
import '../../../../shared/http/http_service.dart' as http_service;
import '../../../../shared/ui/common_widgets.dart';
import 'perfetto/perfetto.dart';
import 'timeline_events_controller.dart';

class TimelineEventsTabView extends StatefulWidget {
  const TimelineEventsTabView({super.key, required this.controller});

  final TimelineEventsController controller;

  @override
  State<TimelineEventsTabView> createState() => _TimelineEventsTabViewState();
}

class _TimelineEventsTabViewState extends State<TimelineEventsTabView>
    with AutoDisposeMixin {
  /// Size for the [_refreshingOverlay].
  static const _overlaySize = Size(300.0, 200.0);

  /// Offset to position the [_refreshingOverlay] over the top of the
  /// timeline events view.
  static const _overlayOffset = 50.0;

  /// Timeout used by [_removeOverlayTimer].
  static const _removeOverlayTimeout = Duration(seconds: 6);

  /// Timer that will remove [_refreshingOverlay], after a time period of
  /// [_removeOverlayTimeout], if it has not already been removed due to a
  /// change in [TimelineEventsController.status].
  Timer? _removeOverlayTimer;

  OverlayEntry? _refreshingOverlay;

  @override
  void initState() {
    super.initState();
    addAutoDisposeListener(widget.controller.status, () {
      final status = widget.controller.status.value;
      if (status == EventsControllerStatus.refreshing &&
          widget.controller.isActiveFeature) {
        _insertOverlay();
      } else {
        _removeOverlay();
      }
    });
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _insertOverlay() {
    final theme = Theme.of(context);
    _refreshingOverlay?.remove();
    Overlay.of(context).insert(
      _refreshingOverlay = OverlayEntry(
        maintainState: true,
        builder: (context) {
          return DevToolsOverlay(
            topOffset: _overlayOffset,
            maxSize: _overlaySize,
            content: Text(
              'Refreshing the timeline...\n\n'
              'This may take a few seconds. Please do not\n'
              'refresh the page.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          );
        },
      ),
    );
    _removeOverlayTimer = Timer(_removeOverlayTimeout, _removeOverlay);
  }

  void _removeOverlay() {
    _refreshingOverlay?.remove();
    _refreshingOverlay = null;
    _removeOverlayTimer?.cancel();
    _removeOverlayTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    return KeepAliveWrapper(
      child: EmbeddedPerfetto(
        perfettoController: widget.controller.perfettoController,
      ),
    );
  }
}

class TimelineEventsTabControls extends StatelessWidget {
  const TimelineEventsTabControls({super.key, required this.controller});

  final TimelineEventsController controller;

  @override
  Widget build(BuildContext context) {
    final showingOfflineData = offlineDataController.showingOfflineData.value;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (!showingOfflineData)
          Row(
            children: [
              const Text('Include CPU samples'),
              const SizedBox(width: densePadding),
              DevToolsTooltip(
                message:
                    'Include CPU samples in the timeline\n'
                    '(this may negatively impact performance)',
                child: NotifierSwitch(
                  notifier: preferences.performance.includeCpuSamplesInTimeline,
                ),
              ),
            ],
          ),
        const SizedBox(width: densePadding),
        PerfettoHelpButton(perfettoController: controller.perfettoController),
        if (!showingOfflineData) ...[
          const SizedBox(width: densePadding),
          const TimelineSettingsButton(),
          const SizedBox(width: densePadding),
          RefreshTimelineEventsButton(controller: controller),
        ],
      ],
    );
  }
}

class TimelineSettingsButton extends StatelessWidget {
  const TimelineSettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return GaDevToolsButton.iconOnly(
      icon: Icons.settings_outlined,
      outlined: false,
      tooltip: 'Timeline settings',
      gaScreen: gac.performance,
      gaSelection: gac.PerformanceEvents.timelineSettings.name,
      onPressed: () => _openTimelineSettingsDialog(context),
    );
  }

  void _openTimelineSettingsDialog(BuildContext context) {
    unawaited(
      showDialog(
        context: context,
        builder: (context) => const TimelineSettingsDialog(),
      ),
    );
  }
}

class RefreshTimelineEventsButton extends StatelessWidget {
  const RefreshTimelineEventsButton({required this.controller, super.key});

  final TimelineEventsController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EventsControllerStatus>(
      valueListenable: controller.status,
      builder: (context, status, _) {
        return RefreshButton(
          iconOnly: true,
          outlined: false,
          onPressed: status == EventsControllerStatus.refreshing
              ? null
              : controller.forceRefresh,
          tooltip: 'Refresh timeline events',
          gaScreen: gac.performance,
          gaSelection: gac.PerformanceEvents.refreshTimelineEvents.name,
        );
      },
    );
  }
}

class TimelineSettingsDialog extends StatefulWidget {
  const TimelineSettingsDialog({super.key});

  @override
  State<TimelineSettingsDialog> createState() => _TimelineSettingsDialogState();
}

class _TimelineSettingsDialogState extends State<TimelineSettingsDialog>
    with AutoDisposeMixin {
  late final ValueNotifier<bool?> _httpLogging;

  @override
  void initState() {
    super.initState();
    // Mirror the value of [http_service.httpLoggingState] in the [_httpLogging]
    // notifier so that we can use [_httpLogging] for the [CheckboxSetting]
    // widget below.
    _httpLogging = ValueNotifier<bool>(http_service.httpLoggingEnabled);
    addAutoDisposeListener(http_service.httpLoggingState, () {
      _httpLogging.value = http_service.httpLoggingState.value.enabled;
    });
  }

  @override
  void dispose() {
    cancelListeners();
    _httpLogging.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DevToolsDialog(
      title: const DialogTitleText('Timeline Settings'),
      includeDivider: false,
      content: SizedBox(
        width: defaultDialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ..._defaultRecordedStreams(theme),
            const SizedBox(height: denseSpacing),
            ..._advancedStreams(theme),
          ],
        ),
      ),
      actions: const [DialogCloseButton()],
    );
  }

  List<Widget> _defaultRecordedStreams(ThemeData theme) {
    return [
      ...dialogSubHeader(theme, 'Trace categories'),
      RichText(
        text: TextSpan(text: 'Default', style: theme.subtleTextStyle),
      ),
      ..._timelineStreams(advanced: false),
      // Special case "Network Traffic" because it is not implemented as a
      // Timeline recorded stream in the VM. The user does not need to be aware of
      // the distinction, however.
      CheckboxSetting(
        title: 'Network',
        description: 'Http traffic',
        notifier: _httpLogging,
        onChanged: (value) =>
            unawaited(http_service.toggleHttpRequestLogging(value ?? false)),
      ),
    ];
  }

  List<Widget> _advancedStreams(ThemeData theme) {
    return [
      RichText(
        text: TextSpan(text: 'Advanced', style: theme.subtleTextStyle),
      ),
      ..._timelineStreams(advanced: true),
    ];
  }

  List<Widget> _timelineStreams({required bool advanced}) {
    final streams = advanced
        ? serviceConnection.timelineStreamManager.advancedStreams
        : serviceConnection.timelineStreamManager.basicStreams;
    final settings = streams
        .map(
          (stream) => CheckboxSetting(
            title: stream.name,
            description: stream.description,
            notifier: stream.recorded as ValueNotifier<bool?>,
            onChanged: (newValue) => unawaited(
              serviceConnection.timelineStreamManager.updateTimelineStream(
                stream,
                newValue ?? false,
              ),
            ),
          ),
        )
        .toList();
    return settings;
  }
}
