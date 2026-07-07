import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:samantha/cubit/chat_cubit.dart';
import 'package:samantha/models/settings.dart';
import 'package:samantha/screens/chat_screen.dart';
import 'package:samantha/screens/settings_screen.dart';
import 'package:samantha/services/websocket_service.dart';

void main() {
  runApp(const SamanthaApp());
}

class SamanthaApp extends StatelessWidget {
  const SamanthaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Samantha',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const _ConnectionGate(),
    );
  }
}

class _ConnectionGate extends StatefulWidget {
  const _ConnectionGate();

  @override
  State<_ConnectionGate> createState() => _ConnectionGateState();
}

class _ConnectionGateState extends State<_ConnectionGate> {
  late final ChatCubit _cubit;
  ConnectionSettings? _settings;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cubit = ChatCubit(WebSocketService());
    _loadSettingsAndConnect();
  }

  Future<void> _loadSettingsAndConnect() async {
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString('host');
    final port = prefs.getInt('port');

    if (host != null && port != null) {
      final settings = ConnectionSettings(host: host, port: port);
      await _cubit.connect(settings);
      setState(() {
        _settings = settings;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  void _openSettings() async {
    final settings = await Navigator.of(context).push<ConnectionSettings>(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );

    if (settings != null && mounted) {
      await _cubit.connect(settings);
      setState(() => _settings = settings);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_settings != null) {
      return _buildChatScreen();
    }

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat, size: 64),
            const SizedBox(height: 16),
            const Text('Welcome to Saman\u{1E6D}ha',
                style: TextStyle(fontSize: 24)),
            const SizedBox(height: 8),
            const Text('Configure your bridge server to get started'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _openSettings,
              icon: const Icon(Icons.settings),
              label: const Text('Configure Connection'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatScreen() {
    return BlocProvider.value(
      value: _cubit,
      child: ChatScreen(settings: _settings!),
    );
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }
}
