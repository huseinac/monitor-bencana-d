import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'map_view.dart';
import 'dart:io';
import 'combo_box_area.dart';

import '../controllers/wilayah_selection_controller.dart';

import '../controllers/indikator_controller.dart';
import '../models/indikator_model.dart';

// 1. The Widget configuration class (Immutable)
class IndikatorPanel extends StatefulWidget {
  final VoidCallback onClose;
  final GlobalKey<MapViewState> mapViewKey;
  const IndikatorPanel({
    super.key, 
    required this.onClose,
    required this.mapViewKey,
  });

  @override
  State<IndikatorPanel> createState() => _IndikatorPanelState();
}

class AppImage extends StatelessWidget {
  final String path;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Color? color;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  const AppImage(
    this.path, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.color,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (path.contains(':\\') || path.startsWith('\\')) {
      return Image.file(
        File(path),
        width: width,
        height: height,
        fit: fit,
        color: color,
        errorBuilder: errorBuilder,
      );
    }
    
    return Image.asset(
      path,
      width: width,
      height: height,
      fit: fit,
      color: color,
      errorBuilder: errorBuilder,
    );
  }
}

class _IndikatorRow extends StatefulWidget {
  final IndikatorModel item;
  final bool isSelected;
  final VoidCallback onTap;

  const _IndikatorRow({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_IndikatorRow> createState() => _IndikatorRowState();
}

class _IndikatorRowState extends State<_IndikatorRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isSelected = widget.isSelected;
    final String percentageStr = "${item.persentase}%";

    //const IconData displayIcon = Icons.bar_chart;
    //const Color displayColor = Colors.blue;

    IconData displayIcon = Icons.business;
    Color displayColor = const Color(0xFF4DE1B6);

    String lowercaseTitle = item.nama.toLowerCase();
    if (lowercaseTitle.contains("desa") || lowercaseTitle.contains("kelurahan")) {
      displayIcon = Icons.domain;
      displayColor = const Color(0xFF5A86E9);
    } else if (lowercaseTitle.contains("lumpur") || lowercaseTitle.contains("bersih")) {
      displayIcon = Icons.cleaning_services;
      displayColor = const Color(0xFF3263E3);
    } else if (lowercaseTitle.contains("faskes") || lowercaseTitle.contains("rs") || lowercaseTitle.contains("klinik")) {
      displayIcon = Icons.favorite;
      displayColor = lowercaseTitle.contains("klinik") ? const Color(0xFFFABE2C) : const Color(0xFF4279F4);
    } else if (['paud', 'tk', 'sd', 'smp', 'sma', 'sekolah'].any(lowercaseTitle.contains)) {
      displayIcon = Icons.school;
      displayColor = lowercaseTitle.contains("paud") ? const Color(0xFF26A69A) : const Color(0xFF3B72E2);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: InkWell(
          onTap: widget.onTap,
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFD2A86A).withOpacity(0.18)
                  : _isHovered
                      ? Colors.black.withOpacity(0.05)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFD2A86A)
                    : Colors.transparent,
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(displayIcon, color: displayColor, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.nama,
                              style: TextStyle(
                                color: isSelected
                                    ? const Color(0xFFD2A86A)
                                    : Colors.black,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      "Total : ${item.total_data} | Normal : ${item.total_normal} | Mendekati : ${item.total_mendekati} | Atensi : ${item.total_atensi}",
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  percentageStr,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IndikatorPanelState extends State<IndikatorPanel> {

  final ScrollController _panelScrollController = ScrollController();

  late final IndikatorController indikator =
      context.read<IndikatorController>();

  late final WilayahSelectionController _selection =
      context.read<WilayahSelectionController>();

  @override
  void initState() {
    super.initState();
  }

  Widget _areaStatusCounter(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(
                color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget pencarian() {
    return  Container(
      //padding: const EdgeInsets.only(top: 16.0), // mt-3
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent), // bg-transparent
        child: ExpansionTile(
          tilePadding: const EdgeInsets.only(right: 40.0, left: 16.0), // padding-right: 2.5rem
          title: const Row(
            children: [
              Icon(Icons.search, size: 20), // bi bi-search
              SizedBox(width: 8),
              Text(
                'Pencarian data', // <h5> Pencarian data
                style: TextStyle(color: Colors.black, fontSize: 15),
              ),
            ],
          ),
          trailing: const Icon(Icons.expand_more, color: Colors.grey), // bi bi-chevron-down
          
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nama Pekerjaan', style: TextStyle(color: Colors.black, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('Tekan enter untuk mencari', style: TextStyle(color: Colors.black, fontSize: 9, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 4),
                  TextField(
                        style: const TextStyle(color: Colors.black, fontSize: 14),
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: 'Pencarian',
                          hintText: 'Cari nama pekerjaan...',
                          hintStyle: const TextStyle(color: Colors.black, fontSize: 12),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        ),
                        onSubmitted: (textValue) {
                          indikator.searchByKeyword(textValue);
                        },
                      ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  //Widget _buildProgressIndicatorRow(IndikatorModel item) {
  //  final bool isSelected = indikator.selectedIndikatorId == item.id; // was hardcoded `false`

  //  final List<IndikatorModel> childIndikators = indikator.data
  //      .where((element) => element.parentKode == item.kode)
  //      .toList();

  //  final String percentageStr = "${item.persentase}%";

  //  IconData displayIcon = Icons.bar_chart;
  //  Color displayColor = Colors.blue;

  //  return Padding(
  //    padding: const EdgeInsets.symmetric(vertical: 4.0),
  //    child: InkWell(
  //      onTap: () {
  //        indikator.selectIndikator(item.id);
  //      },
  //      borderRadius: BorderRadius.circular(6),
  //      child: Container(
  //        padding: const EdgeInsets.all(8.0),
  //        decoration: BoxDecoration(
  //          color: isSelected ? Colors.black.withOpacity(0.08) : Colors.transparent,
  //          borderRadius: BorderRadius.circular(6),
  //          border: Border.all(
  //            color: isSelected ? const Color(0xFFD2A86A).withOpacity(0.4) : Colors.transparent,
  //            width: 1,
  //          ),
  //        ),
  //        child: Column(
  //          crossAxisAlignment: CrossAxisAlignment.start,
  //          children: [
  //            Row(
  //              mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //              crossAxisAlignment: CrossAxisAlignment.start,
  //              children: [
  //                Expanded(
  //                  child: Row(
  //                    children: [
  //                      Icon(
  //                        displayIcon, 
  //                        color: displayColor, 
  //                        size: 22,
  //                      ),
  //                      const SizedBox(width: 12),
  //                      Expanded(
  //                        child: Text(
  //                          item.nama, // Accessed from IndikatorModel directly
  //                          style: TextStyle(
  //                            color: isSelected ? const Color(0xFFD2A86A) : Colors.black,
  //                            fontSize: 13,
  //                            fontWeight: FontWeight.bold,
  //                          ),
  //                        ),
  //                      ),
  //                    ],
  //                  ),
  //                ),
                  
  //                Text(
  //                  "Total : ${item.total_data} | Normal : ${item.total_normal} | Mendekati : ${item.total_mendekati} | Atensi : ${item.total_atensi}",
  //                  style: const TextStyle(
  //                    color: Colors.black,
  //                    fontSize: 11,
  //                    fontWeight: FontWeight.w400,
  //                    letterSpacing: 0.2,
  //                  ),
  //                ),
  //              ],
  //            ),
  //            const SizedBox(height: 8),
              
  //            Text(
  //              percentageStr,
  //              style: const TextStyle(
  //                color: Colors.black,
  //                fontSize: 13,
  //                fontWeight: FontWeight.bold,
  //              ),
  //            ),
  //          ],
  //        ),
  //      ),
  //    ),
  //  );
  //}

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 600,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
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
                  "Kondisi dan Progress Indikator Pemulihan Pemerintahan dan Kemasyarakatan yang Terdampak Bencana",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                // Notice how you access variables from the top class using "widget."
                onPressed: widget.onClose, 
                icon: const Icon(Icons.close, color: Colors.black, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ComboBoxArea(
            mapViewKey: widget.mapViewKey,
          ),
          const SizedBox(height: 16),
          //Row(
          //  mainAxisAlignment: MainAxisAlignment.spaceBetween,
          //  children: [
          //    _areaStatusCounter(Colors.green, "NORMAL : "+_selection.wilayah.countWilayahNormal.toString()),
          //    _areaStatusCounter(Colors.blue, "MENDEKATI NORMAL : "+_selection.wilayah.countWilayahAgakNormal.toString()),
          //    _areaStatusCounter(Colors.yellow[700]!, "ATENSI KHUSUS : "+_selection.wilayah.countWilayahAtensi.toString()),
          //  ],
          //),
          pencarian(),
          const Divider(color: Colors.white10, height: 24),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.65,
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                scrollbarTheme: ScrollbarThemeData(
                  thumbColor: WidgetStateProperty.all(Colors.grey.withValues(alpha: 0.5)),
                  trackColor: WidgetStateProperty.all(Colors.grey.withValues(alpha: 0.9)),
                  interactive: true,
                ),
              ),
              child: 
              Scrollbar(
                controller: _panelScrollController,
                thumbVisibility: true,
                trackVisibility: true,
                thickness: 4.0,
                child: ListView.separated(
                  controller: _panelScrollController,
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: indikator.count,
                  separatorBuilder: (context, index) => const Divider(
                    color: Colors.black,
                    height: 1,
                  ),
                  //itemBuilder: (context, index) {
                  //  final item = indikator.data[index];
                  //  return _buildProgressIndicatorRow(item);
                  //},
                  itemBuilder: (context, index) {
                    final item = indikator.data[index];
                    return _IndikatorRow(
                      item: item,
                      isSelected: indikator.selectedIndikatorId == item.id,
                      onTap: () => indikator.selectIndikator(item.id),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}