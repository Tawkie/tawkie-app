import 'package:flutter/material.dart';

import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:go_router/go_router.dart';

import 'package:tawkie/config/app_config.dart';
import 'package:tawkie/config/setting_keys.dart';
import 'package:tawkie/utils/beautify_string_extension.dart';
import 'package:tawkie/utils/localized_exception_extension.dart';
import 'package:tawkie/utils/platform_infos.dart';
import 'package:tawkie/widgets/layouts/max_width_body.dart';
import 'package:tawkie/widgets/matrix.dart';
import 'package:tawkie/widgets/settings_switch_list_tile.dart';
import 'settings_security.dart';

class SettingsSecurityView extends StatelessWidget {
  final SettingsSecurityController controller;
  const SettingsSecurityView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L10n.of(context)!.security)),
      body: ListTileTheme(
        iconColor: Theme.of(context).colorScheme.onSurface,
        child: MaxWidthBody(
          child: FutureBuilder(
            future: Matrix.of(context)
                .client
                .getCapabilities()
                .timeout(const Duration(seconds: 10)),
            builder: (context, snapshot) {
              final capabilities = snapshot.data;
              final error = snapshot.error;
              if (error == null && capabilities == null) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  ),
                );
              }
              return Column(
                children: [
                  if (error != null)
                    ListTile(
                      leading: const Icon(
                        Icons.warning_outlined,
                        color: Colors.orange,
                      ),
                      title: Text(
                        error.toLocalizedString(context),
                        style: const TextStyle(color: Colors.orange),
                      ),
                    ),
                  if (capabilities?.mChangePassword?.enabled != false ||
                      error != null) ...[
                    /* TODO using kratos
                    ListTile(
                      leading: const Icon(Icons.key_outlined),
                      trailing: error != null
                          ? null
                          : const Icon(Icons.chevron_right_outlined),
                      title: Text(
                        L10n.of(context)!.changePassword,
                        style: TextStyle(
                          decoration:
                              error == null ? null : TextDecoration.lineThrough,
                        ),
                      ),
                      onTap: error != null
                          ? null
                          : () =>
                              context.go('/rooms/settings/security/password'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.mail_outlined),
                      trailing: error != null
                          ? null
                          : const Icon(Icons.chevron_right_outlined),
                      title: Text(
                        L10n.of(context)!.passwordRecovery,
                        style: TextStyle(
                          decoration:
                              error == null ? null : TextDecoration.lineThrough,
                        ),
                      ),
                      onTap: error != null
                          ? null
                          : () => context.go('/rooms/settings/security/3pid'),
                    ),
                    */
                  ],
                  ListTile(
                    title: Text(
                      L10n.of(context)!.privacy,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SettingsSwitchListTile.adaptive(
                    title: L10n.of(context)!.sendTypingNotifications,
                    subtitle:
                        L10n.of(context)!.sendTypingNotificationsDescription,
                    onChanged: (b) => AppConfig.sendTypingNotifications = b,
                    storeKey: SettingKeys.sendTypingNotifications,
                    defaultValue: AppConfig.sendTypingNotifications,
                  ),
                  SettingsSwitchListTile.adaptive(
                    title: L10n.of(context)!.sendReadReceipts,
                    subtitle: L10n.of(context)!.sendReadReceiptsDescription,
                    onChanged: (b) => AppConfig.sendPublicReadReceipts = b,
                    storeKey: SettingKeys.sendPublicReadReceipts,
                    defaultValue: AppConfig.sendPublicReadReceipts,
                  ),
                  ListTile(
                    trailing: const Icon(Icons.chevron_right_outlined),
                    title: Text(L10n.of(context)!.blockedUsers),
                    subtitle: Text(
                      L10n.of(context)!.thereAreCountUsersBlocked(
                        Matrix.of(context).client.ignoredUsers.length,
                      ),
                    ),
                    onTap: () =>
                        context.go('/rooms/settings/security/ignorelist'),
                  ),
                  if (Matrix.of(context).client.encryption != null) ...{
                    if (PlatformInfos.isMobile)
                      ListTile(
                        trailing: const Icon(Icons.chevron_right_outlined),
                        title: Text(L10n.of(context)!.appLock),
                        subtitle: Text(L10n.of(context)!.appLockDescription),
                        onTap: controller.setAppLockAction,
                      ),
                  },
                  Divider(
                    color: Theme.of(context).dividerColor,
                  ),
                  ListTile(
                    title: Text(
                      L10n.of(context)!.account,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ListTile(
                    title: Text(L10n.of(context)!.yourPublicKey),
                    leading: const Icon(Icons.vpn_key_outlined),
                    subtitle: SelectableText(
                      Matrix.of(context).client.fingerprintKey.beautified,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                  if (capabilities?.mChangePassword?.enabled != false ||
                      error != null)
                    ListTile(
                      leading: const Icon(Icons.password_outlined),
                      trailing: const Icon(Icons.chevron_right_outlined),
                      title: Text(L10n.of(context)!.changePassword),
                      onTap: () =>
                          context.go('/rooms/settings/security/password'),
                    ),
                  ListTile(
                    iconColor: Colors.orange,
                    leading: const Icon(Icons.tap_and_play),
                    title: Text(
                      L10n.of(context)!.dehydrate,
                      style: const TextStyle(color: Colors.orange),
                    ),
                    onTap: controller.dehydrateAction,
                  ),
                  ListTile(
                    iconColor: Colors.red,
                    leading: const Icon(Icons.delete_outlined),
                    title: Text(
                      L10n.of(context)!.deleteAccount,
                      style: const TextStyle(color: Colors.red),
                    ),
                    onTap: controller.deleteAccountAction,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
