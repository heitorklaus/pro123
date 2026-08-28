import 'package:cloud_firestore/cloud_firestore.dart';

/// Status do cliente no CRM
enum ClientStatus {
  active,
  inactive,
  prospect,
  blocked;

  String get label {
    switch (this) {
      case ClientStatus.active:
        return 'Ativo';
      case ClientStatus.inactive:
        return 'Inativo';
      case ClientStatus.prospect:
        return 'Prospecto';
      case ClientStatus.blocked:
        return 'Bloqueado';
    }
  }
}

/// Tipo de pessoa do cliente
enum ClientType {
  person,
  company;

  String get label {
    switch (this) {
      case ClientType.person:
        return 'Pessoa Física';
      case ClientType.company:
        return 'Pessoa Jurídica';
    }
  }
}

/// Modelo de Dados do Cliente no Cloud Firestore (`clients/{clientId}`)
class ClientModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? document; // CPF ou CNPJ
  final ClientType type;
  final ClientStatus status;
  final String? company;
  // Endereço estruturado
  final String? zipCode;
  final String? street;
  final String? addressNumber;
  final String? complement;
  final String? neighborhood;
  final String? city;
  final String? state;
  final String? notes;
  final String? companyId; // Multi-tenancy
  final DateTime createdAt;
  final DateTime updatedAt;

  ClientModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.document,
    this.type = ClientType.person,
    this.status = ClientStatus.active,
    this.company,
    this.zipCode,
    this.street,
    this.addressNumber,
    this.complement,
    this.neighborhood,
    this.city,
    this.state,
    this.notes,
    this.companyId,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => status == ClientStatus.active;
  bool get isPerson => type == ClientType.person;

  /// Endereço formatado para exibição
  String get fullAddress {
    final parts = [
      if (street != null && street!.isNotEmpty) street!,
      if (addressNumber != null && addressNumber!.isNotEmpty) 'nº ${addressNumber!}',
      if (complement != null && complement!.isNotEmpty) complement!,
      if (neighborhood != null && neighborhood!.isNotEmpty) neighborhood!,
      if (city != null && city!.isNotEmpty)
        state != null && state!.isNotEmpty ? '${city!} - ${state!}' : city!,
      if (zipCode != null && zipCode!.isNotEmpty) 'CEP: ${zipCode!}',
    ];
    return parts.join(', ');
  }

  factory ClientModel.fromMap(Map<String, dynamic> map, String id) {
    return ClientModel(
      id: id,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String?,
      document: map['document'] as String?,
      type: _parseType(map['type'] as String?),
      status: _parseStatus(map['status'] as String?),
      company: map['company'] as String?,
      zipCode: map['zipCode'] as String?,
      street: map['street'] as String?,
      addressNumber: map['addressNumber'] as String?,
      complement: map['complement'] as String?,
      neighborhood: map['neighborhood'] as String?,
      city: map['city'] as String?,
      state: map['state'] as String?,
      notes: map['notes'] as String?,
      companyId: map['companyId'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'document': document,
      'type': type.name,
      'status': status.name,
      'company': company,
      'zipCode': zipCode,
      'street': street,
      'addressNumber': addressNumber,
      'complement': complement,
      'neighborhood': neighborhood,
      'city': city,
      'state': state,
      'notes': notes,
      'companyId': companyId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  ClientModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? document,
    ClientType? type,
    ClientStatus? status,
    String? company,
    String? zipCode,
    String? street,
    String? addressNumber,
    String? complement,
    String? neighborhood,
    String? city,
    String? state,
    String? notes,
    String? companyId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ClientModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      document: document ?? this.document,
      type: type ?? this.type,
      status: status ?? this.status,
      company: company ?? this.company,
      zipCode: zipCode ?? this.zipCode,
      street: street ?? this.street,
      addressNumber: addressNumber ?? this.addressNumber,
      complement: complement ?? this.complement,
      neighborhood: neighborhood ?? this.neighborhood,
      city: city ?? this.city,
      state: state ?? this.state,
      notes: notes ?? this.notes,
      companyId: companyId ?? this.companyId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static ClientType _parseType(String? value) {
    switch (value) {
      case 'company':
        return ClientType.company;
      default:
        return ClientType.person;
    }
  }

  static ClientStatus _parseStatus(String? value) {
    switch (value) {
      case 'inactive':
        return ClientStatus.inactive;
      case 'prospect':
        return ClientStatus.prospect;
      case 'blocked':
        return ClientStatus.blocked;
      default:
        return ClientStatus.active;
    }
  }
}
