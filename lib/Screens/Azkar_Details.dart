import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:iqra/models/Azkar_Model.dart';

class SectionDetailScreen extends StatefulWidget {
  final int id;
  final String title;
  const SectionDetailScreen({Key? key, required this.id, required this.title}) : super(key: key);

  @override
  _SectionDetailScreenState createState() => _SectionDetailScreenState();
}

class _SectionDetailScreenState extends State<SectionDetailScreen> with SingleTickerProviderStateMixin {
  List<AzkarItem> azkarItems = [];
  PageController _pageController = PageController();
  Map<int, int> counters = {};
  bool isLoading = true;
  String? errorMessage;
  int currentPage = 0;

  // For counter animation
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    loadAzkarItems();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = Tween<double>(begin: 1, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _pageController.addListener(() {
      int page = _pageController.page?.round() ?? 0;
      if (currentPage != page) {
        setState(() {
          currentPage = page;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> loadAzkarItems() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final String data = await rootBundle.loadString("assets/database/adhkar.json");
      final List<dynamic> response = json.decode(data);

      final SectionModel section = response
          .map((json) => SectionModel.fromJson(json))
          .firstWhere((s) => s.id == widget.id, orElse: () => SectionModel());

      setState(() {
        azkarItems = section.azkar ?? [];
        counters = {
          for (int i = 0; i < azkarItems.length; i++) i: azkarItems[i].count ?? 1,
        };
        isLoading = false;
      });
    } catch (error) {
      setState(() {
        errorMessage = "حدث خطأ أثناء تحميل البيانات. الرجاء المحاولة لاحقاً.";
        isLoading = false;
      });
      debugPrint("Error loading azkar items: $error");
    }
  }

  void _incrementCounter(int index) {
    if (counters[index] == null || counters[index]! <= 0) return;

    setState(() {
      counters[index] = counters[index]! - 1;
    });

    _animationController.forward(from: 0).then((_) => _animationController.reverse());

    HapticFeedback.selectionClick();

    if (counters[index] == 0 && index < azkarItems.length - 1) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _pageController.nextPage(duration: Duration(milliseconds: 400), curve: Curves.easeInOut);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color primaryGreen = isDarkMode ? Colors.green.shade800 : Colors.green.shade600;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryGreen,
        centerTitle: true,
        elevation: 4,
        shadowColor: isDarkMode ? Colors.black87 : Colors.greenAccent,
      ),
      body: SafeArea(
        child: isLoading
            ? Center(child: CircularProgressIndicator())
            : errorMessage != null
            ? Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.redAccent, size: 50),
                SizedBox(height: 12),
                Text(errorMessage!,
                    style: TextStyle(fontSize: 18, color: Colors.redAccent),
                    textAlign: TextAlign.center),
                SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: Icon(Icons.refresh),
                  label: Text('إعادة المحاولة'),
                  onPressed: loadAzkarItems,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        )
            : RefreshIndicator(
          onRefresh: loadAzkarItems,
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: BouncingScrollPhysics(),
                  itemCount: azkarItems.length,
                  itemBuilder: (context, index) {
                    final azkarItem = azkarItems[index];
                    final counterValue = counters[index] ?? (azkarItem.count ?? 1);

                    return Container(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[900] : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: isDarkMode ? Colors.black54 : Colors.grey.shade300,
                            blurRadius: 12,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              physics: BouncingScrollPhysics(),
                              child: Center(
                                child: Text(
                                  azkarItem.text ?? '',
                                  textDirection: TextDirection.rtl,
                                  style: TextStyle(
                                    color: isDarkMode ? Colors.white : Colors.black87,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w600,
                                    height: 1.5,
                                    fontFamily: 'Tajawal', // Better Arabic font if available
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 28),
                          ScaleTransition(
                            scale: _animation,
                            child: Text(
                              "$counterValue",
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: primaryGreen,
                                shadows: [
                                  Shadow(
                                    blurRadius: 8,
                                    color: primaryGreen.withOpacity(0.5),
                                    offset: Offset(0, 2),
                                  )
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 28),
                          FloatingActionButton(
                            onPressed: counterValue > 0 ? () => _incrementCounter(index) : null,
                            backgroundColor: counterValue > 0 ? primaryGreen : Colors.grey,
                            elevation: counterValue > 0 ? 6 : 0,
                            child: Icon(Icons.fingerprint, size: 32),
                            heroTag: 'fab_$index',
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: EdgeInsets.only(bottom: 16),
                child: _buildPageIndicator(),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        azkarItems.length,
            (index) => AnimatedContainer(
          duration: Duration(milliseconds: 300),
          margin: EdgeInsets.symmetric(horizontal: 5),
          width: currentPage == index ? 24 : 12,
          height: 12,
          decoration: BoxDecoration(
            color: currentPage == index ? Colors.green : Colors.green.withOpacity(0.4),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}
