import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pact.dart';

class HellboundRepository {
  final SupabaseClient client;
  HellboundRepository(this.client);
  String get uid => client.auth.currentUser!.id;
  Future<List<Map<String, dynamic>>> users() async =>
      await client.from('user').select('id,username').order('username');
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final text = query.trim();
    if (text.isEmpty) return [];
    final escaped = text
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    return await client
        .from('user')
        .select('id,username')
        .ilike('username', '%$escaped%')
        .order('username')
        .order('id')
        .limit(20);
  }

  Future<Map<String, dynamic>> profile() async =>
      await client.from('user').select().eq('id', uid).single();
  Future<Map<String, dynamic>> settings() async =>
      await client.from('user_settings').select().eq('user_id', uid).single();
  Future<void> saveSettings(List<bool> v) async => await client
      .from('user_settings')
      .update({
        'deadline_reminders': v[0],
        'pact_invitations': v[1],
        'verification_results': v[2],
      })
      .eq('user_id', uid);
  Future<void> saveProfile(String name, String email) async {
    await client.from('user').update({'username': name}).eq('id', uid);
    if (email != client.auth.currentUser!.email) {
      await client.auth.updateUser(UserAttributes(email: email));
    }
  }

  Future<List<Map<String, dynamic>>> notifications() async => await client
      .from('notifications')
      .select()
      .order('created_at', ascending: false);
  Future<void> markRead(String id) async => await client
      .from('notifications')
      .update({'read_at': DateTime.now().toUtc().toIso8601String()})
      .eq('id', id);
  Future<List<Map<String, dynamic>>> wall() async =>
      List<Map<String, dynamic>>.from(
        await client.rpc('hellbound_wall_of_shame'),
      );
  static const statuses = {
    'awaiting_acceptance': 'Awaiting Acceptance',
    'active': 'Active',
    'under_verification': 'Under Verification',
    'completed': 'Completed',
    'breached': 'Breached',
    'declined': 'Declined',
  };
  static const types = {
    'photo': 'Photo',
    'text': 'Text',
    'photo_or_text': 'Photo or Text',
  };
  static const consequences = {
    'funny_forfeit': 'Funny Forfeit',
    'private_shame_card': 'Private Shame Card',
    'app_ban': '24-Hour App Ban',
  };
  Future<void> expireDue() async => await client.rpc('hellbound_expire_due');

  Future<List<Pact>> pacts() async {
    final people = {
      for (final u in await users()) u['id'] as String: u['username'] as String,
    };
    final rows = await client
        .from('pacts')
        .select(
          '*,pact_members(*),evidence_submissions(*),pact_activities(*),app_bans(*)',
        )
        .order('created_at', ascending: false);
    return rows.map((row) => parsePact(row, people)).toList();
  }

  static Pact parsePact(Map<String, dynamic> row, Map<String, String> people) {
    final members = List<Map<String, dynamic>>.from(row['pact_members']);
    String roleId(String role) =>
        members.firstWhere((m) => m['role'] == role)['user_id'] as String;
    final r = roleId('responsible'), v = roleId('verifier');
    final p = Pact(
      row['title'],
      row['description'],
      DateTime.parse(row['deadline']).toLocal(),
      responsible: people[r] ?? 'Mortal',
      verifier: people[v] ?? 'Mortal',
      witnesses: members
          .where((m) => m['role'] == 'witness')
          .map((m) => people[m['user_id']] ?? 'Mortal')
          .toList(),
      proof: row['evidence_requirement'],
      evidenceType: types[row['evidence_type']]!,
      consequence: consequences[row['consequence_type']]!,
      detail: row['consequence_detail'],
      audience: row['announcement_audience'] == 'community'
          ? 'Hellbound Community'
          : 'Pact Members Only',
      status: statuses[row['status']]!,
    );
    p.id = row['id'];
    p.responsibleId = r;
    p.verifierId = v;
    p.memberIds.addAll(members.map((m) => m['user_id'] as String));
    p.acceptedBy.addAll(
      members
          .where((m) => m['acceptance_status'] == 'accepted')
          .map((m) => m['user_id'] as String),
    );
    final activity = List<Map<String, dynamic>>.from(row['pact_activities'])
      ..sort((a, b) => (a['created_at'] as String).compareTo(b['created_at']));
    p.activity
      ..clear()
      ..addAll(
        activity.map(
          (a) =>
              '${a['description']} · ${DateTime.parse(a['created_at']).toLocal()}',
        ),
      );
    final submissions =
        List<Map<String, dynamic>>.from(row['evidence_submissions'])..sort(
          (a, b) => (b['submitted_at'] as String).compareTo(a['submitted_at']),
        );
    if (submissions.isNotEmpty) {
      final e = submissions.first;
      p.evidence = e['text_content'] ?? '';
      p.notes = e['review_notes'] ?? '';
      p.photoPath = e['photo_path'];
    }
    // pact_id is UNIQUE: PostgREST embeds this relation as an object/null.
    final ban = row['app_bans'] as Map<String, dynamic>?;
    if (ban != null) {
      p.bannedUntil = DateTime.parse(ban['ends_at']).toLocal();
    }
    return p;
  }

  Future<String> create(Pact p) async => await client.rpc(
    'hellbound_create_pact',
    params: {
      'payload': {
        'title': p.title,
        'description': p.description,
        'deadline': p.deadline.toUtc().toIso8601String(),
        'responsible_id': p.responsible,
        'verifier_id': p.verifier,
        'witness_ids': p.witnesses,
        'evidence_type': types.entries
            .firstWhere((e) => e.value == p.evidenceType)
            .key,
        'evidence_requirement': p.proof,
        'consequence_type': consequences.entries
            .firstWhere((e) => e.value == p.consequence)
            .key,
        'consequence_detail': p.detail,
        'announcement_audience': p.consequence == 'Private Shame Card'
            ? (p.audience == 'Hellbound Community'
                  ? 'community'
                  : 'pact_members')
            : null,
      },
    },
  ) as String;
  Future<void> respond(Pact p, bool accept) async => await client.rpc(
    'hellbound_respond',
    params: {'pact': p.id, 'accept': accept},
  );
  Future<void> review(Pact p, bool approve, String notes) async =>
      await client.rpc(
        'hellbound_review',
        params: {'pact': p.id, 'approve': approve, 'notes': notes},
      );
  Future<Uint8List> photo(String path) =>
      client.storage.from('pact-evidence').download(path);
  Future<void> submit(
    Pact p,
    String text,
    Uint8List? bytes,
    String mime,
  ) async {
    String? path;
    if (bytes != null) {
      final ext = {
        'image/png': 'png',
        'image/jpeg': 'jpg',
        'image/webp': 'webp',
      }[mime];
      if (ext == null || bytes.length > 10485760) {
        throw StateError('Choose a PNG, JPEG or WebP under 10 MiB.');
      }
      path = '$uid/${p.id}/${DateTime.now().microsecondsSinceEpoch}.$ext';
      await client.storage
          .from('pact-evidence')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: mime),
          );
    }
    // On a timeout the server may have committed. Do not delete evidence automatically.
    await client.rpc(
      'hellbound_submit_evidence',
      params: {'pact': p.id, 'body': text, 'photo': path},
    );
  }
}
