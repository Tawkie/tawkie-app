import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:tawkie/config/app_config.dart';
import 'package:tawkie/pages/add_bridge/add_bridge_body.dart';
import 'package:tawkie/pages/add_bridge/qr_code_connect.dart';
import 'package:tawkie/pages/add_bridge/service/hostname.dart';
import 'package:tawkie/pages/add_bridge/service/reg_exp_pattern.dart';
import 'package:tawkie/pages/add_bridge/show_bottom_sheet.dart';
import 'package:tawkie/pages/add_bridge/success_message.dart';
import 'package:tawkie/pages/add_bridge/web_view_connection.dart';
import 'package:tawkie/utils/bridge_utils.dart';
import 'package:tawkie/utils/platform_infos.dart';
import 'package:tawkie/widgets/matrix.dart';
import 'package:tawkie/widgets/notifier_state.dart';
import 'package:webview_cookie_manager/webview_cookie_manager.dart';

import 'bot_chat_list.dart';
import 'delete_conversation_dialog.dart';
import 'error_message_dialog.dart';
import 'login_form.dart';
import 'model/social_network.dart';

enum ConnectionStatus {
  connected,
  notConnected,
  error,
  connecting,
  transientDisconnect,
  badCredentials,
  unknownError,


}

enum ConnectionError {
  roomNotFound,
  directChatCreationFailed,
  messageSendingFailed,
  timeout,
  unknown,
  badCredentials,
}

class AddBridge extends StatefulWidget {
  const AddBridge({super.key});

  @override
  BotController createState() => BotController();
}

class BotController extends State<AddBridge> {
  bool loading = true;
  bool continueProcess = true;

  late Client client;
  late String hostname;
  late Map<String, String> headers;

  late Dio dio;

  List<SocialNetwork> socialNetworks = SocialNetworkManager.socialNetworks;

  // Map to store StreamSubscriptions for each social network
  final Map<String, StreamSubscription> _pingSubscriptions = {};

  @override
  void initState() {
    super.initState();
    matrixInit();
    initializeHeaders();
    initializeDio();
    handleRefresh();
  }

  @override
  void dispose() {
    // Cancel all listeners when the widget is destroyed
    _pingSubscriptions.forEach((key, subscription) => subscription.cancel());
    continueProcess = false;
    super.dispose();
  }

  void initializeDio() {
    final serverUrl = AppConfig.server.startsWith(':')
        ? AppConfig.server.substring(1)
        : AppConfig.server;

    dio = Dio(BaseOptions(
      baseUrl: 'https://matrix.$serverUrl/_matrix/',
      headers: headers,
    ));
  }

  /// Initialize Matrix client and extract hostname
  void matrixInit() {
    client = Matrix.of(context).client;

    final String fullUrl = client.homeserver!.host;
    hostname = extractHostName(fullUrl);
  }

  void initializeHeaders() {
    headers = {
      'Authorization': 'Bearer ${client.accessToken}',
      'Content-Type': 'application/json',
    };
  }

  /// Wait for Matrix synchronization
  Future<void> waitForMatrixSync() async {
    await client.sync(
      fullState: true,
      setPresence: PresenceType.online,
    );
  }

  /// Stop the ongoing process
  void stopProcess() {
    continueProcess = false;
  }

  List<String> getBotIds() {
    return SocialNetworkManager.socialNetworks
        .map((sn) => sn.chatBot + hostname)
        .toList();
  }

  List<String> get botIds => getBotIds();

