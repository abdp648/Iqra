import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quran/quran.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:just_audio/just_audio.dart';

class PageScreen extends StatefulWidget {
  final int page;
  const PageScreen({Key? key, required this.page}) : super(key: key);

  @override
  _PageScreenState createState() => _PageScreenState();
}

class _PageScreenState extends State<PageScreen> with AutomaticKeepAliveClientMixin {
  late PageController _pageController;
  late int currentPage;
  late String currentSurahName;
  late AudioPlayer _audioPlayer;
  bool _isAudioPlaying = false;
  bool _isLooping = false;
  late String _currentAudioUrl;
  int repeatCount = 1;


  @override
  void initState() {
    super.initState();
    currentPage = widget.page;
    currentSurahName = getSurahNameForPage(currentPage);
    _pageController = PageController(initialPage: currentPage - 1);
    _audioPlayer = AudioPlayer();
    _currentAudioUrl = "";
    _saveLastReadPage(currentPage);
    _audioPlayer.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        _goToNextPageAndPlay();
      }
    });
  }

  void _goToNextPageAndPlay() async {
    if (currentPage < 604) {
      int currentSurah = getSurahForPage(currentPage);
      int nextPage = currentPage + 1;
      int nextSurah = getSurahForPage(nextPage);

      if (currentSurah == nextSurah) {
        var pageData = getPageData(nextPage);
        List<AudioSource> audioSources = [];

        for (var entry in pageData) {
          int surahNumber = entry["surah"];
          int startAyah = entry["start"];
          int endAyah = entry["end"];

          for (int ayah = startAyah; ayah <= endAyah; ayah++) {
            String audioUrl = getAudioURLByVerse(surahNumber, ayah);
            for (int i = 0; i < repeatCount; i++) {
              audioSources.add(AudioSource.uri(Uri.parse(audioUrl))); // Repeat the ayah
            }
          }
        }

        if (audioSources.isNotEmpty) {
          await _audioPlayer.setAudioSource(ConcatenatingAudioSource(children: audioSources));
          _audioPlayer.play();
          setState(() {
            _isAudioPlaying = true;
          });

          _audioPlayer.playerStateStream.listen((playerState) {
            if (playerState.processingState == ProcessingState.completed) {
              setState(() {
                _isAudioPlaying = false;
              });
              setState(() {
                currentPage = nextPage;
              });

              _pageController.nextPage(
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          });
        }
      }
    }
  }



  Future<void> _saveLastReadPage(int page) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastReadPage', page);
  }

  void _onPageChanged(int index) {
    setState(() {
      currentPage = index + 1;
      currentSurahName = getSurahNameForPage(currentPage);
    });
    _saveLastReadPage(currentPage);
  }

  Future<void> _startAudioForSurah(int pageNumber) async {
    var pageData = getPageData(pageNumber);
    List<AudioSource> audioSources = [];

    for (var entry in pageData) {
      int surahNumber = entry["surah"];
      int startAyah = entry["start"];
      int endAyah = entry["end"];

      for (int ayah = startAyah; ayah <= endAyah; ayah++) {
        String audioUrl = getAudioURLByVerse(surahNumber, ayah);
        for (int i = 0; i < repeatCount; i++) {
          audioSources.add(AudioSource.uri(Uri.parse(audioUrl)));
        }
      }
    }

    if (audioSources.isNotEmpty) {
      await _audioPlayer.setAudioSource(ConcatenatingAudioSource(children: audioSources));
      _audioPlayer.play();
      setState(() {
        _isAudioPlaying = true;
      });

      _audioPlayer.playerStateStream.listen((playerState) {
        if (playerState.processingState == ProcessingState.completed) {
          setState(() {
            _isAudioPlaying = false;
          });
        }
      });
    }
  }




  Future<void> _stopAudio() async {
    await _audioPlayer.stop();
    setState(() {
      _isAudioPlaying = false;
    });
  }


  Future<void> _startAudioFromAyah(int surahNumber, int ayahNumber) async {
    String audioUrl = getAudioURLByVerse(surahNumber, ayahNumber);
    await _audioPlayer.setUrl(audioUrl);
    _audioPlayer.play();
    setState(() {
      _isAudioPlaying = true;
      _isLooping = false;
    });
  }

  String getSurahNameForPage(int pageNumber) {
    var pageData = getPageData(pageNumber);
    if (pageData.isNotEmpty) {
      return getSurahName(pageData.first["surah"]);
    }
    return "";
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.green.shade900 : Colors.greenAccent.shade400,
        title: Column(
          children: [
            Text('Quran', style: TextStyle(fontSize: 20)),
            Text(currentSurahName, style: TextStyle(fontSize: 20)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isAudioPlaying ? Icons.stop : Icons.play_arrow),
            onPressed: _isAudioPlaying ? _stopAudio : () => _showRepeatBottomSheet(context),
          ),
        ],
      ),
      body: PageView.builder(
      reverse: true,
      controller: _pageController,
      physics: const ClampingScrollPhysics(),
      scrollDirection: Axis.horizontal,
      itemCount: 604,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  panEnabled: true,
                  scaleEnabled: true,
                  child: Container(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight * 0.9,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(15),
                    child: GestureDetector(
                      onLongPress: () {
                        int surahNumber = getSurahForPage(index + 1);
                        int ayahNumber = 1;
                        _startAudioFromAyah(surahNumber, ayahNumber);
                      },
                      child: (index + 1 == 1 || index + 1 == 2)
                          ? Center(
                        child: Text(
                          getFullPageText(index + 1),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w500,
                            fontFamily: GoogleFonts.amiriQuran().fontFamily,
                          ),
                        ),
                      )
                          : AutoSizeText(
                        getFullPageText(index + 1),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 100,
                          fontWeight: FontWeight.w500,
                          fontFamily: GoogleFonts.amiriQuran().fontFamily,
                        ),
                        minFontSize: 15,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      "${index + 1}",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    ),
    );
  }

  void _showRepeatBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        int selectedRepeat = repeatCount;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "choose repeat times",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Slider(
                    activeColor: Colors.green,
                    value: selectedRepeat.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: selectedRepeat.toString(),
                    onChanged: (double value) {
                      setModalState(() {
                        selectedRepeat = value.toInt();
                      });
                    },
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        repeatCount = selectedRepeat;
                      });
                      Navigator.pop(context);
                      _startAudioForSurah(currentPage);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green
                    ),
                    child: const Text("Start", style: TextStyle(
                      color: Colors.black
                    ),),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String getFullPageText(int pageNumber) {
    var pageData = getPageData(pageNumber);
    String fullText = "";

    for (var entry in pageData) {
      int surahNumber = entry['surah'];
      int startAyah = entry['start'];
      int endAyah = entry['end'];

      if (startAyah == 1) {
        fullText += "\n\n◉ ${getSurahNameArabic(surahNumber)} ◉\n\n";
        if (surahNumber != 1 && surahNumber != 9) {
          fullText += "${basmala}\n\n";
        }
      }

      for (int verseNumber = startAyah; verseNumber <= endAyah; verseNumber++) {
        fullText += "${getVerse(surahNumber, verseNumber, verseEndSymbol: true)} ";
      }
    }

    return fullText.trim();
  }

  String getsurahName(int pageNumber) {
    var pageData = getPageData(pageNumber);
    var first = pageData[0];
    var surahNum = first["surah"];
    var surahName = getSurahName(surahNum);

    return surahName;
  }

  int getSurahForPage(int pageNumber) {
    var pageData = getPageData(pageNumber);
    var first = pageData[0];
    var surahNum = first["surah"];

    return surahNum;
  }


  @override
  bool get wantKeepAlive => true;
}
