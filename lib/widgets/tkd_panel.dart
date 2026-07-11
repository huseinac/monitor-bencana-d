import 'package:flutter/material.dart';
import 'panel_dropdown.dart';

// 1. The Widget configuration class (Immutable)
class TkdPanel extends StatefulWidget {
  final VoidCallback onClose;
  
  const TkdPanel({super.key, required this.onClose});

  @override
  State<TkdPanel> createState() => _TkdPanelState();
}

class _TkdPanelState extends State<TkdPanel> {
  final ScrollController _panelScrollController = ScrollController();

  String? _selectedAreaCode = '0';

  // Your option data maps
  final Map<String, String> _optionProvinces = const {
    '0': 'All',
    '11': 'Aceh',
    '12': 'Sumatera Utara',
    '13': 'Sumatera Barat',
  };
  String? _selectedOptionProv;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 700,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  "Analisa Penyaluran Transfer Ke Daerah (TKD ) PROV dan Kabupaten/Kota Terdampak Bencana Sumatera dan Aceh",
                  style: TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: widget.onClose, 
                icon: const Icon(Icons.close, color: Colors.black, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: PanelDropdown(
                  hint: "Prop :",
                  value: _selectedOptionProv, // Uses the state variable
                  items: _optionProvinces,
                  onChanged: (String? selectedId) {
                    setState(() {
                      _selectedOptionProv = selectedId;
                      _selectedAreaCode = selectedId;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PanelDropdown(
                  hint: "Kab :",
                  value: null,
                  items: const {'0':'-Pilih Kabupaten'},
                  onChanged: (String? selectedId) {
                    //setState(() {
                    //  _selectedOptionProv = selectedId;
                    //  _selectedAreaCode = selectedId;
                    //});
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PanelDropdown(
                  hint: "Kec :",
                  value: null,
                  items: const {'0':'-Pilih Kecamatan'},
                  onChanged: (String? selectedId) {
                    //setState(() {
                    //  _selectedOptionProv = selectedId;
                    //  _selectedAreaCode = selectedId;
                    //});
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withOpacity(0.50)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Builder(
                builder: (context) {
                  //List<dynamic> displayList = [];
                  //if (_selectedOptionProv == null || _selectedOptionProv == 'All' || _selectedOptionProv == '') {
                  //  displayList = List.from(_tkdData);
                  //} else {
                  //  displayList = _tkdData.where((item) {
                  //    final wilayah = item['wilayah'] ?? {};
                  //    return wilayah['parent_kode']?.toString() == _selectedOptionProv.toString() ||
                  //           wilayah['kode']?.toString() == _selectedOptionProv.toString();
                  //  }).toList();
                  //}

                  String formatRawNum(dynamic val) {
                    if (val == null) return "0";
                    double numVal = double.tryParse(val.toString()) ?? 0.0;
                    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
                    return numVal.toStringAsFixed(0).replaceAllMapped(reg, (Match match) => '${match[1]},');
                  }

                  return Column(
                    children: [
                      Container(
                        color: Colors.black.withOpacity(0.05),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        child: const Row(
                          children: [
                            Expanded(flex: 1, child: Text("No", style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold))),
                            Expanded(flex: 3, child: Text("Pemerintah daerah", style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold))),
                            Expanded(flex: 2, child: Text("TKD 2026", style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold))),
                            Expanded(flex: 2, child: Text("Penyesuaian TKD 2026", style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold))),
                            Expanded(flex: 3, child: Text("Total TKD setelah penyesuaian", style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold))),
                          ],
                        ),
                      ),
                      
                      Expanded(
                        child: Center(
                          child: Text(
                            "Tidak ada data TKD tersedia untuk filter ini.",
                            style: TextStyle(color: Colors.black, fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                        ),
                        //child: displayList.isEmpty
                        //? const Center(
                        //    child: Text(
                        //      "Tidak ada data TKD tersedia untuk filter ini.",
                        //      style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic),
                        //    ),
                        //  )
                        //: ListView.separated(
                        //  padding: EdgeInsets.zero,
                        //  itemCount: displayList.length,
                        //  separatorBuilder: (context, index) => const Divider(color: Colors.black, height: 1),
                        //  itemBuilder: (context, index) {
                        //    final rowItem = displayList[index];
                        //    final wilayah = rowItem['wilayah'] ?? {};
                            
                        //    double ang2026 = double.tryParse(rowItem['anggaran_2026']?.toString() ?? '0') ?? 0.0;
                        //    double penyesuaian = double.tryParse(rowItem['penyesuaian']?.toString() ?? '0') ?? 0.0;
                        //    double totalAkhir = ang2026 + penyesuaian;

                        //    return Container(
                        //      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        //      color: index % 2 == 0 ? Colors.transparent : Colors.white.withOpacity(0.02),
                        //      child: Row(
                        //        children: [
                        //          Expanded(flex: 1, child: Text("${index + 1}", style: const TextStyle(color: Colors.white70, fontSize: 11))),
                        //          Expanded(flex: 3, child: Text(wilayah['nama'] ?? '-', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                        //          Expanded(flex: 2, child: Text(formatRawNum(ang2026), style: const TextStyle(color: Colors.white70, fontSize: 11))),
                        //          Expanded(flex: 2, child: Text(formatRawNum(penyesuaian), style: const TextStyle(color: Colors.amberAccent, fontSize: 11))),
                        //          Expanded(flex: 3, child: Text(formatRawNum(totalAkhir), style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold))),
                        //        ],
                        //      ),
                        //    );
                        //  },
                        //),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}