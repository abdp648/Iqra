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
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
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
                Navigator.push(context, MaterialPageRoute(builder: (context) => PageScreen(initialPage: lastPage ,)));
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
      )
    );
  }
}
