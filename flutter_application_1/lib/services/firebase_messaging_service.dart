// services/firebase_messaging_service.dart
//
// Handles all Firestore messaging operations.
// Used by both MessagesPage (thread list) and ChatPage (individual chat).
//
// Firestore structure:
//   /conversations/{userId}/metadata   — thread summary + unread counts
//   /conversations/{userId}/messages   — subcollection of individual messages
//
// {userId} is always the regular user's ID so it's consistent from both sides.

import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseMessagingService {
  static final _db = FirebaseFirestore.instance;

  /// Reference to a conversation document by user ID
  static DocumentReference _conv(int userId) =>
      _db.collection('conversations').doc('user_$userId');

  /// Reference to the messages subcollection
  static CollectionReference _messages(int userId) =>
      _conv(userId).collection('messages');

  // ── Send a message ──────────────────────────────────────────────────────────

  /// Send a message as a USER to admin.
  static Future<void> sendAsUser({
    required int userId,
    required String userName,
    required String text,
  }) async {
    final now = FieldValue.serverTimestamp();
    final batch = _db.batch();

    // Add the message document
    final msgRef = _messages(userId).doc();
    batch.set(msgRef, {
      'sender':      'user',
      'sender_name': userName,
      'text':        text,
      'timestamp':   now,
      'is_read':     false,
    });

    // Update thread metadata — increment admin's unread count
    batch.set(_conv(userId), {
      'user_id':       userId,
      'user_name':     userName,
      'last_message':  text,
      'last_timestamp': now,
      'unread_admin':  FieldValue.increment(1), // admin has a new message
      'unread_user':   0,                        // user sent it, so not unread for them
    }, SetOptions(merge: true));

    await batch.commit();
  }

  /// Send a message as ADMIN to a user.
  static Future<void> sendAsAdmin({
    required int userId,
    required String text,
    String adminName = 'Admin',
  }) async {
    final now = FieldValue.serverTimestamp();
    final batch = _db.batch();

    final msgRef = _messages(userId).doc();
    batch.set(msgRef, {
      'sender':      'admin',
      'sender_name': adminName,
      'text':        text,
      'timestamp':   now,
      'is_read':     false,
    });

    batch.set(_conv(userId), {
      'last_message':   text,
      'last_timestamp': now,
      'unread_user':    FieldValue.increment(1), // user has a new message
      'unread_admin':   0,
    }, SetOptions(merge: true));

    await batch.commit();
  }

  static Stream<QuerySnapshot> conversationsStream() =>
      _db.collection('conversations')
         .orderBy('last_timestamp', descending: true)
         .snapshots();

  
  static Stream<DocumentSnapshot> userConversationStream(int userId) =>
      _conv(userId).snapshots();

  /// Real-time stream of messages for a conversation — used by ChatPage.
  static Stream<QuerySnapshot> messagesStream(int userId) =>
      _messages(userId)
          .orderBy('timestamp', descending: false)
          .snapshots();

  
  static Future<void> markReadByUser(int userId) async {
    // Reset the unread counter in metadata
    await _conv(userId).set({'unread_user': 0}, SetOptions(merge: true));

    // Mark individual unread messages sent by admin as read
    final unread = await _messages(userId)
        .where('sender',  isEqualTo: 'admin')
        .where('is_read', isEqualTo: false)
        .get();

    final batch = _db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'is_read': true});
    }
    await batch.commit();
  }

 
  static Future<void> markReadByAdmin(int userId) async {
    await _conv(userId).set({'unread_admin': 0}, SetOptions(merge: true));

    final unread = await _messages(userId)
        .where('sender',  isEqualTo: 'user')
        .where('is_read', isEqualTo: false)
        .get();

    final batch = _db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'is_read': true});
    }
    await batch.commit();
  }

 

  
  static Stream<int> unreadCountForUser(int userId) =>
      _conv(userId).snapshots().map((snap) {
        if (!snap.exists) return 0;
        final data = snap.data() as Map<String, dynamic>;
        return (data['unread_user'] as int?) ?? 0;
      });
}
