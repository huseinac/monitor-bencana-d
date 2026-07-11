import 'package:flutter/material.dart';
import 'wilayah_controller.dart';

class WilayahSelectionController extends ChangeNotifier {
  final WilayahController wilayah = WilayahController();

  String _selectedProv = '0';
  String get selectedProv => _selectedProv;

  String _selectedKabupaten = '0';
  String get selectedKabupaten => _selectedKabupaten;

  String _selectedKecamatan = '0';
  String get selectedKecamatan => _selectedKecamatan;

  String _activeAreaCode = '';
  String get activeAreaCode => _activeAreaCode;

  int _currentLevel = 1;
  int get currentLevel => _currentLevel;

  final Map<String, String> optionProvinces = const {
    '0': 'All',
    '11': 'Aceh',
    '12': 'Sumatera Utara',
    '13': 'Sumatera Barat',
  };

  Map<String, String> _optionKabupaten = {'0': '-Pilih Kabupaten-'};
  Map<String, String> get optionKabupaten => _optionKabupaten;

  Map<String, String> _optionKecamatan = {'0': '-Pilih Kecamatan-'};
  Map<String, String> get optionKecamatan => _optionKecamatan;

  bool _dataLoaded = false;

  Future<void> ensureDataLoaded() async {
    if (_dataLoaded) return;
    await wilayah.loadWilayahData();
    _dataLoaded = true;
    notifyListeners();
  }

  void setSelectedProv(String code) {
    _selectedProv = code;
    notifyListeners();
  }

  void setSelectedKabupaten(String code) {
    _selectedKabupaten = code;
    notifyListeners();
  }

  void setSelectedKecamatan(String code) {
    _selectedKecamatan = code;
    notifyListeners();
  }

  void setActiveAreaCode(String code) {
    _activeAreaCode = code;
    notifyListeners();
  }

  void setLevel(int level) {
    _currentLevel = level;
    notifyListeners();
  }

  void populateOptionKabupaten() {
    _selectedKabupaten = '0';
    _selectedKecamatan = '0';

    _optionKabupaten = {'0': '-Pilih Kabupaten-'};
    if (_selectedProv != '0') {
      wilayah.selectKabupaten(_selectedProv);
      for (final w in wilayah.wilayahList) {
        _optionKabupaten[w.kode] = w.nama;
      }
    }
    notifyListeners();
  }

  void populateOptionKecamatan() {
    _selectedKecamatan = '0';
    _currentLevel = 3;

    _optionKecamatan = {'0': '-Pilih Kecamatan-'};
    if (_selectedKabupaten != '0') {
      wilayah.selectKabupaten(_selectedKabupaten);
      for (final w in wilayah.wilayahList) {
        _optionKecamatan[w.kode] = w.nama;
      }
    }
    notifyListeners();
  }

  void resetSelections() {
    _selectedProv = '0';
    _selectedKabupaten = '0';
    _selectedKecamatan = '0';
    _activeAreaCode = '';
    _currentLevel = 1;
    _optionKabupaten = {'0': '-Pilih Kabupaten-'};
    _optionKecamatan = {'0': '-Pilih Kecamatan-'};
    notifyListeners();
  }
}