import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_compass_v2/flutter_compass_v2.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Qiblah extends StatefulWidget {
  @override
  _QiblahState createState() => _QiblahState();
}

class _QiblahState extends State<Qiblah> {
  double? _deviceDirection;
  double? _qiblahDirection;
  String locationText = "Fetching location...";

  @override
  void initState() {
    super.initState();
    _fetchLocation();
    FlutterCompass.events?.listen((event) {
      setState(() {
        _deviceDirection = event.heading;
      });
    });
  }

  Future<void> _fetchLocation() async {
    try {
      final response = await http.get(Uri.parse("http://ip-api.com/json"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        double latitude = data["lat"];
        double longitude = data["lon"];
        setState(() {
          locationText = "Lat: $latitude, Lon: $longitude";
          _qiblahDirection = _calculateQiblahDirection(latitude, longitude);
        });
      } else {
        setState(() {
          locationText = "Failed to get location";
        });
      }
    } catch (e) {
      setState(() {
        locationText = "Error: $e";
      });
    }
  }

  double _calculateQiblahDirection(double lat, double lon) {
    const double kaabaLat = 21.4225;
    const double kaabaLon = 39.8262;
    double deltaLon = (kaabaLon - lon).toRad();
    double latRad = lat.toRad();
    double kaabaLatRad = kaabaLat.toRad();
    double y = sin(deltaLon);
    double x = cos(latRad) * tan(kaabaLatRad) - sin(latRad) * cos(deltaLon);
    double qiblahDirection = atan2(y, x).toDeg();
    return (qiblahDirection + 360) % 360;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    double? adjustedDirection;
    if (_deviceDirection != null && _qiblahDirection != null) {
      adjustedDirection = (_qiblahDirection! - _deviceDirection!) % 360;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Qibla"),
        backgroundColor: isDark ? Colors.green.shade900 : Colors.greenAccent.shade400,
      ),
      body: Center(
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
              const SizedBox(height: 30),
              if (adjustedDirection != null)
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            spreadRadius: 3,
                          )
                        ],
                      ),
                    ),

                    Transform.rotate(
                      angle: adjustedDirection.toRad(),
                      child: Image.asset('assets/Qiblah.png'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on double {
  double toRad() => this * pi / 180;
  double toDeg() => this * 180 / pi;
}
