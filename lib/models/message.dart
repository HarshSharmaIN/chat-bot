import 'package:hive/hive.dart';

part 'message.g.dart';

@HiveType(typeId: 0)
enum MessageRole {
  @HiveField(0)
  user,
  @HiveField(1)
  assistant,
}

@HiveType(typeId: 1)
class Message extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final MessageRole role;
  
  @HiveField(2)
  final String text;
  
  @HiveField(3)
  final DateTime timestamp;
  
  @HiveField(4)
  final bool isError;

  Message({
    required this.id,
    required this.role,
    required this.text,
    required this.timestamp,
    this.isError = false,
  });

  Message copyWith({
    String? id,
    MessageRole? role,
    String? text,
    DateTime? timestamp,
    bool? isError,
  }) {
    return Message(
      id: id ?? this.id,
      role: role ?? this.role,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isError: isError ?? this.isError,
    );
  }

  @override
  String toString() {
    return 'Message(id: $id, role: $role, text: $text, timestamp: $timestamp, isError: $isError)';
  }
}