import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class Prayer extends StatefulWidget {
  @override
  _PrayerTimesScreenState createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<Prayer> {
  Map<String, String> prayerTimes = {};
  bool isLoading = true;
  String? selectedCountry;
  String? selectedCity;

  List<String> countries = [
    "Egypt",
    "Saudi Arabia",
    "United States",
    "Germany",
    "France",
    "India",
    "Japan",
    "Taiwan"
  ];

  Map<String, List<String>> citiesByCountry = {
    "Egypt": ["Cairo", "Alexandria", "Giza", "Sharm El-Sheikh", "Luxor", "Marsa Matrouh", "Dakahlia"],
    "Saudi Arabia": ["Riyadh", "Jeddah", "Mecca", "Medina", "Dammam"],
    "United States": ["New York", "Los Angeles", "Chicago", "Houston", "Miami"],
    "Germany": ["Berlin", "Munich", "Hamburg", "Cologne", "Frankfurt"],
    "France": ["Paris", "Lyon", "Marseille", "Nice", "Toulouse"],
    "India": ["Delhi", "Mumbai", "Bangalore", "Chennai", "Hyderabad"],
    "Japan": ["Tokyo", "Osaka", "Kyoto", "Nagoya", "Sapporo"],
    "Taiwan": ["Taipei", "Kaohsiung", "Taichung", "Tainan", "Taoyuan"],
  };

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedCountry = prefs.getString('country') ?? "Egypt";
      selectedCity = prefs.getString('city') ?? "Cairo";
    });
    _loadPrayerTimes();
  }

  Future<void> _savePreferences(String country, String city) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('country', country);
    await prefs.setString('city', city);
    _loadPrayerTimes();
  }

  Future<void> _loadPrayerTimes() async {
    if (selectedCountry == null || selectedCity == null) {
      setState(() => isLoading = false);
      return;
    }

    String url =
        "https://api.aladhan.com/v1/timingsByCity?city=$selectedCity&country=$selectedCountry&method=5";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        Map<String, dynamic> times = data["data"]["timings"];

        setState(() {
          prayerTimes = {
            "Fajr": _convertTo12HourFormat(times["Fajr"]),
            "Dhuhr": _convertTo12HourFormat(times["Dhuhr"]),
            "Asr": _convertTo12HourFormat(times["Asr"]),
            "Maghrib": _convertTo12HourFormat(times["Maghrib"]),
            "Isha": _convertTo12HourFormat(times["Isha"]),
          };
          isLoading = false;
        });
      } else {
        _handleError();
      }
    } catch (e) {
      _handleError();
    }
  }

  String _convertTo12HourFormat(String time) {
    try {
      List<String> timeParts = time.split(":");
      int hour = int.parse(timeParts[0]);
      String minute = timeParts[1];
      String period = hour >= 12 ? "PM" : "AM";

      if (hour > 12) {
        hour -= 12;
      } else if (hour == 0) {
        hour = 12;
      }
      return "$hour:$minute $period";
    } catch (e) {
      return time;
    }
  }


  void _handleError() {
    setState(() {
      isLoading = false;
    });
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Error"),
          content: Text("Unable to fetch prayer times. Please try again."),
          actions: <Widget>[
            TextButton(
              child: Text("OK"),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Prayer Times"),
        backgroundColor: isDark ? Colors.green.shade800 : Colors.greenAccent.shade400,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [Colors.green.shade900, Colors.green.shade700]
                : [Colors.green.shade300, Colors.green.shade900],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: prayerTimes.length,
                itemBuilder: (context, index) {
                  String key = prayerTimes.keys.elementAt(index);
                  return PrayerCard(
                    prayer: key,
                    time: prayerTimes[key]!,
                    icon: _getPrayerIcon(key),
                    isDark: isDark,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  CountryCitySelector(
                    selectedCountry: selectedCountry!,
                    selectedCity: selectedCity!,
                    countries: countries,
                    citiesByCountry: citiesByCountry,
                    onCountryChanged: (country) {
                      setState(() {
                        selectedCountry = country;
                        selectedCity = citiesByCountry[country]!.first;
                      });
                      _savePreferences(selectedCountry!, selectedCity!);
                    },
                    onCityChanged: (city) {
                      setState(() {
                        selectedCity = city;
                      });
                      _savePreferences(selectedCountry!, selectedCity!);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getPrayerIcon(String prayer) {
    switch (prayer) {
      case "Fajr":
        return Icons.wb_twilight;
      case "Dhuhr":
        return Icons.wb_sunny;
      case "Asr":
        return Icons.wb_cloudy;
      case "Maghrib":
        return Icons.nightlight_round;
      case "Isha":
        return Icons.nights_stay;
      default:
        return Icons.access_time;
    }
  }
}

class PrayerCard extends StatelessWidget {
  final String prayer;
  final String time;
  final IconData icon;
  final bool isDark;

  const PrayerCard({
    required this.prayer,
    required this.time,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      color: isDark ? Colors.green.shade700 : Colors.white.withOpacity(0.9),
      child: ListTile(
        leading: Icon(icon, color: isDark ? Colors.greenAccent.shade100 : Colors.green.shade800, size: 30),
        title: Text(
          prayer,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.green.shade900,
          ),
        ),
        subtitle: Text(
          time,
          style: TextStyle(
            fontSize: 18,
            color: isDark ? Colors.grey.shade300 : Colors.green.shade700,
          ),
        ),
      ),
    );
  }
}

class CountryCitySelector extends StatelessWidget {
  final String selectedCountry;
  final String selectedCity;
  final List<String> countries;
  final Map<String, List<String>> citiesByCountry;
  final ValueChanged<String?> onCountryChanged;  // Change to String?
  final ValueChanged<String?> onCityChanged;     // Change to String?

  const CountryCitySelector({
    required this.selectedCountry,
    required this.selectedCity,
    required this.countries,
    required this.citiesByCountry,
    required this.onCountryChanged,
    required this.onCityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: selectedCountry,
          decoration: InputDecoration(
            labelText: "Select Country",
            labelStyle: TextStyle(
              color: isDark ? Colors.white : Colors.green.shade900,
              fontSize: 18,
            ),
            filled: true,
            fillColor: isDark ? Colors.green.shade700 : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: isDark ? Colors.green.shade800 : Colors.green.shade500,
                width: 2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: isDark ? Colors.greenAccent.shade100 : Colors.green.shade800,
                width: 2,
              ),
            ),
          ),
          items: countries.map((country) {
            return DropdownMenuItem(
              value: country,
              child: Row(
                children: [
                  Icon(Icons.location_on, color: isDark ? Colors.greenAccent.shade100 : Colors.green.shade800),
                  SizedBox(width: 8),
                  Text(
                    country,
                    style: TextStyle(color: isDark ? Colors.white : Colors.green.shade900),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (String? country) {
            if (country != null) {
              onCountryChanged(country); // Pass the country here
            }
          },
        ),
        const SizedBox(height: 20), // Adjust spacing for a better layout

        DropdownButtonFormField<String>(
          value: selectedCity,
          decoration: InputDecoration(
            labelText: "Select City",
            labelStyle: TextStyle(
              color: isDark ? Colors.white : Colors.green.shade900,
              fontSize: 18,
            ),
            filled: true,
            fillColor: isDark ? Colors.green.shade700 : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: isDark ? Colors.green.shade800 : Colors.green.shade500,
                width: 2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: isDark ? Colors.greenAccent.shade100 : Colors.green.shade800,
                width: 2,
              ),
            ),
          ),
          items: (citiesByCountry[selectedCountry] ?? []).map((city) {
            return DropdownMenuItem(
              value: city,
              child: Row(
                children: [
                  Icon(Icons.location_city, color: isDark ? Colors.greenAccent.shade100 : Colors.green.shade800),
                  SizedBox(width: 8),
                  Text(
                    city,
                    style: TextStyle(color: isDark ? Colors.white : Colors.green.shade900),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (String? city) {
            if (city != null) {
              onCityChanged(city); // Pass the city here
            }
          },
        ),
      ],
    );
  }
}
