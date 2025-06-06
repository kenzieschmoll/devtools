// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

/// @docImport 'package:vm_service/vm_service.dart';
library;

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:devtools_app_shared/shared.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'extensions/extension_screen.dart';
import 'framework/framework_core.dart';
import 'framework/home_screen.dart';
import 'framework/initializer.dart';
import 'framework/notifications_view.dart';
import 'framework/observer/disconnect_observer.dart';
import 'framework/release_notes.dart';
import 'framework/scaffold/scaffold.dart';
import 'screens/app_size/app_size_controller.dart';
import 'screens/app_size/app_size_screen.dart';
import 'screens/debugger/debugger_controller.dart';
import 'screens/debugger/debugger_screen.dart';
import 'screens/deep_link_validation/deep_links_controller.dart';
import 'screens/deep_link_validation/deep_links_screen.dart';
import 'screens/dtd/dtd_tools_controller.dart';
import 'screens/dtd/dtd_tools_screen.dart';
import 'screens/inspector_shared/inspector_screen.dart';
import 'screens/inspector_shared/inspector_screen_controller.dart';
import 'screens/logging/logging_controller.dart';
import 'screens/logging/logging_screen.dart';
import 'screens/memory/framework/memory_controller.dart';
import 'screens/memory/framework/memory_screen.dart';
import 'screens/network/network_controller.dart';
import 'screens/network/network_screen.dart';
import 'screens/performance/performance_controller.dart';
import 'screens/performance/performance_screen.dart';
import 'screens/profiler/profiler_screen.dart';
import 'screens/profiler/profiler_screen_controller.dart';
import 'screens/provider/provider_screen.dart';
import 'screens/vm_developer/vm_developer_tools_controller.dart';
import 'screens/vm_developer/vm_developer_tools_screen.dart';
import 'service/service_extension_widgets.dart';
import 'shared/analytics/analytics_controller.dart';
import 'shared/feature_flags.dart';
import 'shared/framework/framework_controller.dart';
import 'shared/framework/routing.dart';
import 'shared/framework/screen.dart';
import 'shared/framework/screen_controllers.dart';
import 'shared/globals.dart';
import 'shared/offline/offline_data.dart';
import 'shared/offline/offline_screen.dart';
import 'shared/primitives/query_parameters.dart';
import 'shared/primitives/utils.dart';
import 'shared/ui/common_widgets.dart';
import 'shared/ui/hover.dart';
import 'shared/utils/focus_utils.dart';
import 'shared/utils/utils.dart';
import 'standalone_ui/standalone_screen.dart';

/// Top-level configuration for the app.
@immutable
class DevToolsApp extends StatefulWidget {
  const DevToolsApp(
    this.originalScreens,
    this.analyticsController, {
    super.key,
  });

  final List<DevToolsScreen> originalScreens;
  final AnalyticsController analyticsController;

  @override
  State<DevToolsApp> createState() => DevToolsAppState();
}

/// Initializer for the [FrameworkCore] and the app's navigation.
///
/// This manages the route generation, and marshals URL query parameters into
/// flutter route parameters.
class DevToolsAppState extends State<DevToolsApp> with AutoDisposeMixin {
  List<Screen> get _screens {
    if (FeatureFlags.devToolsExtensions) {
      // TODO(https://github.com/flutter/devtools/issues/6273): stop special
      // casing the package:provider extension.
      final containsProviderExtension = extensionService
          .currentExtensions
          .value
          .visibleExtensions
          .where((e) => e.name == 'provider')
          .isNotEmpty;
      final devToolsScreens = containsProviderExtension
          ? _originalScreens
                .where((s) => s.screenId != ScreenMetaData.provider.id)
                .toList()
          : _originalScreens;
      return [...devToolsScreens, ..._extensionScreens];
    }
    return _originalScreens;
  }

  List<Screen> get _originalScreens =>
      widget.originalScreens.map((s) => s.screen).toList();

