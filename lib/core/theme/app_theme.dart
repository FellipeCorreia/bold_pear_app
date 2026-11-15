import 'package:material_ui/material_ui.dart';

import 'pi_cores.dart';

ThemeData buildTheme() {
  const radius = BorderRadius.all(Radius.circular(16));
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: PiCores.fundo,
    colorScheme: const ColorScheme.dark(
      primary: PiCores.lima,
      onPrimary: PiCores.textoSobreLima,
      secondary: PiCores.laranja,
      surface: PiCores.painel,
      onSurface: PiCores.texto,
      error: PiCores.bochecha,
    ),
    textTheme: base.textTheme.apply(bodyColor: PiCores.texto, displayColor: PiCores.texto),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: PiCores.lima,
        foregroundColor: PiCores.textoSobreLima,
        minimumSize: const Size(0, 54),
        padding: const EdgeInsets.symmetric(horizontal: 26),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: PiCores.texto,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        side: const BorderSide(color: PiCores.borda, width: 1.5),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: PiCores.lima,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: PiCores.fundo2,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: PiCores.borda)),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: PiCores.borda, width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: PiCores.lima, width: 2)),
      labelStyle: TextStyle(color: PiCores.textoSuave),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
