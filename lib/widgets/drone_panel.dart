import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:html/parser.dart' show parse;

import '../controllers/drone_area_controller.dart';
import '../models/drone_area_model.dart';

import '../widgets/drone_vid_player.dart';

class DronePanel extends StatefulWidget {
  final VoidCallback onClose;
  
  const DronePanel({super.key, required this.onClose});

  @override
  State<DronePanel> createState() => _DronePanelState();
}

class _DronePanelState extends State<DronePanel> {
  int _selectedFilterIndex = 0;
  bool _isDetailOpen = false;
  int _selectedDroneArea = 0;

  int? _playingIndex;

  late final DroneAreaController droneArea = context.read<DroneAreaController>();

  String panelTitle = 'Daftar Kabupaten / Kota';

  String parseHtmlToText(String htmlString) {
    final document = parse(htmlString);
    return document.body?.text ?? '';
  }

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

  Widget _buildBackButton() {
    return OutlinedButton.icon(
      onPressed: () {
        setState(() {
          panelTitle = 'Daftar Kabupaten / Kota';
          _isDetailOpen = false;
          _playingIndex = null;
        });
      },
      icon: const Icon(Icons.arrow_back, size: 14, color: Color(0xFF4A5568)),
      label: const Text(
        "Kembali",
        style: TextStyle(
          color: Color(0xFF4A5568),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: const BorderSide(color: Color(0xFF718096), width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _buildKabKotaCard({
    required int droneAreaId,
    required String title,
    required String subtitle,
    required bool hasDrone,
  }) {
    return InkWell(
      mouseCursor: SystemMouseCursors.click,
      hoverColor: Colors.grey.shade200, // <--- Darker background shade on hover
      onTap: () {
        // Card click action
        setState(() {
          panelTitle = title;
          _isDetailOpen = true;
          _selectedDroneArea = droneAreaId;
        });
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

  Widget _buildComparisonCard({
    required String badgeLabel,
    required Color badgeColor,
    required Widget content,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              badgeLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 10),
          content,
        ],
      ),
    );
  }

  Widget _buildKabKotaDetail() {
    DroneAreaModel droneAreaData = droneArea.data.where((x) => x.kabkotaId == _selectedDroneArea).single;

    return 
    droneAreaData.detailData.length > 0 ?
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  droneAreaData.detailData.single.title,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  droneAreaData.detailData.single.disclaimer,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 20),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if(droneAreaData.detailData.single.satellite_analysis != '')
                        Expanded(
                          child: _buildComparisonCard(
                            badgeLabel: "Sebelum Bencana",
                            badgeColor: const Color(0xFF5A626A),
                            content: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  parseHtmlToText(droneAreaData.detailData.single.satellite_analysis)
                                  , style: TextStyle(fontSize: 12)
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(width: 12),
                      if(droneAreaData.detailData.single.satellite_analysis != '')
                        Expanded(
                          child: _buildComparisonCard(
                            badgeLabel: "Sesudah Bencana",
                            badgeColor: const Color(0xFFDC3545),
                            content: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  parseHtmlToText(droneAreaData.detailData.single.drone_analysis)
                                  , style: TextStyle(fontSize: 12)
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: droneAreaData.detailData.single.videoData.length,
                  itemBuilder: (context, index) {
                    final item = droneAreaData.detailData.single.videoData[index];
                    return DroneVideoCard(
                      videoPath: item.url,
                      title: item.url,
                      isPlaying: _playingIndex == index,
                      onPlayTapped: () {
                        setState(() => _playingIndex = index);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    )
    :
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Belum ada data video drone untuk wilayah ini.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    )
    ;
  }

  @override
  Widget build(BuildContext context) {  
    List<DroneAreaModel> filteredDroneAreaData = _selectedFilterIndex == 1 ? droneArea.data.where((x) => x.hasDrone == _selectedFilterIndex).toList()
     : droneArea.data.toList()
    ;

    return Container(
      width: MediaQuery.of(context).size.width * 0.30,
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
                panelTitle,
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildFilterButtons(),

                if(_isDetailOpen) 
                  _buildBackButton(),
              ],
            ),
          ),

          if (!_isDetailOpen)
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
                      droneAreaId: item.kabkotaId,
                      title: item.kabkotaNama,
                      subtitle: item.provinsiNama,
                      hasDrone: item.hasDrone == 1 ? true : false,
                    );
                  },
                ),
              ),
            ),

          if (_isDetailOpen)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildKabKotaDetail(),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}