  Iterable<Screen> get _extensionScreens =>
      extensionService.visibleExtensions.map(
        (e) =>
            DevToolsScreen<DevToolsScreenController>(ExtensionScreen(e)).screen,
      );

  final hoverCardController = HoverCardController();

  late ReleaseNotesController releaseNotesController;

  late final routerDelegate = DevToolsRouterDelegate(_getPage);

  @override
  void initState() {
    super.initState();
    setGlobal(GlobalKey<NavigatorState>, routerDelegate.navigatorKey);

    autoDisposeStreamSubscription(
      frameworkController.onConnectVmEvent.listen(_connectVm),
    );

    _initScreenControllers(
      connected:
          serviceConnection.serviceManager.connectedState.value.connected,
      offline: offlineDataController.showingOfflineData.value,
    );
    addAutoDisposeListener(offlineDataController.showingOfflineData, () {
      final offlineMode = offlineDataController.showingOfflineData.value;
      // Dispose the current offline controllers, if any, for any change to the
      // showing offline data value.
      screenControllers.disposeOfflineControllers();
      if (offlineMode) {
        _initScreenControllers(offline: offlineMode);
      }
    });
    addAutoDisposeListener(serviceConnection.serviceManager.connectedState, () {
      final connectionState =
          serviceConnection.serviceManager.connectedState.value;

      // When disconnecting from an app, prepare the offline state for reviewing
      // history.
      screenControllers.forEachInitialized((screenController) {
        if (screenController is OfflineScreenControllerMixin &&
            !connectionState.connected &&
            !connectionState.userInitiatedConnectionState) {
          screenController.maybePrepareDataForReviewingHistory();
        }
      });

      // Dispose the current connected controllers, if any, for any change to
      // the connected state.
      screenControllers.disposeConnectedControllers();
      _initScreenControllers(connected: connectionState.connected);
    });

    // TODO(https://github.com/flutter/devtools/issues/6018): Once
    // https://github.com/flutter/flutter/issues/129692 is fixed, disable the
    // browser's native context menu on secondary-click, and instead use the
    // menu provided by Flutter:
    // if (kIsWeb) {
    //   unawaited(BrowserContextMenu.disableContextMenu());
    // }

    void clearRoutesAndSetState() {
      setState(() {
        _clearCachedRoutes();
      });
    }

    if (FeatureFlags.devToolsExtensions) {
      addAutoDisposeListener(
        extensionService.currentExtensions,
        clearRoutesAndSetState,
      );
    }

    addAutoDisposeListener(
      serviceConnection.serviceManager.isolateManager.mainIsolate,
      clearRoutesAndSetState,
    );

    addAutoDisposeListener(preferences.darkModeEnabled);

    releaseNotesController = ReleaseNotesController();

    // Workaround for https://github.com/flutter/flutter/issues/155265.
    setUpTextFieldFocusFixHandler();
  }

  @override
  void dispose() {
    FrameworkCore.dispose();
    // Workaround for https://github.com/flutter/flutter/issues/155265.
    removeTextFieldFocusFixHandler();
    super.dispose();
  }

  @override
  void didUpdateWidget(DevToolsApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    _clearCachedRoutes();
  }

  /// Connects to the VM with the given URI.
  ///
  /// This request usually comes from the IDE via the server API to reuse the
  /// DevTools window after being disconnected (for example if the user stops
  /// a debug session then launches a new one).
  Future<void> _connectVm(ConnectVmEvent event) async {
    await routerDelegate.updateArgsIfChanged({
      'uri': event.serviceProtocolUri.toString(),
      if (event.notify) 'notify': 'true',
    });
  }

