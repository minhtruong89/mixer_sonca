import 'package:equatable/equatable.dart';

class DeviceModel extends Equatable {
  final String modelName;
  final int modelId;
  final int modelIdSub;

  const DeviceModel({
    required this.modelName,
    required this.modelId,
    required this.modelIdSub,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      modelName: json['model_name'] as String,
      modelId: json['model_id'] as int,
      modelIdSub: json['model_id_sub'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [modelName, modelId, modelIdSub];
}
