import 'dart:convert';

List<StatusPelaksanaanModel> statusPelaksanaanModelFromJson(String str) => 
    List<StatusPelaksanaanModel>.from(json.decode(str).map((x) => StatusPelaksanaanModel.fromJson(x)));

String StatusAnggaranToJsonModel(List<StatusPelaksanaanModel> data) => 
    json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

class StatusPelaksanaanModel {
  final int id;
  final String nama;

  StatusPelaksanaanModel({
    required this.id,
    required this.nama,
  });

  factory StatusPelaksanaanModel.fromJson(Map<String, dynamic> json) => StatusPelaksanaanModel(
        id: json["id"],
        nama: json["nama"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "nama": nama,
      };
}