import 'package:flutter/material.dart';

import 'theme/hellbound_theme.dart';
import 'hellbound.dart';

class MainApp extends StatelessWidget {
  const MainApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Hellbound — Make a Pact',
    debugShowCheckedModeBanner: false,
    theme: HellboundTheme.dark,
    home: const Hellbound(),
  );
}
