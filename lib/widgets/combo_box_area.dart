import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'panel_dropdown.dart';

import '../controllers/wilayah_selection_controller.dart';

import 'map_view.dart';

class ComboBoxArea extends StatefulWidget {
  final GlobalKey<MapViewState> mapViewKey;

  const ComboBoxArea({
    super.key, 
    required this.mapViewKey,
    });

  @override
  State<ComboBoxArea> createState() => ComboBoxAreaState();
}

class ComboBoxAreaState extends State<ComboBoxArea> {
  
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final selection = context.watch<WilayahSelectionController>();

    return Row(
      children: [
        Expanded(
          child: PanelDropdown(
            hint: "Prop :",
            value: selection.selectedProv,
            items: selection.optionProvinces,
            onChanged: (String? selectedId) async {
              await widget.mapViewKey.currentState?.selectProvinceByCode(selectedId ?? '0');
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: PanelDropdown(
            hint: "Kab :",
            value: selection.selectedKabupaten,
            items: selection.optionKabupaten,
            onChanged: (String? selectedId) async {
              await widget.mapViewKey.currentState?.selectKabupatenByCode(selectedId ?? '0');
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: PanelDropdown(
            hint: "Kec :",
            value: selection.selectedKecamatan,
            items: selection.optionKecamatan,
            onChanged: (String? selectedId) async {
              await widget.mapViewKey.currentState?.selectKecamatanByCode(selectedId ?? '0');
            },
          ),
        ),
      ],
    );
  }
}