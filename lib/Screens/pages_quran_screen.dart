import 'package:flutter/material.dart';
import 'package:iqra/Data/Surahs.dart';
import 'package:iqra/Screens/page.dart';

class PagesQuran extends StatelessWidget {
  const PagesQuran({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.green.shade800 : Colors.white,
      appBar: AppBar(
        title: const Text("Quran by page"),
        backgroundColor: isDark ? Colors.green.shade800 : Colors.greenAccent.shade200,
        leading: Icon(Icons.auto_stories, color: isDark ? Colors.greenAccent.shade100 : Colors.green),
      ),
      body: ListView.builder(
        itemCount: juzdata.keys.length,
        itemBuilder: (context, index) {
          String Juzname = juzdata.keys.elementAt(index);
          List<Map<String, dynamic>> Surahs = juzdata[Juzname]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                alignment: Alignment.centerLeft,
                width: double.infinity,
                height: 50,
                color: isDark ? Colors.green.shade700 : Colors.greenAccent.shade100,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  Juzname,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              ...Surahs.map((surah) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isDark ? Colors.green.shade700 : Colors.greenAccent.shade100,
                    child: Text(
                      "${surah["Index"]}",
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    "Surah ${surah["Surah"]}",
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    "${surah["ayah"]}",
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    ),
                  ),
                  trailing: Chip(
                    label: Text("${surah["page"]}"),
                    backgroundColor: isDark ? Colors.green.shade600 : Colors.greenAccent.shade100,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => PageScreen(initialPage: surah["page"])),
                    );
                  },
                );
              }).toList(),
            ],
          );
        },
      ),
    );
  }
}
