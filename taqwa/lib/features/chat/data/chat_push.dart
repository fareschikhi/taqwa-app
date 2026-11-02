import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The `data` of every push that arrives while the app is open.
///
/// A provider rather than a direct `FirebaseMessaging.onMessage` call, so a
/// screen can be tested without Firebase (override it with an empty stream).
/// The web build never starts Firebase, so it gets nothing.
final chatPushesProvider = Provider<Stream<Map<String, dynamic>>>((ref) {
  if (kIsWeb) return const Stream.empty();
  return FirebaseMessaging.onMessage.map((m) => m.data);
});

/// Whether push [data] is about the chat thread of [parentId] (staff), or
/// about the parent's own thread when [parentId] is null.
bool isChatPushFor(Map<String, dynamic> data, int? parentId) {
  if (data['route'] != 'chat') return false;
  return parentId == null || data['parentId'] == '$parentId';
}
