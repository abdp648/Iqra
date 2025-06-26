import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'Screens/Home.dart';
import 'onBording/onboarding.dart';
import 'Themes/Themes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: WidgetsFlutterBinding.ensureInitialized());

  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool onboardingDone = prefs.getBool('onboardingCompleted') ?? false;
  bool? savedTheme = prefs.getBool('Theme');

  FlutterNativeSplash.remove();

  runApp(MyApp(
    initialScreen: onboardingDone
        ?  HomeScreen()
        : OnboardingScreen(),
    savedTheme: savedTheme,
  ));
}

class MyApp extends StatefulWidget {
  final Widget initialScreen;
  final bool? savedTheme;

  const MyApp({super.key, required this.initialScreen, required this.savedTheme});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool? savedTheme = prefs.getBool('Theme');
    setState(() {
      _themeMode = savedTheme == null
          ? ThemeMode.system
          : (savedTheme ? ThemeMode.dark : ThemeMode.light);
    });
  }

  void _setTheme(ThemeMode mode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (mode == ThemeMode.system) {
      await prefs.remove('Theme');
    } else {
      await prefs.setBool('Theme', mode == ThemeMode.dark);
    }
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Iqra',
      theme: AppThemes.lightTheme,
      darkTheme: AppThemes.darkTheme,
      themeMode: _themeMode,
      home: widget.initialScreen,
    );
  }
}
