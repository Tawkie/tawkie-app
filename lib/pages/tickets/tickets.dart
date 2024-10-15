import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:tawkie/config/app_config.dart';
import 'package:tawkie/pages/tickets/tickets_page.dart';
import 'package:tawkie/utils/platform_infos.dart';
import 'package:tawkie/utils/room_utils.dart';
import 'package:tawkie/widgets/matrix.dart';

import 'error_dialog.dart';
import 'model/ticket_model.dart';

class Tickets extends StatefulWidget {
  const Tickets({super.key});

  @override
  TicketsController createState() => TicketsController();
}

class TicketsController extends State<Tickets> {
  String userId = AppConfig.ticketsBotId;
  List<Room> filteredRooms = [];
  List<Ticket> tickets = [];
  List<Ticket> filteredTickets = [];
  bool loading = true;

  bool stopProcess = false;

  @override
  void initState() {
    super.initState();
    _initializeTickets();
  }

  @override
  void dispose() {
    stopProcess = true;
    super.dispose();
  }

  Future<void> _initializeTickets() async {
    await _getRoomsForUser();
    for (var room in filteredRooms) {
      await getTicketsFromRoom(room);
    }

    if (mounted) {
      setState(() {
        loading = false;
        filteredTickets = tickets;
      });
    }
  }

  // Filter tickets by search text
  void filterTickets(String searchText) {
    setState(() {
      if (searchText.isEmpty) {
        filteredTickets = tickets;
      } else {
        filteredTickets = tickets
            .where((ticket) =>
                ticket.content.toLowerCase().contains(searchText.toLowerCase()))
            .toList();
      }
    });
  }

  // Method to recover and filter rooms
  Future<void> _getRoomsForUser() async {
    List<Room> filteredRooms = await getTicketRooms();

    if (mounted) {
      setState(() {
        this.filteredRooms = filteredRooms;
      });
    }

    // For each filtered room, retrieve the tickets
    for (var room in filteredRooms) {
      await getTicketsFromRoom(room);
    }
  }

  Future<void> _checkRoomParticipants(Room room) async {
    // Always check participants' status, even if tickets have already been collected
    List<User> participants = room.getParticipants();

    bool isHonoroitPresent = participants.any((user) => user.id == userId);

    String status = isHonoroitPresent ? 'open' : 'closed';

    // Update this room's ticket status
    for (var ticket in tickets) {
      if (ticket.roomId == room.id) {
        setState(() {
          ticket.status = status;
        });
      }
    }

    if (kDebugMode) {
      print("Room ${room.id} status checked: $status");
    }
  }

  // Function to obtain rooms where a specific user is present
  Future<List<Room>> getTicketRooms() async {
    return getFilteredRooms(
      context,
      key: 'm.room.tawkie.ticket',
    );
  }


  // Function to create a new direct chat with a user (forces creation of a new room)
  Future<String?> createNewDirectChatWithUser(String userId) async {
    try {
      // Create a new room specifically for this user
      String roomId = await Matrix.of(context).client.createRoom(
            isDirect: true,
            invite: [userId],
            preset: CreateRoomPreset.trustedPrivateChat,
          );
      return roomId;
    } catch (e) {
      if (kDebugMode) {
        print("Error when creating a new room with the user $userId: $e");
      }
      showErrorDialog(context);
      return null;
    }
  }

  // Function to send a message to a room
  Future<void> sendMessageToRoom({
    required String roomId,
    required String version,
    required String platform,
    required String userMessage,
  }) async {
    try {
      // Construct the content of the message to be sent
      String messageContent = """
**Version**: $version
**Plateforme**: $platform
**Message de l'utilisateur**: $userMessage
""";

      // Send the message to the specified room
      String txnId = Matrix.of(context).client.generateUniqueTransactionId();
      await Matrix.of(context).client.sendMessage(
        roomId,
        "m.room.message",
        txnId,
        {
          "msgtype": "m.text",
          "body": messageContent,
        },
      );

      final newTicket = Ticket(
          version: version,
          platform: platform,
          content: userMessage,
          date: DateTime.now(),
          roomId: roomId,
          status: "open");

      setState(() {
        tickets.add(newTicket);
      });

      if (kDebugMode) {
        print("Message sent in the room $roomId.");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error sending message to room $roomId: $e");
      }
      showErrorDialog(context);
    }
  }

