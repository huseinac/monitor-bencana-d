import 'dart:convert';

// For parsing the wrapper object
IndikatorResponse indikatorResponseFromJson(String str) =>
    IndikatorResponse.fromJson(json.decode(str));

String indikatorResponseToJson(IndikatorResponse data) =>
    json.encode(data.toJson());

// For parsing just the list (if you already extracted it)
List<IndikatorModel> indikatorModelFromJson(String str) =>
    List<IndikatorModel>.from(
        json.decode(str).map((x) => IndikatorModel.fromJson(x)));

String indikatorModelToJson(List<IndikatorModel> data) =>
    json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

/// Helper to safely parse a DateTime that may be null.
DateTime? _parseDate(dynamic value) =>
    value == null ? null : DateTime.tryParse(value.toString());

/// Helper to safely parse a double that may come as String, num or null.
double? _parseDouble(dynamic value) =>
    value == null ? null : double.tryParse(value.toString());

// ---------------------------------------------------------------------------
// Wrapper Response
// ---------------------------------------------------------------------------
class IndikatorResponse {
  final List<IndikatorModel> listIndikator;

  IndikatorResponse({
    required this.listIndikator,
  });

  factory IndikatorResponse.fromJson(Map<String, dynamic> json) =>
      IndikatorResponse(
        listIndikator: List<IndikatorModel>.from(
          json["list_indikator"].map((x) => IndikatorModel.fromJson(x)),
        ),
      );

  Map<String, dynamic> toJson() => {
        "list_indikator": List<dynamic>.from(
          listIndikator.map((x) => x.toJson()),
        ),
      };
}

// ---------------------------------------------------------------------------
// Indikator Model
// ---------------------------------------------------------------------------
class IndikatorModel {
  final int id;
  final String kode;
  final String? parentKode;
  final String nama;
  final String? keterangan;
  final double? bobot;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final String? icon;
  final String? icon2;
  final String? icon3;
  final String? satuan;
  final int? total_data;
  final int? total_normal;
  final int? total_mendekati;
  final int? total_atensi;
  final double? persentase;

  IndikatorModel({
    required this.id,
    required this.kode,
    this.parentKode,
    required this.nama,
    this.keterangan,
    this.bobot,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.icon,
    this.icon2,
    this.icon3,
    this.satuan,
    this.total_data,
    this.total_normal,
    this.total_mendekati,
    this.total_atensi,
    this.persentase,
  });

  factory IndikatorModel.fromJson(Map<String, dynamic> json) => IndikatorModel(
        id: json["id"],
        kode: json["kode"],
        parentKode: json["parent_kode"],
        nama: json["nama"],
        keterangan: json["keterangan"],
        bobot: _parseDouble(json["bobot"]),
        createdAt: _parseDate(json["created_at"]),
        updatedAt: _parseDate(json["updated_at"]),
        deletedAt: _parseDate(json["deleted_at"]),
        icon: json["icon"],
        icon2: json["icon2"],
        icon3: json["icon3"],
        satuan: json["satuan"],
        total_data: json["total_data"],
        total_normal: json["total_normal"],
        total_mendekati: json["total_mendekati"],
        total_atensi: json["total_atensi"],
        persentase: _parseDouble(json["persentase"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "kode": kode,
        "parent_kode": parentKode,
        "nama": nama,
        "keterangan": keterangan,
        "bobot": bobot,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
        "deleted_at": deletedAt?.toIso8601String(),
        "icon": icon,
        "icon2": icon2,
        "icon3": icon3,
        "satuan": satuan,
        "total_data": total_data,
        "total_normal": total_normal,
        "total_mendekati": total_mendekati,
        "total_atensi": total_atensi,
        "persentase": persentase,
      };
}