import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'panel_dropdown.dart';

import '../controllers/wilayah_selection_controller.dart';
import '../controllers/pekerjaan_controller.dart';
import '../controllers/status_anggaran_controller.dart';
import '../controllers/status_pelaksanaan_controller.dart';
import '../controllers/indikator_controller.dart';
import '../controllers/kategori_paket_pekerjaan_controller.dart';
import '../models/indikator_model.dart';
import '../models/pekerjaan_model.dart';
import '../models/status_anggaran_model.dart';
import '../models/status_pelaksanaan_model.dart';
import '../models/kategori_paket_pekerjaan_model.dart';

// 1. The Widget configuration class (Immutable)
class RendukPanel extends StatefulWidget {
  final VoidCallback onClose;

  const RendukPanel({super.key, required this.onClose});

  @override
  State<RendukPanel> createState() => _RendukPanelState();
}

class _RendukPanelState extends State<RendukPanel> {
  late final WilayahSelectionController _wilayah =context.read<WilayahSelectionController>();

  late final PekerjaanController dataSource =context.read<PekerjaanController>();

  late final StatusAnggaranController statusAnggaran = context.read<StatusAnggaranController>();

  late final StatusPelaksanaanController statusPelaksanaan = context.read<StatusPelaksanaanController>();

  late final IndikatorController indikator = context.read<IndikatorController>();

  late final KategoriPaketPekerjaanController kategoriPaketPekerjaan = context.watch<KategoriPaketPekerjaanController>();

  final ScrollController _panelScrollController = ScrollController();

  String? _selectedAreaCode = '0';

  final Map<String, String> _optionProvinces = const {
    //'0': 'All',
    '11': 'Aceh',
    '12': 'Sumatera Utara',
    '13': 'Sumatera Barat',
  };
  String? _selectedOptionProv;

  final List<String> _pilihanCariTahunPelaksanaan = [
    '2025',
    '2026',
    '2027',
    '2028',
  ];
  String? _cariTahunAnggaran;
  String? _cariNamaPekerjaan;
  String? _cariPelaksanaId;

