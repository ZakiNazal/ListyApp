import 'package:cloud_firestore/cloud_firestore.dart';

/// A single line on a list, e.g. "Football x2".
/// Stored at `lists/{listId}/items/{itemId}`.
class ListItem {
  const ListItem({
    required this.id,
    required this.name,
    required this.quantity,
    this.done = false,
    this.createdAt,
  });

  final String id;
  final String name;
  final int quantity;
  final bool done;
  final DateTime? createdAt;

  factory ListItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return ListItem(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      done: (data['done'] as bool?) ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// [memberUids] is denormalised from the parent list -- see the items block
  /// in firestore.rules for why the rules cannot read it from the parent.
  Map<String, dynamic> toMap({required List<String> memberUids}) =>
      <String, dynamic>{
        'name': name,
        'quantity': quantity,
        'done': done,
        'memberUids': memberUids,
        'createdAt': FieldValue.serverTimestamp(),
      };

  ListItem copyWith({String? name, int? quantity, bool? done}) => ListItem(
        id: id,
        name: name ?? this.name,
        quantity: quantity ?? this.quantity,
        done: done ?? this.done,
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

  /// [memberUids] must match the parent list's, or the security rules will
  /// reject the write.
  Map<String, dynamic> toMap({required List<String> memberUids}) =>
      <String, dynamic>{
        'name': name.trim(),
        'quantity': quantity,
        'done': false,
        'memberUids': memberUids,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
