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
///
/// Denied and completed lists are excluded: the cards are meant to answer
/// "how much is on my plate", and a refused list is not.
final listStatsProvider = Provider<({int lists, int items})>((ref) {
  final lists = ref.watch(myListsProvider).valueOrNull ?? const <ListyList>[];
  final active = lists.where((l) => l.isActive);
  return (
    lists: active.length,
    items: active.fold<int>(0, (sum, l) => sum + l.itemCount),
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

/// Incoming lists that still need something from you.
///
/// This is what the Upcoming badge counts: anything denied or finished is done
/// with, however many items it happens to contain.
final incomingActiveListsProvider = Provider<List<ListyList>>((ref) {
  return ref
      .watch(incomingListsProvider)
      .where((l) => l.isActive)
      .toList(growable: false);
});

/// Incoming lists the recipient has not yet accepted or denied.
///
/// Surfaced as a "Needs your response" chip on Upcoming Lists so an unanswered
/// list is visible without opening it.
final pendingResponseListsProvider = Provider<List<ListyList>>((ref) {
  return ref
      .watch(incomingListsProvider)
      .where((l) => l.status == ListStatus.pending)
      .toList(growable: false);
});

/// How many incoming lists are waiting on an accept or deny.
final pendingResponseCountProvider = Provider<int>(
  (ref) => ref.watch(pendingResponseListsProvider).length,
);

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

  /// Lists this user is part of and has not dismissed.
  ///
  /// `hiddenFor` is filtered client-side on purpose: Firestore has no
  /// "array does not contain" operator, and adding one would mean a second
  /// query plus a composite index for no real benefit at this scale.
  Stream<List<ListyList>> watchLists(String uid) => _lists
      .where('memberUids', arrayContains: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (s) => s.docs
            .map(ListyList.fromDoc)
            .where((l) => !l.isHiddenFor(uid))
            .toList(),
      );

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
        item.toMap(memberUids: memberUids, ownerUid: ownerUid),
      );
    }

    await batch.commit();
    return listRef.id;
  }

  Future<void> updateListStatus(String listId, ListStatus status) => _lists
      .doc(listId)
      .update(<String, dynamic>{
        'status': status.name,
        'lastActivityAt': FieldValue.serverTimestamp(),
      });

  /// Applies one item change and moves the list's status if that was the last
  /// (or first-undone) item.
  ///
  /// Runs in a transaction rather than a batch so `doneCount` and `status` are
  /// derived from the list as it actually is on the server. A batch would let
  /// two devices ticking at once each compute their own idea of "finished".
  ///
  /// Returns true when this change completed the list, so the caller knows
  /// whether to notify -- and, because the transaction decides, it fires
  /// exactly once no matter how many devices are ticking.
  Future<bool> updateItemState(
    String listId,
    String itemId, {
    required bool done,
    required bool isMissing,
    required bool wasCounting,
  }) {
    final listRef = _lists.doc(listId);
    final itemRef = listRef.collection('items').doc(itemId);

    return _db.runTransaction<bool>((tx) async {
      final listSnap = await tx.get(listRef);
      if (!listSnap.exists) return false;

      final list = ListyList.fromDoc(listSnap);

      final isCounting = done || isMissing;
      var diff = 0;
      if (isCounting && !wasCounting) diff = 1;
      if (!isCounting && wasCounting) diff = -1;

      final newDone = (list.doneCount + diff).clamp(0, list.itemCount);
      final nowComplete = list.itemCount > 0 && newDone >= list.itemCount;

      // Un-ticking something on a finished list puts it back in play.
      final nextStatus = nowComplete
          ? ListStatus.completed
          : (list.status == ListStatus.completed
                ? ListStatus.accepted
                : list.status);

      tx.update(listRef, <String, dynamic>{
        'doneCount': newDone,
        'status': nextStatus.name,
        'lastActivityAt': FieldValue.serverTimestamp(),
        'assigneeReadAt': FieldValue.serverTimestamp(),
      });

      tx.update(itemRef, <String, dynamic>{
        'done': done,
        'isMissing': isMissing,
      });

      // Only true on the transition, so re-ticking a finished list is silent.
      return nowComplete && list.status != ListStatus.completed;
    });
  }

  /// Hides a list from one member's view without deleting it for the other.
  Future<void> setHidden(String listId, String uid, bool hidden) =>
      _lists.doc(listId).update(<String, dynamic>{
        'hiddenFor': hidden
            ? FieldValue.arrayUnion(<String>[uid])
            : FieldValue.arrayRemove(<String>[uid]),
      });

  Future<void> updateList({
    required String listId,
    required String title,
    required String ownerUid,
    required List<String> memberUids,
    required List<ListItem> existingItemsToUpdate,
    required List<DraftItem> newItemsToAdd,
    required List<String> itemIdsToDelete,
  }) async {
    final batch = _db.batch();

    final keptNewItems = newItemsToAdd.where((i) => !i.isEmpty).toList();
    final newTotal = existingItemsToUpdate.length + keptNewItems.length;

    // doneCount is deliberately NOT written here.
    //
    // It used to be recomputed from the editor's snapshot and written
    // absolutely, so if the recipient ticked something while the sender had the
    // edit screen open, whoever saved last won and the tick was silently lost.
    // The counter belongs to updateItemState, which owns it transactionally.
    // Deleting a completed item is reconciled below instead.
    batch.update(_lists.doc(listId), <String, dynamic>{
      'title': title.trim(),
      'itemCount': newTotal,
      'lastActivityAt': FieldValue.serverTimestamp(),
    });

    final itemsRef = _lists.doc(listId).collection('items');
    for (final id in itemIdsToDelete) {
      batch.delete(itemsRef.doc(id));
    }
    for (final item in existingItemsToUpdate) {
      batch.update(itemsRef.doc(item.id), <String, dynamic>{
        'name': item.name.trim(),
        'quantity': item.quantity,
        'done': item.done,
        'isMissing': item.isMissing,
      });
    }
    for (final item in keptNewItems) {
      batch.set(
        itemsRef.doc(),
        item.toMap(memberUids: memberUids, ownerUid: ownerUid),
      );
    }

    await batch.commit();

    // Adding or deleting items shifts the totals, so recount from the
    // collection rather than trusting the editor's view of it.
    await reconcileCounts(listId, ownerUid);
  }

  /// Recomputes itemCount / doneCount / status from the items actually stored.
  ///
  /// The counters are denormalised for cheap reads, which means they can drift
  /// when items are added or removed. This is the repair: it reads the truth
  /// and writes it back, and is safe to call at any time.
  Future<void> reconcileCounts(String listId, String uid) async {
    final listRef = _lists.doc(listId);

    final snapshot = await listRef
        .collection('items')
        .where('memberUids', arrayContains: uid)
        .get();

    final items = snapshot.docs.map(ListItem.fromDoc).toList();
    final total = items.length;
    final handled = items.where((i) => i.done || i.isMissing).length;

    await _db.runTransaction((tx) async {
      final listSnap = await tx.get(listRef);
      if (!listSnap.exists) return;
      final list = ListyList.fromDoc(listSnap);

      // Denied lists keep their status: a denial is a decision, not progress.
      var status = list.status;
      if (status != ListStatus.denied) {
        final complete = total > 0 && handled >= total;
        if (complete) {
          status = ListStatus.completed;
        } else if (status == ListStatus.completed) {
          status = ListStatus.accepted;
        }
      }

      tx.update(listRef, <String, dynamic>{
        'itemCount': total,
        'doneCount': handled,
        'status': status.name,
      });
    });
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
