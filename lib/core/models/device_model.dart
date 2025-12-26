import 'package:equatable/equatable.dart';

class Preset extends Equatable {
  final int idConfig;
  final String name;
  final String nameEn;
  final String desc;
  final String descEn;
  final String data;
  final String dataNew;

  const Preset({
    required this.idConfig,
    required this.name,
    required this.nameEn,
    required this.desc,
    required this.descEn,
    required this.data,
    required this.dataNew,
  });

  factory Preset.fromJson(Map<String, dynamic> json) {
    return Preset(
      idConfig: json['id_config'] as int,
      name: json['name'] as String,
      nameEn: json['name_en'] as String,
      desc: json['desc'] as String,
      descEn: json['desc_en'] as String,
      data: json['data'] as String,
      dataNew: json['data_new'] as String,
    );
  }

  @override
  List<Object?> get props => [idConfig, name, nameEn, desc, descEn, data, dataNew];
}

class Profile extends Equatable {
  final int micId;
  final List<Preset> presets;

  const Profile({
    required this.micId,
    required this.presets,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      micId: json['mic_id'] as int,
      presets: (json['preset'] as List)
          .map((p) => Preset.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [micId, presets];
}

class DeviceModel extends Equatable {
  final String modelName;
  final int modelId;
  final String dataSimple;
  final String dataLimit;
  final List<Profile> profiles;

  const DeviceModel({
    required this.modelName,
    required this.modelId,
    required this.dataSimple,
    required this.dataLimit,
    required this.profiles,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      modelName: json['model_name'] as String,
      modelId: json['model_id'] as int,
      dataSimple: json['data_simple'] as String,
      dataLimit: json['data_limit'] as String,
      profiles: (json['profile'] as List)
          .map((p) => Profile.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [modelName, modelId, dataSimple, dataLimit, profiles];
}
