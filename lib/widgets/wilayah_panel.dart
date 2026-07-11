import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'map_view.dart';
import 'combo_box_area.dart';

import '../controllers/wilayah_selection_controller.dart';

// 1. The Widget configuration class (Immutable)
class WilayahPanel extends StatefulWidget {
  final VoidCallback onClose;
  final GlobalKey<MapViewState> mapViewKey;
  
  const WilayahPanel({
    super.key, 
    required this.onClose,
    required this.mapViewKey,
    });

  @override
  State<WilayahPanel> createState() => WilayahPanelState();
}

class WilayahPanelState extends State<WilayahPanel> {

  final ScrollController _panelScrollController = ScrollController();

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

  Widget _buildChecklistItem(String label, String kondisi, String kode) {
    Color indikatorColor;
    switch (kondisi) {
      case "Mendekati":
        indikatorColor = Color(0xFF0030B3);
      break;

      case 'Atensi':
        indikatorColor = Color(0xFF998000);
      break;

      default:
        indikatorColor = Color(0xFF00A042);
    }
    return 
    MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: GestureDetector(
          onTap: () async {
            debugPrint(_selection.currentLevel.toString());
            switch (_selection.currentLevel) {
              case 1:
                await widget.mapViewKey.currentState?.selectProvinceByCode(kode);
              break;
              case 2:
                await widget.mapViewKey.currentState?.selectKabupatenByCode(kode);
              break;
              case 3:
                await widget.mapViewKey.currentState?.selectKecamatanByCode(kode);
              break;
              default:
            }
          },
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: indikatorColor,
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: Colors.black),
                ),
              ),
              const SizedBox(width: 12),
              Text(label, style: const TextStyle(color: Colors.black, fontSize: 14)),
            ],
          ),
        ),

      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 500,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _areaStatusCounter(Colors.green, "NORMAL : "+_selection.wilayah.countWilayahNormal.toString()),
              _areaStatusCounter(Colors.blue, "MENDEKATI NORMAL : "+_selection.wilayah.countWilayahAgakNormal.toString()),
              _areaStatusCounter(Colors.yellow[700]!, "ATENSI KHUSUS : "+_selection.wilayah.countWilayahAtensi.toString()),
            ],
          ),
          const Divider(color: Colors.white10, height: 24),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                scrollbarTheme: ScrollbarThemeData(
                  thumbColor: WidgetStateProperty.all(Colors.white.withOpacity(0.5)),
                  trackColor: WidgetStateProperty.all(Colors.white10),
                  interactive: true,
                ),
              ),
              child: Scrollbar(
                controller: _panelScrollController,
                thumbVisibility: true,
                trackVisibility: true,
                thickness: 6.0,       
                radius: const Radius.circular(10),
                child: SingleChildScrollView(
                  controller: _panelScrollController,
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      if (_selection.currentLevel < 2) ...[
                        _buildChecklistItem("Aceh", '', '11'),
                        _buildChecklistItem("Sumatera Utara", '', '12'),
                        _buildChecklistItem("Sumatera Barat", '', '13'),
                      ]
                      else ...[
                        for (var w in _selection.wilayah.wilayahList)
                          _buildChecklistItem(w.nama, (w.kondisi ?? 'Normal'), w.kode),
                      ]
                    ],
                  ),
                ),
              ),
            )
          ),
        ],
      ),
    );
  }
}