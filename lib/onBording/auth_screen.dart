import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Screens/Home.dart';

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  String? _imagePath;
  String? _selectedCountry;
  String? _selectedCity;

  final Map<String, List<String>> countryCities = {
    "Egypt": ["Cairo", "Alexandria", "Giza", "Sharm El-Sheikh", "Luxor" ,"Marsa Matrouh", "Dakahlia"],
    "Saudi Arabia": ["Riyadh", "Jeddah", "Mecca", "Medina", "Dammam"],
    "United States": ["New York", "Los Angeles", "Chicago", "Houston", "Miami"],
    "Germany": ["Berlin", "Munich", "Hamburg", "Cologne", "Frankfurt"],
    "France": ["Paris", "Lyon", "Marseille", "Nice", "Toulouse"],
    "India": ["Delhi", "Mumbai", "Bangalore", "Chennai", "Hyderabad"],
    "Japan": ["Tokyo", "Osaka", "Kyoto", "Nagoya", "Sapporo"],
    "Taiwan": ["Taipei", "Kaohsiung", "Taichung", "Tainan", "Taoyuan"],
  };

  Future<void> _saveUserData() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _selectedCountry == null ||
        _selectedCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please fill in all fields!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', _nameController.text);
    await prefs.setString('email', _emailController.text);
    await prefs.setString('country', _selectedCountry!);
    await prefs.setString('city', _selectedCity!);
    await prefs.setBool('isLoggedIn', true);

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: Duration(milliseconds: 500),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/Mosque.jpg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.darken),
          ),
        ),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.green.withOpacity(0.4),
                    Colors.black.withOpacity(0.9),
                  ],
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {},
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          backgroundImage: _imagePath != null ? FileImage(File(_imagePath!)) : null,
                          child: _imagePath == null ? Icon(Icons.person, size: 60, color: Colors.white) : null,
                        ),
                      ),
                      SizedBox(height: 20),
                      _buildInputField(_nameController, "Username", Icons.person),
                      SizedBox(height: 15),
                      _buildInputField(_emailController, "Email", Icons.email),
                      SizedBox(height: 15),
                      _buildDropdown("Select Country", _selectedCountry, countryCities.keys.toList(), (value) {
                        setState(() {
                          _selectedCountry = value;
                          _selectedCity = null;
                        });
                      }),
                      SizedBox(height: 15),
                      if (_selectedCountry != null)
                        _buildDropdown("Select City", _selectedCity, countryCities[_selectedCountry!]!, (value) {
                          setState(() {
                            _selectedCity = value;
                          });
                        }),
                      SizedBox(height: 25),
                      ElevatedButton(
                        onPressed: _saveUserData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent.shade400,
                          foregroundColor: Colors.black,
                          padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text("Save & Continue", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      style: TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.white70),
        labelStyle: TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, String? value, List<String> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
      ),
      dropdownColor: Colors.black87,
      icon: Icon(Icons.arrow_drop_down, color: Colors.white70),
      style: TextStyle(color: Colors.white),
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}
