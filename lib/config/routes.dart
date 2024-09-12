import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:tawkie/config/themes.dart';
import 'package:tawkie/pages/add_bridge/add_bridge.dart';
import 'package:tawkie/pages/archive/archive.dart';
import 'package:tawkie/pages/auth/auth.dart';
import 'package:tawkie/pages/beta/beta.dart';
import 'package:tawkie/pages/chat/chat.dart';
import 'package:tawkie/pages/chat_access_settings/chat_access_settings_controller.dart';
import 'package:tawkie/pages/chat_details/chat_details.dart';
import 'package:tawkie/pages/chat_encryption_settings/chat_encryption_settings.dart';
import 'package:tawkie/pages/chat_list/chat_list.dart';
import 'package:tawkie/pages/chat_members/chat_members.dart';
import 'package:tawkie/pages/chat_permissions_settings/chat_permissions_settings.dart';
import 'package:tawkie/pages/chat_search/chat_search_page.dart';
import 'package:tawkie/pages/device_settings/device_settings.dart';
import 'package:tawkie/pages/invitation_selection/invitation_selection.dart';
import 'package:tawkie/pages/new_group/new_group.dart';
import 'package:tawkie/pages/new_private_chat/new_private_chat.dart';
import 'package:tawkie/pages/new_space/new_space.dart';
import 'package:tawkie/pages/not_subscribe/not_subscribe_page.dart';
import 'package:tawkie/pages/settings/settings.dart';
import 'package:tawkie/pages/settings_3pid/settings_3pid.dart';
import 'package:tawkie/pages/settings_chat/settings_chat.dart';
import 'package:tawkie/pages/settings_emotes/settings_emotes.dart';
import 'package:tawkie/pages/settings_ignore_list/settings_ignore_list.dart';
import 'package:tawkie/pages/settings_multiple_emotes/settings_multiple_emotes.dart';
import 'package:tawkie/pages/settings_notifications/settings_notifications.dart';
import 'package:tawkie/pages/settings_password/settings_password.dart';
import 'package:tawkie/pages/settings_security/settings_security.dart';
import 'package:tawkie/pages/settings_style/settings_style.dart';
import 'package:tawkie/pages/sub/sub_body.dart';
import 'package:tawkie/pages/tickets/tickets_page.dart';
import 'package:tawkie/pages/welcome_slides/slides.dart';
import 'package:tawkie/widgets/layouts/empty_page.dart';
import 'package:tawkie/widgets/layouts/two_column_layout.dart';
import 'package:tawkie/widgets/log_view.dart';
import 'package:tawkie/widgets/matrix.dart';

abstract class AppRoutes {
  static FutureOr<String?> loggedInRedirect(
    BuildContext context,
    GoRouterState state,
  ) async {
    final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
    final sessionToken = await _secureStorage.read(key: 'sessionToken');

    final bool isLoggedKratos =
        sessionToken is String && sessionToken.isNotEmpty;
    final bool isLoggedMatrix = Matrix.of(context).client.isLogged();
    final bool preAuth = state.fullPath!.startsWith('/home');

    if (isLoggedKratos && isLoggedMatrix) {
      return '/rooms';
    } else if (isLoggedKratos && !isLoggedMatrix && !preAuth) {
      return '/home/login';
    } else if (!isLoggedMatrix && !preAuth) {
      return '/home/welcome';
    }

    return null;
  }

  static FutureOr<String?> loggedOutRedirect(
    BuildContext context,
    GoRouterState state,
  ) async {
    // Check connection to Matrix
    final hasLogin = Matrix.of(context).client.isLogged();
    if (!hasLogin) {
      return '/home';
    }
    return null;
  }

  AppRoutes();

