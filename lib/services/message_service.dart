// lib/services/message_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MessageService {
  final SupabaseClient client = Supabase.instance.client;

  // ------------------------------------------------------------
  // GET CONVERSATION LIST (LATEST PER USER)
  // ------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getConversations(String meId) async {
    final data = await client
        .from('dm')
        .select('id, created_at, sender_id, reciver_id, message, seen')
        .or('sender_id.eq.$meId,reciver_id.eq.$meId')
        .order('created_at', ascending: false)
        .limit(200);

    final rows = (data is List) ? data : [data];
    final map = <String, Map<String, dynamic>>{};

    for (final r in rows) {
      if (r is! Map) continue;
      final msg = Map<String, dynamic>.from(r);
      final s = msg['sender_id'];
      final rcv = msg['reciver_id'];
      if (s == null || rcv == null) continue;

      final other = s == meId ? rcv : s;
      map.putIfAbsent(other, () => msg);
    }

    final out = map.values.toList();
    out.sort((a, b) => (b['created_at']).compareTo(a['created_at']));
    return out;
  }

  // ------------------------------------------------------------
  // FETCH MESSAGES FOR ONE CHAT
  // ------------------------------------------------------------
  Future<List<Map<String, dynamic>>> fetchMessages(
      String meId, String otherId) async {
    final filter =
        'and(or(sender_id.eq.$meId,reciver_id.eq.$meId),or(sender_id.eq.$otherId,reciver_id.eq.$otherId))';

    final data = await client
        .from('dm')
        .select()
        .or(filter)
        .order('created_at', ascending: true);

      return data.map((e) => Map<String, dynamic>.from(e)).toList();

  }

  // ------------------------------------------------------------
  // SEND MESSAGE
  // ------------------------------------------------------------
  Future<void> sendMessage(
      String senderId, String receiverId, String text) async {
    await client.from('dm').insert({
      'sender_id': senderId,
      'reciver_id': receiverId,
      'message': text,
      'seen': 0,
    });
  }

  // ------------------------------------------------------------
  // MARK AS SEEN
  // ------------------------------------------------------------
  Future<void> markAsSeen(String meId, String otherId) async {
    await client
        .from('dm')
        .update({'seen': 1})
        .match({'sender_id': otherId, 'reciver_id': meId})
        .eq('seen', 0);
  }

  // ------------------------------------------------------------
  // REALTIME MESSAGES FOR ONE CHAT
  // Using ONLY .stream() → filter client-side
  // ------------------------------------------------------------
  Stream<List<Map<String, dynamic>>> subscribeConversation(
      String meId, String otherId) {
    return client
        .from('dm')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .map((rows) {
      final List<Map<String, dynamic>> out = [];
      for (final r in rows) {
        if (r is! Map) continue;
        final msg = Map<String, dynamic>.from(r);
        final s = msg['sender_id'];
        final rcv = msg['reciver_id'];

        final isMine = (s == meId && rcv == otherId);
        final isTheirs = (s == otherId && rcv == meId);

        if (isMine || isTheirs) out.add(msg);
      }
      out.sort((a, b) => (a['created_at']).compareTo(b['created_at']));
      return out;
    });
  }

  // ------------------------------------------------------------
  // REALTIME UPDATES FOR CONVERSATION LIST (any DM involving me)
  // ------------------------------------------------------------
  Stream<List<Map<String, dynamic>>> subscribeConversations(String meId) {
    return client
        .from('dm')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) {
      final List<Map<String, dynamic>> out = [];
      for (final r in rows) {
        if (r is! Map) continue;
        final msg = Map<String, dynamic>.from(r);

        if (msg['sender_id'] == meId || msg['reciver_id'] == meId) {
          out.add(msg);
        }
      }
      return out;
    });
  }
}
