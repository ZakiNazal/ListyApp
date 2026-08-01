import 'package:cloud_firestore/cloud_firestore.dart';

import 'list_item.dart';

/// A list of items sent from one user to another. Stored at `lists/{listId}`.
///
/// [memberUids] is what the Firestore security rules check, so it must always
/// contain both the owner and the assigned user.
class ListyList {
  const ListyList({
    required this.id,
    required this.title,
    required this.ownerUid,
    required this.assignedToUid,
    required this.memberUids,
    this.itemCount = 0,
    this.doneCount = 0,
    this.status = ListStatus.pending,
    this.createdAt,
    this.lastActivityAt,
    this.ownerReadAt,
    this.assigneeReadAt,
    this.hiddenFor = const [],
  });

  final String id;
  final String title;
  final String ownerUid;
  final String assignedToUid;
  final List<String> memberUids;

  /// Denormalised count so the Home screen can total items without reading
  /// every subcollection.
  final int itemCount;
  final int doneCount;
  final ListStatus status;
  final DateTime? createdAt;
  final DateTime? lastActivityAt;
  final DateTime? ownerReadAt;
  final DateTime? assigneeReadAt;

  /// Uids that have dismissed this list from their own view.
  ///
  /// Deleting outright is owner-only, but a recipient still needs a way to get
  /// an unwanted list off their screen without destroying it for the sender.
  final List<String> hiddenFor;

  bool isHiddenFor(String? uid) => uid != null && hiddenFor.contains(uid);

  /// Every item ticked or marked missing.
  bool get allHandled => itemCount > 0 && doneCount >= itemCount;

  /// Still needs work from the assignee: accepted (or untouched) and unfinished.
  bool get isActive =>
      status != ListStatus.denied && status != ListStatus.completed;

  factory ListyList.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return ListyList(
      id: doc.id,
      title: (data['title'] as String?) ?? '',
      ownerUid: (data['ownerUid'] as String?) ?? '',
      assignedToUid: (data['assignedToUid'] as String?) ?? '',
      memberUids:
          (data['memberUids'] as List<dynamic>?)?.cast<String>() ?? const [],
      itemCount: (data['itemCount'] as num?)?.toInt() ?? 0,
      doneCount: (data['doneCount'] as num?)?.toInt() ?? 0,
      status: ListStatus.fromName(data['status'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      lastActivityAt: (data['lastActivityAt'] as Timestamp?)?.toDate() ??
          (data['createdAt'] as Timestamp?)?.toDate(),
      ownerReadAt: (data['ownerReadAt'] as Timestamp?)?.toDate(),
      assigneeReadAt: (data['assigneeReadAt'] as Timestamp?)?.toDate(),
      hiddenFor:
          (data['hiddenFor'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }

  static Map<String, dynamic> newListMap({
    required String title,
    required String ownerUid,
    required String assignedToUid,
    required int itemCount,
  }) =>
      <String, dynamic>{
        'title': title,
        'ownerUid': ownerUid,
        'assignedToUid': assignedToUid,
        'memberUids': <String>{ownerUid, assignedToUid}.toList(),
        'itemCount': itemCount,
        'doneCount': 0,
        'status': ListStatus.pending.name,
        'createdAt': FieldValue.serverTimestamp(),
        'lastActivityAt': FieldValue.serverTimestamp(),
        'ownerReadAt': FieldValue.serverTimestamp(),
        'hiddenFor': <String>[],
      };
}

enum ListStatus {
  pending,
  accepted,
  denied,
  completed;

  static ListStatus fromName(String? name) => ListStatus.values.firstWhere(
        (s) => s.name == name,
        orElse: () => ListStatus.pending,
      );
}

/// A list plus its items, used by the Item Lists screen which renders them
/// grouped under a header.
class ListWithItems {
  const ListWithItems({required this.list, required this.items});

  final ListyList list;
  final List<ListItem> items;
}
