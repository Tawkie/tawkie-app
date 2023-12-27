import 'package:tawkie/pages/add_bridge/model/social_network.dart';
import 'package:tawkie/pages/add_bridge/service/bot_bridge_connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:future_loading_dialog/future_loading_dialog.dart';

// ShowDialog to offer the user the option of cancelling the conversation with the bot after disconnection
Future<void> deleteConversationDialog(BuildContext context,
    SocialNetwork network, BotBridgeConnection botConnection) async {
  return showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(
          L10n.of(context)!.bridgeBot_deleteConvTitle,
        ),
        content: Text(
          L10n.of(context)!.bridgeBot_deleteConvDescription,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(L10n.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () async {
              // Action to delete the conversation
              await showFutureLoadingDialog(
                context: context,
                title: L10n.of(context)!.loading_deleteRoom,
                future: () async {
                  await botConnection.deleteConversation(network.chatBot);
                },
              );
              Navigator.of(context).pop(); // Close the dialog
            },
            child: Text(
              L10n.of(context)!.delete,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    },
  );
}
