// sektor_terdampak_simple.dart
import 'dart:convert';

/// Helper to parse nullable DateTime
DateTime? _parseDate(dynamic value) =>
    value == null ? null : DateTime.tryParse(value.toString());

/// Helper to parse nullable double
double? _parseDouble(dynamic value) =>
    value == null ? null : double.tryParse(value.toString());

/// Model for an item inside "list_sektor_terdampak"
/// (skips the nested "indikator" and "wilayah" objects)
class PaketPekerjaanModel {
  final int id;
  final int wilayahId;
  final int indikatorId;
  final String? kondisiAwal;
  final String? keterangan;
  final DateTime? batasWaktu;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? fotoSebelum;
  final String? fotoSesudah;
  final double? latitude;
  final double? longitude;
  final String? kondisi;
  final String? status;
  final String? namaLokasi;
  final String? alamat;
  final int? persentase;

  PaketPekerjaanModel({
    required this.id,
    required this.wilayahId,
    required this.indikatorId,
    this.kondisiAwal,
    this.keterangan,
    this.batasWaktu,
    this.createdAt,
    this.updatedAt,
    this.fotoSebelum,
    this.fotoSesudah,
    this.latitude,
    this.longitude,
    this.kondisi,
    this.status,
    this.namaLokasi,
    this.alamat,
    this.persentase,
  });

  factory PaketPekerjaanModel.fromJson(Map<String, dynamic> json) =>
      PaketPekerjaanModel(
        id: json["id"],
        wilayahId: json["wilayah_id"],
        indikatorId: json["indikator_id"],
        kondisiAwal: json["kondisi_awal"],
        keterangan: json["keterangan"],
        batasWaktu: _parseDate(json["batas_waktu"]),
        createdAt: _parseDate(json["created_at"]),
        updatedAt: _parseDate(json["updated_at"]),
        fotoSebelum: json["foto_sebelum"],
        fotoSesudah: json["foto_sesudah"],
        latitude: _parseDouble(json["latitude"]),
        longitude: _parseDouble(json["longitude"]),
        kondisi: json["kondisi"],
        status: json["status"],
        namaLokasi: json["nama_lokasi"],
        alamat: json["alamat"],
        persentase: json["persentase"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "wilayah_id": wilayahId,
        "indikator_id": indikatorId,
        "kondisi_awal": kondisiAwal,
        "keterangan": keterangan,
        "batas_waktu": batasWaktu?.toIso8601String(),
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
        "foto_sebelum": fotoSebelum,
        "foto_sesudah": fotoSesudah,
        "latitude": latitude,
        "longitude": longitude,
        "kondisi": kondisi,
        "status": status,
        "nama_lokasi": namaLokasi,
        "alamat": alamat,
        "persentase": persentase,
      };
}