  void showPopupMenu(BuildContext context) async {
    await showMenu(
      context: context,
      position: const RelativeRect.fromLTRB(100, 80, 0, 100),
      items: [
        PopupMenuItem(
          value: 'see_bots',
          child: Text(L10n.of(context)!.seeBotsRoom),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BotChatListPage(botUserIds: botIds),
              ),
            );
          },
        ),
      ],
      elevation: 8.0,
    );
  }

  Future<String?> _getOrCreateDirectChat(String botUserId) async {
    try {
      await waitForMatrixSync(); // Make sure all conversations are loaded
      final client = Matrix.of(context).client;
      String? directChat;

      // Check whether a direct conversation already exists for this bot
      final room = client.rooms.firstWhereOrNull(
        (room) => botUserId == room.directChatMatrixID,
      );

      if (room != null) {
        directChat = room.id;
      } else {
        // If the conversation doesn't exist, create a new one
        directChat = await client.startDirectChat(
          botUserId,
          preset: CreateRoomPreset.privateChat,
        );
        final roomBot = client.getRoomById(directChat);
        if (roomBot != null) {
          await waitForBotFirstMessage(roomBot);
        }
      }

      return directChat;
    } catch (e) {
      Logs().i('Error getting or starting direct chat: $e');
      return null;
    }
  }

  /// Wait for the first message from the bot (when the conversation created)
  Future<void> waitForBotFirstMessage(Room room) async {
    const int maxWaitTime = 20;
    int waitedTime = 0;

    while (waitedTime < maxWaitTime) {
      await Future.delayed(const Duration(seconds: 1));
      final Event? lastEvent = room.lastEvent;

      if (lastEvent != null && lastEvent.senderId != client.userID) {
        // Received a message from the bot
        // Wait an additional 2 seconds to ensure other messages are received
        await Future.delayed(const Duration(seconds: 5));
        return;
      }

      waitedTime++;
    }

    // If no message received from the bot within the max wait time
    Logs().i('No message received from bot within the wait time');
  }

  Future<void> pingBridgeAPI(SocialNetwork network) async {
    final userId = client.userID;

    final response = await dio.get('${network.apiPath}/_matrix/provision/v3/whoami?user_id=$userId');

    final status = interpretBridgeResponse(response);

    switch (status) {
      case ConnectionStatus.connecting:
        if (kDebugMode) {
          print('Connecting to ${network.name}...');
        }
        break;
      case ConnectionStatus.connected:
        setState(() => network.updateConnectionResult(true));
        break;
      case ConnectionStatus.transientDisconnect:
        if (kDebugMode) {
          print('Transient disconnect detected for ${network.name}.');
        }
        break;
      case ConnectionStatus.badCredentials:
        _handleError(network, ConnectionError.badCredentials);
        break;
      case ConnectionStatus.unknownError:
        _handleError(network, ConnectionError.unknown);
        break;
      case ConnectionStatus.notConnected:
        setState(() => network.updateConnectionResult(false));
        break;
      case ConnectionStatus.error:
        _handleError(
            network,
            ConnectionError.unknown,
            null,
            'An unexpected error occurred while communicating with the server. Please check your connection or try again later.',
        );
        break;
    }
  }

  ConnectionStatus interpretBridgeResponse(Response response) {
    try {
      final responseJson = response.data;
      final networkName = responseJson['network']?['displayname'];

      if (networkName != null) {
        final logins = responseJson['logins'];

        if (logins != null && logins.isNotEmpty) {
          final stateEvent = logins[0]['state']?['state_event'];

          switch (stateEvent) {
            case 'CONNECTING':
              return ConnectionStatus.connecting;
            case 'CONNECTED':
              return ConnectionStatus.connected;
            case 'TRANSIENT_DISCONNECT':
              return ConnectionStatus.transientDisconnect;
            case 'BAD_CREDENTIALS':
              return ConnectionStatus.badCredentials;
            case 'UNKNOWN_ERROR':
              return ConnectionStatus.unknownError;
            default:
              return ConnectionStatus.notConnected;
          }
        } else {
          return ConnectionStatus.notConnected;
        }
      }
    } catch (e) {
      return ConnectionStatus.error;
    }
    return ConnectionStatus.error;
  }

  // Future<void> fetchLoginFlows(SocialNetwork network) async {
  //   final accessToken = client.accessToken;
  //   final userId = client.userID;
  //   final url = '/${network.apiPath}/_matrix/provision/v3/login/flows?user_id=$userId';
  //
  //   try {
  //     final response = await dio.get(
  //       url,
  //       options: Options(
  //         headers: {'Authorization': 'Bearer $accessToken'},
  //       ),
  //     );
  //
  //     if (response.statusCode == 200) {
  //       final responseJson = response.data;
  //       final flows = responseJson['flows'];
  //
  //       if (flows != null) {
  //         if (kDebugMode) {
  //           print('Available login flows for ${network.name}:');
  //         }
  //         for (var flow in flows) {
  //           if (kDebugMode) {
  //             print('Name: ${flow['name']}, Description: ${flow['description']}, ${flow['id']}');
  //           }
  //         }
  //       } else {
  //         _handleError(network, ConnectionError.unknown, "No login flows found.");
  //       }
  //     } else if (response.statusCode == 401) {
  //       _handleError(network, ConnectionError.unknown, "Invalid token for ${network.name}.");
  //     } else {
  //       _handleError(network, ConnectionError.unknown, "Unexpected error: ${response.statusCode}");
  //     }
  //   } catch (error) {
  //     _handleError(network, ConnectionError.unknown, error.toString());
  //   }
  // }

  /// Ping a social network to check connection status
  Future<void> pingSocialNetwork(SocialNetwork socialNetwork) async {
    final String botUserId = '${socialNetwork.chatBot}$hostname';
    final SocialNetworkEnum? networkEnum =
        getSocialNetworkEnum(socialNetwork.name);

    final RegExpPingPatterns patterns = getPingPatterns(networkEnum!);
    final String? directChat = await _getOrCreateDirectChat(botUserId);

    if (directChat == null) {
      _handleError(socialNetwork, ConnectionError.directChatCreationFailed);
      return;
    }

    final Room? roomBot = client.getRoomById(directChat);
    if (roomBot == null) {
      _handleError(socialNetwork, ConnectionError.roomNotFound);
      return;
    }

    // Reset existing listeners
    _pingSubscriptions[socialNetwork.name]?.cancel();

    // Initialize listener before sending ping
    final Completer<void> completer = Completer<void>();
    final subscription = client.onEvent.stream.listen((eventUpdate) {
      if (eventUpdate.content['sender']?.contains(socialNetwork.chatBot)) {
        _onNewPingMessage(
          roomBot,
          socialNetwork,
          patterns,
          completer,
        );
      }
    });

    // Storing the listener in the map
    _pingSubscriptions[socialNetwork.name] = subscription;

    try {
      final successSendingPing = await _sendPingMessage(roomBot, socialNetwork);
      if (!successSendingPing) {
        _handleError(socialNetwork, ConnectionError.messageSendingFailed);
        return;
      }

      await Future.delayed(const Duration(seconds: 2));

      // Wait for the ping response
      await _processPingResponse(socialNetwork, completer);
    } catch (e) {
      Logs().v("Error processing ping response: ${e.toString()}");
      _handleError(socialNetwork, ConnectionError.unknown);
    } finally {
      subscription.cancel();
    }
  }

  /// Handle refresh action for social networks
  Future<void> handleRefresh() async {
    setState(() {
      for (final network in socialNetworks) {
        continueProcess = true;
        network.loading = true;
        network.connected = false;
        network.error = false;
      }
    });

    await Future.wait(socialNetworks.where((network) => network.available).map((network) {
      if (network.supportsBridgev2Apis) {
        // Calling up the ping API function for Messenger
        return pingBridgeAPI(network);
      } else {
        // Continue with existing function for other networks
        return pingSocialNetwork(network);
      }
    }));
  }

  /// Process the ping response from a social network
  Future<void> _processPingResponse(
      SocialNetwork socialNetwork, Completer<void> completer) async {
    final timer = Timer(const Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        completer.completeError(ConnectionError.timeout);
      }
    });

    try {
      await completer.future;
    } catch (e) {
      Logs().v(
          "Timeout reached, setting result to 'error to ${socialNetwork.name}'");
      _handleError(socialNetwork, ConnectionError.timeout);
    } finally {
      timer.cancel();
    }
  }

  Future<void> _onNewPingMessage(
    Room roomBot,
    SocialNetwork socialNetwork,
    RegExpPingPatterns patterns,
    Completer<void> completer,
  ) async {
    if (kDebugMode) {
      print("social network: $socialNetwork");
    }

    final lastEvent = roomBot.lastEvent?.text;

    if (kDebugMode) {
      print("lastest message: $lastEvent");
    }

    if (isOnline(patterns.onlineMatch, lastEvent!)) {
      Logs().v("You're logged to ${socialNetwork.name}");
      _updateNetworkStatus(socialNetwork, true, false);
      if (!completer.isCompleted) {
        completer.complete();
      }
    } else if (isNotLogged(
        patterns.notLoggedMatch, lastEvent, patterns.notLoggedAnymoreMatch)) {
      Logs().v('Not connected to ${socialNetwork.name}');
      _updateNetworkStatus(socialNetwork, false, false);
      if (!completer.isCompleted) {
        completer.complete();
      }
    } else if (shouldReconnect(patterns.mQTTNotMatch, lastEvent)) {
      roomBot.sendTextEvent("reconnect");
    } else  // For Instagram/Facebook Messenger cases
    if (socialNetwork.name == "Instagram" || socialNetwork.name == "Facebook Messenger") {
      if (hasUserInfoPattern(lastEvent)){
        _updateNetworkStatus(socialNetwork, true, false);
      }else{
        Logs().v('Not connected to ${socialNetwork.name}');
        _updateNetworkStatus(socialNetwork, false, false);
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }

  /// Send a ping message to the bot
  Future<bool> _sendPingMessage(
      Room roomBot, SocialNetwork socialNetwork) async {
    try {
      switch (socialNetwork.name) {
        case "Instagram":
          await roomBot.sendTextEvent("!ig list-logins");
          break;
        case "Facebook Messenger":
          await roomBot.sendTextEvent("!fb list-logins");
          break;
        case "Linkedin":
          await roomBot.sendTextEvent("whoami");
          break;
        default:
          await roomBot.sendTextEvent("ping");
      }
      return true;
    } on MatrixException catch (exception) {
      final messageError = exception.errorMessage;
      showCatchErrorDialog(context, messageError);
      return false;
    }
  }

  /// Update the status of a social network
  void _updateNetworkStatus(
      SocialNetwork socialNetwork, bool isConnected, bool isError) {
    setState(() {
      socialNetwork.connected = isConnected;
      socialNetwork.loading = false;
      socialNetwork.error = isError;
    });
  }

  /// Error handling method with a default error type
  void _handleError(SocialNetwork socialNetwork,
      [ConnectionError error = ConnectionError.unknown, String? lastMessage, String? customMessage]) {
    setState(() {
      socialNetwork.setError(true);
    });

    String errorMessage;

    switch (error) {
      case ConnectionError.roomNotFound:
        errorMessage = 'Room not found';
        break;
      case ConnectionError.directChatCreationFailed:
        errorMessage = 'Failed to create direct chat';
        break;
      case ConnectionError.messageSendingFailed:
        errorMessage = 'Failed to send message';
        break;
      case ConnectionError.timeout:
        errorMessage = 'Operation timed out';
        break;
      case ConnectionError.badCredentials:
        errorMessage = 'Invalid credentials provided';
        break;
      case ConnectionError.unknown:
      default:
        errorMessage = customMessage ?? 'An unknown error occurred';
        break;
    }

    Logs().v(errorMessage);

    if (lastMessage != null) {
      showCatchErrorDialog(
          context, "${L10n.of(context)!.errorSendUsProblem} $lastMessage");
    } else {
      showCatchErrorDialog(context,
          "${L10n.of(context)!.errorConnectionText}.\n\n${L10n.of(context)!.errorSendUsProblem} $errorMessage");
    }
  }

  /// Disconnect from a social network
  Future<void> disconnectBridgeApi(
      BuildContext context,
      SocialNetwork network,
      ConnectionStateModel connectionState,
      {String loginId = 'all'}
      ) async {
    final userId = client.userID;
    final logoutUrl = '/${network.apiPath}/_matrix/provision/v3/logout/$loginId?user_id=$userId';

    Future.microtask(() {
      connectionState.updateConnectionTitle(L10n.of(context)!.loadingDisconnectionDemand);
    });

    try {
      final response = await dio.post(logoutUrl);

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print("Successful disconnection for ${network.name}");
        }
        setState(() => network.updateConnectionResult(false));
      } else {
        _handleError(network, ConnectionError.unknown, "Disconnection error: ${response.statusCode}");
      }
    } catch (error) {
      _handleError(network, ConnectionError.unknown, "Disconnection error: $error");
    } finally {
      Future.microtask(() {
        connectionState.reset();
      });
    }
  }

  Future<void> disconnectFromNetwork(BuildContext context,
      SocialNetwork network, ConnectionStateModel connectionState) async {
    final String botUserId = '${network.chatBot}$hostname';
    final SocialNetworkEnum? networkEnum = getSocialNetworkEnum(network.name);

    Future.microtask(() {
      connectionState
          .updateConnectionTitle(L10n.of(context)!.loadingDisconnectionDemand);
    });

    final Map<String, RegExp> patterns = getLogoutNetworkPatterns(networkEnum!);
    final String eventName = _getEventName(network.name);

    final String? directChat = await _getOrCreateDirectChat(botUserId);
    if (directChat == null) {
      throw ConnectionError.directChatCreationFailed;
    }

    final Room? roomBot = client.getRoomById(directChat);
    if (roomBot == null) {
      throw ConnectionError.roomNotFound;
    }

    await _sendLogoutEvent(roomBot, eventName);

    await _waitForDisconnection(
        context, network, connectionState, directChat, patterns);
  }

  /// Get the event name for logout based on the social network
  String _getEventName(String networkName) {
    switch (networkName) {
      case "Instagram":
        return '!ig logout';
      case "Facebook Messenger":
        return '!fb logout';
      default:
        return 'logout';

    }
  }

  /// Send a logout event to the bot
  Future<bool> _sendLogoutEvent(Room roomBot, String eventName) async {
    try {
      await roomBot.sendTextEvent(eventName);
      await Future.delayed(const Duration(seconds: 3));
      return true;
    } catch (e) {
      Logs().v('Error sending text event: $e');
      return false;
    }
  }

  /// Wait for the disconnection process to complete
  Future<void> _waitForDisconnection(
      BuildContext context,
      SocialNetwork network,
      ConnectionStateModel connectionState,
      String directChat,
      Map<String, RegExp> patterns) async {
    const int maxIterations = 5;
    int currentIteration = 0;

    bool sentLogoutMessage = false;  // To check if we've already sent the logout message (For Meta)

    while (currentIteration < maxIterations) {
      try {
        final GetRoomEventsResponse response =
        await client.getRoomEvents(directChat, Direction.b, limit: 1);
        final List<MatrixEvent> latestMessages = response.chunk ?? [];

        if (latestMessages.isNotEmpty) {
          final MatrixEvent latestEvent = latestMessages.first;
          final String latestMessage = latestEvent.content['body'].toString() ?? '';
          final String sender = latestEvent.senderId;
          final String botUserId = '${network.chatBot}$hostname';

          if (sender == botUserId) {
            // Check for user ID pattern in logout message for Instagram or Facebook Messenger
            if (!sentLogoutMessage && (network.name == "Instagram" || network.name == "Facebook Messenger")) {
              final userId = extractUserId(latestMessage);
              if (userId != null) {
                final room = client.getRoomById(directChat);
                switch (network.name) {
                  case "Instagram":
                    room?.sendTextEvent("!ig logout $userId");
                    break;
                  case "Facebook Messenger":
                    room?.sendTextEvent("!fb logout $userId");
                    break;
                }
                Logs().v("Sent logout message for user $userId on ${network.name}");
                sentLogoutMessage = true;  // Set the flag to prevent sending the message again
                await Future.delayed(const Duration(seconds: 3));
                continue;  // Skip the rest of the loop to re-check the connection status
              }
            }

            print("latestMessage: $latestMessage");

            // Check if still connected
            if (isStillConnected(latestMessage, patterns)) {
              Logs().v("You're still connected to ${network.name}");
              setState(() => network.updateConnectionResult(true));
              return;
            } else {
              Logs().v("You're disconnected from ${network.name}");
              connectionState.updateConnectionTitle(L10n.of(context)!.loadingDisconnectionSuccess);
              connectionState.updateLoading(false);
              await Future.delayed(const Duration(seconds: 1));
              connectionState.reset();
              setState(() => network.updateConnectionResult(false));
              return;
            }
          }

          await Future.delayed(const Duration(seconds: 3));
        }
      } catch (e) {
        Logs().v('Error in matrix related async function call: $e');
        throw ConnectionError.unknown;
      }
      currentIteration++;
    }

    connectionState.reset();
    throw ConnectionError.timeout;
  }

  /// Delete a conversation with the bot
  Future<void> deleteConversation(BuildContext context, String chatBot,
      ConnectionStateModel connectionState) async {
    final String botUserId = "$chatBot$hostname";

    Future.microtask(() {
      connectionState
          .updateConnectionTitle(L10n.of(context)!.loadingDeleteRoom);
    });

    try {
      final roomId = client.getDirectChatFromUserId(botUserId);
      final room = client.getRoomById(roomId!);

      if (room != null) {
        await room.leave();
        Logs().v('Conversation deleted successfully');

        Future.microtask(() {
          connectionState.updateConnectionTitle(
              L10n.of(context)!.loadingDeleteRoomSuccess);
          connectionState.updateLoading(false);
        });

        await Future.delayed(const Duration(seconds: 1));
      } else {
        Logs().v('Room not found');
      }
    } catch (e) {
      Logs().v('Error deleting conversation: $e');
    }

    Future.microtask(() {
      connectionState.reset();
    });
  }

  /// Handle social network action based on its current status
  void handleSocialNetworkAction(SocialNetwork network) async {
    if (!network.loading) {
      if (!network.connected && !network.error) {
        await processSocialNetworkAuthentication(context, network);
      } else if (network.connected && !network.error) {
        try {
          await handleDisconnection(context, network);
        } catch (error) {
          if (error is ConnectionError) {
            _handleError(network, error);
          } else {
            _handleError(network, ConnectionError.unknown);
          }
        }
      }

      if (network.error && !network.connected) {
        setState(() {
          network.loading = true;
        });

        try {
          await pingSocialNetwork(network);
        } catch (error) {
          if (error is ConnectionError) {
            _handleError(network, error);
          } else {
            _handleError(network, ConnectionError.unknown);
          }
        }
      }
    }
  }

  /// Handle connection to a social network
  Future<void> processSocialNetworkAuthentication(
      BuildContext context, SocialNetwork network) async {
    final connectionState =
    Provider.of<ConnectionStateModel>(context, listen: false);

    switch (network.name) {
      case "WhatsApp":
        await startBridgeLogin(context, connectionState, network);
        break;
      case "Instagram":
      case "Facebook Messenger":
      case "Linkedin":
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WebViewConnection(
              controller: this,
              network: network,
              onConnectionResult: (bool success) {
                if (success) {
                  network.updateConnectionResult(true);
                  showCatchSuccessDialog(context,
                      "${L10n.of(context)!.youAreConnectedTo} ${network.name}");
                } else {
                  showCatchErrorDialog(context,
                      "${L10n.of(context)!.errToConnect} ${network.name}");
                }
              },
            ),
          ),
        );
        break;
    }
  }

  /// Handle disconnection from a social network
  Future<void> handleDisconnection(
      BuildContext context, SocialNetwork network) async {
    final bool success = await showBottomSheetBridge(context, network, this);

    if (success && !network.supportsBridgev2Apis) {
      await deleteConversationDialog(context, network, this);
    }
  }

  // 📌 ***********************************************************************
  // 📌 ************************** Messenger & Instagram **************************
  // 📌 ***********************************************************************

  Future<void> handleStepResponse(Response response, SocialNetwork network, String loginId) async {
    if (response.statusCode == 200) {
      final stepData = response.data;

      if (stepData['type'] == 'complete') {
        setState(() => network.updateConnectionResult(true));
        if (kDebugMode) print("Login successful for ${network.name}");
      } else if (stepData['type'] == 'display_and_wait' && stepData['display_and_wait']?['type'] == 'code') {
        final pairingCode = stepData['display_and_wait']['data'];
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QRCodeConnectPage(
              qrCode: null,
              code: pairingCode,
              stepData: stepData,
              botConnection: this,
              socialNetwork: network,
            ),
          ),
        );

      } else {
        network.setError(true);
        _handleError(network, ConnectionError.unknown, 'Unexpected response type: ${stepData['type']}');
      }
    } else {
      network.setError(true);
      _handleError(network, ConnectionError.unknown, 'Error submitting step: ${response.statusCode}');
    }
  }

  Future<void> loginWithCookies(SocialNetwork network, dynamic startData) async {
    final userId = client.userID;
    final loginId = startData['login_id'];
    final stepType = startData['type'];
    final stepId = startData['step_id'];
    final cookieManager = WebviewCookieManager();

    if (stepType == 'user_input' || stepType == 'cookies') {
      // Retrieve cookies
      final gotCookies = await cookieManager.getCookies(network.urlRedirect);
      final formattedCookieString = formatCookiesToJsonApi(gotCookies);

      // Submit cookies to the login process step
      final stepUrl = '/${network.apiPath}/_matrix/provision/v3/login/step/$loginId/$stepId/cookies?user_id=$userId';

      final stepResponse = await dio.post(stepUrl, data: formattedCookieString);

      await handleStepResponse(stepResponse, network, loginId);
    } else {
      network.setError(true);
      _handleError(network, ConnectionError.unknown, 'Unexpected step type: $stepType');
    }
  }

  Future<void> loginWithQRCode(SocialNetwork network, dynamic startData) async {
    final data = startData['display_and_wait']['data'];
    final stepType = startData['type'];

    if (stepType == 'display_and_wait') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QRCodeConnectPage(
            qrCode: data,
            code: null,
            stepData: startData,
            botConnection: this,
            socialNetwork: network,
          ),
        ),
      );

    } else {
      network.setError(true);
      _handleError(network, ConnectionError.unknown, 'Unexpected step type: $stepType');
    }
  }

  Future<void> loginWithPhone(SocialNetwork network, dynamic startData) async {
    final userId = client.userID;
    final loginId = startData['login_id'];
    final stepType = startData['type'];
    final stepId = startData['step_id'];
    final phoneNumber = await showPhoneNumberDialog(context, network);

    if (stepType == 'user_input') {
      final stepUrl = '/${network.apiPath}/_matrix/provision/v3/login/step/$loginId/$stepId/user_input?user_id=$userId';

      final stepResponse = await dio.post(
        stepUrl,
        data: jsonEncode({
          "phone_number": phoneNumber,
        }),
      );

      await handleStepResponse(stepResponse, network, loginId);

    } else {
      network.setError(true);
      _handleError(network, ConnectionError.unknown, 'Unexpected step type: $stepType');
    }
  }

  Future<String?> showPhoneNumberDialog(BuildContext context, SocialNetwork network) async {
    final TextEditingController controller = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final Completer<bool> completer = Completer<bool>();

    return showDialog<String?>(
      context: context,
      builder: (BuildContext context) {
        return Center(
          child: SingleChildScrollView(
            child: AlertDialog(
              title: Text(
                "${L10n.of(context)!.connectYourSocialAccount} ${network.name}",
                style: const TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: WhatsAppLoginForm(
                formKey: formKey,
                controller: controller,
                completerCallback: completer.complete,
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    completer.complete(false);
                  },
                  child: Text(L10n.of(context)!.cancel),
                ),
                TextButton(
                  onPressed: () async {
                    if (controller.text.isNotEmpty) {
                      Navigator.of(context).pop(controller.text);
                    }
                  },
                  child: Text(
                    L10n.of(context)!.login,
                    style: const TextStyle(
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> checkLoginStatus(SocialNetwork network, dynamic stepData) async {
    final userId = client.userID;
    final loginId = stepData['login_id'];
    final stepId = stepData['step_id'];
    final checkStatusUrl = '/${network.apiPath}/_matrix/provision/v3/login/step/$loginId/$stepId/display_and_wait?user_id=$userId';

    try {
      final statusResponse = await dio.post(checkStatusUrl);

      if (statusResponse.statusCode == 200) {
        final statusData = statusResponse.data;

        if (statusData['type'] == 'complete') {
          setState(() => network.updateConnectionResult(true));
          if (kDebugMode) {
            print("Login successful for ${network.name}");
          }
          Navigator.of(context).pop();
        }
      } else {
        _handleError(network, ConnectionError.unknown, 'Error checking login status: ${statusResponse.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print("error: $e");
      }

      if (e is DioException && e.response?.statusCode == 500){
        // Show timeout dialog
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(
                L10n.of(context)!.errElapsedTime,
              ),
              content: Text(
                L10n.of(context)!.errExpiredSession,
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    L10n.of(context)!.ok,
                  ),
                ),
              ],
            );
          },
        );
      }
    }
  }

  Future<void> startBridgeLogin(
      BuildContext context,
      ConnectionStateModel connectionState,
      SocialNetwork network,
      ) async {
    final flowID = network.flowId;
    final userId = client.userID;

    // Step 1: Start the login process
    final loginStartUrl = '/${network.apiPath}/_matrix/provision/v3/login/start/$flowID?user_id=$userId';

    try {
      // Initiate the login process
      final startResponse = await dio.post(loginStartUrl);

      if (startResponse.statusCode == 200) {
        final startData = startResponse.data;
        final stepType = startData['type'];

        // Update state if there's a display message
        if (stepType == 'display_and_wait') {
          connectionState.updateConnectionTitle(
            startData['instructions'] ?? 'Waiting for user action...',
          );
        }

        // Step 2: For differents methods
        switch (network.name) {
          case "WhatsApp":
            if(PlatformInfos.isMobile){
              await loginWithPhone(network, startData);
            }else{
              await loginWithQRCode(network, startData);
            }
            break;

          case "Facebook Messenger":
          case "Instagram":
            await loginWithCookies(network, startData);
            break;

          default:
            network.setError(true);
            if (kDebugMode) {
              print('Unsupported network for login: ${network.name}');
            }
            break;
        }
      } else {
        network.setError(true);
        _handleError(network, ConnectionError.unknown, 'Login initiation failed with status: ${startResponse.statusCode}');
      }
    } catch (error) {
      network.setError(true);
      _handleError(network, ConnectionError.unknown, error.toString());
    } finally {
      Future.microtask(() {
        connectionState.reset();
      });
    }
  }

  /// Create a bridge for Messenger & Instagram using cookies
  Future<void> createBridgeMeta(
      BuildContext context,
      WebviewCookieManager cookieManager,
      ConnectionStateModel connectionState,
      SocialNetwork network) async {
    final String botUserId = '${network.chatBot}$hostname';

    Future.microtask(() {
      connectionState
          .updateConnectionTitle(L10n.of(context)!.loadingDemandToConnect);
    });

    final gotCookies = await cookieManager.getCookies(network.urlRedirect);

    if (kDebugMode) {
      print("cookies: $gotCookies");
    }

    final formattedCookieString =
        formatCookiesToJsonString(gotCookies, network);

    if (kDebugMode) {
      print("formattedCookie: $formattedCookieString");
    }

    final RegExp successMatch = LoginRegex.facebookSuccessMatch;
    final RegExp alreadyConnected = LoginRegex.facebookAlreadyConnectedMatch;
    final RegExp pasteCookie = LoginRegex.loginUrlMetaMatch;

    final String? directChat = await _getOrCreateDirectChat(botUserId);
    if (directChat == null) {
      _handleError(network, ConnectionError.directChatCreationFailed);
      return;
    }

    final Room? roomBot = client.getRoomById(directChat);
    if (roomBot == null) {
      _handleError(network, ConnectionError.roomNotFound);
      return;
    }

    final completer = Completer<String>();
    final timer = Timer(const Duration(seconds: 20), () {
      if (!completer.isCompleted) {
        completer.completeError(ConnectionError.timeout);
      }
    });

    String? lastMessage;
    StreamSubscription? subscription;
    subscription = client.onEvent.stream.listen((eventUpdate) {
      if (eventUpdate.content['sender']?.contains(network.chatBot)) {
        lastMessage = _onNewMessage(
          roomBot,
          botUserId,
          formattedCookieString,
          pasteCookie,
          successMatch,
          alreadyConnected,
          connectionState,
          network,
          completer,
        );
      }
    });

    try {
      switch (network.name) {
        case "Instagram":
          await roomBot.sendTextEvent("!ig login");
          break;
        case "Facebook Messenger":
          await roomBot.sendTextEvent("!fb login");
          break;
      }

      Future.microtask(() {
        connectionState
            .updateConnectionTitle(L10n.of(context)!.loadingVerification);
      });

      final result = await completer.future;
      Logs().v("Result: $result");
    } catch (e) {
      Logs().v(
          "Maximum iterations reached, setting result to 'error to ${network.name}'");
      _handleError(
          network, ConnectionError.unknown, lastMessage ?? e.toString());
    } finally {
      timer.cancel();
      await subscription
          .cancel(); // Cancel the subscription to avoid memory leaks
      Future.microtask(() {
        connectionState.reset();
      });
    }
  }

  bool cookiesSent = false;

  String? _onNewMessage(
      Room roomBot,
      String botUserId,
      String formattedCookieString,
      RegExp pasteCookie,
      RegExp successMatch,
      RegExp alreadyConnected,
      ConnectionStateModel connectionState,
      SocialNetwork network,
      Completer<void> completer) {
    final lastEvent = roomBot.lastEvent;
    final lastMessage = lastEvent?.text;

    if (lastEvent != null && lastEvent.senderId == botUserId) {
      if (pasteCookie.hasMatch(lastMessage!) && !cookiesSent) {
        switch (network.name) {
          case "Instagram":
            roomBot.sendTextEvent("!ig $formattedCookieString");
            break;
          case "Facebook Messenger":
            roomBot.sendTextEvent("!fb $formattedCookieString");
            break;
        }
        cookiesSent = true;
      } else if (alreadyConnected.hasMatch(lastMessage)) {
        Logs().v("Already Connected to ${network.name}");

        setState(() => network.updateConnectionResult(true));
        connectionState.updateConnectionTitle(L10n.of(context)!.connected);
        connectionState.updateLoading(false);
        connectionState.reset();

        if (!completer.isCompleted) {
          completer.complete(lastMessage);
        }
      } else if (successMatch.hasMatch(lastMessage)) {
        Logs().v("You're logged to ${network.name}");

        cookiesSent = false;

        setState(() => network.updateConnectionResult(true));

        connectionState.updateConnectionTitle(L10n.of(context)!.connected);
        connectionState.updateLoading(false);
        connectionState.reset();

        if (!completer.isCompleted) {
          completer.complete(lastMessage);
        }
      }
    }
    return lastMessage;
  }

  // 📌 ***********************************************************************
  // 📌 ************************** LinkedIn **************************
  // 📌 ***********************************************************************

  /// Create a bridge for LinkedIn using cookies
  Future<void> createBridgeLinkedin(
      BuildContext context,
      WebviewCookieManager cookieManager,
      ConnectionStateModel connectionState,
      SocialNetwork network) async {
    final String botUserId = '${network.chatBot}$hostname';

    Future.microtask(() {
      connectionState
          .updateConnectionTitle(L10n.of(context)!.loadingDemandToConnect);
    });

    final gotCookies = await cookieManager.getCookies(network.urlRedirect);

    if (kDebugMode) {
      print("cookies: $gotCookies");
    }

    final formattedCookieString =
        formatCookiesToJsonString(gotCookies, network);

    if (kDebugMode) {
      print("formatCookies: $formatCookiesToJsonString");
    }

    final RegExp successMatch = LoginRegex.linkedinSuccessMatch;
    final RegExp alreadySuccessMatch = LoginRegex.linkedinAlreadySuccessMatch;

    final String? directChat = await _getOrCreateDirectChat(botUserId);
    if (directChat == null) {
      _handleError(network, ConnectionError.directChatCreationFailed);
      return;
    }

    final Room? roomBot = client.getRoomById(directChat);
    if (roomBot == null) {
      _handleError(network, ConnectionError.roomNotFound);
      return;
    }

    final completer = Completer<String>();
    final timer = Timer(const Duration(seconds: 20), () {
      if (!completer.isCompleted) {
        completer.completeError(ConnectionError.timeout);
      }
    });

    String? lastMessage;
    StreamSubscription? subscription;
    subscription = client.onEvent.stream.listen((eventUpdate) {
      if (eventUpdate.content['sender']?.contains(network.chatBot)) {
        lastMessage = _onLinkedInMessage(
          roomBot,
          botUserId,
          successMatch,
          alreadySuccessMatch,
          connectionState,
          network,
          completer,
        );
      }
    });

    try {
      await roomBot.sendTextEvent("login $formattedCookieString");

      Future.microtask(() {
        connectionState
            .updateConnectionTitle(L10n.of(context)!.loadingVerification);
      });

      final result = await completer.future;
      Logs().v("Result: $result");
    } catch (e) {
      Logs().v(
          "Maximum iterations reached, setting result to 'error to ${network.name}'");
      _handleError(
          network, ConnectionError.unknown, lastMessage ?? e.toString());
    } finally {
      timer.cancel();
      await subscription
          .cancel(); // Cancel the subscription to avoid memory leaks
      Future.microtask(() {
        connectionState.reset();
      });
    }
  }

  String? _onLinkedInMessage(
      Room roomBot,
      String botUserId,
      RegExp successMatch,
      RegExp alreadySuccessMatch,
      ConnectionStateModel connectionState,
      SocialNetwork network,
      Completer<String> completer) {
    final lastEvent = roomBot.lastEvent;
    final lastMessage = lastEvent?.text;

    final senderId = lastEvent?.senderId;
    if (lastEvent != null && senderId == botUserId) {
      if (successMatch.hasMatch(lastMessage!) ||
          alreadySuccessMatch.hasMatch(lastMessage)) {
        Logs().v("You're logged to Linkedin");

        if (!completer.isCompleted) {
          completer.complete(lastMessage);
        }

        Future.microtask(() {
          connectionState.updateConnectionTitle(L10n.of(context)!.connected);
          connectionState.updateLoading(false);
        });

        setState(() => network.updateConnectionResult(true));
      }
    }
    return lastMessage;
  }

  @override
  Widget build(BuildContext context) => AddBridgeBody(controller: this);
}
