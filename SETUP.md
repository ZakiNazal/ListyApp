# Listy App — setup

Built from the Figma file `nfGefk8nTFQFgI1ZITLLiX`. English only, Phone (OTP)
auth, Riverpod, Firebase project `listyapp-29eee`.

## 1. Install dependencies

```bash
flutter pub get
```

If version resolution fails (the pinned versions may have moved on), let pub
pick current ones instead:

```bash
flutter pub add firebase_core firebase_auth cloud_firestore \
  flutter_riverpod go_router flutter_contacts \
  url_launcher google_fonts shared_preferences
```

Do **not** add `share_plus` or `permission_handler`. Both were tried and both
break this build:

- `share_plus` has not migrated its Android build to AGP 9's built-in Kotlin
  support and fails to compile its own Kotlin sources
  ([plus_plugins#3745](https://github.com/fluttercommunity/plus_plugins/issues/3745)).
  Downgrading AGP is not a fix, because `flutter_contacts` 2.2+ *requires*
  built-in Kotlin — the two have mutually exclusive Gradle requirements.
  The "Invite" action uses `url_launcher` with an `sms:` URI instead.
- `permission_handler` demands `compileSdk 37` and is redundant now that
  `FlutterContacts.permissions` exists.

Note on `flutter_contacts`: this project targets **2.x**, which is a full rewrite
of the 1.x API. `getContacts()` became `getAll(properties: {...})`,
`requestPermission()` became `FlutterContacts.permissions.request(...)`, and
`contact.photo` is now a `Photo` object rather than raw bytes. 2.2.0+ also
requires Flutter 3.44+. If you ever downgrade to 1.x, `ContactsRepository` is
the only file that needs changing.

No separate permissions plugin is required — `FlutterContacts.permissions`
covers request, check, and opening system settings.

## 2. Firebase console — three things to switch on

FlutterFire is already configured (`lib/firebase_options.dart` and
`android/app/google-services.json` are present), but the backend still needs:

**a. Phone sign-in**
Authentication → Sign-in method → **Phone** → Enable.
Under *Phone numbers for testing*, add a fake number and code so you can develop
without burning SMS quota.

**b. Android SHA fingerprints — this is the one that catches people**

Firebase will not send an SMS until it can prove the request came from your app
rather than from someone who extracted the API key out of your APK. The proof is
your signing certificate: Play Integrity attests the package name + certificate
hash to Firebase, which compares it against the fingerprints you registered here.

No fingerprint means that check fails, Firebase drops to a reCAPTCHA webview
fallback, and the redirect back into the app frequently doesn't complete — so
the button appears to do nothing and no SMS arrives. The app surfaces this as
*"This device could not be verified"* (see `AuthRepository._messageFor`).

Get the fingerprints:

```bash
cd android
./gradlew signingReport      # Windows: gradlew signingReport
```

Add **both** the SHA-1 and SHA-256 from the `debug` variant under
Project settings → Your apps → Android → Add fingerprint. SHA-256 drives Play
Integrity; SHA-1 covers the older SafetyNet path and Google Sign-In.

Debug fingerprints registered for this project:

```
SHA-1    13:B0:48:F8:B2:65:76:C4:18:E5:34:BA:55:4F:0A:6D:2A:3F:A6:96
SHA-256  92:4A:B6:54:51:90:6D:A6:1A:15:43:39:AC:B2:C8:23:22:3F:E8:8D:05:9F:30:F7:34:64:89:E9:87:BC:63:46
```

The check is server-side, so this takes effect within a minute and needs no
rebuild. You do **not** have to re-download `google-services.json` for phone
auth to work. Re-download it only if you later add Google Sign-In, which reads
the `oauth_client` array that registering a SHA-1 populates (it is currently
empty).

Before shipping you will also need the **release** fingerprints — from your
upload keystore, plus the Play App Signing certificate that Play Console
generates after your first upload. Debug fingerprints only cover `flutter run`.

**c. Firestore**
Firestore Database → Create database → production mode → nearest region.

## 3. Deploy rules and indexes

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

Or paste `firestore.rules` into the console by hand. The composite index in
`firestore.indexes.json` is required — `watchLists` combines `arrayContains`
with `orderBy`, which Firestore cannot serve unindexed. Without it the Home and
Item Lists screens error out with a link to create it.

## 4. iOS (skip if Android only)

- `flutterfire configure` did not write `ios/Runner/GoogleService-Info.plist`.
  Re-run it with iOS selected, or download the plist from the console and add it
  to the Runner target in Xcode.
- Phone auth needs an APNs auth key uploaded under Project settings → Cloud
  Messaging, plus the Push Notifications capability on the Runner target.
- `NSContactsUsageDescription` is already in `Info.plist`.

## 5. Run

```bash
flutter analyze
flutter test
flutter run
```

## Data model

```
users/{uid}
  phone         E.164, e.g. +966501234567   <- the contacts picker matches on this
  displayName
  photoUrl
  createdAt

lists/{listId}
  title
  ownerUid
  assignedToUid
  memberUids[]   [owner, assignee]          <- what the security rules check
  itemCount      denormalised for the Home stat cards
  status         pending | accepted | completed
  createdAt

lists/{listId}/items/{itemId}
  name
  quantity
  done           flipped from the list detail screen; streams to both people
  createdAt

invites/{inviteId}
  invitedByUid   private to the inviter
  name
  phone          E.164
  acceptedUid    set once someone with this number registers
  createdAt
```

## How sending works

1. **Request** tab: name the list, pick a registered contact, add items.
2. `ListRepository.createList` writes the list and every item in one atomic
   batch, with `memberUids: [you, them]`. A list can never land in Firestore
   without its contents.
3. The recipient's app is already listening on
   `where('memberUids', arrayContains: uid)`, so it appears immediately — no
   push notification needed while the app is open.
4. Either person opens the list and ticks items off. `done` streams both ways,
   so progress stays in sync live.

`memberUids` is what the security rules check, which is why it must always
contain both people.

## How the contacts matching works

1. `flutter_contacts` reads the device address book.
2. Every number is folded to E.164 by `PhoneUtils.normalize`, using the dial
   code of the signed-in user's own number. `0501234567`, `+966 50 123 4567` and
   `00966501234567` all collapse to `+966501234567`.
3. Those numbers are queried against `users.phone` in chunks of 30 (Firestore's
   `whereIn` cap), run concurrently.
4. Matches render as tappable rows under **On Listy**; the rest render with the
   blue **Invite** link under **Invite to Listy**, exactly the two row states in
   the Figma frame.

Worth knowing: the rules let any signed-in user read `users`, which is required
for step 3 and means a client can test whether a given number is registered.
That's the same trade-off WhatsApp and Signal make. To close it, move the match
into a callable Cloud Function and tighten the rule to `isSelf(uid)`.

## Icons and logo

The supplied artwork in `assets/` replaces the Material icons that stood in for
it. Paths live in `lib/core/constants/app_assets.dart` — filenames contain
spaces, and a mistyped asset path fails at runtime rather than compile time, so
nothing references them as string literals.

`AppIcon` (`lib/widgets/app_icon.dart`) renders either format and tints via a
colour filter, which is what drives the active/inactive nav states — the glyphs
are monochrome, so there is no separate "selected" artwork.

| Asset | Used for |
|---|---|
| `logo/Logo.png` | splash, language, login, OTP, About |
| `icons/Home.png` | bottom nav Home |
| `icons/Add documents.png` | bottom nav Request, drawer Requests, Upcoming Lists |
| `icons/Profile.png` | bottom nav Profile, drawer Profile, Invited Friends |
| `icons/Menu.png` | app bar hamburger |
| `icons/Basics.png` | app bar bell, Notifications rows |
| `icons/Clipboard menu.svg` | Number of Lists card, Item Lists, My Lists |
| `icons/Game objects.svg` | Number of Items card |

Material icons remain where no artwork was supplied: back arrows, chevrons,
checkboxes, the quantity stepper's +/−, search, and delete.

Two things worth knowing:

- **The PNGs are a single 24×24 resolution** with no `@2x` / `@3x` variants, so
  they are upscaled on high-density screens and will look slightly soft.
  `FilterQuality.medium` reduces the stair-stepping. Exporting 2x and 3x from
  Figma into `assets/icons/2.0x/` and `3.0x/` (same filenames) would fix it —
  Flutter picks the right one automatically, no code change.
- **`flutter_svg` is required** for the two SVGs. It is pure Dart with no
  Android module, so unlike `share_plus` it is unaffected by AGP 9.

## Deviations from the Figma file

| Figma | Built as | Why |
|---|---|---|
| Login and confirmation frames in Arabic | English | Brief specifies English only |
| Logo wordmark "وان ماب" | "Listy App" | Same |
| Design 23 menu: Checks, Bills, Beneficiaries, Currency Calculator… | My Lists, Requests, Notifications, Profile + SETTINGS group | Banking placeholders from the source UI kit; replaced with this app's real screens |
| Design 23 active item in green | Orange (`#EE492E`) | Every other frame uses the orange `Static` token |
| No OTP screen in the file | Built one from the file's tokens | Phone auth cannot work without it |
| Language screen offers Arabic | Present but disabled | English-only build |
| About Us frame is empty | Placeholder copy | Swap in the real text when you have it |

Designs 22 and 24 were left unbuilt — you picked 23.
