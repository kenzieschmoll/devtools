// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:dtd/dtd.dart' show DartToolingDaemon, DTDEvent;
import 'package:flutter/material.dart';

import 'dtd_tools_model.dart';
import 'shared.dart';

/// Manages business logic for the [EventsView] widget, which displays
/// information about events sent and received over DTD event streams.
class EventsController extends FeatureController {
  late DartToolingDaemon dtd;

  @visibleForTesting
  final events = ListValueNotifier<DTDEvent>([]);

  @visibleForTesting
  final selectedEvent = ValueNotifier<DTDEvent?>(null);

  final scrollController = ScrollController();

  @override
  void init() {
    super.init();
    for (final stream in knownDtdStreams) {
      autoDisposeStreamSubscription(
        dtd.onEvent(stream).listen((event) {
          events.add(event);
          // Schedule a scroll to the bottom after the frame is built.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (scrollController.hasClients) {
              scrollController.jumpTo(
                scrollController.position.maxScrollExtent,
              );
            }
          });
        }),
      );
    }
  }

  @override
  void dispose() {
    events.dispose();
    selectedEvent.dispose();
    scrollController.dispose();
    super.dispose();
  }
}

/// Displays information about events sent and received over DTD event streams.
class EventsView extends StatelessWidget {
  const EventsView({super.key, required this.controller});

  final EventsController controller;

  @override
  Widget build(BuildContext context) {
    return DevToolsAreaPane(
      header: AreaPaneHeader(
        title: Text('DTD Events', style: Theme.of(context).boldTextStyle),
        roundedTopBorder: false,
        includeTopBorder: false,
        tall: true,
        actions: [
          DevToolsButton(
            icon: Icons.delete,
            label: 'Clear',
            onPressed: () {
              controller.events.clear();
              controller.selectedEvent.value = null;
            },
          ),
        ],
      ),
      child: ValueListenableBuilder<List<DTDEvent>>(
        valueListenable: controller.events,
        builder: (context, events, _) {
          if (events.isEmpty) {
            return const Center(child: Text('No events received'));
          }

          return ValueListenableBuilder<DTDEvent?>(
            valueListenable: controller.selectedEvent,
            builder: (context, selectedEvent, _) {
              return SplitPane(
                initialFractions: const [0.7, 0.3],
                axis: Axis.vertical,
                children: [
                  OutlineDecoration.onlyBottom(
                    child: Scrollbar(
                      thumbVisibility: true,
                      controller: controller.scrollController,
                      child: ListView.builder(
                        controller: controller.scrollController,
                        itemCount: events.length,
                        itemBuilder: (context, index) => _EventListTile(
                          event: events[index],
                          selected: events[index] == selectedEvent,
                          onTap: () {
                            controller.selectedEvent.value = events[index];
                          },
                        ),
                      ),
                    ),
                  ),
                  OutlineDecoration.onlyTop(
                    child: Padding(
                      padding: const EdgeInsets.all(denseSpacing),
                      child: EventDetailView(event: selectedEvent),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// A display tile for a single event in [EventsView].
class _EventListTile extends StatelessWidget {
  const _EventListTile({
    required this.event,
    this.selected = false,
    this.onTap,
  });

  final DTDEvent event;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Row(
        children: [
          Text(
            '[${event.stream}]',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _getStreamColor(event.stream),
            ),
          ),
          const SizedBox(width: denseSpacing),
          Text(event.kind),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Timestamp: ${event.timestamp}'),
          Text('Data: ${event.data}', overflow: TextOverflow.ellipsis),
        ],
      ),
      dense: true,
      selected: selected,
      onTap: onTap,
    );
  }

  Color _getStreamColor(String stream) {
    // Create a consistent color based on the stream name
    final hash = stream.hashCode.abs();
    return Colors.primaries[hash % Colors.primaries.length];
  }
}

/// The details view for a single [DTDEvent] selected from [EventsView].
@visibleForTesting
class EventDetailView extends StatelessWidget {
  const EventDetailView({super.key, required this.event});

  final DTDEvent? event;

  @override
  Widget build(BuildContext context) {
    final localEvent = event;
    if (localEvent == null) {
      return const Center(child: Text('No event selected'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Event details', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: defaultSpacing),
        _buildDetailRow('Stream', localEvent.stream),
        _buildDetailRow('Kind', localEvent.kind),
        _buildDetailRow('Timestamp', localEvent.timestamp.toString()),
        const SizedBox(height: defaultSpacing),
        Text('Data:', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: denseSpacing),
        Expanded(
          child: SingleChildScrollView(
            child: SelectableText(localEvent.data.toString()),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: denseSpacing),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
