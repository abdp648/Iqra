import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:iqra/models/Azkar_Model.dart';

class SectionDetailScreen extends StatefulWidget {
  final int id;
  final String title;
  const SectionDetailScreen({Key? key, required this.id, required this.title}) : super(key: key);

  @override
  _SectionDetailScreenState createState() => _SectionDetailScreenState();
}

class _SectionDetailScreenState extends State<SectionDetailScreen> {
  List<AzkarItem> azkarItems = [];
  PageController _pageController = PageController();
  Map<int, int> counters = {};

  @override
  void initState() {
    super.initState();
    loadAzkarItems();
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: isDarkMode ? Colors.green.shade900 : Colors.greenAccent.shade400,
      ),
      body: azkarItems.isEmpty
          ? Center(child: CircularProgressIndicator())
          : PageView.builder(
        controller: _pageController,
        physics: BouncingScrollPhysics(),
        itemCount: azkarItems.length,
        itemBuilder: (context, index) {
          return Container(
            color: isDarkMode ? Colors.black54 : Colors.white,
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Center(
                      child: Text(
                        azkarItems[index].text ?? '',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  "${counters[index] ?? azkarItems[index].count ?? 1}",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green),
                ),
                SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.only(bottom: 30),
                  child: FloatingActionButton(
                    onPressed: () => _incrementCounter(index),
                    child: Icon(Icons.fingerprint, size: 32),
                    backgroundColor: Colors.green,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _incrementCounter(int index) {
    setState(() {
      if ((counters[index] ?? azkarItems[index].count ?? 1) > 0) {
        counters[index] = (counters[index] ?? azkarItems[index].count ?? 1) - 1;
      }
      if (counters[index] == 0 && index < azkarItems.length - 1) {
        _pageController.nextPage(duration: Duration(milliseconds: 300), curve: Curves.easeInOut);
      }
    });
  }

  Future<void> loadAzkarItems() async {
    try {
      String data = await rootBundle.loadString("assets/database/adhkar.json");
      List<dynamic> response = json.decode(data);

      SectionModel? section = response
          .map((json) => SectionModel.fromJson(json))
          .firstWhere((s) => s.id == widget.id, orElse: () => SectionModel());

      setState(() {
        azkarItems = section.azkar ?? [];
        for (int i = 0; i < azkarItems.length; i++) {
          counters[i] = azkarItems[i].count ?? 1;
        }
      });
    } catch (error) {
      debugPrint("Error loading azkar items: $error");
    }
  }
}
