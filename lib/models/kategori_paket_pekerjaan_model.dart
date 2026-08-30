import 'dart:convert';

List<KategoriPaketPekerjaanModel> kategoriPaketPekerjaanModelFromJson(String str) {
  final List<dynamic> rawData = json.decode(str);
  final Map<int, KategoriPaketPekerjaanModel> uniqueMap = {};

  for (var topItem in rawData) {
    if (topItem is Map<String, dynamic> && topItem['list_pekerjaan'] is List) {
    //if(topItem['list_pekerjaan'].length > 0){
      final listPekerjaan = topItem['list_pekerjaan'] as List<dynamic>;

      for (var pekerjaan in listPekerjaan) {
        if (pekerjaan is Map<String, dynamic> &&
            pekerjaan['kategori_paket_pekerjaan'] is Map<String, dynamic>) {
        //if(pekerjaan['kategori_paket_pekerjaan'].length > 0) {
          
          final kategoriData =
              pekerjaan['kategori_paket_pekerjaan'] as Map<String, dynamic>;
          final model = KategoriPaketPekerjaanModel.fromJson(kategoriData);

          if (model.id != 0) {
            uniqueMap[model.id] = model;
          }
        }
      }
    }
  }

  return uniqueMap.values.toList();
}

String KategoriPaketPekerjaanToJsonModel(List<KategoriPaketPekerjaanModel> data) =>
    json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

class KategoriPaketPekerjaanModel {
  final int id;
  final String nama;

  KategoriPaketPekerjaanModel({
    required this.id,
    required this.nama,
  });

  factory KategoriPaketPekerjaanModel.fromJson(Map<String, dynamic> json) =>
      KategoriPaketPekerjaanModel(
        id: json["id"] as int? ?? 0,
        nama: json["nama"] as String? ?? "",
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "nama": nama,
      };
}