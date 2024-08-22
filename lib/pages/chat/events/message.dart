import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:matrix/matrix.dart';
import 'package:swipe_to_action/swipe_to_action.dart';
import 'package:tawkie/config/app_config.dart';
import 'package:tawkie/config/themes.dart';
import 'package:tawkie/pages/chat/events/message_reactions.dart';
import 'package:tawkie/utils/date_time_extension.dart';
import 'package:tawkie/utils/string_color.dart';
import 'package:tawkie/widgets/avatar.dart';
import 'package:tawkie/widgets/matrix.dart';

import 'message_group_content.dart';
import 'message_content.dart';
import 'reply_content.dart';
import 'state_message.dart';
import 'verification_request_content.dart';

class Message extends StatelessWidget {
  final Event event;
  final Event? nextEvent;
  final Event? previousEvent;
  final bool displayReadMarker;
  final void Function(Event) onTab;
  final void Function(Event) onSelect;
  final void Function(Event) onDoubleTap; // Double tap to like
  final void Function(Event) onAvatarTab;
  final void Function(Event) onInfoTab;
  final void Function(String) scrollToEventId;
  final void Function() onSwipe;
  final bool longPressSelect;
  final bool selected;
  final bool onTabInfo;
  final Timeline timeline;
  final bool highlightMarker;
  final bool animateIn;
  final void Function()? resetAnimateIn;
  final Color? avatarPresenceBackgroundColor;

