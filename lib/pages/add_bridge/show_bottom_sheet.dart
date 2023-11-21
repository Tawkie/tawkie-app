import 'dart:async';

import 'package:fluffychat/pages/add_bridge/service/bot_bridge_connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:future_loading_dialog/future_loading_dialog.dart';
import 'error_message_dialog.dart';
import 'model/social_network.dart';

// Disconnect button display
Future<bool> showBottomSheetBridge(
  BuildContext context,
  SocialNetwork network,
  BotBridgeConnection botConnection,
) async {
  final Completer<bool> completer = Completer<bool>();

  showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            title: Text(
              L10n.of(context)!.logout,
              style: const TextStyle(
                color: Colors.red,
              ),
            ),
            onTap: () async {
              try {
                Navigator.of(context).pop();

                String result =
                    ""; // Variable to store the result of the connection

                // To show Loading while executing the function
                await showFutureLoadingDialog(
                  context: context,
                  future: () async {
                    switch (network.name) {
                      case "Instagram":
                        result = await botConnection.disconnectToInstagram();
                        break;
                    // For other networks
                    }
                  },
                );

                if (result == "Not Connected") {

                  completer.complete(
                      true,); // returns true if is not connected

                } else if (result == "error" || result == 'Connected') {
                  completer.complete(
                    false,);
                  // Display a showDialog with an unknown error message
                  showCatchErrorDialog(
                    context,
                    L10n.of(context)!.err_tryAgain,
                  );
                }
              } catch (e) {
                Navigator.of(context).pop();
                print(('Error: $e'));

                //To view other catch-related errors
                showCatchErrorDialog(context, e);
              }

            },
          ),
        ],
      );
    },
  );

  return completer.future;
}
