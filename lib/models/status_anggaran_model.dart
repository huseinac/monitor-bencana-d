import 'dart:convert';

List<StatusAnggaranModel> statusAnggaranModelFromJson(String str) => 
    List<StatusAnggaranModel>.from(json.decode(str).map((x) => StatusAnggaranModel.fromJson(x)));

String StatusAnggaranToJsonModel(List<StatusAnggaranModel> data) => 
    json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

class StatusAnggaranModel {
  final int id;
  final String nama;

  StatusAnggaranModel({
    required this.id,
    required this.nama,
  });

  factory StatusAnggaranModel.fromJson(Map<String, dynamic> json) => StatusAnggaranModel(
        id: json["id"],
        nama: json["nama"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "nama": nama,
      };
}