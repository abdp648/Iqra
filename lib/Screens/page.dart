import 'dart:async';
import 'dart:ui';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quran/quran.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/Tafsir.dart';

class PageScreen extends StatefulWidget {
  final int initialPage;
  const PageScreen({Key? key, required this.initialPage}) : super(key: key);

  @override
  State<PageScreen> createState() => _PageScreenState();
}

class _PageScreenState extends State<PageScreen> with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  late final PageController _pageController;
  late final AudioPlayer _audioPlayer;
  late final AnimationController _playButtonController;
  late final AnimationController _highlightController;
  int currentPage = 1;
  int currentPagePlaying = 1;
  static const int maxPages = 604;
  int repeatCount = 1;
  double playbackSpeed = 1.0;
  bool isAutoScrollEnabled = true;
  final Map<String, int> _currentPlayingAyah = {'surah': 0, 'ayah': 0};
  final ValueNotifier<bool> isAudioPlaying = ValueNotifier(false);
  final ValueNotifier<Duration> currentPosition = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> totalDuration = ValueNotifier(Duration.zero);
  final Map<int, ConcatenatingAudioSource> _audioSourceCache = {};
  StreamSubscription<int?>? _indexStreamSubscription;
  StreamSubscription<Duration>? _positionStreamSubscription;
  StreamSubscription<Duration?>? _durationStreamSubscription;
  List<Tafsir> tafsirList = [];
  final Map<int, List<Map<String, dynamic>>> _versesCache = {};
  bool isBottomSheetVisible = false;
  final ValueNotifier<double> fontSize = ValueNotifier(18.0);

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeAudio();
    _loadInitialData();
  }

  void _initializeControllers() {
    currentPage = widget.initialPage.clamp(1, maxPages);
    _pageController = PageController(initialPage: currentPage - 1);

    _playButtonController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _highlightController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  void _initializeAudio() {
    _audioPlayer = AudioPlayer();

    // Audio state listeners
    _audioPlayer.playerStateStream.listen(_handlePlayerStateChange);
    _positionStreamSubscription = _audioPlayer.positionStream.listen((position) {
      currentPosition.value = position;
    });
    _durationStreamSubscription = _audioPlayer.durationStream.listen((duration) {
      if (duration != null) totalDuration.value = duration;
    });
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadTafsir(),
      _loadUserPreferences(),
    ]);
    _saveLastReadPage(currentPage);
  }

  Future<void> _loadUserPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        repeatCount = prefs.getInt('repeatCount') ?? 1;
        playbackSpeed = prefs.getDouble('playbackSpeed') ?? 1.0;
        fontSize.value = prefs.getDouble('fontSize') ?? 18.0;
        isAutoScrollEnabled = prefs.getBool('autoScroll') ?? true;
      });
    } catch (e) {
      debugPrint('Error loading preferences: $e');
    }
  }

  Future<void> _saveUserPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setInt('repeatCount', repeatCount),
        prefs.setDouble('playbackSpeed', playbackSpeed),
        prefs.setDouble('fontSize', fontSize.value),
        prefs.setBool('autoScroll', isAutoScrollEnabled),
      ]);
    } catch (e) {
      debugPrint('Error saving preferences: $e');
    }
  }

  void _handlePlayerStateChange(PlayerState state) async {
    final isPlaying = state.playing;
    final processingState = state.processingState;

    isAudioPlaying.value = isPlaying;

    if (isPlaying) {
      _playButtonController.forward();
    } else {
      _playButtonController.reverse();
    }

    if (processingState == ProcessingState.completed) {
      await _handleAudioComplete();
    }
  }

  Future<void> _handleAudioComplete() async {
    try {
      if (currentPagePlaying < maxPages) {
        final nextPage = currentPagePlaying + 1;
        final currentSurah = getSurahForPage(currentPagePlaying);
        final nextSurah = getSurahForPage(nextPage);

        if (currentSurah == nextSurah) {
          await _playAudioForPage(nextPage);
          if (isAutoScrollEnabled && mounted) {
            _jumpToPage(nextPage);
          }
        } else {
          await _stopAudio();
          _showCompletionMessage();
        }
      } else {
        await _stopAudio();
        _showCompletionMessage();
      }
    } catch (e) {
      debugPrint('Error handling audio completion: $e');
      await _stopAudio();
    }
  }

  void _showCompletionMessage() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Audio playback completed'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _loadTafsir() async {
    try {
      final String response = await rootBundle.loadString('assets/database/tafseer.json');
      final List<dynamic> data = jsonDecode(response);
      tafsirList = data.map((e) => Tafsir.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error loading tafsir: $e');
      tafsirList = [];
    }
  }

  Future<void> _playAudioForPage(int page) async {
    try {
      await _indexStreamSubscription?.cancel();
      _indexStreamSubscription = null;

      if (page < 1 || page > maxPages) {
        _showErrorMessage('Invalid page number');
        return;
      }

      final pageData = getPageData(page);
      if (pageData.isEmpty) {
        _showErrorMessage('No verses found for this page');
        return;
      }

      final firstEntry = pageData.first;
      setState(() {
        currentPagePlaying = page;
        _currentPlayingAyah['surah'] = firstEntry['surah'];
        _currentPlayingAyah['ayah'] = firstEntry['start'];
      });

      if (!_audioSourceCache.containsKey(page)) {
        final source = await _createAudioSourceForPage(page);
        _audioSourceCache[page] = source;
      }
      await _audioPlayer.setAudioSource(_audioSourceCache[page]!);
      await _audioPlayer.setSpeed(playbackSpeed);
      _setupVerseAudioListener();
      await _audioPlayer.play();

      if (isAutoScrollEnabled && currentPage != page) {
        setState(() {
          currentPage = page;
        });
        _pageController.animateToPage(
          page - 1,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      }

      _saveLastReadPage(page);
    } catch (e) {
      debugPrint('Error playing audio for page $page: $e');
      _showErrorMessage('Failed to play audio');
      await _stopAudio();
    }
  }

  void _setupVerseAudioListener() {
    int? lastSurah;
    int? lastAyah;

    _indexStreamSubscription = _audioPlayer.currentIndexStream.listen((index) {
      try {
        final source = _audioPlayer.sequence;
        if (index != null && source != null && index < source.length) {
          final currentSource = source[index];
          final tag = currentSource.tag;

          if (tag is Map<String, dynamic> && tag.containsKey('surah') && tag.containsKey('ayah')) {
            final int surah = tag['surah'] as int;
            final int ayah = tag['ayah'] as int;

            // Only update if verse changed
            if (lastSurah != surah || lastAyah != ayah) {
              lastSurah = surah;
              lastAyah = ayah;

              if (mounted) {
                setState(() {
                  _currentPlayingAyah['surah'] = surah;
                  _currentPlayingAyah['ayah'] = ayah;
                });

                // Animate highlight
                _highlightController.forward().then((_) {
                  if (mounted) _highlightController.reverse();
                });

                // Auto-scroll to page if needed
                if (isAutoScrollEnabled) {
                  final newPage = getPageNumber(surah, ayah);
                  if (newPage != currentPage && newPage >= 1 && newPage <= maxPages) {
                    setState(() {
                      currentPage = newPage;
                    });
                    _pageController.animateToPage(
                      newPage - 1,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOut,
                    );
                  }
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error in verse audio listener: $e');
      }
    });
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<ConcatenatingAudioSource> _createAudioSourceForPage(int pageNumber) async {
    final pageData = getPageData(pageNumber);
    final List<AudioSource> sources = [];

    for (final entry in pageData) {
      final surahNum = entry["surah"] as int;
      final startAyah = entry["start"] as int;
      final endAyah = entry["end"] as int;

      for (int ayah = startAyah; ayah <= endAyah; ayah++) {
        try {
          final url = getAudioURLByVerse(surahNum, ayah);
          for (int i = 0; i < repeatCount; i++) {
            sources.add(
              AudioSource.uri(
                Uri.parse(url),
                tag: {'surah': surahNum, 'ayah': ayah},
              ),
            );
          }
        } catch (e) {
          debugPrint('Error creating audio source for $surahNum:$ayah - $e');
        }
      }
    }

    return ConcatenatingAudioSource(children: sources);
  }

  Future<void> _saveLastReadPage(int page) async {
    try {
      if (page >= 1 && page <= maxPages) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('lastReadPage', page);
      }
    } catch (e) {
      debugPrint('Error saving last read page: $e');
    }
  }

  Future<void> _stopAudio() async {
    try {
      await _audioPlayer.stop();
      await _indexStreamSubscription?.cancel();
      _indexStreamSubscription = null;

      if (mounted) {
        isAudioPlaying.value = false;
        _playButtonController.reverse();
        setState(() {
          _currentPlayingAyah['surah'] = 0;
          _currentPlayingAyah['ayah'] = 0;
        });
      }
    } catch (e) {
      debugPrint('Error stopping audio: $e');
    }
  }

  void _jumpToPage(int page) {
    if (page >= 1 && page <= maxPages && mounted) {
      _pageController.animateToPage(
        page - 1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onPageChanged(int index) {
    final newPage = index + 1;
    if (newPage != currentPage && newPage >= 1 && newPage <= maxPages) {
      setState(() {
        currentPage = newPage;
      });
      _saveLastReadPage(newPage);
    }
  }

  Future<void> _playAudioFromVerse(int page, int surahNumber, int startAyah) async {
    try {
      // Cancel existing subscriptions
      await _indexStreamSubscription?.cancel();
      _indexStreamSubscription = null;

      // Validate inputs
      if (surahNumber < 1 || surahNumber > 114) {
        _showErrorMessage('Invalid surah number');
        return;
      }

      final maxAyah = getVerseCount(surahNumber);
      if (startAyah < 1 || startAyah > maxAyah) {
        _showErrorMessage('Invalid ayah number');
        return;
      }

      setState(() {
        currentPage = page;
        currentPagePlaying = page;
        _currentPlayingAyah['surah'] = surahNumber;
        _currentPlayingAyah['ayah'] = startAyah;
      });

      final List<AudioSource> sources = [];

      // Create audio sources for all ayahs from startAyah to end of surah
      for (int ayah = startAyah; ayah <= maxAyah; ayah++) {
        try {
          final url = getAudioURLByVerse(surahNumber, ayah);
          for (int i = 0; i < repeatCount; i++) {
            sources.add(
              AudioSource.uri(
                Uri.parse(url),
                tag: {'surah': surahNumber, 'ayah': ayah},
              ),
            );
          }
        } catch (e) {
          debugPrint('Error creating audio source for verse $surahNumber:$ayah - $e');
        }
      }

      if (sources.isEmpty) {
        _showErrorMessage('No audio sources available');
        return;
      }

      final concatenatedSource = ConcatenatingAudioSource(children: sources);
      await _audioPlayer.setAudioSource(concatenatedSource);
      await _audioPlayer.setSpeed(playbackSpeed);

      _setupVerseAudioListener();
      await _audioPlayer.play();

      _saveLastReadPage(currentPage);
    } catch (e) {
      debugPrint('Error playing verse audio: $e');
      _showErrorMessage('Failed to play verse audio');
    }
  }

  void _showAudioControls(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AudioControlsSheet(
        repeatCount: repeatCount,
        playbackSpeed: playbackSpeed,
        isAutoScrollEnabled: isAutoScrollEnabled,
        onRepeatChanged: (value) {
          setState(() => repeatCount = value);
        },
        onSpeedChanged: (value) {
          setState(() => playbackSpeed = value);
        },
        onAutoScrollChanged: (value) {
          setState(() => isAutoScrollEnabled = value);
        },
        onPlay: () => _playAudioForPage(currentPage),
        onSavePreferences: _saveUserPreferences,
      ),
    );
  }

  String get currentSurahName => getSurahNameForPage(currentPage);

  String getSurahNameForPage(int pageNumber) {
    try {
      final data = getPageData(pageNumber);
      if (data.isNotEmpty) {
        return getSurahNameArabic(data.first["surah"]);
      }
    } catch (e) {
      debugPrint('Error getting surah name for page $pageNumber: $e');
    }
    return '';
  }

  List<Map<String, dynamic>> getVersesForPage(int pageNumber) {
    if (_versesCache.containsKey(pageNumber)) {
      return _versesCache[pageNumber]!;
    }

    try {
      final pageData = getPageData(pageNumber);
      final List<Map<String, dynamic>> verses = [];
      const String basmala = '﷽';

      for (final entry in pageData) {
        final surahNum = entry['surah'] as int;
        final startAyah = entry['start'] as int;
        final endAyah = entry['end'] as int;

        for (int ayah = startAyah; ayah <= endAyah; ayah++) {
          if (ayah == 1) {
            final surahName = getSurahNameArabic(surahNum);
            verses.add({
              'surah': surahNum,
              'ayah': -1,
              'text': '\n\n- $surahName -\n\n',
              'type': 'header',
            });
          }

          // Adding basmala for first ayah (except Al-Fatiha and At-Tawbah)
          if (ayah == 1 && surahNum != 9 && surahNum != 1) {
            verses.add({
              'surah': surahNum,
              'ayah': 0,
              'text': "$basmala\n",
              'type': 'basmala',
            });
          }

          // Add verse text
          try {
            final verseText = getVerse(surahNum, ayah, verseEndSymbol: true);
            verses.add({
              'surah': surahNum,
              'ayah': ayah,
              'text': verseText,
              'type': 'verse',
            });
          } catch (e) {
            debugPrint('Error getting verse $surahNum:$ayah - $e');
          }
        }
      }

      _versesCache[pageNumber] = verses;
      return verses;
    } catch (e) {
      debugPrint('Error getting verses for page $pageNumber: $e');
      return [];
    }
  }

  int getSurahForPage(int pageNumber) {
    try {
      final pageData = getPageData(pageNumber);
      return pageData.isNotEmpty ? pageData[0]['surah'] as int : 1;
    } catch (e) {
      debugPrint('Error getting surah for page $pageNumber: $e');
      return 1;
    }
  }

  @override
  void dispose() {
    _indexStreamSubscription?.cancel();
    _positionStreamSubscription?.cancel();
    _durationStreamSubscription?.cancel();
    _audioPlayer.dispose();
    _pageController.dispose();
    _playButtonController.dispose();
    _highlightController.dispose();
    isAudioPlaying.dispose();
    currentPosition.dispose();
    totalDuration.dispose();
    fontSize.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: _buildAppBar(isDark),
      body: _buildBody(isDark),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: isDark ? Colors.green.shade900 : Colors.greenAccent.shade400,
      elevation: 0,
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Quran',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => _showSettingsSheet(context),
        ),
      ],
    );
  }

  Widget _buildBody(bool isDark) {
    return Stack(
      children: [
        _buildPageView(isDark),
        _buildBottomControls(isDark),
      ],
    );
  }

  Widget _buildPageView(bool isDark) {
    return PageView.builder(
      controller: _pageController,
      reverse: true,
      itemCount: maxPages,
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) {
        final pageNum = index + 1;
        final verses = getVersesForPage(pageNum);

        return Container(
          width: double.infinity,
          height: double.infinity,
          color: isDark ? Colors.black : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Stack(
              children: [
                Positioned(
                  top: 5,
                  left: 15,
                  child: Text(
                    "$currentSurahName",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
                Positioned(
                  top: 5,
                  right: 15,
                  child: Text(
                    "$currentPage",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
                // Main content
                Positioned.fill(
                  top: 30,
                  child: Column(
                    mainAxisAlignment: pageNum == 1 || pageNum == 2
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Card(
                          elevation: 4,
                          shadowColor: Colors.green.withOpacity(0.3),
                          color: isDark ? Colors.grey.shade900 : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: SingleChildScrollView(
                                child: ValueListenableBuilder<double>(
                                  valueListenable: fontSize,
                                  builder: (context, fontSizeValue, _) {
                                    return AutoSizeText.rich(
                                      TextSpan(
                                        children: verses.map<TextSpan>((verse) {
                                          return _buildVerseSpan(verse, isDark, fontSizeValue);
                                        }).toList(),
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 100,
                                      minFontSize: 12,
                                      overflow: TextOverflow.fade,
                                    );
                                  },
                                ),
                              )
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildPageNumber(pageNum, isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  TextSpan _buildVerseSpan(Map<String, dynamic> verse, bool isDark, double fontSizeValue) {
    final isCurrentlyPlaying = _currentPlayingAyah['surah'] == verse['surah'] &&
        _currentPlayingAyah['ayah'] == verse['ayah'];

    switch (verse['type']) {
      case 'header':
        return TextSpan(
          text: verse['text'],
          style: GoogleFonts.amiriQuran(
            fontSize: fontSizeValue + 6,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        );
      case 'basmala':
        return TextSpan(
          text: verse['text'],
          style: GoogleFonts.amiriQuran(
            fontSize: fontSizeValue + 2,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        );
      default:
        return TextSpan(
          text: '${verse['text']} ',
          style: GoogleFonts.amiriQuran(
            fontSize: fontSizeValue,
            height: 2.2,
            backgroundColor: isCurrentlyPlaying
                ? Colors.green.withOpacity(0.3)
                : Colors.transparent,
            color: isCurrentlyPlaying
                ? Colors.green.shade700
                : (isDark ? Colors.white : Colors.black87),
          ),
          recognizer: LongPressGestureRecognizer()
            ..onLongPress = () {
              if (verse['ayah'] > 0) {
                HapticFeedback.mediumImpact();
                _showVerseOptions(
                  context,
                  verse['surah'],
                  verse['ayah'],
                  verse['text'],
                );
              }
            },
        );
    }
  }

  Widget _buildPageNumber(int pageNum, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.green.shade900 : Colors.green.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$pageNum',
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildBottomControls(bool isDark) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              isDark ? Colors.green.shade900.withOpacity(0.9) : Colors.greenAccent.shade100.withOpacity(0.9),
            ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: (isDark ? Colors.green.shade900 : Colors.greenAccent.shade100).withOpacity(0.8),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildPlayButton(isDark),
                    _buildProgressIndicator(isDark),
                    _buildSettingsButton(isDark),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayButton(bool isDark) {
    return ValueListenableBuilder<bool>(
      valueListenable: isAudioPlaying,
      builder: (context, playing, _) {
        return AnimatedBuilder(
          animation: _playButtonController,
          builder: (context, child) {
            return FloatingActionButton(
              heroTag: "play_button",
              mini: true,
              backgroundColor: Colors.green,
              onPressed: playing ? _stopAudio : () => _showAudioControls(context),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  playing ? Icons.stop : Icons.play_arrow,
                  key: ValueKey(playing),
                  color: Colors.white,
                  size: 24,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProgressIndicator(bool isDark) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ValueListenableBuilder<Duration>(
          valueListenable: currentPosition,
          builder: (context, position, _) {
            return ValueListenableBuilder<Duration>(
              valueListenable: totalDuration,
              builder: (context, duration, _) {
                final progress = duration.inMilliseconds > 0
                    ? position.inMilliseconds / duration.inMilliseconds
                    : 0.0;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(position),
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        Text(
                          _formatDuration(duration),
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildSettingsButton(bool isDark) {
    return IconButton(
      icon: Icon(
        Icons.more_vert,
        color: isDark ? Colors.white : Colors.black,
      ),
      onPressed: () => _showSettingsSheet(context),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _showVerseOptions(BuildContext context, int surah, int ayah, String text) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _VerseOptionsSheet(
        surah: surah,
        ayah: ayah,
        text: text,
        onPlay: () => _playAudioFromVerse(currentPage, surah, ayah),
        onShowTafsir: () => _showTafsirDialog(context, surah, ayah),
      ),
    );
  }

  void _showTafsirDialog(BuildContext context, int surah, int ayah) {
    final tafsir = tafsirList.firstWhere(
          (t) => t.number == surah.toString() && t.aya == ayah.toString(),
      orElse: () => Tafsir(text: 'التفسير غير متاح لهذه الآية'),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _TafsirSheet(
        surah: surah,
        ayah: ayah,
        tafsir: tafsir,
      ),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SettingsSheet(
        fontSize: fontSize,
        onSave: _saveUserPreferences,
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _AudioControlsSheet extends StatefulWidget {
  final int repeatCount;
  final double playbackSpeed;
  final bool isAutoScrollEnabled;
  final Function(int) onRepeatChanged;
  final Function(double) onSpeedChanged;
  final Function(bool) onAutoScrollChanged;
  final VoidCallback onPlay;
  final VoidCallback onSavePreferences;

  const _AudioControlsSheet({
    required this.repeatCount,
    required this.playbackSpeed,
    required this.isAutoScrollEnabled,
    required this.onRepeatChanged,
    required this.onSpeedChanged,
    required this.onAutoScrollChanged,
    required this.onPlay,
    required this.onSavePreferences,
  });

  @override
  State<_AudioControlsSheet> createState() => _AudioControlsSheetState();
}

class _AudioControlsSheetState extends State<_AudioControlsSheet> {
  late int tempRepeatCount;
  late double tempPlaybackSpeed;
  late bool tempAutoScroll;

  @override
  void initState() {
    super.initState();
    tempRepeatCount = widget.repeatCount;
    tempPlaybackSpeed = widget.playbackSpeed;
    tempAutoScroll = widget.isAutoScrollEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          const SizedBox(height: 16),
          const Text(
            'Audio Settings',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _buildRepeatSlider(),
          const SizedBox(height: 16),
          _buildSpeedSlider(),
          const SizedBox(height: 16),
          _buildAutoScrollSwitch(),
          const SizedBox(height: 24),
          _buildStartButton(),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      height: 4,
      width: 50,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _buildRepeatSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Repeat Count: $tempRepeatCount', style: const TextStyle(fontSize: 16)),
        Slider(
          min: 1,
          max: 5,
          divisions: 4,
          value: tempRepeatCount.toDouble(),
          activeColor: Colors.green,
          onChanged: (val) {
            setState(() => tempRepeatCount = val.toInt());
          },
        ),
      ],
    );
  }

  Widget _buildSpeedSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Playback Speed: ${tempPlaybackSpeed.toStringAsFixed(1)}x',
            style: const TextStyle(fontSize: 16)),
        Slider(
          min: 0.5,
          max: 2.0,
          divisions: 6,
          value: tempPlaybackSpeed,
          activeColor: Colors.green,
          onChanged: (val) {
            setState(() => tempPlaybackSpeed = val);
          },
        ),
      ],
    );
  }

  Widget _buildAutoScrollSwitch() {
    return SwitchListTile(
      title: const Text('Auto Scroll'),
      subtitle: const Text('Automatically scroll to playing verse'),
      value: tempAutoScroll,
      activeColor: Colors.green,
      onChanged: (value) {
        setState(() => tempAutoScroll = value);
      },
    );
  }

  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () {
          widget.onRepeatChanged(tempRepeatCount);
          widget.onSpeedChanged(tempPlaybackSpeed);
          widget.onAutoScrollChanged(tempAutoScroll);
          widget.onSavePreferences();
          Navigator.pop(context);
          widget.onPlay();
        },
        child: const Text('Start Playing', style: TextStyle(fontSize: 16)),
      ),
    );
  }
}

class _VerseOptionsSheet extends StatelessWidget {
  final int surah;
  final int ayah;
  final String text;
  final VoidCallback onPlay;
  final VoidCallback onShowTafsir;

  const _VerseOptionsSheet({
    required this.surah,
    required this.ayah,
    required this.text,
    required this.onPlay,
    required this.onShowTafsir,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          const SizedBox(height: 16),
          Text(
            'آية $ayah من سورة ${getSurahNameArabic(surah)}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.3),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Text(
                text,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  height: 1.8,
                  fontFamily: GoogleFonts.amiriQuran().fontFamily,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildOptionButton(
                  icon: Icons.play_arrow,
                  label: 'Play',
                  onTap: () {
                    Navigator.pop(context);
                    onPlay();
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildOptionButton(
                  icon: Icons.menu_book,
                  label: 'Tafsir',
                  onTap: () {
                    Navigator.pop(context);
                    onShowTafsir();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      height: 4,
      width: 50,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _TafsirSheet extends StatelessWidget {
  final int surah;
  final int ayah;
  final Tafsir tafsir;

  const _TafsirSheet({
    required this.surah,
    required this.ayah,
    required this.tafsir,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              _buildHandle(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'تفسير آية $ayah من سورة ${getSurahName(surah)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Text(
                    tafsir.text ?? 'لا يوجد تفسير متاح لهذه الآية',
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 1.8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHandle() {
    return Container(
      height: 4,
      width: 50,
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

class _SettingsSheet extends StatefulWidget {
  final ValueNotifier<double> fontSize;
  final VoidCallback onSave;

  const _SettingsSheet({
    required this.fontSize,
    required this.onSave,
  });

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          const SizedBox(height: 16),
          const Text(
            'Display Settings',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _buildFontSizeSlider(),
          const SizedBox(height: 24),
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      height: 4,
      width: 50,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _buildFontSizeSlider() {
    return ValueListenableBuilder<double>(
      valueListenable: widget.fontSize,
      builder: (context, fontSize, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Font Size: ${fontSize.toInt()}',
                style: const TextStyle(fontSize: 16)),
            Slider(
              min: 14.0,
              max: 28.0,
              divisions: 7,
              value: fontSize,
              activeColor: Colors.green,
              onChanged: (val) {
                widget.fontSize.value = val;
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(
              12)),
        ),
        onPressed: () {
          widget.onSave();
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Settings saved successfully'),
              duration: Duration(seconds: 2),
            ),
          );
        },
        child: const Text('Save Settings', style: TextStyle(fontSize: 16)),
      ),
    );
  }
}