  // Wait for the bot to accept the conversation before sending a message
  Future<void> waitForBotToJoinRoom(String roomId, String botUserId,
      {Duration timeout = const Duration(seconds: 10)}) async {
    final startTime = DateTime.now();
    bool botJoined = false;

    while (!botJoined) {
      if (DateTime.now().difference(startTime) > timeout) {
        throw Exception(
            "The bot did not join the room within the allotted time.");
      }

      Room? room = Matrix.of(context).client.getRoomById(roomId);
      if (room == null) {
        throw Exception("Room not found : $roomId");
      }

      // Check if the bot is in the list of participants
      List<User> participants = room.getParticipants();
      botJoined = participants.any((user) => user.id == botUserId);

      if (!botJoined) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  Future<void> setTicketMetadata(String roomId) async {
    try {
      await Matrix.of(context).client.setRoomStateWithKey(
        roomId,
        'm.room.tawkie.ticket',
        // Custom event type for tickets
        '', // Status key (can be empty if only one instance)
        {
          'created_at': DateTime.now().toIso8601String(),
        },
      );
      if (kDebugMode) {
        print("Ticket metadata set in room $roomId.");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error setting ticket metadata for room $roomId: $e");
      }
    }
  }

  // Function to open a new ticket
  Future<void> openNewTicket({
    required String userMessage,
  }) async {
    String platform = PlatformInfos.getPlatform();
    String version = await PlatformInfos.getVersion();
    String? roomId = await createNewDirectChatWithUser(userId);

    if (kDebugMode) {
      print('platform: $platform');
      print('version: $version');
    }

    try {
      if (roomId != null) {
        await waitForBotToJoinRoom(roomId, userId);

        await sendMessageToRoom(
          roomId: roomId,
          version: version,
          platform: platform,
          userMessage: userMessage,
        );

        // Marking the room as a ticket
        await setTicketMetadata(roomId);
      }
    } catch (e) {
      if (kDebugMode) {
        print("Impossible to create a new conversation: $e");
      }
    }
  }

  Future<void> getTicketsFromRoom(Room room) async {
    try {
      if (tickets.any((ticket) => ticket.roomId == room.id)) {
        if (kDebugMode) {
          print(
              'Tickets for this room have already been collected: ${room.id}');
        }
        await _checkRoomParticipants(room);
        return;
      }

      String? fromToken;
      bool moreMessagesExist = true;

      // Continue fetching messages until there are no more
      while (moreMessagesExist || !stopProcess) {
        // Fetch a batch of messages
        final eventsResponse = await Matrix.of(context).client.getRoomEvents(
              room.id,
              Direction.b,
              limit: 5,
              from: fromToken, // Pagination token
            );

        if (eventsResponse.chunk.isEmpty) {
          moreMessagesExist = false;
          break; // No more messages to fetch
        }

        // Check number of participants to determine ticket status
        List<User> participants = room.getParticipants();
        String status = (participants.length == 2) ? 'open' : 'closed';

        print("status: ${participants.length}");

        // Process the messages and attempt to extract tickets
        List<Ticket> newTickets = eventsResponse.chunk
            .map((event) {
              Map<String, Object?> content = event.content;

              String? messageBody = content['body'] as String?;
              if (messageBody != null) {
                if (kDebugMode) {
                  print("Text message: $messageBody");
                }
                try {
                  DateTime date = event.originServerTs;

                  // Try to create a ticket from the message
                  return Ticket.fromRoomMessage(messageBody, date, status)
                    ..roomId = room.id;
                } catch (e) {
                  // Handle invalid message formats without stopping the process
                  if (kDebugMode) {
                    print("Error parsing message: $e");
                  }
                  return null; // Ignore invalid messages
                }
              } else {
                if (kDebugMode) {
                  print("No text found in the message");
                }
                return null;
              }
            })
            .where((ticket) => ticket != null) // Filter out null tickets
            .cast<Ticket>()
            .toList();

        // Add new tickets to the list
        if (mounted) {
          setState(() {
            tickets.addAll(newTickets);
          });
        }

        // Update the pagination token to fetch older messages in the next iteration
        fromToken = eventsResponse.end;

        // If the end token is null, there are no more messages to fetch
        if (fromToken == null) {
          moreMessagesExist = false;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error retrieving events for room ${room.id}: $e');
      }
      showErrorDialog(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    } else {
      return TicketsPage(
        controller: this,
      );
    }
  }
}
