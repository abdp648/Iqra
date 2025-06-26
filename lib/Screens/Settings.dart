import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings extends StatefulWidget {
  final Function(ThemeMode) onThemeChanged;

  const Settings({super.key, required this.onThemeChanged});

  @override
  State<Settings> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<Settings> {
  ThemeMode? _themeMode;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool? savedTheme = prefs.getBool('Theme');
    setState(() {
      _themeMode = savedTheme == null
          ? ThemeMode.system
          : (savedTheme ? ThemeMode.dark : ThemeMode.light);
    });
  }

  Future<void> _setTheme(ThemeMode mode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (mode == ThemeMode.system) {
      await prefs.remove('Theme');
    } else {
      await prefs.setBool('Theme', mode == ThemeMode.dark);
    }
    setState(() {
      _themeMode = mode;
    });

    widget.onThemeChanged(mode); // Notify main app
  }

  Widget _buildOption(String label, ThemeMode value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.black54 : Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: RadioListTile<ThemeMode>(
          value: value,
          groupValue: _themeMode,
          onChanged: (mode) => _setTheme(mode!),
          title: Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.greenAccent : Colors.green,
            ),
          ),
          activeColor: isDark ? Colors.greenAccent : Colors.green,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: isDark ? Colors.green.shade900 : Colors.greenAccent.shade400,
        elevation: 5,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [Colors.green.shade900, Colors.green.shade700]
                : [Colors.green.shade200, Colors.green.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildOption("System Default", ThemeMode.system, isDark),
            _buildOption("Light Mode", ThemeMode.light, isDark),
            _buildOption("Dark Mode", ThemeMode.dark, isDark),
            const SizedBox(height: 30),
            Icon(
              Icons.color_lens_rounded,
              size: 50,
              color: isDark ? Colors.greenAccent : Colors.white,
            ),
            const SizedBox(height: 10),
            Text(
              "Choose App Theme",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.greenAccent : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
