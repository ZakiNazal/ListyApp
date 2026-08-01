/**
 * Listy App Cloud Functions.
 *
 * One job: turn a notification document into an actual push, so the recipient
 * hears about a list even with the app closed. Everything else in the app works
 * client-side against Firestore; this is the one thing that cannot.
 *
 * Deploy:  firebase deploy --only functions
 * Requires the Blaze plan -- Cloud Functions are not available on Spark.
 */

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

const db = getFirestore();

/**
 * Fires when the app writes users/{uid}/notifications/{id} and pushes it to
 * that user's devices.
 *
 * The in-app banner and the push are driven by the same document, so there is
 * exactly one source of truth and no chance of the two disagreeing.
 */
exports.pushNotification = onDocumentCreated(
  "users/{uid}/notifications/{notificationId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const notification = snap.data();
    const { uid } = event.params;

    const userSnap = await db.collection("users").doc(uid).get();
    if (!userSnap.exists) return;

    const tokens = userSnap.get("fcmTokens") || [];
    if (tokens.length === 0) return;

    // The sender's name is nicer than a bare message, but a missing profile
    // must not stop the push.
    let title = "Listy App";
    const fromUid = notification.fromUid;
    if (fromUid) {
      const fromSnap = await db.collection("users").doc(fromUid).get();
      title = fromSnap.get("displayName") || fromSnap.get("phone") || title;
    }

    const response = await getMessaging().sendEachForMulticast({
      tokens,
      notification: { title, body: notification.message || "" },
      data: {
        listId: notification.listId || "",
        // Lets the app route straight to the list when the push is tapped.
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: { priority: "high", notification: { channelId: "listy_lists" } },
      apns: { payload: { aps: { sound: "default" } } },
    });

    // Tokens die when an app is uninstalled or reinstalled. Left in place they
    // accumulate forever and every send wastes a call, so prune the dead ones.
    const stale = [];
    response.responses.forEach((r, i) => {
      if (r.success) return;
      const code = r.error && r.error.code;
      if (
        code === "messaging/invalid-registration-token" ||
        code === "messaging/registration-token-not-registered"
      ) {
        stale.push(tokens[i]);
      }
    });

    if (stale.length > 0) {
      const { FieldValue } = require("firebase-admin/firestore");
      await userSnap.ref.update({ fcmTokens: FieldValue.arrayRemove(...stale) });
    }
  }
);
