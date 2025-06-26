import 'package:flutter/material.dart';
import 'pages_quran_screen.dart';
import 'surahs_quran_screen.dart';
import 'drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const PagesQuran(),
    const SurahsQuran(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text("Quran"),
        backgroundColor: isDarkMode ? Colors.green.shade900 : Colors.greenAccent.shade400,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
        ),

      ),
      drawer: const AppDrawer(),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: isDarkMode ? Colors.greenAccent.shade200 : Colors.green,
        unselectedItemColor: isDarkMode ? Colors.grey.shade400 : Colors.grey,
        backgroundColor: isDarkMode ? Colors.grey.shade900 : Colors.white,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.auto_stories), label: "Pages"),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: "Surahs"),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
    );
  }
}
