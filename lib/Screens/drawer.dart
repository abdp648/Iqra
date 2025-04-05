import 'package:flutter/material.dart';
import 'package:iqra/Screens/Azkar.dart';
import 'package:iqra/Screens/Prayer.dart';
import 'package:iqra/Screens/Qibla.dart';
import 'package:iqra/Screens/Settings.dart';
import 'package:iqra/Screens/page.dart';
import 'package:iqra/Screens/Tasbih.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:io';
import 'Home.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  _AppDrawerState createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String _username = "Guest";
  String _email = "guest@example.com";
  String? _imagePath;
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username') ?? "Guest";
      _email = prefs.getString('email') ?? "guest@example.com";
      _imagePath = prefs.getString('imagePath');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(_username),
            accountEmail: Text(_email),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.greenAccent,
              backgroundImage: _imagePath != null ? FileImage(File(_imagePath!)) : null,
              child: _imagePath == null ? Icon(Icons.person, size: 40, color: Colors.green) : null,
            ),
            decoration: BoxDecoration(color: Colors.greenAccent.shade400),
          ),
          ListTile(
            leading: const Icon(Icons.radio_button_checked, color: Colors.green),
            title: const Text("Tasbih"),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => Tasbih()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.book, color: Colors.green),
            title: const Text("Quran"),
            onTap: () {Navigator.push(context, MaterialPageRoute(builder: (context) => HomeScreen()));
            },
          ),
          ListTile(
            leading: const Icon(FontAwesomeIcons.mosque, color: Colors.green),
            title: const Text("Prayer"),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => Prayer()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.bookmark, color: Colors.green),
            title: const Text("Last Read Page"),
            onTap: () async {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              int lastPage = prefs.getInt('lastReadPage') ?? 1;
              Navigator.push(context, MaterialPageRoute(builder: (context) => PageScreen(page: lastPage ,)));
            },
          ),
          ListTile(
            leading: const Icon(FontAwesomeIcons.handsPraying, color: Colors.green),
            title: const Text("Azkar"),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => AzkarHome()));
            },
          ),
          ListTile(
            leading: const Icon(FontAwesomeIcons.compass, color: Colors.green),
            title: const Text("Qiblah"),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => Qiblah()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings, color: Colors.green),
            title: const Text("Settings"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => Settings(
                    onThemeChanged: (ThemeMode mode) {
                      setState(() {});
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
