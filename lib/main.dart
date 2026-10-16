import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Endless runner is portrait-only.
  await SystemChrome.setPreferredOrientations(
    const [DeviceOrientation.portraitUp],
  );
  runApp(const SoulDuskRunApp());
}
