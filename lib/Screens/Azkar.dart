import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:iqra/screens/Azkar_Details.dart';
import 'package:iqra/models/Azkar_Model.dart';
import 'dart:async';

class AzkarHome extends StatefulWidget {
  const AzkarHome({Key? key}) : super(key: key);

  @override
  _AzkarHomeState createState() => _AzkarHomeState();
}

class _AzkarHomeState extends State<AzkarHome> {
  List<SectionModel> sections = [];
  List<SectionModel> filteredSections = [];
  final TextEditingController searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    loadSections();
    searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _filterSections(searchController.text);
    });
  }

  Future<void> loadSections() async {
    try {
      final String data = await rootBundle.loadString("assets/database/adhkar.json");
      final List<dynamic> response = json.decode(data);
      final loadedSections = response.map((json) => SectionModel.fromJson(json)).toList();

      setState(() {
        sections = loadedSections;
        filteredSections = List.from(sections);
      });
    } catch (error) {
      debugPrint("Error loading sections: $error");
    }
  }

  void _filterSections(String query) {
    final lowerQuery = query.toLowerCase();
    setState(() {
      filteredSections = sections.where((section) {
        final category = section.category ?? '';
        return category.toLowerCase().contains(lowerQuery);
      }).toList();
    });
  }

  Future<void> _refresh() async {
    await loadSections();
    _filterSections(searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Azkar", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 4,
        backgroundColor: isDarkMode ? Colors.green.shade900 : Colors.greenAccent.shade400,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            children: [
              _buildSearchBar(isDarkMode),
              const SizedBox(height: 14),
              Expanded(
                child: filteredSections.isEmpty
                    ? Center(
                  child: Text(
                    searchController.text.isEmpty
                        ? "No categoreis avalibale"
                        : "No results found",
                    style: TextStyle(
                      fontSize: 18,
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                  ),
                )
                    : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: filteredSections.length,
                  itemBuilder: (context, index) => _buildSectionItem(filteredSections[index], isDarkMode),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDarkMode) {
    return Material(
      elevation: 5,
      shadowColor: isDarkMode ? Colors.black54 : Colors.grey.withOpacity(0.3),
      borderRadius: BorderRadius.circular(35),
      child: TextField(
        controller: searchController,
        textInputAction: TextInputAction.search,
        cursorColor: Colors.green.shade700,
        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          hintText: "Search here...",
          prefixIcon: Icon(Icons.search, color: isDarkMode ? Colors.white70 : Colors.black45),
          filled: true,
          fillColor: isDarkMode ? Colors.white10 : Colors.black12,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(35),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(35),
            borderSide: BorderSide(color: Colors.green.shade600, width: 2),
          ),
        ),
        keyboardType: TextInputType.text,
        onSubmitted: (_) => _filterSections(searchController.text),
      ),
    );
  }

  Widget _buildSectionItem(SectionModel model, bool isDarkMode) {
    return Semantics(
      button: true,
      label: '${model.category}',
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SectionDetailScreen(
              id: model.id ?? 0,
              title: model.category ?? '',
            ),
          ),
        ),
        borderRadius: BorderRadius.circular(16),
        splashColor: Colors.greenAccent.withOpacity(0.3),
        highlightColor: Colors.greenAccent.withOpacity(0.1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: isDarkMode
                  ? [Colors.green.shade900, Colors.green.shade700]
                  : [Colors.lightGreenAccent.shade100, Colors.greenAccent.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: isDarkMode ? Colors.black87 : Colors.green.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.menu_book_rounded, size: 42, color: Colors.white),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  model.category ?? 'No Title',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
