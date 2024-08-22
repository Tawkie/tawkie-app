import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:tawkie/pages/chat/events/message_content.dart';

class MessageGroupContent extends StatelessWidget {
  final List<Event> events;
  final Color textColor;
  final void Function(Event)? onInfoTab;
  final BorderRadius borderRadius;

  const MessageGroupContent(
    this.events, {
    this.onInfoTab,
    super.key,
    required this.textColor,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    // Separate events into two lists: media and others
    List<Event> mediaEvents = [];
    List<Event> otherEvents = [];

    for (var event in events) {
      if (event.messageType == MessageTypes.Image ||
          event.messageType == MessageTypes.Video) {
        mediaEvents.add(event);
      } else {
        otherEvents.add(event);
      }
    }

    // Combine media first, then other events
    List<Event> sortedEvents = [...mediaEvents, ...otherEvents];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sortedEvents.map((event) {
        return Padding(
          padding: const EdgeInsets.only(top: 3.0),
          child: MessageContent(
            event,
            textColor: textColor,
            borderRadius: borderRadius,
            onInfoTab: onInfoTab,
          ),
        );
      }).toList(),
    );
  }
}
