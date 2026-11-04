import 'package:supabase_flutter/supabase_flutter.dart';

bool supabaseReady = false;

/// Public website. Override with --dart-define=WEB_APP_URL=... for a phone on the same network.
const webAppUrl = String.fromEnvironment(
  'WEB_APP_URL',
  defaultValue: 'http://localhost:3000',
);

SupabaseClient? get supabase =>
    supabaseReady ? Supabase.instance.client : null;
