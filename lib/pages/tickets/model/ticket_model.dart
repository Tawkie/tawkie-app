class Ticket {
  final String version;
  final String platform;
  final String content;
  final DateTime date;
  String? roomId;
  String status;

  Ticket({
    required this.version,
    required this.platform,
    required this.content,
    required this.date,
    this.roomId,
    required this.status,
  });

  factory Ticket.fromRoomMessage(String message, DateTime date, String status) {
    final versionRegExp = RegExp(r'\*\*Version\*\*: ([^\n]+)');
    final platformRegExp = RegExp(r'\*\*Plateforme\*\*: ([^\n]+)');
    final contentRegExp =
    RegExp(r"\*\*Message de l'utilisateur\*\*: ?([\s\S]*)");

    final versionMatch = versionRegExp.firstMatch(message);
    final platformMatch = platformRegExp.firstMatch(message);
    final contentMatch = contentRegExp.firstMatch(message);

    if (versionMatch != null && platformMatch != null && contentMatch != null) {
      return Ticket(
        version: versionMatch.group(1) ?? '',
        platform: platformMatch.group(1) ?? '',
        content: contentMatch.group(1)?.trim() ?? '',
        date: date,
        status: status,
      );
    } else {
      throw const FormatException("Message format is invalid");
    }
  }
}
