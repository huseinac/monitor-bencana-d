import 'dart:convert';
import 'drone_area_detail_model.dart';

List<DroneAreaModel> droneAreaModelFromJson(String str) =>
    List<DroneAreaModel>.from(json.decode(str).map((x) => DroneAreaModel.fromJson(x)));

String DroneAreaModelToJson(List<DroneAreaModel> data) =>
    json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

class DroneAreaModel {
  final int kabkotaId;
  final String kabkotaNama;
  final int provinsiId;
  final String provinsiNama;
  final int jumlahRo;
  final int jumlahProgram;
  final double totalAnggaran;
  final double lat;
  final double lng;
  final int hasDrone;
  List<DroneAreaDetailModel> detailData;

  DroneAreaModel({
    required this.kabkotaId,
    required this.kabkotaNama,
    required this.provinsiId,
    required this.provinsiNama,
    required this.jumlahRo,
    required this.jumlahProgram,
    required this.totalAnggaran,
    required this.lat,
    required this.lng,
    required this.hasDrone,
    required this.detailData
  });

  factory DroneAreaModel.fromJson(Map<String, dynamic> json) =>
      DroneAreaModel(
        kabkotaId: json["kabkota_id"] as int? ?? 0,
        kabkotaNama: json["kabkota_nama"] as String? ?? "",
        provinsiId: json["provinsi_id"] as int? ?? 0,
        provinsiNama: json["provinsi_nama"] as String? ?? "",
        jumlahRo: json["jumlah_ro"] as int? ?? 0,
        jumlahProgram: json["jumlah_program"] as int? ?? 0,
        totalAnggaran: (json["total_anggaran"] as num?)?.toDouble() ?? 0.0,
        lat: (json["lat"] as num?)?.toDouble() ?? 0.0,
        lng: (json["lng"] as num?)?.toDouble() ?? 0.0,
        hasDrone: json["has_drone"] as bool ? 1 : 0,
        detailData: []
      );

  Map<String, dynamic> toJson() => {
        "kabkota_id": kabkotaId,
        "kabkota_nama": kabkotaNama,
        "provinsi_id": provinsiId,
        "provinsi_nama": provinsiNama,
        "jumlah_ro": jumlahRo,
        "jumlah_program": jumlahProgram,
        "total_anggaran": totalAnggaran,
        "lat": lat,
        "lng": lng,
        "has_drone": hasDrone,
        "detailData": detailData
      };
}