import 'package:supabase_flutter/supabase_flutter.dart';

bool supabaseReady = false;

/// Public website opened by the Home globe/web icon (same role as Cupid’s site link).
/// Override with --dart-define=WEB_APP_URL=... (production Vercel URL or LAN next server).
const webAppUrl = String.fromEnvironment(
  'WEB_APP_URL',
  defaultValue: 'https://wendo-love.vercel.app',
);

SupabaseClient? get supabase =>
    supabaseReady ? Supabase.instance.client : null;