  int _selectedPekerjaanIndex = 0;

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Ringkasan Paket Pekerjaan Penanganan Bencana Sumatra dan Aceh",
                style: TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close, color: Colors.black, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const Text("Ringkasan jenis paket pekerjaan di Sumatera dan Aceh",
              style: TextStyle(color: Colors.black, fontSize: 11)),
          //const SizedBox(height: 15),
          //Row(
          //  children: [
          //    Expanded(
          //      child: PanelDropdown(
          //        hint: "Prop :",
          //        value: _wilayah.selectedProv,
          //        items: _optionProvinces,
          //        onChanged: (String? selectedId) {
          //          _wilayah.setSelectedProv(selectedId ?? '0');
          //          setState(() {
          //            _selectedOptionProv = selectedId;
          //            _selectedAreaCode = selectedId;
          //          });
          //          dataSource.filterByProvinsiId(_wilayah.selectedProv);
          //        },
          //      ),
          //    ),
          //  ],
          //),
          const SizedBox(height: 10),
          rendukPencarianData(),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              dataSource.clearFilters();
            },
            icon: const Icon(Icons.filter_alt_off, size: 16),
            label: const Text("Reset Filter"),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black,
              side: const BorderSide(color: Colors.grey),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text("Total pekerjaan : ${dataSource.filteredPekerjaanData.length}",
              style: const TextStyle(color: Colors.black, fontSize: 15)),
          const Divider(color: Colors.black),
        ],
      ),
    );
  }

  Widget _buildPekerjaanList() {
    return ListView.separated(
      padding: const EdgeInsets.all(10),
      controller: _panelScrollController,
      itemCount: dataSource.filteredPelaksanaData.length,
      separatorBuilder: (_, __) => const SizedBox(height: 20),
      itemBuilder: (context, index) {
        final pelaksana = dataSource.filteredPelaksanaData[index];

        final String namaPelaksana = pelaksana.nama ?? "Tanpa Nama";
        final num progressPersen = pelaksana.persentase ?? 0;
        final int jumlahPekerjaan = pelaksana.listPekerjaan.length;
        final bool isSelected = index == _selectedPekerjaanIndex;

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedPekerjaanIndex = index;
              });
              dataSource.filterByPelaksanaId(pelaksana.id);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF996600).withOpacity(0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "${index + 1}. $namaPelaksana",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      Text(
                        "${progressPersen.toStringAsFixed(0)}% | $jumlahPekerjaan Pekerjaan",
                        style: const TextStyle(color: Colors.black, fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  LinearProgressIndicator(
                    value: progressPersen.toDouble() / 100,
                    backgroundColor: Colors.black.withOpacity(0.1),
                    color: jumlahPekerjaan > 0
                        ? const Color(0xFF996600)
                        : Colors.transparent,
                    minHeight: 3,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Right-hand detail pane: shows every pekerjaan item whose `pelaksanaId`
  /// matches the pelaksana currently selected in [_buildPekerjaanList].
  Widget _detail() {
    if (dataSource.filteredPelaksanaData.isEmpty) {
      return const Center(
        child: Text(
          "Tidak ada data pelaksana",
          style: TextStyle(color: Colors.black38),
        ),
      );
    }

    // Guard against the selected index going out of range if the data
    // changes (e.g. after a filter refresh).
    final int safeIndex = _selectedPekerjaanIndex
        .clamp(0, dataSource.filteredPelaksanaData.length - 1);
    final selectedPelaksana = dataSource.filteredPelaksanaData[safeIndex];

    final List<PekerjaanModel> matchingPekerjaan = dataSource.filteredPekerjaanData
        .where((pekerjaan) => pekerjaan.pelaksanaId == selectedPelaksana.id)
        .toList();

    if (matchingPekerjaan.isEmpty) {
      return const Center(
        child: Text(
          "Tidak ada rincian pekerjaan",
          style: TextStyle(color: Colors.black38),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: matchingPekerjaan.length,
      itemBuilder: (context, index) {
        final detail = matchingPekerjaan[index];

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              dataSource.filterById(detail.id);
            },
            child: Card(
              color: Colors.white.withOpacity(0.05),
              margin: const EdgeInsets.only(bottom: 15),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.engineering,
                            color: Colors.cyanAccent, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            detail.nama ?? "Tanpa Nama",
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildDetailRow("Nominal", formatRupiah(detail.nominal)),
                    _buildDetailRow(
                      "Nilai Kontrak",
                      detail.nilaiKontrak != null
                          ? formatRupiah(detail.nilaiKontrak)
                          : '-',
                    ),
                    _buildDetailRow(
                        "Tahun anggaran", detail.tahunAnggaran ?? '-'),
                    const SizedBox(height: 10),
                    Text(
                      "Progres: ${detail.persentase ?? 0}%",
                      style: const TextStyle(
                          color: Colors.orangeAccent, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String formatRupiah(dynamic rawValue) {
    if (rawValue == null) return 'Rp. 0';
    String digitsOnly = rawValue.toString().replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return 'Rp. 0';
    final intValue = int.tryParse(digitsOnly) ?? 0;
    final RegExp regex = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String formatted =
        intValue.toString().replaceAllMapped(regex, (Match m) => '${m[1]}.');
    return 'Rp. $formatted';
  }

  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text("$label: ${value ?? '-'}",
          style: const TextStyle(color: Colors.white70, fontSize: 11)),
    );
  }

  Widget rendukPencarianData() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.10),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.only(right: 40.0, left: 16.0),
          title: const Row(
            children: [
              Icon(Icons.search, size: 20),
              SizedBox(width: 8),
              Text(
                'Pencarian data',
                style: TextStyle(color: Colors.black, fontSize: 15),
              ),
            ],
          ),
          trailing: const Icon(Icons.expand_more, color: Colors.black),
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.60),
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Nama / Keterangan',
                            style: TextStyle(color: Colors.black, fontSize: 15)),
                        const SizedBox(height: 4),
                        TextField(
                          style: const TextStyle(color: Colors.black, fontSize: 14),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Cari nama pekerjaan',
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                          onChanged: (textValue) {
                            setState(() {
                              _cariNamaPekerjaan = textValue;
                            });
                            dataSource.filterByNama(textValue);
                          },
                        ),
                        const SizedBox(height: 16),
                        const Text('Provinsi',
                            style: TextStyle(color: Colors.black, fontSize: 15)),
                        const SizedBox(height: 4),
                        DropdownMenu<String>(
                          menuHeight: MediaQuery.of(context).size.height * 0.40,
                          expandedInsets: EdgeInsets.zero,
                          //initialSelection: _cariTahunAnggaran,
                          textStyle: const TextStyle(color: Colors.black, fontSize: 14),
                          hintText: '-Pilih Provinsi-',
                          inputDecorationTheme: const InputDecorationTheme(
                            border: OutlineInputBorder(),
                            hintStyle: TextStyle(color: Colors.black, fontSize: 12),
                          ),
                          dropdownMenuEntries:
                            _optionProvinces.entries.map((opt) {
                            return DropdownMenuEntry<String>(
                              value: opt.key,
                              label: opt.value,
                              style:
                                  MenuItemButton.styleFrom(foregroundColor: Colors.black),
                            );
                          }).toList(),
                          onSelected: (newValue) {
                            _wilayah.setSelectedProv(newValue ?? '0');

                            setState(() {
                            });
                            dataSource.filterByProvinsiId(_wilayah.selectedProv);
                            _wilayah.populateOptionKabupaten();
                          },
                        ),
                        const SizedBox(height: 16),
                        const Text('Kabupaten / Kota',
                            style: TextStyle(color: Colors.black, fontSize: 15)),
                        const SizedBox(height: 4),
                        DropdownMenu<String>(
                          menuHeight: MediaQuery.of(context).size.height * 0.40,
                          expandedInsets: EdgeInsets.zero,
                          //initialSelection: _cariTahunAnggaran,
                          textStyle: const TextStyle(color: Colors.black, fontSize: 14),
                          hintText: '-Pilih kabupaten / kota-',
                          inputDecorationTheme: const InputDecorationTheme(
                            border: OutlineInputBorder(),
                            hintStyle: TextStyle(color: Colors.black, fontSize: 12),
                          ),
                          dropdownMenuEntries:
                            _wilayah.optionKabupaten.entries.map((opt) {
                            return DropdownMenuEntry<String>(
                              value: opt.key,
                              label: opt.value,
                              style:
                                  MenuItemButton.styleFrom(foregroundColor: Colors.black),
                            );
                          }).toList(),
                          onSelected: (newValue) {
                            _wilayah.setSelectedKabupaten(newValue ?? '0');

                            setState(() {
                            });
                            dataSource.filterByKabupatenId(newValue);
                            _wilayah.populateOptionKecamatan();
                          },
                        ),
                        const SizedBox(height: 16),
                        const Text('Kecamatan',
                            style: TextStyle(color: Colors.black, fontSize: 15)),
                        const SizedBox(height: 4),
                        DropdownMenu<String>(
                          menuHeight: MediaQuery.of(context).size.height * 0.40,
                          expandedInsets: EdgeInsets.zero,
                          //initialSelection: _cariTahunAnggaran,
                          textStyle: const TextStyle(color: Colors.black, fontSize: 14),
                          hintText: '-Pilih kecamatan-',
                          inputDecorationTheme: const InputDecorationTheme(
                            border: OutlineInputBorder(),
                            hintStyle: TextStyle(color: Colors.black, fontSize: 12),
                          ),
                          dropdownMenuEntries:
                            _wilayah.optionKecamatan.entries.map((opt) {
                            return DropdownMenuEntry<String>(
                              value: opt.key,
                              label: opt.value,
                              style:
                                  MenuItemButton.styleFrom(foregroundColor: Colors.black),
                            );
                          }).toList(),
                          onSelected: (newValue) {
                            _wilayah.setSelectedKecamatan(newValue ?? '0');

                            setState(() {
                            });
                            dataSource.filterByKecamatanId(newValue);
                          },
                        ),
                        const SizedBox(height: 16),
                        const Text('Pelaksana',
                            style: TextStyle(color: Colors.black, fontSize: 15)),
                        const SizedBox(height: 4),
                        DropdownMenu<String>(
                          menuHeight: MediaQuery.of(context).size.height * 0.40,
                          expandedInsets: EdgeInsets.zero,
                          initialSelection: _cariPelaksanaId,
                          textStyle: const TextStyle(color: Colors.black, fontSize: 14),
                          hintText: '-Pilih pelaksana-',
                          inputDecorationTheme: const InputDecorationTheme(
                            border: OutlineInputBorder(),
                            hintStyle: TextStyle(color: Colors.black, fontSize: 12),
                          ),
                          dropdownMenuEntries: dataSource.allPelaksanaData.map((PelaksanaModel pelaksana) {
                            return DropdownMenuEntry<String>(
                              value: pelaksana.id.toString(),
                              label: pelaksana.nama ?? 'Tanpa Nama',
                              style: MenuItemButton.styleFrom(foregroundColor: Colors.black),
                            );
                          }).toList(),
                          onSelected: (newValue) {
                            setState(() {
                              _cariPelaksanaId = newValue;
                            });
                            dataSource.filterByPelaksanaId(
                              newValue == null ? null : int.tryParse(newValue),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        const Text('Status Anggaran',
                            style: TextStyle(color: Colors.black, fontSize: 15)),
                        const SizedBox(height: 4),
                        DropdownMenu<String>(
                          menuHeight: MediaQuery.of(context).size.height * 0.40,
                          expandedInsets: EdgeInsets.zero,
                          //initialSelection: _cariPelaksanaId,
                          textStyle: const TextStyle(color: Colors.black, fontSize: 14),
                          hintText: '-Pilih status anggaran-',
                          inputDecorationTheme: const InputDecorationTheme(
                            border: OutlineInputBorder(),
                            hintStyle: TextStyle(color: Colors.black, fontSize: 12),
                          ),
                          dropdownMenuEntries: statusAnggaran.data.map((StatusAnggaranModel status) {
                            return DropdownMenuEntry<String>(
                              value: status.id.toString(),
                              label: status.nama,
                              style: MenuItemButton.styleFrom(foregroundColor: Colors.black),
                            );
                          }).toList(),
                          onSelected: (newValue) {
                            dataSource.filterByStatusAnggaranId(
                              newValue == null ? null : int.tryParse(newValue),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        const Text('Status Pelaksanaan',
                            style: TextStyle(color: Colors.black, fontSize: 15)),
                        const SizedBox(height: 4),
                        DropdownMenu<String>(
                          menuHeight: MediaQuery.of(context).size.height * 0.40,
                          expandedInsets: EdgeInsets.zero,
                          //initialSelection: _cariPelaksanaId,
                          textStyle: const TextStyle(color: Colors.black, fontSize: 14),
                          hintText: '-Pilih status pelaksanaan-',
                          inputDecorationTheme: const InputDecorationTheme(
                            border: OutlineInputBorder(),
                            hintStyle: TextStyle(color: Colors.black, fontSize: 12),
                          ),
                          dropdownMenuEntries: statusPelaksanaan.data.map((StatusPelaksanaanModel status) {
                            return DropdownMenuEntry<String>(
                              value: status.id.toString(),
                              label: status.nama,
                              style: MenuItemButton.styleFrom(foregroundColor: Colors.black),
                            );
                          }).toList(),
                          onSelected: (newValue) {
                            dataSource.filterByStatusPelaksanaanId(
                              newValue == null ? null : int.tryParse(newValue),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        const Text('Indikator',
                            style: TextStyle(color: Colors.black, fontSize: 15)),
                        const SizedBox(height: 4),
                        DropdownMenu<String>(
                          menuHeight: MediaQuery.of(context).size.height * 0.40,
                          expandedInsets: EdgeInsets.zero,
                          //initialSelection: _cariPelaksanaId,
                          textStyle: const TextStyle(color: Colors.black, fontSize: 14),
                          hintText: '-Pilih status pelaksanaan-',
                          inputDecorationTheme: const InputDecorationTheme(
                            border: OutlineInputBorder(),
                            hintStyle: TextStyle(color: Colors.black, fontSize: 12),
                          ),
                          dropdownMenuEntries: indikator.data.map((IndikatorModel status) {
                            return DropdownMenuEntry<String>(
                              value: status.id.toString(),
                              label: status.nama,
                              style: MenuItemButton.styleFrom(foregroundColor: Colors.black),
                            );
                          }).toList(),
                          onSelected: (newValue) {
                            dataSource.filterByIndikatorId(
                              newValue == null ? null : int.tryParse(newValue),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        const Text('Kategori',
                            style: TextStyle(color: Colors.black, fontSize: 15)),
                        const SizedBox(height: 4),
                        DropdownMenu<String>(
                          menuHeight: MediaQuery.of(context).size.height * 0.40,
                          expandedInsets: EdgeInsets.zero,
                          //initialSelection: _cariPelaksanaId,
                          textStyle: const TextStyle(color: Colors.black, fontSize: 14),
                          hintText: '-Pilih status pelaksanaan-',
                          inputDecorationTheme: const InputDecorationTheme(
                            border: OutlineInputBorder(),
                            hintStyle: TextStyle(color: Colors.black, fontSize: 12),
                          ),
                          dropdownMenuEntries: kategoriPaketPekerjaan.data.map((KategoriPaketPekerjaanModel status) {
                            return DropdownMenuEntry<String>(
                              value: status.id.toString(),
                              label: status.nama,
                              style: MenuItemButton.styleFrom(foregroundColor: Colors.black),
                            );
                          }).toList(),
                          onSelected: (newValue) {
                            dataSource.filterByKategoriPekerjaanId(
                              newValue == null ? null : int.tryParse(newValue),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        const Text('Cari tahun',
                            style: TextStyle(color: Colors.black, fontSize: 15)),
                        const SizedBox(height: 4),
                        DropdownMenu<String>(
                          menuHeight: MediaQuery.of(context).size.height * 0.40,
                          expandedInsets: EdgeInsets.zero,
                          initialSelection: _cariTahunAnggaran,
                          textStyle: const TextStyle(color: Colors.black, fontSize: 14),
                          hintText: '-Pilih tahun-',
                          inputDecorationTheme: const InputDecorationTheme(
                            border: OutlineInputBorder(),
                            hintStyle: TextStyle(color: Colors.black, fontSize: 12),
                          ),
                          dropdownMenuEntries:
                              _pilihanCariTahunPelaksanaan.map((String value) {
                            return DropdownMenuEntry<String>(
                              value: value,
                              label: value,
                              style:
                                  MenuItemButton.styleFrom(foregroundColor: Colors.black),
                            );
                          }).toList(),
                          onSelected: (newValue) {
                            setState(() {
                              _cariTahunAnggaran = newValue;
                            });
                            dataSource.filterByTahunAnggaran(newValue);
                          },
                        ),
                      ],
                    )
                  )
                )
              )
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 650,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black),
      ),
      child: Column(
        children: [
          _header(),
          Expanded(
            child: Row(
              children: [
                Expanded(flex: 5, child: _buildPekerjaanList()),
                Container(width: 1, color: Colors.white10),
                Expanded(flex: 5, child: _detail()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}