import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quran/quran.dart';
import 'package:google_fonts/google_fonts.dart';

class SurahScreen extends StatelessWidget {
  final int surahNumber;

  const SurahScreen({Key? key, required this.surahNumber}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    int totalVerses = getVerseCount(surahNumber);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.green.shade900 : Colors.greenAccent.shade400,
        title: Text(getSurahNameArabic(surahNumber)),
      ),
      body: ListView.builder(
        itemCount: totalVerses,
        itemBuilder: (context, index) {
          String verseText = getVerse(surahNumber, index + 1 , verseEndSymbol: true);

          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              verseText,
              style: TextStyle(
                fontSize: 23,
                fontFamily: GoogleFonts.amiriQuran().fontFamily,
              ),
              textAlign: TextAlign.right,
            ),
          );
        },
      ),
    );
  }
}
