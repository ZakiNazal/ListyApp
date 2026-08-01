import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityNotification {
  const ActivityNotification({
    required this.id,
    required this.listId,
    required this.message,
    required this.isRead,
    this.createdAt,
  });

  final String id;
  final String listId;
  final String message;
  final bool isRead;
  final DateTime? createdAt;

  factory ActivityNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ActivityNotification(
      id: doc.id,
      listId: data['listId'] as String? ?? '',
      message: data['message'] as String? ?? '',
      isRead: data['isRead'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'listId': listId,
        'message': message,
        'isRead': isRead,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
