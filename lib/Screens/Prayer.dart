import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';

class Prayer extends StatefulWidget {
  const Prayer({Key? key}) : super(key: key);

  @override
  State<Prayer> createState() => _PrayerTimesState();
}

class _PrayerTimesState extends State<Prayer> with WidgetsBindingObserver {
  Map<String, PrayerTime> _prayerTimes = {};
  LocationInfo? _currentLocation;
  String? _hijriDate;
  String? _gregorianDate;
  bool _isLoading = true;
  String? _error;
  DateTime? _lastUpdated;
  Timer? _refreshTimer;

  static const Duration _refreshInterval = Duration(minutes: 30);
  static const Duration _timeoutDuration = Duration(seconds: 15);

  static const List<LocationInfo> _availableLocations = [
    LocationInfo(country: "Egypt", city: "Cairo"),
    LocationInfo(country: "Egypt", city: "Alexandria"),
    LocationInfo(country: "Egypt", city: "Giza"),
    LocationInfo(country: "Egypt", city: "Sharm El-Sheikh"),
    LocationInfo(country: "Egypt", city: "Luxor"),
    LocationInfo(country: "Egypt", city: "Mersa Matruh"),
    LocationInfo(country: "Egypt", city: "Dakahlia"),
    LocationInfo(country: "Saudi Arabia", city: "Riyadh"),
    LocationInfo(country: "Saudi Arabia", city: "Jeddah"),
    LocationInfo(country: "Saudi Arabia", city: "Mecca"),
    LocationInfo(country: "Saudi Arabia", city: "Medina"),
    LocationInfo(country: "Saudi Arabia", city: "Dammam"),
    LocationInfo(country: "United States", city: "New York"),
    LocationInfo(country: "United States", city: "Los Angeles"),
    LocationInfo(country: "United States", city: "Chicago"),
    LocationInfo(country: "United States", city: "Houston"),
    LocationInfo(country: "United States", city: "Miami"),
    LocationInfo(country: "Germany", city: "Berlin"),
    LocationInfo(country: "Germany", city: "Munich"),
    LocationInfo(country: "Germany", city: "Hamburg"),
    LocationInfo(country: "Germany", city: "Cologne"),
    LocationInfo(country: "Germany", city: "Frankfurt"),
    LocationInfo(country: "France", city: "Paris"),
    LocationInfo(country: "France", city: "Lyon"),
    LocationInfo(country: "France", city: "Marseille"),
    LocationInfo(country: "France", city: "Nice"),
    LocationInfo(country: "France", city: "Toulouse"),
    LocationInfo(country: "India", city: "Delhi"),
    LocationInfo(country: "India", city: "Mumbai"),
    LocationInfo(country: "India", city: "Bangalore"),
    LocationInfo(country: "India", city: "Chennai"),
    LocationInfo(country: "India", city: "Hyderabad"),
    LocationInfo(country: "Japan", city: "Tokyo"),
    LocationInfo(country: "Japan", city: "Osaka"),
    LocationInfo(country: "Japan", city: "Kyoto"),
    LocationInfo(country: "Japan", city: "Nagoya"),
    LocationInfo(country: "Japan", city: "Sapporo"),
    LocationInfo(country: "Taiwan", city: "Taipei"),
    LocationInfo(country: "Taiwan", city: "Kaohsiung"),
    LocationInfo(country: "Taiwan", city: "Taichung"),
    LocationInfo(country: "Taiwan", city: "Tainan"),
    LocationInfo(country: "Taiwan", city: "Taoyuan"),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeData();
    _setupAutoRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkForDataRefresh();
    }
  }

  void _setupAutoRefresh() {
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (mounted) _loadPrayerTimes();
    });
  }

  Future<void> _initializeData() async {
    try {
      await _loadSavedLocation();
      await _loadPrayerTimes();
    } catch (e) {
      _handleError('Failed to initialize: ${e.toString()}');
    }
  }

  Future<void> _loadSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final country = prefs.getString('prayer_country') ?? 'Egypt';
    final city = prefs.getString('prayer_city') ?? 'Cairo';

    _currentLocation = LocationInfo(country: country, city: city);
  }

  Future<void> _saveLocation(LocationInfo location) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString('prayer_country', location.country),
      prefs.setString('prayer_city', location.city),
    ]);
  }

  void _checkForDataRefresh() {
    if (_lastUpdated == null) return;

    final timeSinceUpdate = DateTime.now().difference(_lastUpdated!);
    if (timeSinceUpdate > _refreshInterval) {
      _loadPrayerTimes();
    }
  }

  Future<void> _loadPrayerTimes() async {
    if (_currentLocation == null) return;

    if (!_isLoading) {
      setState(() => _isLoading = true);
    }

    try {
      final times = await _fetchPrayerTimes(_currentLocation!);

      if (mounted) {
        setState(() {
          _prayerTimes = times;
          _isLoading = false;
          _error = null;
          _lastUpdated = DateTime.now();
        });
      }
    } catch (e) {
      _handleError('Failed to load prayer times: ${e.toString()}');
    }
  }

  Future<Map<String, PrayerTime>> _fetchPrayerTimes(LocationInfo location) async {
    final url = 'https://api.aladhan.com/v1/timingsByCity'
        '?city=${Uri.encodeComponent(location.city)}'
        '&country=${Uri.encodeComponent(location.country)}'
        '&method=5';

    final response = await http.get(
      Uri.parse(url),
    ).timeout(_timeoutDuration);

    if (response.statusCode != 200) {
      throw Exception('Server returned ${response.statusCode}');
    }

    final data = json.decode(response.body);
    if (data['code'] != 200 || data['data'] == null) {
      throw Exception('Invalid response from server');
    }

    final timings = data['data']['timings'] as Map<String, dynamic>;
    final hijriDate = data['data']['date']['hijri'];
    final gregorianDate = data['data']['date']['gregorian'];

    _hijriDate = '${hijriDate['day']} ${hijriDate['month']['en']} ${hijriDate['year']} AH';
    _gregorianDate = '${gregorianDate['day']} ${gregorianDate['month']['en']} ${gregorianDate['year']}';

    return {
      'Fajr': PrayerTime(
        name: 'Fajr',
        arabicName: 'الفجر',
        time: _parseTime(timings['Fajr']),
        icon: Icons.wb_twilight,
        description: 'Dawn Prayer',
      ),
      'Dhuhr': PrayerTime(
        name: 'Dhuhr',
        arabicName: 'الظهر',
        time: _parseTime(timings['Dhuhr']),
        icon: Icons.wb_sunny,
        description: 'Noon Prayer',
      ),
      'Asr': PrayerTime(
        name: 'Asr',
        arabicName: 'العصر',
        time: _parseTime(timings['Asr']),
        icon: Icons.wb_cloudy,
        description: 'Afternoon Prayer',
      ),
      'Maghrib': PrayerTime(
        name: 'Maghrib',
        arabicName: 'المغرب',
        time: _parseTime(timings['Maghrib']),
        icon: Icons.nightlight_round,
        description: 'Sunset Prayer',
      ),
      'Isha': PrayerTime(
        name: 'Isha',
        arabicName: 'العشاء',
        time: _parseTime(timings['Isha']),
        icon: Icons.nights_stay,
        description: 'Night Prayer',
      ),
    };
  }
  TimeOfDay _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  void _handleError(String message) {
    if (mounted) {
      setState(() {
        _error = message;
        _isLoading = false;
      });
    }
  }

  Future<void> _changeLocation(LocationInfo newLocation) async {
    if (_currentLocation == newLocation) return;

    setState(() {
      _currentLocation = newLocation;
      _isLoading = true;
      _error = null;
    });

    await _saveLocation(newLocation);
    await _loadPrayerTimes();
  }

  PrayerTime? _getNextPrayer() {
    final now = TimeOfDay.now();
    final currentMinutes = now.hour * 60 + now.minute;

    for (final prayer in _prayerTimes.values) {
      final prayerMinutes = prayer.time.hour * 60 + prayer.time.minute;
      if (prayerMinutes > currentMinutes) {
        return prayer;
      }
    }

    return _prayerTimes['Fajr'];
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
      floatingActionButton: _buildRefreshButton(isDark),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark, ColorScheme colorScheme) {
    return AppBar(
      title: const Text(
        'Prayer Times',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      backgroundColor: isDark ? Colors.green.shade900 : Colors.greenAccent.shade400,
      foregroundColor: isDark ? colorScheme.onSurface : Colors.white,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      actions: [
        if (_lastUpdated != null)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Updated: ${_formatUpdateTime(_lastUpdated!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? colorScheme.onSurface.withOpacity(0.7) : Colors.white70,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDateCard(bool isDark, ColorScheme colorScheme) {
    if (_gregorianDate == null || _hijriDate == null) return const SizedBox();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withOpacity(0.3)
            : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                color: isDark ? Colors.green.shade200 : Colors.green.shade700,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Today\'s Date',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.green.shade200 : Colors.green.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gregorian',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _gregorianDate!,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.green.shade900,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Hijri',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _hijriDate!,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.green.shade900,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [Colors.green.shade900, Colors.green.shade800, Colors.green.shade700]
              : [Colors.green.shade300, Colors.green.shade600, Colors.green.shade900],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildLocationSelector(isDark, colorScheme),
            _buildDateCard(isDark, colorScheme),
            _buildNextPrayerCard(isDark),
            Expanded(child: _buildPrayerList(isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSelector(bool isDark, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withOpacity(0.3)
            : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButton<LocationInfo>(
        value: _currentLocation,
        hint: const Text('Select Location'),
        items: _availableLocations.map((location) => DropdownMenuItem(
          value: location,
          child: Text(
            '${location.city}, ${location.country}',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.green.shade800,
              fontWeight: FontWeight.w500,
            ),
          ),
        )).toList(),
        onChanged: (location) {
          if (location != null) _changeLocation(location);
        },
        isExpanded: true,
        underline: const SizedBox(),
        icon: Icon(
          Icons.location_on,
          color: isDark ? Colors.white : Colors.green.shade800,
        ),
        dropdownColor: isDark ? Colors.grey.shade800 : Colors.white,
      ),
    );
  }

  Widget _buildNextPrayerCard(bool isDark) {
    final nextPrayer = _getNextPrayer();

    if (nextPrayer == null) return const SizedBox();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.green.shade800.withOpacity(0.8)
            : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade600,
              shape: BoxShape.circle,
            ),
            child: Icon(
              nextPrayer.icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Next Prayer',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.green.shade200 : Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${nextPrayer.name} (${nextPrayer.arabicName})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.green.shade900,
                  ),
                ),
              ],
            ),
          ),
          Text(
            nextPrayer.time.format(context),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.green.shade200 : Colors.green.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerList(bool isDark) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Loading prayer times...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadPrayerTimes,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_prayerTimes.isEmpty) {
      return const Center(
        child: Text(
          'No prayer times available',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _prayerTimes.length,
      itemBuilder: (context, index) {
        final prayer = _prayerTimes.values.elementAt(index);
        return _buildPrayerCard(prayer, isDark);
      },
    );
  }

  Widget _buildPrayerCard(PrayerTime prayer, bool isDark) {
    final now = TimeOfDay.now();
    final isCurrentPrayer = _isCurrentPrayerTime(prayer.time, now);
    final isNextPrayer = prayer == _getNextPrayer();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isCurrentPrayer
            ? Colors.orange.shade600.withOpacity(0.9)
            : isNextPrayer
            ? Colors.green.shade600.withOpacity(0.9)
            : isDark
            ? Colors.black.withOpacity(0.3)
            : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: isCurrentPrayer || isNextPrayer
            ? Border.all(color: Colors.white, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isCurrentPrayer || isNextPrayer
                ? Colors.white.withOpacity(0.2)
                : Colors.green.shade600,
            shape: BoxShape.circle,
          ),
          child: Icon(
            prayer.icon,
            color: isCurrentPrayer || isNextPrayer
                ? Colors.white
                : Colors.white,
            size: 24,
          ),
        ),
        title: Row(
          children: [
            Text(
              prayer.name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isCurrentPrayer || isNextPrayer
                    ? Colors.white
                    : isDark
                    ? Colors.white
                    : Colors.green.shade900,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              prayer.arabicName,
              style: TextStyle(
                fontSize: 16,
                color: isCurrentPrayer || isNextPrayer
                    ? Colors.white.withOpacity(0.8)
                    : isDark
                    ? Colors.green.shade200
                    : Colors.green.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        subtitle: Text(
          prayer.description,
          style: TextStyle(
            fontSize: 14,
            color: isCurrentPrayer || isNextPrayer
                ? Colors.white.withOpacity(0.7)
                : isDark
                ? Colors.grey.shade300
                : Colors.green.shade600,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              prayer.time.format(context),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isCurrentPrayer || isNextPrayer
                    ? Colors.white
                    : isDark
                    ? Colors.green.shade200
                    : Colors.green.shade700,
              ),
            ),
            if (isCurrentPrayer)
              Text(
                'Now',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.w600,
                ),
              )
            else if (isNextPrayer)
              Text(
                'Next',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRefreshButton(bool isDark) {
    return FloatingActionButton(
      onPressed: _isLoading ? null : _loadPrayerTimes,
      backgroundColor: isDark ? Colors.green.shade700 : Colors.green.shade600,
      foregroundColor: Colors.white,
      child: _isLoading
          ? const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2,
        ),
      )
          : const Icon(Icons.refresh),
    );
  }

  bool _isCurrentPrayerTime(TimeOfDay prayerTime, TimeOfDay currentTime) {
    final prayerMinutes = prayerTime.hour * 60 + prayerTime.minute;
    final currentMinutes = currentTime.hour * 60 + currentTime.minute;

    return currentMinutes >= prayerMinutes &&
        currentMinutes <= prayerMinutes + 30;
  }

  String _formatUpdateTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${time.day}/${time.month}';
    }
  }
}

class PrayerTime {
  final String name;
  final String arabicName;
  final TimeOfDay time;
  final IconData icon;
  final String description;

  const PrayerTime({
    required this.name,
    required this.arabicName,
    required this.time,
    required this.icon,
    required this.description,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PrayerTime &&
        other.name == name &&
        other.time == time;
  }

  @override
  int get hashCode => name.hashCode ^ time.hashCode;
}

class LocationInfo {
  final String country;
  final String city;

  const LocationInfo({
    required this.country,
    required this.city,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocationInfo &&
        other.country == country &&
        other.city == city;
  }

  @override
  int get hashCode => country.hashCode ^ city.hashCode;

  @override
  String toString() => '$city, $country';
}