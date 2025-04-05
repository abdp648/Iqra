import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Tasbih extends StatefulWidget {
  const Tasbih({super.key});

  @override
  State<Tasbih> createState() => _TasbihPageState();
}

class _TasbihPageState extends State<Tasbih> {
  int _count = 0;
  int _maxCount = 33;
  int _loopCounter = 0;
  String _selectedZikr = "سبحان الله";
  final List<String> _azkar = ["سبحان الله", "الحمد لله", "الله أكبر", "لا إله إلا الله"];
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedZikr = _prefs.getString("selectedZikr") ?? "سبحان الله";
      _count = _prefs.getInt(_selectedZikr) ?? 0;
      _loopCounter = _prefs.getInt("loopCounter_$_selectedZikr") ?? 0;
    });
  }

  Future<void> _saveData() async {
    await _prefs.setInt(_selectedZikr, _count);
    await _prefs.setInt("loopCounter_$_selectedZikr", _loopCounter);
  }

  void _incrementCounter() {
    setState(() {
      if (_count < _maxCount) {
        _count++;
      } else {
        _count = 1;
        _loopCounter++;
      }
      HapticFeedback.lightImpact();
    });
    _saveData();
  }

  void _resetCounter() {
    setState(() {
      _count = 0;
      _loopCounter = 0;
    });
    _saveData();
  }

  void _changeZikr(String? newZikr) {
    if (newZikr != null) {
      setState(() {
        _selectedZikr = newZikr;
        _count = _prefs.getInt(newZikr) ?? 0;
        _loopCounter = _prefs.getInt("loopCounter_$newZikr") ?? 0;
      });
      _prefs.setString("selectedZikr", newZikr);
      _saveData();
    }
  }

  double _progress() {
    return _count / _maxCount;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Tasbih"),
        backgroundColor: isDark ? Colors.green.shade900 : Colors.greenAccent.shade400,
        elevation: 5,
      ),
      body: GestureDetector(
        onTap: _incrementCounter,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [Colors.green.shade900, Colors.green.shade700]
                  : [Colors.green.shade200, Colors.green.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black54 : Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: DropdownButton<String>(
                    value: _selectedZikr,
                    items: _azkar.map((String zikr) {
                      return DropdownMenuItem<String>(
                        value: zikr,
                        child: Center(
                          child: Text(
                            zikr,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.greenAccent : Colors.green,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: _changeZikr,
                    isExpanded: true,
                    underline: Container(),
                    icon: Icon(Icons.arrow_drop_down, color: isDark ? Colors.greenAccent : Colors.green),
                    style: TextStyle(fontSize: 18, color: isDark ? Colors.greenAccent : Colors.green),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: 180,
                    width: 180,
                    child: CircularProgressIndicator(
                      value: _progress(),
                      backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(isDark ? Colors.greenAccent : Colors.green),
                      strokeWidth: 10,
                    ),
                  ),
                  Text(
                    '$_count',
                    style: TextStyle(
                      fontSize: 50,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 50),
              Text(
                'Completed Loops count $_loopCounter',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.greenAccent : Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _resetCounter,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.green.shade800 : Colors.green.shade500,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 5,
                ),
                child: Text(
                  "Reset",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.black : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
