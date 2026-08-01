# Listy App — setup and architecture

Firebase project `listyapp-29eee`. Phone (OTP) auth, Riverpod, English only.

## Deploy after pulling these changes

```bash
flutter pub get                                    # firebase_messaging is new
firebase deploy --only firestore:rules,firestore:indexes

cd functions && npm install && cd ..
firebase deploy --only functions                   # requires the Blaze plan

flutter clean && flutter run
```

Rules **must** be redeployed — items now carry `ownerUid`, and lists carry
`hiddenFor`, both of which the new rules require.

## Push notifications

Everything else runs client-side against Firestore. Push is the one thing that
cannot: a notification has to reach someone whose app is closed.

`functions/index.js` triggers on `users/{uid}/notifications/{id}` and pushes to
that user's `fcmTokens`. The in-app banner and the push are driven by the same
document, so they can never disagree. Dead tokens are pruned on send.

Without Blaze the app still works — the in-app banner fires whenever the app is
open — but a closed app hears nothing.

iOS additionally needs an APNs auth key under Project settings → Cloud
Messaging, plus the Push Notifications capability on the Runner target.

## Status lifecycle

```
pending ──accept──> accepted ──all items handled──> completed
   │                    ▲                                │
   └──deny──> denied ───┘                       un-tick an item
              (recipient can undo)                       │
                                              accepted <─┘
```

`completed` is set inside the transaction in `updateItemState`, never by the UI.
That means it is decided from real server state and its notification fires
exactly once, however many devices are ticking at the same time.

Denied and completed lists are excluded from the Home counters and from Upcoming
Lists — a refused list is not outstanding work.

## Data model

```
users/{uid}
  phone                  E.164 — what the contacts picker matches on
  displayName, photoUrl
  lastSeenNotifications
  fcmTokens[]            one entry per signed-in device

users/{uid}/notifications/{id}
  fromUid                pinned by rules to the real author
  listId, message, isRead, createdAt

lists/{listId}
  title, ownerUid, assignedToUid
  memberUids[]           what the rules check
  itemCount, doneCount   denormalised; doneCount owned by updateItemState
  status                 pending | accepted | denied | completed
  hiddenFor[]            per-user dismissal
  createdAt              pinned by rules — the edit window is measured from it
  lastActivityAt, ownerReadAt, assigneeReadAt

lists/{listId}/items/{itemId}
  name, quantity, done, isMissing
  memberUids[]           denormalised — see below
  ownerUid               denormalised — see below
```

### Why membership is duplicated onto items

Two independent reasons, both learned the hard way:

1. **`get()` sees pre-batch state.** `createList` writes the list and its items
   in one atomic batch. A rule that reads the parent with `get()` finds nothing,
   denies every item, and fails the whole batch.
2. **Rules constrain queries, they do not filter them.** Firestore rejects any
   query it cannot statically prove will only return permitted documents. The
   items query therefore *must* carry `.where('memberUids', arrayContains: uid)`
   — that constraint is what makes the read rule provable.

`ownerUid` is on items for the same reason: checking it via `get()` would bill a
document read on every single tick and on every item of a list being deleted.

Both are safe to duplicate because the rules forbid ever changing `memberUids`
or `ownerUid` after creation, so the copies cannot drift.

## Sender / receiver rules of engagement

| | Sender (owner) | Receiver (assignee) |
|---|---|---|
| Edit title/items | yes, 15 min from creation | never |
| Tick / mark missing | never | yes |
| Accept / deny | never | yes, and may undo a denial |
| Delete for both | yes | never |
| Hide for self | yes | yes (`hiddenFor`) |

The 15-minute window is enforced in `firestore.rules`, not just the UI —
previously anyone calling the SDK directly could rewrite a list forever.

## Known limitations

- `reconcileCounts` reads every item on the list; fine at this size, would need
  a counter shard if lists ever got very large.
- No pagination anywhere. `watchListsWithItems` fans out one query per list.
- Denial has no reason attached.
- `hiddenFor` is filtered client-side; Firestore has no "array does not contain".
