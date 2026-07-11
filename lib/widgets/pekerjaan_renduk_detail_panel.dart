import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/pekerjaan_controller.dart';
import '../models/pekerjaan_model.dart';

class PekerjaanRendukDetailPanel extends StatefulWidget {
  const PekerjaanRendukDetailPanel({super.key});

  @override
  State<PekerjaanRendukDetailPanel> createState() => _PekerjaanRendukDetailPanelState();
}

class _PekerjaanRendukDetailPanelState extends State<PekerjaanRendukDetailPanel> {
  int selectedTab = 0;

  // Accept the model type safely instead of a raw Map
  List<Widget> _buildTabContentHeader(PekerjaanModel model) {
    return [
      Text(
        'No. ${model.id ?? "-"}',
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        model.nama ?? '-',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
      Text(
        model.noKontrak ?? '-',
        style: const TextStyle(
          color: Colors.white54,
        ),
      ),
      const SizedBox(height: 18),
      Container(
        height: 18,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(height: 22),
      _menuItem(
        title: 'Grafik Pekerjaan',
        selected: selectedTab == 0,
        onTap: () => setState(() => selectedTab = 0),
      ),
      _menuItem(
        title: 'Informasi',
        selected: selectedTab == 1,
        onTap: () => setState(() => selectedTab = 1),
      ),
      _menuItem(
        title: 'Penyedia',
        selected: selectedTab == 2,
        onTap: () => setState(() => selectedTab = 2),
      ),
      _menuItem(
        title: 'Rincian',
        selected: selectedTab == 3,
        onTap: () => setState(() => selectedTab = 3),
      ),
      _menuItem(
        title: 'Timeline',
        selected: selectedTab == 4,
        onTap: () => setState(() => selectedTab = 4),
      ),
      _menuItem(
        title: 'Realisasi',
        selected: selectedTab == 5,
        onTap: () => setState(() => selectedTab = 5),
      ),
      _menuItem(
        title: 'Pembayaran',
        selected: selectedTab == 6,
        onTap: () => setState(() => selectedTab = 6),
      ),
    ];
  }

  Widget _buildTabContent(PekerjaanModel model) {
    switch (selectedTab) {
      case 0:
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _topCard(
                    title: 'Realisasi Keuangan',
                    value: model.nominal != null ? 'Rp. ${model.nominal}' : 'Rp. 0',
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: _topCard(
                    title: 'Realisasi Fisik',
                    value: model.persentase != null ? '${model.persentase}%' : '-',
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: _topCard(
                    title: 'Realisasi Waktu',
                    value: '-',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              height: 120,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white10,
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Grafik Realisasi Timeline',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '-',
                    style: TextStyle(color: Colors.white54, fontSize: 18),
                  ),
                ],
              ),
            ),
          ],
        );

      case 1:
        return Padding(
          padding: const EdgeInsets.all(4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildSectionCard(
                  icon: Icons.assignment_outlined,
                  title: 'Detail Informasi',
                  children: [
                    const Text(
                      'Informasi Paket Pekerjaan',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('Tahun Anggaran', model.tahunAnggaran ?? '-'),
                    _buildDetailRow('Nama Paket', model.namaPaket ?? model.nama ?? '-'),
                    _buildDetailRow('Program', model.namaProgram ?? '-'),
                    _buildDetailRow('Kegiatan / Sub', model.namaKegiatan ?? '-'),
                    _buildDetailRow('Pagu Dana', model.paguDana != null ? 'Rp. ${model.paguDana}' : '-'),
                    _buildDetailRow('Kategori', model.jenisPengadaan ?? '-'),
                    _buildDetailRow('Model Pengadaan', model.modelPengadaan ?? '-'),
                    const SizedBox(height: 24),
                    const Text(
                      'Informasi Pengadaan',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('Nilai Pagu', model.paguDana != null ? 'Rp. ${model.paguDana}' : '-'),
                    _buildDetailRow('Nilai Kontrak', model.nominal != null ? 'Rp. ${model.nominal}' : '-'),
                    _buildDetailRow('Nama Rekening', model.namaRekening ?? '-'),
                    _buildDetailRow('No. Kontrak', model.noKontrak ?? '-'),
                    _buildDetailRow(
                      'Masa Pelaksanaan', 
                      '${model.tanggalKontrak?.toLocal().toString().split(' ')[0] ?? ''} s/d ${model.tanggalSelesai?.toLocal().toString().split(' ')[0] ?? ''}'
                    ),
                    _buildDetailRow('Koordinat', '${model.latitude ?? '-'}, ${model.longitude ?? '-'}'),
                    _buildDetailRow('Keterangan', model.keterangan ?? '-'),
                  ],
                ),
              ),
            ],
          ),
        );

      case 2:
        return Padding(
          padding: const EdgeInsets.all(4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildSectionCard(
                  icon: Icons.business_outlined,
                  title: 'Informasi Penyedia',
                  children: [
                    _buildDetailRow('ID Penyedia', model.penyediaId?.toString() ?? '-'),
                    _buildDetailRow('ID Pelaksana', model.pelaksanaId?.toString() ?? '-'),
                    _buildDetailRow('NIB', '-'),
                    _buildDetailRow('NPWP', '-'),
                    _buildDetailRow('Kontak Person', '-'),
                    _buildDetailRow('Alamat', '-'),
                  ],
                ),
              ),
            ],
          ),
        );

      default:
        return const SizedBox();
    }
  }

  Widget _buildDetailRow(String label, String value, {bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 13,
              ),
            ),
          ),
          const Text(':', style: TextStyle(color: Colors.white30, fontSize: 13)),
          const SizedBox(width: 12),
          Expanded(
            child: isStatus
                ? Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
                        ),
                        child: Text(
                          value.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF34D399),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  )
                : Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required IconData icon, required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF11161D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFE2B93B), size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10.0),
            child: Divider(color: Colors.white10, height: 1),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _menuItem({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF101A2A) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: selected
              ? const Border(left: BorderSide(color: Color(0xFF3B82F6), width: 3))
              : null,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            style: TextStyle(color: selected ? const Color(0xFF60A5FA) : Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _topCard({
    required String title,
    required String value,
  }) {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch the active PekerjaanController
    final controller = context.watch<PekerjaanController>();
    
    // Retrieve the active PekerjaanModel from the controller's selection state
    final PekerjaanModel? activePekerjaan = controller.selectedDetailData;

    // If no detail option is open or clicked, securely collapse panel visualization
    if (activePekerjaan == null) return const SizedBox.shrink();

    return Container(
      width: 1300,
      height: 780,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0F14).withOpacity(0.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 260,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildTabContentHeader(activePekerjaan),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: _buildTabContent(activePekerjaan),
                ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: InkWell(
              onTap: () => controller.hideDetailPanel(),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, color: Color(0xFFD2A86A), size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}