  static final List<RouteBase> routes = [
    GoRoute(
      path: '/',
      redirect: loggedInRedirect,
    ),
    GoRoute(
      path: '/home',
      pageBuilder: (context, state) => defaultPageBuilder(
        context,
        state,
        const Auth(authType: AuthType.register),
      ),
      redirect: loggedInRedirect,
      routes: [
        GoRoute(
          path: 'welcome',
          pageBuilder: (context, state) => defaultPageBuilder(
            context,
            state,
            const WelcomeSlidePage(), // Welcome slide show widget
          ),
          redirect: loggedInRedirect,
        ),
        GoRoute(
          path: 'login',
          pageBuilder: (context, state) => defaultPageBuilder(
            context,
            state,
            const Auth(authType: AuthType.login),
          ),
          redirect: loggedInRedirect,
        ),
        GoRoute(
          path: 'register',
          pageBuilder: (context, state) => defaultPageBuilder(
            context,
            state,
            const Auth(authType: AuthType.register),
          ),
          redirect: loggedInRedirect,
        ),
        GoRoute(
          path: 'subscribe',
          pageBuilder: (context, state) =>
              const MaterialPage(child: NotSubscribePage()),
          redirect: loggedInRedirect,
        ),
      ],
    ),
    GoRoute(
      path: '/logs',
      pageBuilder: (context, state) => defaultPageBuilder(
        context,
        state,
        const LogViewer(),
      ),
    ),
    ShellRoute(
      pageBuilder: (context, state, child) => defaultPageBuilder(
        context,
        state,
        FluffyThemes.isColumnMode(context) &&
                state.fullPath?.startsWith('/rooms/settings') == false
            ? TwoColumnLayout(
                displayNavigationRail:
                    state.path?.startsWith('/rooms/settings') != true,
                mainView: ChatList(
                  activeChat: state.pathParameters['roomid'],
                  displayNavigationRail:
                      state.path?.startsWith('/rooms/settings') != true,
                ),
                sideView: child,
              )
            : child,
      ),
      routes: [
        GoRoute(
          path: '/rooms',
          redirect: loggedOutRedirect,
          pageBuilder: (context, state) => defaultPageBuilder(
            context,
            state,
            FluffyThemes.isColumnMode(context)
                ? const EmptyPage()
                : ChatList(
                    activeChat: state.pathParameters['roomid'],
                  ),
          ),
          routes: [
            GoRoute(
              path: 'archive',
              pageBuilder: (context, state) => defaultPageBuilder(
                context,
                state,
                const Archive(),
              ),
              routes: [
                GoRoute(
                  path: ':roomid',
                  pageBuilder: (context, state) => defaultPageBuilder(
                    context,
                    state,
                    ChatPage(
                      roomId: state.pathParameters['roomid']!,
                      eventId: state.uri.queryParameters['event'],
                    ),
                  ),
                  redirect: loggedOutRedirect,
                ),
              ],
              redirect: loggedOutRedirect,
            ),
            GoRoute(
              path: 'newprivatechat',
              pageBuilder: (context, state) => defaultPageBuilder(
                context,
                state,
                const NewPrivateChat(),
              ),
              redirect: loggedOutRedirect,
            ),
            GoRoute(
              path: 'newgroup',
              pageBuilder: (context, state) => defaultPageBuilder(
                context,
                state,
                const NewGroup(),
              ),
              redirect: loggedOutRedirect,
            ),
            GoRoute(
              path: 'newspace',
              pageBuilder: (context, state) => defaultPageBuilder(
                context,
                state,
                const NewSpace(),
              ),
              redirect: loggedOutRedirect,
            ),
            ShellRoute(
              pageBuilder: (context, state, child) => defaultPageBuilder(
                context,
                state,
                FluffyThemes.isColumnMode(context)
                    ? TwoColumnLayout(
                        mainView: const Settings(),
                        sideView: child,
                        displayNavigationRail: false,
                      )
                    : child,
              ),
              routes: [
                GoRoute(
                  path: 'settings',
                  pageBuilder: (context, state) => defaultPageBuilder(
                    context,
                    state,
                    FluffyThemes.isColumnMode(context)
                        ? const EmptyPage()
                        : const Settings(),
                  ),
                  routes: [
                    GoRoute(
                      path: 'notifications',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        const SettingsNotifications(),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'style',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        const SettingsStyle(),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'devices',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        const DevicesSettings(),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'chat',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        const SettingsChat(),
                      ),
                      routes: [
                        GoRoute(
                          path: 'emotes',
                          pageBuilder: (context, state) => defaultPageBuilder(
                            context,
                            state,
                            const EmotesSettings(),
                          ),
                        ),
                      ],
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'addaccount',
                      redirect: loggedOutRedirect,
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        const Auth(authType: AuthType.login),
                      ),
                      routes: [
                        GoRoute(
                          path: 'login',
                          pageBuilder: (context, state) => defaultPageBuilder(
                            context,
                            state,
                            const Auth(authType: AuthType.login),
                          ),
                          redirect: loggedOutRedirect,
                        ),
                      ],
                    ),
                    GoRoute(
                      path: 'joinBeta',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        const BetaJoinPage(),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'tickets',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        TicketsPage(),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                    // Route to social networking page via chat bot
                    // The entire path is: /rooms/settings/addbridgebot
                    GoRoute(
                      path: 'addbridgeBot',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        const AddBridge(),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                    // Route to subscription page
                    // The entire path is: /rooms/settings/subs
                    GoRoute(
                      path: 'subs',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        SubscriptionPage(),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'security',
                      redirect: loggedOutRedirect,
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        const SettingsSecurity(),
                      ),
                      routes: [
                        GoRoute(
                          path: 'password',
                          pageBuilder: (context, state) {
                            return defaultPageBuilder(
                              context,
                              state,
                              const SettingsPassword(),
                            );
                          },
                          redirect: loggedOutRedirect,
                        ),
                        GoRoute(
                          path: 'ignorelist',
                          pageBuilder: (context, state) {
                            return defaultPageBuilder(
                              context,
                              state,
                              SettingsIgnoreList(
                                initialUserId: state.extra?.toString(),
                              ),
                            );
                          },
                          redirect: loggedOutRedirect,
                        ),
                        GoRoute(
                          path: '3pid',
                          pageBuilder: (context, state) => defaultPageBuilder(
                            context,
                            state,
                            const Settings3Pid(),
                          ),
                          redirect: loggedOutRedirect,
                        ),
                      ],
                    ),
                  ],
                  redirect: loggedOutRedirect,
                ),
              ],
            ),
            GoRoute(
              path: ':roomid',
              pageBuilder: (context, state) => defaultPageBuilder(
                context,
                state,
                ChatPage(
                  roomId: state.pathParameters['roomid']!,
                  shareText: state.uri.queryParameters['body'],
                  eventId: state.uri.queryParameters['event'],
                ),
              ),
              redirect: loggedOutRedirect,
              routes: [
                GoRoute(
                  path: 'search',
                  pageBuilder: (context, state) => defaultPageBuilder(
                    context,
                    state,
                    ChatSearchPage(
                      roomId: state.pathParameters['roomid']!,
                    ),
                  ),
                  redirect: loggedOutRedirect,
                ),
                GoRoute(
                  path: 'encryption',
                  pageBuilder: (context, state) => defaultPageBuilder(
                    context,
                    state,
                    const ChatEncryptionSettings(),
                  ),
                  redirect: loggedOutRedirect,
                ),
                GoRoute(
                  path: 'invite',
                  pageBuilder: (context, state) => defaultPageBuilder(
                    context,
                    state,
                    InvitationSelection(
                      roomId: state.pathParameters['roomid']!,
                    ),
                  ),
                  redirect: loggedOutRedirect,
                ),
                GoRoute(
                  path: 'details',
                  pageBuilder: (context, state) => defaultPageBuilder(
                    context,
                    state,
                    ChatDetails(
                      roomId: state.pathParameters['roomid']!,
                    ),
                  ),
                  routes: [
                    GoRoute(
                      path: 'access',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        ChatAccessSettings(
                          roomId: state.pathParameters['roomid']!,
                        ),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'members',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        ChatMembersPage(
                          roomId: state.pathParameters['roomid']!,
                        ),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'permissions',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        const ChatPermissionsSettings(),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'invite',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        InvitationSelection(
                          roomId: state.pathParameters['roomid']!,
                        ),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'multiple_emotes',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        const MultipleEmotesSettings(),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'emotes',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        const EmotesSettings(),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'emotes/:state_key',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        const EmotesSettings(),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                  ],
                  redirect: loggedOutRedirect,
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ];

  static Page defaultPageBuilder(
    BuildContext context,
    GoRouterState state,
    Widget child,
  ) =>
      FluffyThemes.isColumnMode(context)
          ? NoTransitionPage(
              key: state.pageKey,
              restorationId: state.pageKey.value,
              child: child,
            )
          : MaterialPage(
              key: state.pageKey,
              restorationId: state.pageKey.value,
              child: child,
            );
}
