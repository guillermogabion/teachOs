import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:teacheros/core/database/database_service.dart';
import 'package:teacheros/features/dashboard/dashboard_screen.dart';
import 'package:teacheros/services/backup_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://elzeaiveldahaoquolmz.supabase.co',
    publishableKey: 'sb_publishable_FV9a7dWbHdOa65wlC6LEOA_cxbFWoEd',
  );

  await DatabaseService.instance.database;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TeacherOS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const AutoSyncWrapper(),
    );
  }
}

class _AutoSyncWrapperState extends State<AutoSyncWrapper>
    with WidgetsBindingObserver {
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncAfterDbReady(); // ✅ waits for DB before syncing
    _startTimer();
  }

  // ✅ Always await DB before syncing
  Future<void> _syncAfterDbReady() async {
    await DatabaseService.instance.database;
    autoSyncIfBackupExists();
  }

  void _startTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 15), (_) async {
      debugPrint('Auto-upload: 15-min tick — uploading...');
      await DatabaseService.instance.database; // ✅ guard every tick
      autoSyncIfBackupExists();
    });
  }

  void _stopTimer() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('App foregrounded — resuming auto-upload timer');
      _syncAfterDbReady(); // ✅ waits for DB before syncing
      _startTimer();
    } else if (state == AppLifecycleState.paused) {
      debugPrint('App backgrounded — pausing auto-upload timer');
      _stopTimer();
    }
  }

  @override
  void dispose() {
    _stopTimer();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const DashboardScreen();
}

// ✅ Don't forget to keep the StatefulWidget class itself
class AutoSyncWrapper extends StatefulWidget {
  const AutoSyncWrapper({super.key});

  @override
  State<AutoSyncWrapper> createState() => _AutoSyncWrapperState();
}
