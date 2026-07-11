import 'dart:convert';

List<WilayahModel> wilayahModelFromJson(String str) => 
    List<WilayahModel>.from(json.decode(str).map((x) => WilayahModel.fromJson(x)));

String wilayahModelToJson(List<WilayahModel> data) => 
    json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

class WilayahModel {
  final int id;
  final String kode;
  final String? parentKode;
  final String nama;
  final String polygon;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double? latitude;
  final double? longitude;
  final String? kondisi;

  WilayahModel({
    required this.id,
    required this.kode,
    this.parentKode,
    required this.nama,
    required this.polygon,
    required this.createdAt,
    required this.updatedAt,
    this.latitude,
    this.longitude,
    this.kondisi,
  });

  factory WilayahModel.fromJson(Map<String, dynamic> json) => WilayahModel(
        id: json["id"],
        kode: json["kode"],
        parentKode: json["parent_kode"],
        nama: json["nama"],
        polygon: json["polygon"],
        createdAt: DateTime.parse(json["created_at"]),
        updatedAt: DateTime.parse(json["updated_at"]),
        latitude: 
          json["latitude"] != null ? double.tryParse(json["latitude"].toString()) :
          (
            json["nama"] == 'Aceh' ? double.tryParse('5.5483') :
            (json["nama"] == 'Sumatera Utara' ? double.tryParse('3.5952') :
              (json["nama"] == 'Sumatera Barat' ? double.tryParse('-0.9471') : null)
            )
          )
        ,
        longitude: json["longitude"] != null ? double.tryParse(json["longitude"].toString()) :
          (
            json["nama"] == 'Aceh' ? double.tryParse('95.3238') :
            (json["nama"] == 'Sumatera Utara' ? double.tryParse('98.6722') :
              (json["nama"] == 'Sumatera Barat' ? double.tryParse('100.4172') : null)
            )
          )
        ,
        kondisi: json["kondisi"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "kode": kode,
        "parent_kode": parentKode,
        "nama": nama,
        "polygon": polygon,
        "created_at": createdAt.toIso8601String(),
        "updated_at": updatedAt.toIso8601String(),
        "latitude": latitude,
        "longitude": longitude,
        "kondisi": kondisi,
      };
}