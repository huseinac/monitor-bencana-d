import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

import '../controllers/drone_area_controller.dart';
import '../models/drone_area_model.dart';

class DronePanel extends StatefulWidget {
  final VoidCallback onClose;
  
  const DronePanel({super.key, required this.onClose});

  @override
  State<DronePanel> createState() => _DronePanelState();
}

class _DronePanelState extends State<DronePanel> {
  int _selectedFilterIndex = 0;

  late final DroneAreaController droneArea = context.read<DroneAreaController>();

  Widget _buildFilterButtons() {
      const primaryBlue = Color(0xFF0A58CA);

      return Container(
        //height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: primaryBlue, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Left Option: Semua Kabupaten
            InkWell(
              onTap: () {
                setState(() {
                  _selectedFilterIndex = 0;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _selectedFilterIndex == 0 ? primaryBlue : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(3),
                    bottomLeft: Radius.circular(3),
                  ),
                ),
                child: Text(
                  "Semua Kabupaten",
                  style: TextStyle(
                    color: _selectedFilterIndex == 0 ? Colors.white : primaryBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            // Divider between buttons
            Container(
              width: 1,
              height: 24,
              color: primaryBlue,
            ),

            // Right Option: Ada Video
            InkWell(
              onTap: () {
                setState(() {
                  _selectedFilterIndex = 1;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _selectedFilterIndex == 1 ? primaryBlue : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(3),
                    bottomRight: Radius.circular(3),
                  ),
                ),
                child: Text(
                  "Ada Video",
                  style: TextStyle(
                    color: _selectedFilterIndex == 1 ? Colors.white : primaryBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

  Widget _buildKabKotaCard({
    required String title,
    required String subtitle,
    required bool hasDrone,
  }) {
    return InkWell(
      mouseCursor: SystemMouseCursors.click,
      hoverColor: Colors.grey.shade200, // <--- Darker background shade on hover
      onTap: () {
        // Card click action
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left text column
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),

            // Right status badge
            if (hasDrone)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F8A5F), // Green badge color
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      "Drone",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  "Belum ada",
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {  
    List<DroneAreaModel> filteredDroneAreaData = _selectedFilterIndex == 1 ? droneArea.data.where((x) => x.hasDrone == _selectedFilterIndex).toList()
     : droneArea.data.toList()
    ;

    return Container(
      width: MediaQuery.of(context).size.width * 0.25,
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
                  "Video Drone Kabupaten/Kota Terdampak Bencana",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 17,
                    //fontWeight: FontWeight.bold
                  ),
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
          const Divider(color: Colors.grey),
          const SizedBox(height: 20),
          Column(
            children: [
              Text(
                "Daftar Kabupaten / Kota",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.bold
                ),
              )
            ],
          ),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 10, bottom: 10),
            alignment: Alignment.centerLeft,
            child: _buildFilterButtons(),
          ),

          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(6),
              ),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: filteredDroneAreaData.length,
                separatorBuilder: (context, index) => Divider(
                  color: Colors.grey.shade200,
                  height: 1,
                  thickness: 1,
                ),
                itemBuilder: (context, index) {
                  final item = filteredDroneAreaData[index];
                  return _buildKabKotaCard(
                    title: item.kabkotaNama,
                    subtitle: item.provinsiNama,
                    hasDrone: item.hasDrone == 1 ? true : false,
                  );
                },
              ),
            ),
          )

          //Expanded(
          //  child: Container(
          //    decoration: BoxDecoration(
          //      border: Border.all(color: Colors.grey.withOpacity(0.50)),
          //      borderRadius: BorderRadius.circular(4),
          //    ),
          //    child: Builder(
          //      builder: (context) {
          //        //List<dynamic> displayList = [];
          //        //if (_selectedOptionProv == null || _selectedOptionProv == 'All' || _selectedOptionProv == '') {
          //        //  displayList = List.from(_tkdData);
          //        //} else {
          //        //  displayList = _tkdData.where((item) {
          //        //    final wilayah = item['wilayah'] ?? {};
          //        //    return wilayah['parent_kode']?.toString() == _selectedOptionProv.toString() ||
          //        //           wilayah['kode']?.toString() == _selectedOptionProv.toString();
          //        //  }).toList();
          //        //}

          //        String formatRawNum(dynamic val) {
          //          if (val == null) return "0";
          //          double numVal = double.tryParse(val.toString()) ?? 0.0;
          //          RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
          //          return numVal.toStringAsFixed(0).replaceAllMapped(reg, (Match match) => '${match[1]},');
          //        }

          //        return Column(
          //          children: [
          //            Container(
          //              color: Colors.black.withOpacity(0.05),
          //              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          //              child: const Row(
          //                children: [
          //                  Expanded(flex: 1, child: Text("No", style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold))),
          //                  Expanded(flex: 3, child: Text("Pemerintah daerah", style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold))),
          //                  Expanded(flex: 2, child: Text("TKD 2026", style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold))),
          //                  Expanded(flex: 2, child: Text("Penyesuaian TKD 2026", style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold))),
          //                  Expanded(flex: 3, child: Text("Total TKD setelah penyesuaian", style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold))),
          //                ],
          //              ),
          //            ),
                      
          //            Expanded(
          //              child: Center(
          //                child: Text(
          //                  "Tidak ada data TKD tersedia untuk filter ini.",
          //                  style: TextStyle(color: Colors.black, fontSize: 12, fontStyle: FontStyle.italic),
          //                ),
          //              ),
          //              //child: displayList.isEmpty
          //              //? const Center(
          //              //    child: Text(
          //              //      "Tidak ada data TKD tersedia untuk filter ini.",
          //              //      style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic),
          //              //    ),
          //              //  )
          //              //: ListView.separated(
          //              //  padding: EdgeInsets.zero,
          //              //  itemCount: displayList.length,
          //              //  separatorBuilder: (context, index) => const Divider(color: Colors.black, height: 1),
          //              //  itemBuilder: (context, index) {
          //              //    final rowItem = displayList[index];
          //              //    final wilayah = rowItem['wilayah'] ?? {};
                            
          //              //    double ang2026 = double.tryParse(rowItem['anggaran_2026']?.toString() ?? '0') ?? 0.0;
          //              //    double penyesuaian = double.tryParse(rowItem['penyesuaian']?.toString() ?? '0') ?? 0.0;
          //              //    double totalAkhir = ang2026 + penyesuaian;

          //              //    return Container(
          //              //      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          //              //      color: index % 2 == 0 ? Colors.transparent : Colors.white.withOpacity(0.02),
          //              //      child: Row(
          //              //        children: [
          //              //          Expanded(flex: 1, child: Text("${index + 1}", style: const TextStyle(color: Colors.white70, fontSize: 11))),
          //              //          Expanded(flex: 3, child: Text(wilayah['nama'] ?? '-', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
          //              //          Expanded(flex: 2, child: Text(formatRawNum(ang2026), style: const TextStyle(color: Colors.white70, fontSize: 11))),
          //              //          Expanded(flex: 2, child: Text(formatRawNum(penyesuaian), style: const TextStyle(color: Colors.amberAccent, fontSize: 11))),
          //              //          Expanded(flex: 3, child: Text(formatRawNum(totalAkhir), style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold))),
          //              //        ],
          //              //      ),
          //              //    );
          //              //  },
          //              //),
          //            ),
          //          ],
          //        );
          //      },
          //    ),
          //  ),
          //),
        ],
      ),
    );
  }
}