  /// Gets the page for a given page/path and args.
  Page _getPage(
    BuildContext context,
    String? page,
    DevToolsQueryParams params,
    DevToolsNavigationState? state,
  ) {
    // `page` will initially be null while the router is set up, then we will
    // be called again with an empty string for the root.
    if (FrameworkCore.vmServiceInitializationInProgress || page == null) {
      return const MaterialPage(child: CenteredCircularProgressIndicator());
    }

    // Provide the appropriate page route.
    if (pages.containsKey(page)) {
      Widget widget = pages[page]!(context, page, params, state);
      assert(() {
        widget = _AlternateCheckedModeBanner(
          builder: (context) => pages[page]!(context, page, params, state),
        );
        return true;
      }());
      return MaterialPage(child: widget);
    }

    // Return a page not found.
    return MaterialPage(
      child: DevToolsScaffold.withChild(
        key: const Key('not-found'),
        embedMode: params.embedMode,
        child: ScreenUnavailable(
          title: "The '$page' page cannot be found.",
          embedMode: params.embedMode,
          routerDelegate: routerDelegate,
        ),
      ),
    );
  }

  Widget _buildTabbedPage(
    BuildContext _,
    String? page,
    DevToolsQueryParams queryParams,
    DevToolsNavigationState? _,
  ) {
    final vmServiceUri = queryParams.vmServiceUri;
    final embedMode = queryParams.embedMode;

    // TODO(dantup): We should be able simplify this a little, removing params['page']
    // and only supporting /inspector (etc.) instead of also &page=inspector if
    // all IDEs switch over to those URLs.
    if (page?.isEmpty ?? true) {
      page = queryParams.legacyPage;
    }

    final paramsContainVmServiceUri =
        vmServiceUri != null && vmServiceUri.isNotEmpty;

    Widget scaffoldBuilder() {
      // Force regeneration of visible screens when Advanced Developer Mode is
      // enabled and when the list of available extensions change.
      return MultiValueListenableBuilder(
        listenables: [
          preferences.advancedDeveloperModeEnabled,
          extensionService.currentExtensions,
        ],
        builder: (_, _, child) {
          final screensInScaffold = _visibleScreens()
              .where(
                (s) => maybeIncludeOnlyEmbeddedScreen(
                  s,
                  page: page,
                  embedMode: embedMode,
                ),
              )
              .toList();

          removeHiddenScreens(screensInScaffold, queryParams);

          DevToolsScaffold scaffold;

          final originalScreen = _screens.firstWhereOrNull(
            (s) => s.screenId == page,
          );
          final screenInOriginalScreens = originalScreen != null;
          final screenInScaffoldScreens = screensInScaffold.any(
            (s) => s.screenId == page,
          );
          if (page != null &&
              screenInOriginalScreens &&
              !screenInScaffoldScreens) {
            // The requested [page] is in the list of DevTools screens, but is
            // not available in list of available screens for this scaffold.
            scaffold = DevToolsScaffold.withChild(
              key: const Key('screen-disabled'),
              embedMode: embedMode,
              child: ScreenUnavailable(
                title: "The '$page' screen is unavailable.",
                description: _screenDisabledMessage(originalScreen),
                routerDelegate: routerDelegate,
                embedMode: embedMode,
              ),
            );
          } else if (screensInScaffold.isEmpty) {
            // TODO(https://github.com/dart-lang/pub-dev/issues/7216): add an
            // extensions store or a link to a pub.dev query for packages with
            // extensions.
            scaffold = DevToolsScaffold.withChild(
              embedMode: embedMode,
              child: CenteredMessage(
                message:
                    'No DevTools '
                    '${queryParams.hideAllExceptExtensions ? 'extensions' : 'screens'} '
                    'available for your project.',
              ),
            );
          } else {
            final connectedToFlutterApp =
                serviceConnection
                    .serviceManager
                    .connectedApp
                    ?.isFlutterAppNow ??
                false;
            final connectedToDartWebApp =
                serviceConnection
                    .serviceManager
                    .connectedApp
                    ?.isDartWebAppNow ??
                false;
            scaffold = DevToolsScaffold(
              embedMode: embedMode,
              page: page,
              screens: screensInScaffold,
              actions: isEmbedded()
                  ? []
                  : [
                      if (paramsContainVmServiceUri) ...[
                        // Hide the hot reload button for Dart web apps, where the
                        // hot reload service extension is not avilable and where the
                        // [service.reloadServices] RPC is not implemented.
                        // TODO(https://github.com/flutter/devtools/issues/6441): find
                        // a way to show this for Dart web apps when supported.
                        if (!connectedToDartWebApp)
                          HotReloadButton(
                            callOnVmServiceDirectly: !connectedToFlutterApp,
                          ),
                        // This button will hide itself based on whether the
                        // hot restart service is available for the connected app.
                        const HotRestartButton(),
                      ],
                      ...DevToolsScaffold.defaultActions(),
                    ],
            );
          }
          return scaffold;
        },
      );
    }

    return paramsContainVmServiceUri
        ? Initializer(builder: (_) => scaffoldBuilder())
        : scaffoldBuilder();
  }

