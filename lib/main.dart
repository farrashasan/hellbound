import 'package:flutter/material.dart';

import 'app.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://hiylifyttpubzqedkajt.supabase.co',
    publishableKey: 'sb_publishable_k6TrmqIS1z0zDpw7NmvBPQ_mgIFxgw_',
  );
  runApp(const MainApp());
}
