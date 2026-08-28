import 'package:cloud_firestore/cloud_firestore.dart';

class SubcategoryModel {
  final String id;
  final String name;
  final String sector;
  final DateTime createdAt;

  SubcategoryModel({
    required this.id,
    required this.name,
    required this.sector,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'sector': sector,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory SubcategoryModel.fromMap(Map<String, dynamic> map, String id) {
    return SubcategoryModel(
      id: id,
      name: map['name'] as String? ?? '',
      sector: map['sector'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  SubcategoryModel copyWith({
    String? id,
    String? name,
    String? sector,
    DateTime? createdAt,
  }) {
    return SubcategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      sector: sector ?? this.sector,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
