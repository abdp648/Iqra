class SectionModel {
  int? id;
  String? category;
  String? audio;
  String? filename;
  List<AzkarItem>? azkar;

  SectionModel({this.id, this.category, this.audio, this.filename, this.azkar});

  SectionModel.fromJson(Map<String, dynamic> json) {
    id = json["id"];
    category = json["category"];
    audio = json["audio"];
    filename = json["filename"];
    if (json["array"] != null) {
      azkar = (json["array"] as List).map((item) => AzkarItem.fromJson(item)).toList();
    }
  }
}

class AzkarItem {
  int? id;
  String? text;
  int? count;
  String? audio;
  String? filename;

  AzkarItem({this.id, this.text, this.count, this.audio, this.filename});

  AzkarItem.fromJson(Map<String, dynamic> json) {
    id = json["id"];
    text = json["text"];
    count = json["count"];
    audio = json["audio"];
    filename = json["filename"];
  }
}
