import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:iqra/screens/Azkar_Details.dart';
import 'package:iqra/models/Azkar_Model.dart';

class AzkarHome extends StatefulWidget {
  const AzkarHome({Key? key}) : super(key: key);

  @override
  _AzkarHomeState createState() => _AzkarHomeState();
}

class _AzkarHomeState extends State<AzkarHome> {
  List<SectionModel> sections = [];
  List<SectionModel> filteredSections = [];
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadSections();
    searchController.addListener(_filterSections);
  }

  @override
  void dispose() {
    searchController.removeListener(_filterSections);
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Azkar"),
        backgroundColor: isDarkMode ? Colors.green.shade900 : Colors.greenAccent.shade400,
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Search TextField with theme-based customization
            TextField(
              controller: searchController,
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
              decoration: InputDecoration(
                labelText: "Search",
                prefixIcon: Icon(Icons.search, color: isDarkMode ? Colors.white70 : Colors.black54),
                labelStyle: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54),
                filled: true,
                fillColor: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Display filtered results in the ListView
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: filteredSections.length,
                itemBuilder: (context, index) => buildSectionItem(
                  model: filteredSections[index],
                  isDarkMode: isDarkMode,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSectionItem({required SectionModel model, required bool isDarkMode}) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SectionDetailScreen(
              id: model.id!,
              title: model.category!,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode
                ? [Colors.green.shade800, Colors.green.shade600]
                : [Colors.lightGreenAccent.shade100, Colors.greenAccent],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const Icon(Icons.menu_book_rounded, size: 40, color: Colors.white),
            const SizedBox(width: 16.0),
            Expanded(
              child: Text(
                model.category!,
                style: const TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 24, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Future<void> loadSections() async {
    try {
      String data = await rootBundle.loadString("assets/database/adhkar.json");
      List<dynamic> response = json.decode(data);
      setState(() {
        sections = response.map((section) => SectionModel.fromJson(section)).toList();
        filteredSections = List.from(sections);
      });
    } catch (error) {
      print("Error loading sections: $error");
    }
  }

  void _filterSections() {
    String query = searchController.text.toLowerCase();
    setState(() {
      filteredSections = sections
          .where((section) => section.category!.toLowerCase().contains(query))
          .toList();
    });
  }
}
