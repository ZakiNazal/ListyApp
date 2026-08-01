// ignore_for_file: avoid_types_as_parameter_names

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/list_item.dart';
import '../models/listy_list.dart';
import 'auth_repository.dart';

final listRepositoryProvider = Provider<ListRepository>(
  (ref) => ListRepository(ref.watch(firestoreProvider)),
);

/// Every list the signed-in user can see (owned by them or assigned to them).
final myListsProvider = StreamProvider<List<ListyList>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream<List<ListyList>>.value(const []);
  return ref.watch(listRepositoryProvider).watchLists(uid);
});

/// Home screen totals.
final listStatsProvider = Provider<({int lists, int items})>((ref) {
  final lists = ref.watch(myListsProvider).valueOrNull ?? const <ListyList>[];
  return (
    lists: lists.length,
    items: lists.fold<int>(0, (sum, l) => sum + l.itemCount),
  );
});

/// Lists with their items resolved, for the Item Lists screen.
final listsWithItemsProvider = StreamProvider<List<ListWithItems>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream<List<ListWithItems>>.value(const []);
  return ref.watch(listRepositoryProvider).watchListsWithItems(uid);
});

/// A single list, streamed live so two people looking at it stay in sync.
final listByIdProvider = StreamProvider.family<ListyList?, String>(
  (ref, listId) => ref.watch(listRepositoryProvider).watchList(listId),
);

/// The items on one list, streamed so a tick on one device appears on the other.
final listItemsProvider = StreamProvider.family<List<ListItem>, String>(
  (ref, listId) {
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;
    if (uid == null) return Stream.value(const []);
    return ref.watch(listRepositoryProvider).watchItems(listId, uid);
  },
);

/// Lists someone else sent to the signed-in user.
final incomingListsProvider = Provider<List<ListyList>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  final lists = ref.watch(myListsProvider).valueOrNull ?? const <ListyList>[];
  if (uid == null) return const [];
  return lists.where((l) => l.ownerUid != uid).toList(growable: false);
});

/// Lists the signed-in user sent to someone else.
final outgoingListsProvider = Provider<List<ListyList>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  final lists = ref.watch(myListsProvider).valueOrNull ?? const <ListyList>[];
  if (uid == null) return const [];
  return lists.where((l) => l.ownerUid == uid).toList(growable: false);
});

/// Lists the signed-in user sent that have some progress made.
final outgoingProgressListsProvider = Provider<List<ListyList>>((ref) {
  final outgoing = ref.watch(outgoingListsProvider);
  return outgoing.where((l) => l.doneCount > 0).toList(growable: false);
});

class ListRepository {
  ListRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _lists =>
      _db.collection('lists');

  Stream<List<ListyList>> watchLists(String uid) => _lists
      .where('memberUids', arrayContains: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(ListyList.fromDoc).toList());

  Stream<ListyList?> watchList(String listId) => _lists
      .doc(listId)
      .snapshots()
      .map((doc) => doc.exists ? ListyList.fromDoc(doc) : null);

  Stream<List<ListItem>> watchItems(String listId, String uid) => _lists
      .doc(listId)
      .collection('items')
      .where('memberUids', arrayContains: uid)
      .snapshots()
      .map((s) {
        final items = s.docs.map(ListItem.fromDoc).toList();
        items.sort((a, b) => (a.createdAt ?? DateTime.now()).compareTo(b.createdAt ?? DateTime.now()));
        return items;
      });

  /// Joins each list to its items subcollection.
  ///
  /// Firestore has no server-side join, so this fans out one items listener per
  /// list and recombines them. Fine at this scale; if a user ever has hundreds
  /// of lists, paginate [watchLists] first.
  Stream<List<ListWithItems>> watchListsWithItems(String uid) {
    return watchLists(uid).asyncMap((lists) async {
      final itemsPerList = await Future.wait(
        lists.map(
          (l) => _lists
              .doc(l.id)
              .collection('items')
              .where('memberUids', arrayContains: uid)
              .get()
              .then((s) {
                final items = s.docs.map(ListItem.fromDoc).toList();
                items.sort((a, b) => (a.createdAt ?? DateTime.now()).compareTo(b.createdAt ?? DateTime.now()));
                return items;
              })
              // One unreadable list must not blank the whole screen. This
              // happens with items written before memberUids was denormalised
              // onto them -- the read rule denies those, and without this the
              // single failure propagates and Item Lists shows only an error.
              .catchError((Object e) {
                debugPrint('items unreadable for list ${l.id}: $e');
                return <ListItem>[];
              }),
        ),
      );
      return <ListWithItems>[
        for (var i = 0; i < lists.length; i++)
          ListWithItems(list: lists[i], items: itemsPerList[i]),
      ];
    });
  }

  /// Writes the list and all of its items in one atomic batch, so a list can
  /// never land in Firestore without its contents.
  Future<String> createList({
    required String title,
    required String ownerUid,
    required String assignedToUid,
    required List<DraftItem> items,
  }) async {
    final kept = items.where((i) => !i.isEmpty).toList();

    // Both the list and every item carry the same membership. The items need
    // their own copy because rules cannot get() a parent being created in the
    // same batch -- see firestore.rules.
    final memberUids = <String>{ownerUid, assignedToUid}.toList();

    final listRef = _lists.doc();
    final batch = _db.batch();

    batch.set(
      listRef,
      ListyList.newListMap(
        title: title.trim(),
        ownerUid: ownerUid,
        assignedToUid: assignedToUid,
        itemCount: kept.length,
      ),
    );

    for (final item in kept) {
      batch.set(
        listRef.collection('items').doc(),
        item.toMap(memberUids: memberUids),
      );
    }

    await batch.commit();
    return listRef.id;
  }

  Future<void> setItemDone(String listId, String itemId, bool done) {
    final batch = _db.batch();
    
    batch.update(_lists.doc(listId), <String, dynamic>{
      'doneCount': FieldValue.increment(done ? 1 : -1),
      'lastActivityAt': FieldValue.serverTimestamp(),
      'assigneeReadAt': FieldValue.serverTimestamp(),
    });

    batch.update(
      _lists.doc(listId).collection('items').doc(itemId),
      <String, dynamic>{'done': done},
    );

    return batch.commit();
  }

  Future<void> markListRead(String listId, bool isOwner) => _lists
      .doc(listId)
      .update(<String, dynamic>{
        isOwner ? 'ownerReadAt' : 'assigneeReadAt': FieldValue.serverTimestamp(),
      });

  /// Deletes a list and its items.
  ///
  /// Firestore does not cascade: deleting a document leaves its subcollections
  /// behind as orphans that nothing can reach but you still pay to store. The
  /// items have to go explicitly, and they go first so a failure part-way
  /// leaves the list intact rather than empty.
  Future<void> deleteList(String listId, String uid) async {
    final listRef = _lists.doc(listId);
    final items = await listRef.collection('items')
        .where('memberUids', arrayContains: uid)
        .get();

    // A batch caps at 500 writes; chunk so a very long list still deletes.
    const limit = 400;
    for (var i = 0; i < items.docs.length; i += limit) {
      final batch = _db.batch();
      for (final doc in items.docs.skip(i).take(limit)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    await listRef.delete();
  }
}
