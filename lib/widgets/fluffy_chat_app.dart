import 'package:flutter/material.dart';

import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:go_router/go_router.dart';
import 'package:matomo_tracker/matomo_tracker.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawkie/config/app_config.dart';

import 'package:tawkie/config/routes.dart';
import 'package:tawkie/config/themes.dart';
import 'package:tawkie/utils/custom_scroll_behaviour.dart';
import 'package:tawkie/utils/platform_size.dart';
import 'package:tawkie/widgets/app_lock.dart';
import 'package:tawkie/widgets/notifier_state.dart';
import 'package:tawkie/widgets/theme_builder.dart';
import 'matrix.dart';

class FluffyChatApp extends StatelessWidget {
  final Widget? testWidget;
  final List<Client> clients;
  final String? pincode;
  final SharedPreferences store;

  const FluffyChatApp({
    super.key,
    this.testWidget,
    required this.clients,
    required this.store,
    this.pincode,
  });

  /// getInitialLink may rereturn the value multiple times if this view is
  /// opened multiple times for example if the user logs out after they logged
  /// in with qr code or magic link.
  static bool gotInitialLink = false;

  // Router must be outside of build method so that hot reload does not reset
  // the current path.
  static final GoRouter router = GoRouter(
    routes: AppRoutes.routes,
    // To get TraceableClientMix and TraceableWidget up and running
    observers: [matomoObserver],
  );

  @override
  Widget build(BuildContext context) {
    PlatformWidth.initialize(
        context); // To initialize size variables according to platform
    return ChangeNotifierProvider(
      create: (context) =>
          ConnectionStateModel(), // To initialize ChangeNotifier
      child: ThemeBuilder(
        builder: (context, themeMode, primaryColor) => MaterialApp.router(
          title: AppConfig.applicationName,
          themeMode: themeMode,
          theme:
              FluffyThemes.buildTheme(context, Brightness.light, primaryColor),
          darkTheme:
              FluffyThemes.buildTheme(context, Brightness.dark, primaryColor),
          scrollBehavior: CustomScrollBehavior(),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          routerConfig: router,
          builder: (context, child) => AppLockWidget(
            pincode: pincode,
            clients: clients,
            // Need a navigator above the Matrix widget for
            // displaying dialogs
            child: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (_) => Matrix(
                  clients: clients,
                  store: store,
                  child: testWidget ?? child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