  /// The pages that the app exposes.
  Map<String, UrlParametersBuilder> get pages {
    return _routes ??= {
      homeScreenId: _buildTabbedPage,
      for (final screen in _screens) screen.screenId: _buildTabbedPage,
      snapshotScreenId: (_, _, params, _) {
        // TODO(kenz): support multiple offline routes, or prevent an offline
        // route from being pushed on top of another one.
        // If an offline route is pushed on top of another offline route, this
        // will cause the oldest set of controllers to be destroyed.
        screenControllers.disposeOfflineControllers();
        _initScreenControllers(offline: true);
        return DevToolsScaffold.withChild(
          key: UniqueKey(),
          embedMode: params.embedMode,
          child: OfflineScreenBody(params.offlineScreenId, _screens),
        );
      },
      ..._standaloneScreens,
    };
  }

  Map<String, UrlParametersBuilder>? _routes;

  void _clearCachedRoutes() {
    _routes = null;
    routerDelegate.refreshPages();
  }

  Map<String, UrlParametersBuilder> get _standaloneScreens {
    // TODO(dantup): Standalone screens do not use DevToolsScaffold which means
    //  they do not currently send an initial "currentPage" event to inform
    //  the server which page they are rendering.
    return {
      for (final type in StandaloneScreenType.values)
        type.name: (_, _, args, _) => type.screen,
    };
  }

  // TODO(kenz): consider showing all screens and displaying the reason why they
  // are not available instead of hiding screens.
  List<Screen> _visibleScreens() =>
      _screens.where((screen) => shouldShowScreen(screen).show).toList();

