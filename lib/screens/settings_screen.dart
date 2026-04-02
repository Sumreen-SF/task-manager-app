import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedSound = "default";

  final List<Map<String, String>> _sounds = [
    {"key": "default", "name": "Default System Sound"},
    {"key": "sound_01", "name": "Sound 01"},
    {"key": "sound_02", "name": "Sound 02"},
    {"key": "sound_03", "name": "Sound 03"},
    {"key": "sound_04", "name": "Sound 04"},
    {"key": "sound_05", "name": "Sound 05"},
    {"key": "sound_06", "name": "Sound 06"},
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedSound();
  }

  Future<void> _loadSavedSound() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedSound = prefs.getString('notification_sound') ?? "default";
    });
  }

  Future<void> _saveSound(String soundKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notification_sound', soundKey);
    setState(() => _selectedSound = soundKey);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Notification sound updated to ${_sounds.firstWhere((s) => s['key'] == soundKey)['name']}"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Theme Section
          Card(
            child: Column(
              children: [
                const ListTile(
                  title: Text("Appearance", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                SwitchListTile(
                  title: const Text("Dark Mode"),
                  subtitle: const Text("Switch between light and dark theme"),
                  value: themeProvider.themeMode == ThemeMode.dark,
                  onChanged: (val) => themeProvider.toggleTheme(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Notification Sound Section with Preview
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ListTile(
                  title: Text("Notification Sound", style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Choose sound for task reminders (tap to preview)"),
                ),
                ..._sounds.map((soundMap) {
                  final key = soundMap["key"]!;
                  final name = soundMap["name"]!;

                  return RadioListTile<String>(
                    title: Text(name),
                    value: key,
                    groupValue: _selectedSound,
                    onChanged: (value) async {
                      if (value != null) {
                        await _saveSound(value);

                        // Play preview
                        if (value != "default") {
                          await NotificationService.showNotification(
                            id: 10000 + DateTime.now().millisecond,
                            title: "Sound Preview",
                            body: "This is how '$name' will sound for reminders",
                            sound: value,
                          );
                        }
                      }
                    },
                  );
                }).toList(),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Text(
            "Note: Changes will apply to future notifications.\nPreview may take a second to play.",
            style: TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}