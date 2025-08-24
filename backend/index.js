const express = require('express');
const cors = require('cors');
const admin = require('firebase-admin');

// --- Initialization ---
const serviceAccountKeyPath = process.env.RENDER_SECRET_FILE_PATH || './serviceAccountKey.json';

const serviceAccount = require(serviceAccountKeyPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

// Get a reference to the Firestore database
const db = admin.firestore();

const app = express();
app.use(cors());
app.use(express.json());

// --- Firestore Configuration ---
// We will store the token in a specific document for easy retrieval.
// Collection: 'devices', Document: 'primary_receiver'
const receiverDeviceRef = db.collection('devices').doc('primary_receiver');


// --- API Endpoints ---

// Endpoint for the Receiver app to register its FCM token
app.post('/register-device', async (req, res) => {
  const { token } = req.body;
  if (!token) {
    return res.status(400).send({ message: 'Token is required.' });
  }

  try {
    // Save the token to Firestore, overwriting any existing one.
    // We also add a timestamp for debugging purposes.
    await receiverDeviceRef.set({
      token: token,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`✅ Firestore: Updated token for primary_receiver.`);
    res.status(200).send({ message: 'Device token saved successfully in Firestore.' });
  } catch (error) {
    console.error('❌ Firestore Error: Failed to save token:', error);
    res.status(500).send({ message: 'Failed to save token.' });
  }
});

// Endpoint for the Sender app's NORMAL button
app.post('/send-normal', async (req, res) => {
  try {
    // 1. Retrieve the token from Firestore
    const doc = await receiverDeviceRef.get();

    if (!doc.exists) {
      console.log(' Firestore: No document found for primary_receiver. Cannot send notification.');
      return res.status(400).send({ message: 'No receiver device is registered in Firestore.' });
    }

    const receiverToken = doc.data().token;

    // 2. Send the notification (same logic as before)
    console.log('-> Received request for a NORMAL ping.');
    const message = {
      notification: {
        title: 'Ping! 👋',
        body: 'Just letting you know I\'m thinking of you.',
      },
      token: receiverToken,
    };

    await admin.messaging().send(message);
    console.log('✅ Normal notification sent successfully.');
    res.status(200).send({ message: 'Normal notification sent.' });

  } catch (error) {
    console.error('❌ Error sending normal notification:', error);
    res.status(500).send({ message: 'Error processing request.' });
  }
});

// Endpoint for the Sender app's PANIC button
app.post('/send-panic', async (req, res) => {
  try {
    // 1. Retrieve the token from Firestore
    const doc = await receiverDeviceRef.get();

    if (!doc.exists) {
      console.log(' Firestore: No document found for primary_receiver. Cannot send notification.');
      return res.status(400).send({ message: 'No receiver device is registered in Firestore.' });
    }

    const receiverToken = doc.data().token;

    // 2. Send the notification (same logic as before)
    console.log('-> Received request for a PANIC alert!');
    const message = {
      data: { type: 'panic' },
      notification: {
        title: '🚨 PANIC ALERT! 🚨',
        body: 'This is an urgent alert. Please check in immediately.',
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'alarm',
          channelId: 'high_importance_channel',
        },
      },
      token: receiverToken,
    };

    await admin.messaging().send(message);
    console.log('✅ Panic notification sent successfully.');
    res.status(200).send({ message: 'Panic notification sent.' });

  } catch (error) {
    console.error('❌ Error sending panic notification:', error);
    res.status(500).send({ message: 'Error processing request.' });
  }
});

const port = 3000;
app.listen(port, () => {
  console.log(`🚀 Server is running on http://localhost:${port}`);
});