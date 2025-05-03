class Chat {
  final String id;
  final String name;
  final String lastMessage;
  final String avatarUrl;
  final DateTime lastMessageTime;
  final int unreadCount;

  Chat({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.avatarUrl,
    required this.lastMessageTime,
    this.unreadCount = 0,
  });
}