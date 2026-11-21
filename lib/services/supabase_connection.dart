import 'package:supabase_flutter/supabase_flutter.dart';

/// Build-time configuration. Never supply a secret/service-role key here.
abstract final class SupabaseConnection {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;

  static Future<void> initialize() async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw StateError('SUPABASE_URL must be a valid HTTPS Project URL.');
    }
    if (!publishableKey.startsWith('sb_publishable_')) {
      throw StateError('Use a Supabase publishable key for this Flutter app.');
    }
    await Supabase.initialize(url: url, publishableKey: publishableKey);
  }

  static SupabaseClient get client => Supabase.instance.client;
}
