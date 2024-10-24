import 'package:flutter/material.dart';

class TicketStatusBadge extends StatelessWidget {
  final String status;

  const TicketStatusBadge({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    // Change background color based on status
    final Color backgroundColor = status.toLowerCase() == 'open'
        ? Colors.green
        : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
