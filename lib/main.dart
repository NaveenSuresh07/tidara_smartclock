import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/audio/horological_audio_engine.dart';
import 'core/security/encrypted_vault.dart';
import 'features/shell/tidara_shell_screen.dart';
import 'models/horological_models.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ensureTimeZonesInitialized();
  await EncryptedVault.initDurablePersistenceAsync();
  await HorologicalAudioEngine.instance.ensurePresetWavFilesExist('');
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const TidaraSmartclockApp());
}