  void _initScreenControllers({bool connected = false, bool offline = false}) {
    // We use [widget.originalScreens] here instead of [_screens] because
    // extension screens do not provide a controller through this mechanism.
    final screensThatProvideController = widget.originalScreens.where(
      (s) => s.providesController,
    );
    var screens = screensThatProvideController;
    if (offline) {
      screens = screensThatProvideController.where(
        (s) => s.screen.worksWithOfflineData,
      );
    } else if (!connected) {
      screens = screensThatProvideController.where(
        (s) => !s.screen.requiresConnection,
      );
    }
    for (final s in screens) {
      s.registerController(routerDelegate, offline: offline);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      themeMode: isDarkThemeEnabled() ? ThemeMode.dark : ThemeMode.light,
      theme: themeFor(
        isDarkTheme: false,
        ideTheme: ideTheme,
        theme: ThemeData(useMaterial3: true, colorScheme: lightColorScheme),
      ),
      darkTheme: themeFor(
        isDarkTheme: true,
        ideTheme: ideTheme,
        theme: ThemeData(useMaterial3: true, colorScheme: darkColorScheme),
      ),
      builder: (context, child) {
        if (child == null) {
          return const CenteredMessage(
            message: 'Uh-oh, something went wrong. Please refresh the page.',
          );
        }
        return MultiProvider(
          providers: [
            Provider<AnalyticsController>.value(
              value: widget.analyticsController,
            ),
            Provider<HoverCardController>.value(value: hoverCardController),
            Provider<ReleaseNotesController>.value(
              value: releaseNotesController,
            ),
          ],
          child: NotificationsView(
            child: ReleaseNotesViewer(
              controller: releaseNotesController,
              child: DisconnectObserver(
                routerDelegate: routerDelegate,
                child: child,
              ),
            ),
          ),
        );
      },
      routerDelegate: routerDelegate,
      routeInformationParser: DevToolsRouteInformationParser(),
      // Disable default scrollbar behavior on web to fix duplicate scrollbars
      // bug, see https://github.com/flutter/flutter/issues/90697:
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        scrollbars: !kIsWeb,
      ),
    );
  }

  /// Helper function that will be used in a 'List.where' call to generate a
  /// list of [Screen]s to pass to a [DevToolsScaffold].
  ///
  /// When [embedMode] is [EmbedMode.embedOne], this method will return true
  /// only when [screen] matches the specified [page]. Otherwise, this method
  /// will return true for any [screen].
  @visibleForTesting
  static bool maybeIncludeOnlyEmbeddedScreen(
    Screen screen, {
    required String? page,
    required EmbedMode embedMode,
  }) {
    if (embedMode == EmbedMode.embedOne && page != null) {
      return screen.screenId == page;
    }
    return true;
  }

  /// Helper function that removes any hidden screens from [screens] based on
  /// the value of the 'hide' query parameter in [params].
  @visibleForTesting
  static void removeHiddenScreens(
    List<Screen> screens,
    DevToolsQueryParams params,
  ) {
    screens.removeWhere((s) => params.hiddenScreens.contains(s.screenId));

    // When 'hide=extensions' is in the query parameters, this remove all
    // extension screens.
    if (params.hideExtensions) {
      screens.removeWhere((s) => s is ExtensionScreen);
    }

    // When 'hide=all-except-extensions' is in the query parameters, remove all
    // non-extension screens.
    if (params.hideAllExceptExtensions) {
      screens.removeWhere((s) => s is! ExtensionScreen);
    }
  }

  String? _screenDisabledMessage(Screen screen) {
    final reason = shouldShowScreen(screen).disabledReason;
    String? disabledMessage;
    if (reason == ScreenDisabledReason.requiresDartLibrary) {
      // Special case for screens that require a library since the message
      // needs to be generated dynamically.
      disabledMessage =
          'The ${screen.title} screen requires library '
          '${screen.requiresLibrary}, but the library was not detected.';
    } else if (reason?.message case final String message) {
      disabledMessage = 'The ${screen.title} screen $message';
    }
    return disabledMessage;
  }
}

/// DevTools screen wrapper that is responsible for creating and providing the
/// screen's controller, if one exists, as well as enabling offline support.
///
/// [C] corresponds to the type of the screen's controller, which is created by
/// [createController].
class DevToolsScreen<C extends DevToolsScreenController> {
  const DevToolsScreen(this.screen, {this.createController});

  final Screen screen;

  /// Responsible for creating the controller for this screen, if non-null.
  ///
  /// If [createController] and `controller` are both null, [screen] will be
  /// responsible for creating and maintaining its own controller.
  ///
  /// In the controller initialization, if logic requires a connected [VmService]
  /// object (`serviceConnection.serviceManager.service`), then the controller should first await
  /// the `serviceConnection.serviceManager.onServiceAvailable` future to ensure the service has
  /// been initialized.
  /// The controller does not need to handle re-connection to the application. When reconnected,
  /// DevTools will create a new controller. However, the controller should make sure
  /// not to fail if the connection is lost.
  final C Function(DevToolsRouterDelegate)? createController;

  /// Returns true if a controller was provided for [screen]. If false,
  /// [screen] is responsible for creating and maintaining its own controller.
  bool get providesController => createController != null;

  /// Registers a screen controller with the [ScreenControllers] manager.
  void registerController(
    DevToolsRouterDelegate routerDelegate, {
    required bool offline,
  }) {
    screenControllers.register<C>(
      () => createController!(routerDelegate),
      offline: offline,
    );
  }
}