  const Message(
    this.event, {
    this.nextEvent,
    this.previousEvent,
    this.displayReadMarker = false,
    this.longPressSelect = false,
    required this.onTab,
    required this.onSelect,
    required this.onDoubleTap,
    required this.onInfoTab,
    required this.onAvatarTab,
    required this.scrollToEventId,
    required this.onSwipe,
    this.selected = false,
    this.onTabInfo = false,
    required this.timeline,
    this.highlightMarker = false,
    this.animateIn = false,
    this.resetAnimateIn,
    this.avatarPresenceBackgroundColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (!{
      EventTypes.Message,
      EventTypes.Sticker,
      EventTypes.Encrypted,
      EventTypes.CallInvite,
    }.contains(event.type)) {
      if (event.type.startsWith('m.call.')) {
        return const SizedBox.shrink();
      }
      return StateMessage(event);
    }

    if (event.type == EventTypes.Message &&
        event.messageType == EventTypes.KeyVerificationRequest) {
      return VerificationRequestContent(event: event, timeline: timeline);
    }

    final client = Matrix.of(context).client;
    final ownMessage = event.senderId == client.userID;
    final alignment = ownMessage ? Alignment.topRight : Alignment.topLeft;
    // ignore: deprecated_member_use
    var color = Theme.of(context).colorScheme.surfaceVariant;
    final displayTime = event.type == EventTypes.RoomCreate ||
        nextEvent == null ||
        !event.originServerTs.sameEnvironment(nextEvent!.originServerTs);
    final nextEventSameSender = nextEvent != null &&
        {
          EventTypes.Message,
          EventTypes.Sticker,
          EventTypes.Encrypted,
        }.contains(nextEvent!.type) &&
        nextEvent!.senderId == event.senderId &&
        !displayTime;

    final previousEventSameSender = previousEvent != null &&
        {
          EventTypes.Message,
          EventTypes.Sticker,
          EventTypes.Encrypted,
        }.contains(previousEvent!.type) &&
        previousEvent!.senderId == event.senderId &&
        previousEvent!.originServerTs.sameEnvironment(event.originServerTs);

    final textColor = ownMessage
        ? Theme.of(context).colorScheme.onPrimary
        : Theme.of(context).colorScheme.onSurface;
    final rowMainAxisAlignment =
        ownMessage ? MainAxisAlignment.end : MainAxisAlignment.start;

    final displayEvent = event.getDisplayEvent(timeline);
    const hardCorner = Radius.circular(4);
    const roundedCorner = Radius.circular(AppConfig.borderRadius);
    final borderRadius = BorderRadius.only(
      topLeft: !ownMessage && nextEventSameSender ? hardCorner : roundedCorner,
      topRight: ownMessage && nextEventSameSender ? hardCorner : roundedCorner,
      bottomLeft:
          !ownMessage && previousEventSameSender ? hardCorner : roundedCorner,
      bottomRight:
          ownMessage && previousEventSameSender ? hardCorner : roundedCorner,
    );
    final noBubble = {
          MessageTypes.Video,
          MessageTypes.Image,
          MessageTypes.Sticker,
        }.contains(event.messageType) &&
        !event.redacted;
    final noPadding = {
      MessageTypes.File,
      MessageTypes.Audio,
    }.contains(event.messageType);

    if (ownMessage) {
      color = displayEvent.status.isError
          ? Colors.redAccent
          : Theme.of(context).colorScheme.primary;
    }

    final resetAnimateIn = this.resetAnimateIn;
    var animateIn = this.animateIn;

    // Message grouping section
    // (if messages have the same originServerTs)
    bool hasSameTimestamp(Event? event, Event? nextEvent) {
      if (event == null || nextEvent == null) {
        return false;
      }
      return event.originServerTs == nextEvent.originServerTs;
    }

    bool isMediaEvent(Event event) {
      return event.messageType == MessageTypes.Image ||
          event.messageType == MessageTypes.Video ||
          event.messageType == MessageTypes.Sticker;
    }

    bool isTextEvent(Event event) {
      return event.messageType == MessageTypes.Text || event.messageType == MessageTypes.Notice;
    }

    bool containsMediaAndText(List<Event> events) {
      bool hasMedia = events.any((event) => isMediaEvent(event));
      bool hasText = events.any((event) => isTextEvent(event));
      return hasMedia && hasText;
    }

    List<Event> groupEvents() {
      List<Event> possibleGroup = [event, nextEvent].where((e) => e != null).cast<Event>().toList();
      if (containsMediaAndText(possibleGroup)) {
        return possibleGroup;
      }

      return [];
    }

    bool canGroupEvents() {
      return hasSameTimestamp(event, nextEvent) && containsMediaAndText([event, nextEvent!]);
    }


    bool hasSamePreviousTimestamp(Event? currentEvent, Event? previousEvent) {
      if (currentEvent == null || previousEvent == null) {
        return false;
      }
      return currentEvent.originServerTs == previousEvent.originServerTs;
    }

    bool isDuplicateEvent() {
      return hasSamePreviousTimestamp(event, previousEvent);
    }

    final isHidden = isDuplicateEvent();

    if (isHidden) {
      return const SizedBox.shrink();
    }

    final List<Event> groupedEvents = canGroupEvents() ? groupEvents() : [];

    Event getEventForReactions(List<Event> groupedEvents) {
      for (var event in groupedEvents) {
        if (isMediaEvent(event)) {
          return event;
        }
      }
      return groupedEvents.isNotEmpty ? groupedEvents.last : event;
    }

    final Event eventForReactions = getEventForReactions(groupedEvents);

    final row = StatefulBuilder(
      builder: (context, setState) {
        if (animateIn && resetAnimateIn != null) {
          WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
            animateIn = false;
            setState(resetAnimateIn);
          });
        }
        return AnimatedSize(
          duration: FluffyThemes.animationDuration,
          curve: FluffyThemes.animationCurve,
          clipBehavior: Clip.none,
          alignment: ownMessage ? Alignment.bottomRight : Alignment.bottomLeft,
          child: animateIn
              ? const SizedBox(height: 0, width: double.infinity)
              : Stack(
                  children: [
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: InkWell(
                        onTap: () => onSelect(event),
                        onLongPress: () => onSelect(event),
                        borderRadius:
                            BorderRadius.circular(AppConfig.borderRadius / 2),
                        child: Material(
                          borderRadius:
                              BorderRadius.circular(AppConfig.borderRadius / 2),
                          color: selected
                              ? Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer
                                  .withAlpha(100)
                              : highlightMarker
                                  ? Theme.of(context)
                                      .colorScheme
                                      .tertiaryContainer
                                      .withAlpha(100)
                                  : Colors.transparent,
                        ),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: rowMainAxisAlignment,
                      children: [
                        if (longPressSelect)
                          SizedBox(
                            height: 32,
                            width: Avatar.defaultSize,
                            child: Checkbox.adaptive(
                              value: selected,
                              shape: const CircleBorder(),
                              onChanged: (_) => onSelect(event),
                            ),
                          )
                        else if (nextEventSameSender || ownMessage)
                          SizedBox(
                            width: Avatar.defaultSize,
                            child: Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: event.status == EventStatus.error
                                    ? const Icon(Icons.error, color: Colors.red)
                                    : event.fileSendingStatus != null
                                        ? const CircularProgressIndicator
                                            .adaptive(
                                            strokeWidth: 1,
                                          )
                                        : null,
                              ),
                            ),
                          )
                        else
                          FutureBuilder<User?>(
                            future: event.fetchSenderUser(),
                            builder: (context, snapshot) {
                              final user = snapshot.data ??
                                  event.senderFromMemoryOrFallback;
                              return Avatar(
                                mxContent: user.avatarUrl,
                                name: user.calcDisplayname(),
                                presenceUserId: user.stateKey,
                                presenceBackgroundColor:
                                    avatarPresenceBackgroundColor,
                                onTap: () => onAvatarTab(event),
                              );
                            },
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!nextEventSameSender)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 8.0,
                                    bottom: 4,
                                  ),
                                  child: ownMessage || event.room.isDirectChat
                                      ? const SizedBox(height: 12)
                                      : FutureBuilder<User?>(
                                          future: event.fetchSenderUser(),
                                          builder: (context, snapshot) {
                                            final displayname = snapshot.data
                                                    ?.calcDisplayname() ??
                                                event.senderFromMemoryOrFallback
                                                    .calcDisplayname();
                                            return Text(
                                              displayname,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: (Theme.of(context)
                                                            .brightness ==
                                                        Brightness.light
                                                    ? displayname.color
                                                    : displayname
                                                        .lightColorText),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            );
                                          },
                                        ),
                                ),
                              Container(
                                alignment: alignment,
                                padding: const EdgeInsets.only(left: 8),
                                child: GestureDetector(
                                  onLongPress: longPressSelect
                                      ? null
                                      : () {
                                          HapticFeedback.heavyImpact();
                                          onSelect(event);
                                        },
                                  child: AnimatedOpacity(
                                    opacity: animateIn
                                        ? 0
                                        : event.redacted ||
                                                event.messageType ==
                                                    MessageTypes.BadEncrypted ||
                                                event.status.isSending
                                            ? 0.5
                                            : 1,
                                    duration: FluffyThemes.animationDuration,
                                    curve: FluffyThemes.animationCurve,
                                    child: Material(
                                      color:
                                          noBubble ? Colors.transparent : color,
                                      clipBehavior: Clip.antiAlias,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: borderRadius,
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            AppConfig.borderRadius,
                                          ),
                                        ),
                                        padding: noBubble || noPadding
                                            ? EdgeInsets.zero
                                            : const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 8,
                                              ),
                                        constraints: const BoxConstraints(
                                          maxWidth:
                                              FluffyThemes.columnWidth * 1.5,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            if (event.relationshipType ==
                                                RelationshipTypes.reply)
                                              FutureBuilder<Event?>(
                                                future: event
                                                    .getReplyEvent(timeline),
                                                builder: (
                                                  BuildContext context,
                                                  snapshot,
                                                ) {
                                                  final replyEvent = snapshot
                                                          .hasData
                                                      ? snapshot.data!
                                                      : Event(
                                                          eventId: event
                                                              .relationshipEventId!,
                                                          content: {
                                                            'msgtype': 'm.text',
                                                            'body': '...',
                                                          },
                                                          senderId:
                                                              event.senderId,
                                                          type:
                                                              'm.room.message',
                                                          room: event.room,
                                                          status:
                                                              EventStatus.sent,
                                                          originServerTs:
                                                              DateTime.now(),
                                                        );
                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                      bottom: 4.0,
                                                    ),
                                                    child: InkWell(
                                                      borderRadius: ReplyContent
                                                          .borderRadius,
                                                      onTap: () =>
                                                          scrollToEventId(
                                                        replyEvent.eventId,
                                                      ),
                                                      child: AbsorbPointer(
                                                        child: ReplyContent(
                                                          replyEvent,
                                                          ownMessage:
                                                              ownMessage,
                                                          timeline: timeline,
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            groupedEvents.isNotEmpty
                                                ? MessageGroupContent(
                                                    groupedEvents,
                                                    textColor: textColor,
                                                    onInfoTab: onInfoTab,
                                                    borderRadius: borderRadius,
                                                  )
                                                : MessageContent(
                                                    displayEvent,
                                                    textColor: textColor,
                                                    onInfoTab: onInfoTab,
                                                    borderRadius: borderRadius,
                                                  ),
                                            if (event.hasAggregatedEvents(
                                              timeline,
                                              RelationshipTypes.edit,
                                            ))
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 4.0,
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.edit_outlined,
                                                      color: textColor
                                                          .withAlpha(164),
                                                      size: 14,
                                                    ),
                                                    Text(
                                                      ' - ${displayEvent.originServerTs.localizedTimeShort(context)}',
                                                      style: TextStyle(
                                                        color: textColor
                                                            .withAlpha(164),
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        );
      },
    );
    Widget container;
    if (event.hasAggregatedEvents(timeline, RelationshipTypes.reaction) ||
        displayTime ||
        selected ||
        displayReadMarker ||
        onTabInfo) {
      container = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            ownMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: <Widget>[
          if (displayTime || selected || onTabInfo)
            Padding(
              padding: displayTime
                  ? const EdgeInsets.symmetric(vertical: 8.0)
                  : EdgeInsets.zero,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    event.originServerTs.localizedTime(context),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12 * AppConfig.fontSizeFactor,
                      color: Theme.of(context).colorScheme.secondary,
                      shadows: [
                        Shadow(
                          color: Theme.of(context).colorScheme.surface,
                          blurRadius: 3,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          row,
          if (event.hasAggregatedEvents(timeline, RelationshipTypes.reaction))
            Padding(
              padding: EdgeInsets.only(
                top: 4.0,
                left: (ownMessage ? 0 : Avatar.defaultSize) + 12.0,
                right: 12.0,
              ),
              child: MessageReactions(groupedEvents.isNotEmpty ?eventForReactions :event, timeline),
            ),
          if (displayReadMarker)
            Row(
              children: [
                Expanded(
                  child: Divider(color: Theme.of(context).colorScheme.primary),
                ),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  margin: const EdgeInsets.all(8.0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                  ),
                  child: Text(
                    L10n.of(context)!.readUpToHere,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.primary),
                  ),
                ),
                Expanded(
                  child: Divider(color: Theme.of(context).colorScheme.primary),
                ),
              ],
            ),
        ],
      );
    } else {
      container = row;
    }

    return Center(
      child: Swipeable(
        key: ValueKey(event.eventId),
        background: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.0),
          child: Center(
            child: Icon(Icons.check_outlined),
          ),
        ),
        direction: AppConfig.swipeRightToLeftToReply
            ? SwipeDirection.endToStart
            : SwipeDirection.startToEnd,
        onSwipe: (_) => onSwipe(),
        child: InkWell(
          onDoubleTap: () => onDoubleTap(event),
          onLongPress: () => onSelect(event),
          onTap: () => onTab(event),
          child: Container(
            color: selected
                ? Theme.of(context).primaryColor.withAlpha(100)
                : Theme.of(context).primaryColor.withAlpha(0),
            constraints: const BoxConstraints(
              maxWidth: FluffyThemes.columnWidth * 2.5,
            ),
            padding: EdgeInsets.only(
              left: 8.0,
              right: 8.0,
              top: nextEventSameSender ? 1.0 : 4.0,
              bottom: previousEventSameSender ? 1.0 : 4.0,
            ),
            child: container,
          ),
        ),
      ),
    );
  }
}
