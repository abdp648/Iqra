import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';

class Tasbih extends StatefulWidget {
  const Tasbih({super.key});

  @override
  State<Tasbih> createState() => _TasbihState();
}

class _TasbihState extends State<Tasbih>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // State variables
  int _count = 0;
  int _maxCount = 33;
  int _loopCounter = 0;
  String _selectedZikr = "سبحان الله";

  // Configuration
  static const List<String> _azkar = [
    "سبحان الله",
    "الحمد لله",
    "الله أكبر",
    "لا إله إلا الله"
  ];

  static const Map<String, int> _zikrMaxCounts = {
    "سبحان الله": 33,
    "الحمد لله": 33,
    "الله أكبر": 34,
    "لا إله إلا الله": 100,
  };

  SharedPreferences? _prefs;
  late AnimationController _animationController;

  bool _isAnimating = false;
  bool _isInitialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeController();
    _initializePreferences();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _saveCurrentState();
    }
  }

  void _initializeController() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  Future<void> _initializePreferences() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadSavedState();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load saved data';
          _isInitialized = true;
        });
      }
    }
  }

  Future<void> _loadSavedState() async {
    if (_prefs == null) return;

    _selectedZikr = _prefs!.getString("selectedZikr") ?? _azkar.first;
    _maxCount = _zikrMaxCounts[_selectedZikr] ?? 33;
    _count = _prefs!.getInt("count_$_selectedZikr") ?? 0;
    _loopCounter = _prefs!.getInt("loops_$_selectedZikr") ?? 0;
  }

  Future<void> _saveCurrentState() async {
    if (_prefs == null) return;

    try {
      await Future.wait([
        _prefs!.setString("selectedZikr", _selectedZikr),
        _prefs!.setInt("count_$_selectedZikr", _count),
        _prefs!.setInt("loops_$_selectedZikr", _loopCounter),
      ]);
    } catch (e) {
      debugPrint('Failed to save state: $e');
    }
  }

  Future<void> _incrementCount() async {
    if (_isAnimating || !_isInitialized) return;

    setState(() => _isAnimating = true);

    HapticFeedback.selectionClick();
    await _animationController.forward(from: 0);

    setState(() {
      if (_count < _maxCount) {
        _count++;
      } else {
        _count = 1;
        _loopCounter++;
        HapticFeedback.mediumImpact();
      }
      _isAnimating = false;
    });

    _saveCurrentState();
  }

  Future<void> _resetCounter() async {
    final shouldReset = await _showResetConfirmation();
    if (!shouldReset) return;

    HapticFeedback.heavyImpact();

    setState(() {
      _count = 0;
      _loopCounter = 0;
    });

    await _saveCurrentState();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Counter reset for $_selectedZikr'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green.shade700,
        ),
      );
    }
  }

  Future<bool> _showResetConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Counter'),
        content: Text('Reset counter for $_selectedZikr?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _changeZikr(String? newZikr) async {
    if (newZikr == null || newZikr == _selectedZikr) return;

    setState(() {
      _selectedZikr = newZikr;
      _maxCount = _zikrMaxCounts[newZikr] ?? 33;
      _count = _prefs?.getInt("count_$newZikr") ?? 0;
      _loopCounter = _prefs?.getInt("loops_$newZikr") ?? 0;
    });

    await _saveCurrentState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: _buildAppBar(isDark, colorScheme),
      body: _buildBody(isDark, colorScheme),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark, ColorScheme colorScheme) {
    return AppBar(
      title: const Text(
        "التسبيح",
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      backgroundColor: isDark ? Colors.green.shade900 : Colors.greenAccent.shade400,
      foregroundColor: isDark ? colorScheme.onSurface : Colors.white,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
    );
  }

  Widget _buildBody(bool isDark, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [Colors.green.shade900, Colors.green.shade800, Colors.green.shade700]
              : [Colors.green.shade200, Colors.green.shade400, Colors.green.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: SafeArea(
        child: _isInitialized ? _buildMainContent(isDark, colorScheme) : _buildLoadingState(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Loading...',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(bool isDark, ColorScheme colorScheme) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                setState(() {
                  _error = null;
                  _isInitialized = false;
                });
                _initializePreferences();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        const SizedBox(height: 16),
        _buildZikrSelector(isDark, colorScheme),
        const SizedBox(height: 24),
        _buildCounterDisplay(isDark),
        const SizedBox(height: 16),
        Expanded(child: _buildTasbihAnimation()),
        _buildProgressIndicator(isDark),
        const SizedBox(height: 24),
        _buildActionButtons(isDark, colorScheme),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildZikrSelector(bool isDark, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withOpacity(0.3)
            : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButton<String>(
        value: _selectedZikr,
        items: _azkar.map((zikr) => DropdownMenuItem(
          value: zikr,
          child: Text(
            zikr,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.green.shade800,
            ),
          ),
        )).toList(),
        onChanged: _changeZikr,
        isExpanded: true,
        underline: const SizedBox(),
        icon: Icon(
          Icons.keyboard_arrow_down,
          color: isDark ? Colors.white : Colors.green.shade800,
        ),
        dropdownColor: isDark ? Colors.grey.shade800 : Colors.white,
      ),
    );
  }

  Widget _buildCounterDisplay(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withOpacity(0.3)
            : Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            '$_count / $_maxCount',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.3),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Completed: $_loopCounter loops',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.green.shade200 : Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTasbihAnimation() {
    return GestureDetector(
      onTap: _incrementCount,
      child: Container(
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Lottie.asset(
          'assets/sebha.json',
          controller: _animationController,
          fit: BoxFit.contain,
          onLoaded: (composition) {
            _animationController.duration = composition.duration;
          },
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(bool isDark) {
    final progress = _count / _maxCount;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(
              isDark ? Colors.green.shade300 : Colors.white,
            ),
            minHeight: 8,
          ),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).toInt()}% Complete',
            style: TextStyle(
              color: isDark ? Colors.green.shade200 : Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isDark, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          onPressed: _incrementCount,
          icon: Icons.add,
          label: 'Count',
          isDark: isDark,
          isPrimary: true,
        ),
        _buildActionButton(
          onPressed: _resetCounter,
          icon: Icons.refresh,
          label: 'Reset',
          isDark: isDark,
          isPrimary: false,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required bool isDark,
    required bool isPrimary,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary
              ? (isDark ? Colors.green.shade700 : Colors.green.shade600)
              : (isDark ? Colors.grey.shade700 : Colors.grey.shade600),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}