/// A [WidgetBuilder] that takes an additional map of URL query parameters and
/// args, as well a state not included in the URL.
typedef UrlParametersBuilder =
    Widget Function(
      BuildContext,
      String?,
      DevToolsQueryParams,
      DevToolsNavigationState?,
    );

/// Displays the checked mode banner in the bottom end corner instead of the
/// top end corner.
///
/// This avoids issues with widgets in the appbar being hidden by the banner
/// in a web or desktop app.
class _AlternateCheckedModeBanner extends StatelessWidget {
  const _AlternateCheckedModeBanner({required this.builder});
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return Banner(
      message: 'DEBUG',
      textDirection: TextDirection.ltr,
      location: BannerLocation.bottomEnd,
      child: Builder(builder: builder),
    );
  }
}

class ScreenUnavailable extends StatelessWidget {
  const ScreenUnavailable({
    super.key,
    required this.title,
    required this.embedMode,
    required this.routerDelegate,
    this.description,
  });

  final String title;
  final DevToolsRouterDelegate routerDelegate;
  final EmbedMode embedMode;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: denseSpacing),
          if (description != null)
            Text(description!, style: theme.regularTextStyle),
          if (embedMode == EmbedMode.none) ...[
            const SizedBox(height: defaultSpacing),
            ElevatedButton(
              onPressed: () =>
                  routerDelegate.navigateHome(clearScreenParam: true),
              child: const Text('Go to Home screen'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Screens to initialize DevTools with.
///
/// If the screen depends on a provided controller, the provider should be
/// provided here.
///
/// Conditional screens can be added to this list, and they will automatically
/// be shown or hidden based on the [Screen] conditionalLibrary provided.
List<DevToolsScreen> defaultScreens({
  List<DevToolsJsonFile> sampleData = const [],
}) {
  return devtoolsScreens ??= <DevToolsScreen>[
    DevToolsScreen<DevToolsScreenController>(
      HomeScreen(sampleData: sampleData),
    ),
    // TODO(https://github.com/flutter/devtools/issues/7860): Clean-up after
    // Inspector V2 has been released.
    DevToolsScreen<InspectorScreenController>(
      InspectorScreen(),
      createController: (_) => InspectorScreenController(),
    ),
    DevToolsScreen<PerformanceController>(
      PerformanceScreen(),
      createController: (_) => PerformanceController(),
    ),
    DevToolsScreen<ProfilerScreenController>(
      ProfilerScreen(),
      createController: (_) => ProfilerScreenController(),
    ),
    DevToolsScreen<MemoryController>(
      MemoryScreen(),
      createController: (_) => MemoryController(),
    ),
    DevToolsScreen<DebuggerController>(
      DebuggerScreen(),
      createController: (routerDelegate) =>
          DebuggerController(routerDelegate: routerDelegate),
    ),
    DevToolsScreen<NetworkController>(
      NetworkScreen(),
      createController: (_) => NetworkController(),
    ),
    DevToolsScreen<LoggingController>(
      LoggingScreen(),
      createController: (_) => LoggingController(),
    ),
    DevToolsScreen<DevToolsScreenController>(ProviderScreen()),
    DevToolsScreen<AppSizeController>(
      AppSizeScreen(),
      createController: (_) => AppSizeController(),
    ),
    DevToolsScreen<DeepLinksController>(
      DeepLinksScreen(),
      createController: (_) => DeepLinksController(),
    ),
    DevToolsScreen<VMDeveloperToolsController>(
      VMDeveloperToolsScreen(),
      createController: (_) => VMDeveloperToolsController(),
    ),
    DevToolsScreen<DTDToolsController>(
      DTDToolsScreen(),
      createController: (_) => DTDToolsController(),
    ),
  ];
}

@visibleForTesting
List<DevToolsScreen>? devtoolsScreens;
