const admin = require('firebase-admin');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');

admin.initializeApp();

exports.sendQueuedPush = onDocumentCreated('push_queue/{pushId}', async (event) => {
  const snap = event.data;
  if (!snap) return;

  const push = snap.data();
  const targetRole = push.targetRole;
  const title = push.title || 'EduTrack';
  const body = push.body || '';
  const payload = push.payload || '';

  if (!targetRole || !title || !body) {
    await snap.ref.set({
      processed: true,
      error: 'Missing targetRole, title, or body',
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    return;
  }

  const devices = await admin.firestore()
    .collection('devices')
    .where('role', '==', targetRole)
    .get();

  const tokens = devices.docs
    .map((doc) => doc.get('token'))
    .filter((token) => typeof token === 'string' && token.length > 0);

  if (tokens.length === 0) {
    await snap.ref.set({
      processed: true,
      sent: 0,
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    return;
  }

  const response = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data: {
      payload,
      targetRole,
    },
    android: {
      priority: 'high',
      notification: {
        channelId: 'edutrack_system',
        sound: 'edutrack_notification',
      },
    },
    apns: {
      payload: {
        aps: {
          sound: 'default',
          contentAvailable: true,
        },
      },
    },
  });

  await snap.ref.set({
    processed: true,
    sent: response.successCount,
    failed: response.failureCount,
    processedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
});
