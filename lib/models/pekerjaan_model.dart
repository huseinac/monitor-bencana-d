num? _parseNum(dynamic value) {
  if (value == null) return null;
  if (value is num) return value;
  if (value is String) return num.tryParse(value);
  return null;
}

/// Helper: safely parse a value into an int.
int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

/// Helper: safely parse a value into a String.
String? _parseString(dynamic value) {
  if (value == null) return null;
  return value.toString();
}

/// Helper: safely parse a value into a DateTime.
DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

/// Top-level model: one entry of the root JSON array.
class PelaksanaModel {
  final int? id;
  final String? nama;
  final String? singkatan;
  final String? keterangan;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final List<PekerjaanModel> listPekerjaan;
  final num? persentase;

  PelaksanaModel({
    this.id,
    this.nama,
    this.singkatan,
    this.keterangan,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.listPekerjaan = const [],
    this.persentase,
  });

  factory PelaksanaModel.fromJson(Map<String, dynamic> json) {
    return PelaksanaModel(
      id: _parseInt(json['id']),
      nama: _parseString(json['nama']),
      singkatan: _parseString(json['singkatan']),
      keterangan: _parseString(json['keterangan']),
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      deletedAt: _parseDate(json['deleted_at']),
      listPekerjaan: (json['list_pekerjaan'] as List<dynamic>? ?? [])
          .map((e) => PekerjaanModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      persentase: _parseNum(json['persentase']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nama': nama,
      'singkatan': singkatan,
      'keterangan': keterangan,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'list_pekerjaan': listPekerjaan.map((e) => e.toJson()).toList(),
      'persentase': persentase,
    };
  }

  /// Parse the whole root JSON array (as returned by the API) into a list.
  static List<PelaksanaModel> listFromJson(List<dynamic> jsonList) {
    return jsonList
        .map((e) => PelaksanaModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

/// Model for each item inside a `list_pekerjaan` array.
class PekerjaanModel {
  final int? id;
  final int? provinsiId;
  final int? kabupatenId;
  final int? wilayahId;
  final int? pelaksanaId;
  final int? indikatorId;
  final String? nama;
  final num? nominal;
  final String? keterangan;
  final String? latitude;
  final String? longitude;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? kategoriPaketPekerjaanId;
  final int? penyediaId;
  final String? tahunAnggaran;
  final String? namaProgram;
  final String? namaKegiatan;
  final String? namaSubKegiatan;
  final String? namaRekening;
  final num? paguDana;
  final String? noKontrak;
  final String? namaPaket;
  final String? jenisPengadaan;
  final String? modelPengadaan;
  final DateTime? tanggalKontrak;
  final DateTime? tanggalSelesai;
  final num? nilaiPagu;
  final num? nilaiKontrak;
  final int? statusAnggaranId;
  final int? statusPelaksanaanId;
  final String? tahunPerencanaan;
  final String? tahunUsulan;
  final String? tahunPelaksanaanPekerjaan;
  final num? persentase;

  PekerjaanModel({
    this.id,
    this.provinsiId,
    this.kabupatenId,
    this.wilayahId,
    this.pelaksanaId,
    this.indikatorId,
    this.nama,
    this.nominal,
    this.keterangan,
    this.latitude,
    this.longitude,
    this.createdAt,
    this.updatedAt,
    this.kategoriPaketPekerjaanId,
    this.penyediaId,
    this.tahunAnggaran,
    this.namaProgram,
    this.namaKegiatan,
    this.namaSubKegiatan,
    this.namaRekening,
    this.paguDana,
    this.noKontrak,
    this.namaPaket,
    this.jenisPengadaan,
    this.modelPengadaan,
    this.tanggalKontrak,
    this.tanggalSelesai,
    this.nilaiPagu,
    this.nilaiKontrak,
    this.statusAnggaranId,
    this.statusPelaksanaanId,
    this.tahunPerencanaan,
    this.tahunUsulan,
    this.tahunPelaksanaanPekerjaan,
    this.persentase,
  });

  factory PekerjaanModel.fromJson(Map<String, dynamic> json) {
    return PekerjaanModel(
      id: _parseInt(json['id']),
      provinsiId: _parseInt(json['provinsi_id']),
      kabupatenId: _parseInt(json['kabupaten_id']),
      wilayahId: _parseInt(json['wilayah_id']),
      pelaksanaId: _parseInt(json['pelaksana_id']),
      indikatorId: _parseInt(json['indikator_id']),
      nama: _parseString(json['nama']),
      nominal: _parseNum(json['nominal']),
      keterangan: _parseString(json['keterangan']),
      latitude: _parseString(json['latitude']),
      longitude: _parseString(json['longitude']),
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      kategoriPaketPekerjaanId: _parseInt(json['kategori_paket_pekerjaan_id']),
      penyediaId: _parseInt(json['penyedia_id']),
      tahunAnggaran: _parseString(json['tahun_anggaran']),
      namaProgram: _parseString(json['nama_program']),
      namaKegiatan: _parseString(json['nama_kegiatan']),
      namaSubKegiatan: _parseString(json['nama_sub_kegiatan']),
      namaRekening: _parseString(json['nama_rekening']),
      paguDana: _parseNum(json['pagu_dana']),
      noKontrak: _parseString(json['no_kontrak']),
      namaPaket: _parseString(json['nama_paket']),
      jenisPengadaan: _parseString(json['jenis_pengadaan']),
      modelPengadaan: _parseString(json['model_pengadaan']),
      tanggalKontrak: _parseDate(json['tanggal_kontrak']),
      tanggalSelesai: _parseDate(json['tanggal_selesai']),
      nilaiPagu: _parseNum(json['nilai_pagu']),
      nilaiKontrak: _parseNum(json['nilai_kontrak']),
      statusAnggaranId: _parseInt(json['status_anggaran_id']),
      statusPelaksanaanId: _parseInt(json['status_pelaksanaan_id']),
      tahunPerencanaan: _parseString(json['tahun_perencanaan']),
      tahunUsulan: _parseString(json['tahun_usulan']),
      tahunPelaksanaanPekerjaan:
          _parseString(json['tahun_pelaksanaan_pekerjaan']),
      persentase: _parseNum(json['persentase']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'provinsi_id': provinsiId,
      'kabupaten_id': kabupatenId,
      'wilayah_id': wilayahId,
      'pelaksana_id': pelaksanaId,
      'indikator_id': indikatorId,
      'nama': nama,
      'nominal': nominal,
      'keterangan': keterangan,
      'latitude': latitude,
      'longitude': longitude,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'kategori_paket_pekerjaan_id': kategoriPaketPekerjaanId,
      'penyedia_id': penyediaId,
      'tahun_anggaran': tahunAnggaran,
      'nama_program': namaProgram,
      'nama_kegiatan': namaKegiatan,
      'nama_sub_kegiatan': namaSubKegiatan,
      'nama_rekening': namaRekening,
      'pagu_dana': paguDana,
      'no_kontrak': noKontrak,
      'nama_paket': namaPaket,
      'jenis_pengadaan': jenisPengadaan,
      'model_pengadaan': modelPengadaan,
      'tanggal_kontrak': tanggalKontrak?.toIso8601String(),
      'tanggal_selesai': tanggalSelesai?.toIso8601String(),
      'nilai_pagu': nilaiPagu,
      'nilai_kontrak': nilaiKontrak,
      'status_anggaran_id': statusAnggaranId,
      'status_pelaksanaan_id': statusPelaksanaanId,
      'tahun_perencanaan': tahunPerencanaan,
      'tahun_usulan': tahunUsulan,
      'tahun_pelaksanaan_pekerjaan': tahunPelaksanaanPekerjaan,
      'persentase': persentase,
    };
  }
}
