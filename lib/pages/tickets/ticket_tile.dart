import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tawkie/pages/chat/chat.dart';
import 'package:tawkie/widgets/platform_avatar.dart';
import 'package:tawkie/widgets/ticket_status_badge.dart';

class TicketTile extends StatelessWidget {
  final String title;
  final String platForm;
  final DateTime date;
  final String status;
  final String roomId;

  const TicketTile({
    super.key,
    required this.title,
    required this.platForm,
    required this.date,
    required this.status,
    required this.roomId,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDarkMode = brightness == Brightness.dark;

    String formattedDate = DateFormat('dd/MM/yyyy').format(date);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2.0),
      // Space between the tiles
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12), // Rounded corners
        border: Border.all(color: Colors.grey[300]!, width: 1), // Fine border
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            // Shadow color with some transparency
            spreadRadius: 1,
            // Spread the shadow a little
            blurRadius: 5,
            // How blurry the shadow should be
            offset:
            const Offset(0, 3), // Shadow position (horizontal, vertical)
          ),
        ],
      ),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(
              color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
          overflow: TextOverflow.ellipsis, // for ellipsis points
        ),
        subtitle: Row(
          children: [
            PlatformAvatar(platform: platForm),
            const SizedBox(
              width: 5.0,
            ),
            Text(
              platForm,
              style: TextStyle(color: isDarkMode ? Colors.black : Colors.grey),
            )
          ],
        ),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Badge for status
            TicketStatusBadge(status: status),
            const SizedBox(height: 4),
            Text(
              formattedDate,
              style: TextStyle(color: isDarkMode ? Colors.black : Colors.grey),
            ),
          ],
        ),
        onTap: () {
          // Handle tap on a bot conversation
          openChatRoom(roomId, context);
        },
      ),
    );
  }

  // Method to handle chat tap
  void openChatRoom(String roomId, BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          roomId: roomId,
        ),
      ),
    );
  }
}