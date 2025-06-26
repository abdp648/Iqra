import 'dart:convert';
import 'package:flutter/services.dart';

class Tafsir {
  String? number;
  String? aya;
  String? text;

  Tafsir({this.number, this.aya, this.text});

  factory Tafsir.fromJson(Map<String, dynamic> json) {
    return Tafsir(
      number: json['number'],
      aya: json['aya'],
      text: json['text'],
    );
  }
}
