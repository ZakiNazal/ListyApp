import 'package:cloud_firestore/cloud_firestore.dart';

/// A single line on a list, e.g. "Football x2".
/// Stored at `lists/{listId}/items/{itemId}`.
class ListItem {
  const ListItem({
    required this.id,
    required this.name,
    required this.quantity,
    this.done = false,
    this.isMissing = false,
    this.createdAt,
  });

  final String id;
  final String name;
  final int quantity;
  final bool done;
  final bool isMissing;
  final DateTime? createdAt;

  factory ListItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return ListItem(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      done: (data['done'] as bool?) ?? false,
      isMissing: (data['isMissing'] as bool?) ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// [memberUids] and [ownerUid] are denormalised from the parent list -- see
  /// the items block in firestore.rules for why the rules cannot read them from
  /// the parent, and why doing so would bill a read on every tick.
  Map<String, dynamic> toMap({
    required List<String> memberUids,
    required String ownerUid,
  }) => <String, dynamic>{
    'name': name,
    'quantity': quantity,
    'done': done,
    'isMissing': isMissing,
    'memberUids': memberUids,
    'ownerUid': ownerUid,
    'createdAt': FieldValue.serverTimestamp(),
  };

  ListItem copyWith({String? name, int? quantity, bool? done, bool? isMissing}) => ListItem(
        id: id,
        name: name ?? this.name,
        quantity: quantity ?? this.quantity,
        done: done ?? this.done,
        isMissing: isMissing ?? this.isMissing,
        createdAt: createdAt,
      );
}

/// An item being composed on the Request screen before it is written to
/// Firestore. Carries a [TextEditingController]-friendly mutable shape.
class DraftItem {
  DraftItem({this.name = '', this.quantity = 0});

  String name;
  int quantity;

  bool get isEmpty => name.trim().isEmpty;

  /// [memberUids] and [ownerUid] must match the parent list's, or the security
  /// rules will reject the write.
  Map<String, dynamic> toMap({
    required List<String> memberUids,
    required String ownerUid,
  }) => <String, dynamic>{
    'name': name.trim(),
    'quantity': quantity,
    'done': false,
    'isMissing': false,
    'memberUids': memberUids,
    'ownerUid': ownerUid,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
