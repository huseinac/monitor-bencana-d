import 'dart:convert';
import 'dart:io';

List<DroneVideoDataModel> droneVideoDataModelFromJson(String str) =>
    List<DroneVideoDataModel>.from(json.decode(str)[0]['views'].map((x) => DroneVideoDataModel.fromJson(x)));

String DroneVideoDataModelToJson(List<DroneVideoDataModel> data) =>
    json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

double? _parseDouble(dynamic value) =>
    value == null ? null : double.tryParse(value.toString());

class DroneVideoDataModel {
  final String name;
  final double? latitude;
  final double? longitude;
  final String title;
  final String url;

  DroneVideoDataModel({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.title,
    required this.url
  });

  factory DroneVideoDataModel.fromJson(Map<String, dynamic> json) =>
  DroneVideoDataModel(
    name: json["name"] as String? ?? "",
    latitude: _parseDouble(json["latitude"]),
    longitude: _parseDouble(json["longitude"]),
    title: json["title"] as String? ?? "",
    url: json["videos"]?[0]?["url"] != '' ? ((Platform.environment['APPDATA']?? "") + "\\SatgasPRR\\monitor_bencana_d\\droneVideo\\" + Uri.parse(json["videos"]?[0]?["url"]).pathSegments.last ) : "",
  );

  Map<String, dynamic> toJson() => {
    "name": name,
    "latitude": latitude,
    "longitude": longitude,
    "title": title,
    "url": url,
  };
}