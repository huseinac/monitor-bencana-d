// lib/services/marker_icon_cache.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class MarkerIconCache {
  static final MarkerIconCache _instance = MarkerIconCache._();
  factory MarkerIconCache() => _instance;
  MarkerIconCache._();

  final Map<String, ui.Image> _cache = {};

  Future<void> preloadAll() async {
    final userProfile = Platform.environment['USERPROFILE']!;
    final base = '$userProfile\\AppData\\Roaming\\SatgasPRR\\monitor_bencana_d\\assets\\icons';

    final icons = [
      'help', 'building', 'health', 'school', 'road', 'bride', 'electric',
      'water', 'religion', 'river', 'home', 'homes', 'gas_station', 'gas', 'store'
    ];

    final colors = ['-yellow', '-blue', '-green', '-red'];

    for (var baseIcon in icons) {
      for (var color in colors) {
        final name = '$baseIcon$color.png';
        final path = '$base\\$name';
        await _loadSingle(path);
      }
    }
  }

  Future<void> _loadSingle(String fullPath) async {
    if (_cache.containsKey(fullPath)) return;
    final file = File(fullPath);
    if (!file.existsSync()) return;

    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    _cache[fullPath] = frame.image;
  }

  ui.Image? get(String path) => _cache[path];
}