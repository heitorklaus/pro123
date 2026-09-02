import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../products/domain/models/product_model.dart';

/// Modelo de Dados da Empresa Integrada / Organização no Cloud Firestore (`companies/{companyId}`)
class CompanyModel {
  final String id;
  final String name; // Razão Social ou Nome Fantasia (Obrigatório)
  final String document; // CNPJ ou CPF formatado (Obrigatório)
  final String phone; // Telefone comercial / WhatsApp (Obrigatório)
  final String? email; // E-mail corporativo
  final String? website; // Site oficial (ex: www.empresa.com.br)
  final String? instagram; // Instagram ou rede social (ex: @empresa)
  final String? slogan; // Frase de impacto / slogan
  final String? sector; // Identificador do nicho principal (ex: 'solarPlant', 'fashion', etc.)
  final String? logoBase64; // Logomarca personalizada em Base64

  // Endereço Estruturado (Preenchimento via API ViaCEP)
  final String? zipCode; // CEP (8 dígitos)
  final String? street; // Logradouro / Rua
  final String? number; // Número do imóvel
  final String? complement; // Complemento (Sala, Apto, Galpão)
  final String? neighborhood; // Bairro
  final String? city; // Cidade
  final String? state; // UF (ex: SP, AM, MG)

  final bool onboardingCompleted; // Se já concluiu o setup inicial
  final int? maxSellers; // Limite customizado de vendedores para este integrador (se null, usa o global)
  final int? maxDailyAiAnalyses; // Limite customizado de análises de IA para este integrador (se null, usa o global)
  final DateTime createdAt;
  final DateTime updatedAt;

  const CompanyModel({
    required this.id,
    required this.name,
    required this.document,
    required this.phone,
    this.email,
    this.website,
    this.instagram,
    this.slogan,
    this.sector,
    this.logoBase64,
    this.zipCode,
    this.street,
    this.number,
    this.complement,
    this.neighborhood,
    this.city,
    this.state,
    this.onboardingCompleted = false,
    this.maxSellers,
    this.maxDailyAiAnalyses,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Converte o enum ProductSector para string de setor
  ProductSector? get productSector {
    if (sector == null || sector!.isEmpty) return null;
    for (final s in ProductSector.values) {
      if (s.name == sector) return s;
    }
    return null;
  }

  /// Retorna o endereço formatado em linha única
  String get formattedAddress {
    final parts = <String>[];
    if (street != null && street!.isNotEmpty) {
      if (number != null && number!.isNotEmpty) {
        parts.add('$street, $number');
      } else {
        parts.add(street!);
      }
    }
    if (complement != null && complement!.isNotEmpty) parts.add(complement!);
    if (neighborhood != null && neighborhood!.isNotEmpty) parts.add(neighborhood!);
    if (city != null && city!.isNotEmpty) {
      if (state != null && state!.isNotEmpty) {
        parts.add('$city - $state');
      } else {
        parts.add(city!);
      }
    }
    if (zipCode != null && zipCode!.isNotEmpty) parts.add('CEP: $zipCode');
    return parts.join(', ');
  }

  factory CompanyModel.fromMap(Map<String, dynamic> map, String id) {
    return CompanyModel(
      id: id,
      name: map['name'] as String? ?? (map['tradeName'] as String? ?? ''),
      document: map['document'] as String? ?? (map['cnpj'] as String? ?? ''),
      phone: map['phone'] as String? ?? '',
      email: map['email'] as String?,
      website: map['website'] as String?,
      instagram: map['instagram'] as String?,
      slogan: map['slogan'] as String?,
      sector: map['sector'] as String?,
      logoBase64: map['logoBase64'] as String?,
      zipCode: map['zipCode'] as String? ?? (map['cep'] as String?),
      street: map['street'] as String? ?? (map['logradouro'] as String?),
      number: map['number'] as String? ?? (map['numero'] as String?),
      complement: map['complement'] as String? ?? (map['complemento'] as String?),
      neighborhood: map['neighborhood'] as String? ?? (map['bairro'] as String?),
      city: map['city'] as String? ?? (map['cidade'] as String?),
      state: map['state'] as String? ?? (map['uf'] as String?),
      onboardingCompleted: map['onboardingCompleted'] as bool? ?? false,
      maxSellers: map['maxSellers'] as int?,
      maxDailyAiAnalyses: map['maxDailyAiAnalyses'] as int?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'document': document,
      'phone': phone,
      'email': email,
      'website': website,
      'instagram': instagram,
      'slogan': slogan,
      'sector': sector,
      'logoBase64': logoBase64,
      'zipCode': zipCode,
      'street': street,
      'number': number,
      'complement': complement,
      'neighborhood': neighborhood,
      'city': city,
      'state': state,
      'onboardingCompleted': onboardingCompleted,
      'maxSellers': maxSellers,
      'maxDailyAiAnalyses': maxDailyAiAnalyses,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  CompanyModel copyWith({
    String? id,
    String? name,
    String? document,
    String? phone,
    String? email,
    String? website,
    String? instagram,
    String? slogan,
    String? sector,
    String? logoBase64,
    String? zipCode,
    String? street,
    String? number,
    String? complement,
    String? neighborhood,
    String? city,
    String? state,
    bool? onboardingCompleted,
    int? maxSellers,
    int? maxDailyAiAnalyses,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CompanyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      document: document ?? this.document,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      instagram: instagram ?? this.instagram,
      slogan: slogan ?? this.slogan,
      sector: sector ?? this.sector,
      logoBase64: logoBase64 ?? this.logoBase64,
      zipCode: zipCode ?? this.zipCode,
      street: street ?? this.street,
      number: number ?? this.number,
      complement: complement ?? this.complement,
      neighborhood: neighborhood ?? this.neighborhood,
      city: city ?? this.city,
      state: state ?? this.state,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      maxSellers: maxSellers ?? this.maxSellers,
      maxDailyAiAnalyses: maxDailyAiAnalyses ?? this.maxDailyAiAnalyses,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
