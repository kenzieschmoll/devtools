import 'dart:async';
import 'dart:convert';

import 'package:devtools_app_shared/ui.dart';
import 'package:dtd/dtd.dart';
import 'package:flutter/material.dart';

import '../../shared/globals.dart';
import '../../shared/primitives/utils.dart';
import '../../shared/ui/common_widgets.dart';
import 'dtd_tools_model.dart';

/// Manages business logic for the [ServicesView] widget, which displays
/// information about service methods registered on DTD and provides
/// functionality for calling them.
class ServicesController extends FeatureController {
  late DartToolingDaemon dtd;

  @visibleForTesting
  final services = ValueNotifier<List<DtdServiceMethod>>([]);

  @visibleForTesting
  final selectedService = ValueNotifier<DtdServiceMethod?>(null);

  @override
  Future<void> init() async {
    super.init();
    await refresh();
  }

  @override
  void dispose() {
    services.dispose();
    selectedService.dispose();
    super.dispose();
  }

  // TODO(kenz): listen on DTD's 'Service' stream to update this list for
  //  service registered and unregistered events.
  /// Refreshes [services] with the current set of services registered on
  /// [dtd].
  Future<void> refresh() async {
    final response = await dtd.getRegisteredServices();
    services.value = <DtdServiceMethod>[
      ...response.dtdServices.map((value) {
        // If the DTD service has the form 'service.method', split up the two
        // values. Otherwise, leave the service null and use the entire name
        // as the method.
        String? service;
        String method;
        final parts = value.split('.');
        if (parts.length > 1) {
          service = parts[0];
        }
        method = parts.last;
        return DtdServiceMethod(service: service, method: method);
      }),
      for (final service in response.clientServices) ...[
        for (final method in service.methods.values)
          DtdServiceMethod(
            service: service.name,
            method: method.name,
            capabilities: method.capabilities,
          ),
      ],
    ];
  }
}

/// Displays information about service methods registered on DTD and provides
/// functionality for calling them.
class ServicesView extends StatefulWidget {
  const ServicesView({super.key, required this.controller});

  final ServicesController controller;

  @override
  State<ServicesView> createState() => _ServicesViewState();
}

class _ServicesViewState extends State<ServicesView> {
  final scrollController = ScrollController();

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return FlexSplitColumn(
          totalHeight: constraints.maxHeight,
          initialFractions: const [0.6, 0.4],
          minSizes: const [100.0, 200.0],
          headers: [
            AreaPaneHeader(
              title: Text('Registered services', style: theme.boldTextStyle),
              roundedTopBorder: false,
              includeTopBorder: false,
              tall: true,
              actions: [
                DevToolsButton.iconOnly(
                  icon: Icons.refresh,
                  onPressed: widget.controller.refresh,
                ),
              ],
            ),
            AreaPaneHeader(
              title: Text('Manually call service', style: theme.boldTextStyle),
              roundedTopBorder: false,
              tall: true,
            ),
          ],
          children: [
            MultiValueListenableBuilder(
              listenables: [
                widget.controller.services,
                widget.controller.selectedService,
              ],
              builder: (context, values, _) {
                final services = values.first as List<DtdServiceMethod>;
                final selectedService = values.second as DtdServiceMethod?;
                final sortedServices = services.toList()..sort();
                return Scrollbar(
                  controller: scrollController,
                  thumbVisibility: true,
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: sortedServices.length,
                    itemBuilder: (context, index) {
                      final service = sortedServices[index];
                      return ListTile(
                        title: Text(
                          service.displayName,
                          style: theme.regularTextStyle,
                        ),
                        selected: selectedService == service,
                        onTap: () {
                          widget.controller.selectedService.value = service;
                        },
                      );
                    },
                  ),
                );
              },
            ),
            ValueListenableBuilder(
              valueListenable: widget.controller.selectedService,
              builder: (context, service, child) {
                return ManuallyCallService(
                  serviceMethod: service,
                  dtd: widget.controller.dtd,
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// A widget that provides support for manually calling a DTD service method and
/// viewing the result.
@visibleForTesting
class ManuallyCallService extends StatefulWidget {
  const ManuallyCallService({
    super.key,
    required this.serviceMethod,
    required this.dtd,
  });

  final DtdServiceMethod? serviceMethod;

  final DartToolingDaemon dtd;

  @override
  State<ManuallyCallService> createState() => ManuallyCallServiceState();
}

@visibleForTesting
class ManuallyCallServiceState extends State<ManuallyCallService> {
  final serviceController = TextEditingController();
  final methodController = TextEditingController();
  final paramsController = TextEditingController();

  Map<String, Object?>? callResult;

  @override
  void initState() {
    super.initState();
    _maybePopulateSelectedService();
  }

  @override
  void didUpdateWidget(covariant ManuallyCallService oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serviceMethod != widget.serviceMethod) {
      callResult = null;
      _maybePopulateSelectedService();
    }
  }

  @override
  void dispose() {
    serviceController.dispose();
    methodController.dispose();
    paramsController.dispose();
    super.dispose();
  }

  void _maybePopulateSelectedService() {
    if (widget.serviceMethod != null) {
      serviceController.text = widget.serviceMethod!.service ?? '';
      methodController.text = widget.serviceMethod!.method;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(denseSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField('Service', serviceController, 'service_name'),
          const SizedBox(height: denseSpacing),
          _buildTextField('Method', methodController, 'method_name'),
          const SizedBox(height: denseSpacing),
          Row(
            children: [
              const Text('Additional parameters (JSON encoded):'),
              const SizedBox(width: defaultSpacing),
              Expanded(
                child: DevToolsClearableTextField(
                  controller: paramsController,
                  hintText: '{"foo":"bar"}',
                ),
              ),
            ],
          ),
          const SizedBox(height: defaultSpacing),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              DevToolsButton(
                label: 'Clear',
                onPressed: () {
                  setState(() {
                    callResult = null;
                    serviceController.clear();
                    methodController.clear();
                    paramsController.clear();
                  });
                },
              ),
              const SizedBox(width: denseSpacing),
              DevToolsButton(
                elevated: true,
                label: 'Call Service',
                onPressed: _callService,
              ),
            ],
          ),
          const PaddedDivider.thin(),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                callResult == null
                    ? 'Call the service to view the response'
                    : callResult.toString(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String hintText,
  ) {
    return Row(
      children: [
        SizedBox(width: 150, child: Text('$label:')),
        Expanded(
          child: DevToolsClearableTextField(
            controller: controller,
            hintText: hintText,
          ),
        ),
      ],
    );
  }

  Future<void> _callService() async {
    if (methodController.text.isEmpty) {
      notificationService.push('Method is required');
      return;
    }

    Map<String, Object?>? params;
    try {
      if (paramsController.text.isNotEmpty) {
        try {
          params = (jsonDecode(paramsController.text) as Map)
              .cast<String, Object?>();
        } catch (e) {
          notificationService.push(
            'Failed to JSON decode parameters: "${paramsController.text}"',
          );
          return;
        }
      }
      final response = await widget.dtd.call(
        serviceController.text.isNotEmpty ? serviceController.text : null,
        methodController.text,
        params: params,
      );
      setState(() {
        callResult = response.result;
      });
    } catch (e) {
      setState(() {
        callResult = {'error': e.toString()};
      });
    }
  }
}
