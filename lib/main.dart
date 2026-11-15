import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app_state.dart';
import 'app/router.dart';
import 'core/config/env.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/space_background.dart';
import 'features/avatar/pear_controller.dart';
import 'features/avatar/pear_touch.dart';
import 'features/checkin/presentation/checkin_controller.dart';
import 'features/voice/voice_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabaseKey);
  await initializeDateFormatting();
  final prefs = await SharedPreferences.getInstance();

  final pear = PearController();
  final voice = VoiceService(pear);
  final app = AppState(prefs, voice, pear);

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: app),
      ChangeNotifierProvider.value(value: pear),
      Provider.value(value: SkyController()),
      Provider.value(value: PearTouch(pear, voice)),
      ChangeNotifierProvider(create: (_) => CheckinController(app)),
    ],
    child: BoldPearApp(app: app),
  ));
}

class BoldPearApp extends StatefulWidget {
  const BoldPearApp({super.key, required this.app});
  final AppState app;

  @override
  State<BoldPearApp> createState() => _BoldPearAppState();
}

class _BoldPearAppState extends State<BoldPearApp> {
  late final _router = buildRouter(widget.app);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Bold Pear',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: _router,
    );
  }
}
