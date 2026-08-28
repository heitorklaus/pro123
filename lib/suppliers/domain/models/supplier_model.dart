import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// STATUS DO FORNECEDOR
// ─────────────────────────────────────────────────────────────────────────────
enum SupplierStatus {
  active('Ativo', Color(0xFF059669), Color(0xFFD1FAE5)),
  inactive('Inativo', Color(0xFF64748B), Color(0xFFF1F5F9)),
  blocked('Bloqueado', Color(0xFFDC2626), Color(0xFFFEF2F2));

  final String label;
  final Color textColor;
  final Color bgColor;

  const SupplierStatus(this.label, this.textColor, this.bgColor);

  static SupplierStatus fromString(String? val) {
    if (val == null) return SupplierStatus.active;
    return SupplierStatus.values.firstWhere(
      (s) => s.name == val,
      orElse: () => SupplierStatus.active,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELO PRINCIPAL DE FORNECEDOR
// ─────────────────────────────────────────────────────────────────────────────
class SupplierModel {
  final String id;
  final String corporateName; // Razão Social
  final String tradeName; // Nome Fantasia
  final String? cnpj;
  final String? stateRegistration; // Inscrição Estadual
  final String email;
  final String phone;
  final String? contactPerson; // Nome do Vendedor / Representante
  final String? category; // Ramo / Tipo de Fornecimento
  final SupplierStatus status;

  // Endereço Estruturado (ViaCEP)
  final String? zipCode;
  final String? street;
  final String? addressNumber;
  final String? complement;
  final String? neighborhood;
  final String? city;
  final String? state;

  // Informações Comerciais
  final String? paymentTerms; // Ex: Boleto 30/60DD, À vista 5% desc
  final String? notes;
  final String? companyId; // Multi-tenancy

  final DateTime createdAt;
  final DateTime updatedAt;

  SupplierModel({
    required this.id,
    required this.corporateName,
    required this.tradeName,
    this.cnpj,
    this.stateRegistration,
    required this.email,
    required this.phone,
    this.contactPerson,
    this.category,
    this.status = SupplierStatus.active,
    this.zipCode,
    this.street,
    this.addressNumber,
    this.complement,
    this.neighborhood,
    this.city,
    this.state,
    this.paymentTerms,
    this.notes,
    this.companyId,
    required this.createdAt,
    required this.updatedAt,
  });

  String get displayName => tradeName.isNotEmpty ? tradeName : corporateName;

  String get fullAddress {
    final parts = <String>[];
    if (street != null && street!.isNotEmpty) {
      parts.add(street! + (addressNumber != null && addressNumber!.isNotEmpty ? ', $addressNumber' : ''));
    }
    if (neighborhood != null && neighborhood!.isNotEmpty) parts.add(neighborhood!);
    if (city != null && city!.isNotEmpty) parts.add('$city - ${state ?? ''}');
    return parts.isEmpty ? 'Endereço não informado' : parts.join(', ');
  }

  Map<String, dynamic> toMap() {
    return {
      'corporateName': corporateName.trim(),
      'tradeName': tradeName.trim(),
      'cnpj': cnpj?.trim(),
      'stateRegistration': stateRegistration?.trim(),
      'email': email.trim().toLowerCase(),
      'phone': phone.trim(),
      'contactPerson': contactPerson?.trim(),
      'category': category?.trim(),
      'status': status.name,
      'zipCode': zipCode?.trim(),
      'street': street?.trim(),
      'addressNumber': addressNumber?.trim(),
      'complement': complement?.trim(),
      'neighborhood': neighborhood?.trim(),
      'city': city?.trim(),
      'state': state?.trim().toUpperCase(),
      'paymentTerms': paymentTerms?.trim(),
      'notes': notes?.trim(),
      'companyId': companyId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory SupplierModel.fromMap(Map<String, dynamic> map, String id) {
    return SupplierModel(
      id: id,
      corporateName: map['corporateName'] as String? ?? '',
      tradeName: map['tradeName'] as String? ?? '',
      cnpj: map['cnpj'] as String?,
      stateRegistration: map['stateRegistration'] as String?,
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      contactPerson: map['contactPerson'] as String?,
      category: map['category'] as String?,
      status: SupplierStatus.fromString(map['status'] as String?),
      zipCode: map['zipCode'] as String?,
      street: map['street'] as String?,
      addressNumber: map['addressNumber'] as String?,
      complement: map['complement'] as String?,
      neighborhood: map['neighborhood'] as String?,
      city: map['city'] as String?,
      state: map['state'] as String?,
      paymentTerms: map['paymentTerms'] as String?,
      notes: map['notes'] as String?,
      companyId: map['companyId'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  SupplierModel copyWith({
    String? id,
    String? corporateName,
    String? tradeName,
    String? cnpj,
    String? stateRegistration,
    String? email,
    String? phone,
    String? contactPerson,
    String? category,
    SupplierStatus? status,
    String? zipCode,
    String? street,
    String? addressNumber,
    String? complement,
    String? neighborhood,
    String? city,
    String? state,
    String? paymentTerms,
    String? notes,
    String? companyId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SupplierModel(
      id: id ?? this.id,
      corporateName: corporateName ?? this.corporateName,
      tradeName: tradeName ?? this.tradeName,
      cnpj: cnpj ?? this.cnpj,
      stateRegistration: stateRegistration ?? this.stateRegistration,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      contactPerson: contactPerson ?? this.contactPerson,
      category: category ?? this.category,
      status: status ?? this.status,
      zipCode: zipCode ?? this.zipCode,
      street: street ?? this.street,
      addressNumber: addressNumber ?? this.addressNumber,
      complement: complement ?? this.complement,
      neighborhood: neighborhood ?? this.neighborhood,
      city: city ?? this.city,
      state: state ?? this.state,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      notes: notes ?? this.notes,
      companyId: companyId ?? this.companyId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
