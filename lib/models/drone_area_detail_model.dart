import 'dart:convert';
import 'drone_video_data_model.dart';

List<DroneAreaDetailModel> droneAreaDetailModelFromJson(String str) =>
    List<DroneAreaDetailModel>.from(json.decode(str).map((x) => DroneAreaDetailModel.fromJson(x)));

String DroneAreaDetailModelToJson(List<DroneAreaDetailModel> data) =>
    json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

class DroneAreaDetailModel {
  final int id;
  final int kabkotaId;
  final String name;
  final String title;
  final String disclaimer;
  final String satellite_badge;
  final String satellite_analysis;
  final String drone_badge;
  final String drone_analysis;
  final List<DroneVideoDataModel> videoData;

  DroneAreaDetailModel({
    required this.id,
    required this.kabkotaId,
    required this.name,
    required this.title,
    required this.disclaimer,
    required this.satellite_badge,
    required this.satellite_analysis,
    required this.drone_badge,
    required this.drone_analysis,
    required this.videoData,
  });

  factory DroneAreaDetailModel.fromJson(Map<String, dynamic> json) =>
  DroneAreaDetailModel(
    id: json["id"] as int? ?? 0,
    kabkotaId: json["kabkotaId"] as int? ?? 0,
    name: json["name"] as String? ?? "",
    title: json["title"] as String? ?? "",
    disclaimer: json["disclaimer"] as String? ?? "",
    satellite_badge: json["satellite_badge"] as String? ?? "",
    satellite_analysis: json["satellite_analysis"] as String? ?? "",
    drone_badge: json["drone_badge"] as String? ?? "",
    drone_analysis: json["drone_analysis"] as String? ?? "",
    videoData: json["views"] != null && json["views"] is List ?
      List<DroneVideoDataModel>.from(
        (json["views"] as List).map((ara) => DroneVideoDataModel.fromJson(ara))
      ) : []
    ,
  );

  Map<String, dynamic> toJson() => {
    "id" : id,
    "kabkotaId" : kabkotaId,
    "name" : name,
    "title" : title,
    "disclaimer" : disclaimer,
    "satellite_badge" : satellite_badge,
    "satellite_analysis" : satellite_analysis,
    "drone_badge" : drone_badge,
    "drone_analysis" : drone_analysis,
    "videoData" : videoData,
  };
}