import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Status do Contrato no ciclo de vida
enum ContractStatus {
  draft(
    'Rascunho',
    Color(0xFF64748B), // Slate 500
    Color(0xFFF1F5F9), // Slate 100
    Icons.edit_note_rounded,
  ),
  pendingSignature(
    'Aguardando Assinatura',
    Color(0xFFD97706), // Amber 600
    Color(0xFFFEF3C7), // Amber 100
    Icons.draw_rounded,
  ),
  signed(
    'Assinado',
    Color(0xFF059669), // Emerald 600
    Color(0xFFD1FAE5), // Emerald 100
    Icons.verified_rounded,
  ),
  canceled(
    'Cancelado',
    Color(0xFFDC2626), // Rose 600
    Color(0xFFFEE2E2), // Rose 100
    Icons.cancel_outlined,
  );

  final String label;
  final Color textColor;
  final Color bgColor;
  final IconData icon;

  const ContractStatus(this.label, this.textColor, this.bgColor, this.icon);

  static ContractStatus fromString(String? val) {
    if (val == null) return ContractStatus.draft;
    final lower = val.toLowerCase().trim();
    if (lower == 'pendingsignature' ||
        lower == 'pending_signature' ||
        lower == 'aguardando assinatura' ||
        lower == 'aguardando' ||
        lower == 'em assinatura') {
      return ContractStatus.pendingSignature;
    }
    if (lower == 'signed' || lower == 'assinado' || lower == 'ativo') {
      return ContractStatus.signed;
    }
    if (lower == 'canceled' ||
        lower == 'cancelled' ||
        lower == 'cancelado' ||
        lower == 'recusado') {
      return ContractStatus.canceled;
    }
    return ContractStatus.draft;
  }
}

/// Modelo de Dados do Contrato no Cloud Firestore (`contracts/{contractId}`)
class ContractModel {
  final String id;
  final String contractNumber; // Ex: CTR-2026-001
  final String proposalId; // ID da proposta comercial vinculada
  final String proposalNumber; // Ex: PROP-2026-101
  final String clientId;
  final String clientName;
  final String? clientDocument; // CPF ou CNPJ
  final String? clientEmail;
  final String? clientPhone;
  final String? clientAddress; // Endereço completo formatado
  final String? companyId; // Multi-tenancy
  final String? companyName;
  final String? companyDocument;
  final String title; // Título do contrato
  final String content; // Texto completo do contrato (HTML / Rich Text com cláusulas)
  final ContractStatus status;
  final double totalAmount; // Valor total do projeto
  final double servicePrice; // Valor da instalação/mão de obra
  final double productsPrice; // Valor dos equipamentos
  final double systemKwp; // Potência em kWp
  final double generationKwh; // Geração estimada em kWh/mês
  final String? roofType; // Tipo de telhado (Cerâmico, Metálico, etc.)
  final String? supplierName; // Nome do distribuidor do kit
  final String? paymentTerms; // Condições de pagamento
  final int validityDays;
  final String? deliveryTime;
  final String? createdByUserId;
  final String? createdByUserName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? signedAt;

  const ContractModel({
    required this.id,
    required this.contractNumber,
    required this.proposalId,
    required this.proposalNumber,
    required this.clientId,
    required this.clientName,
    this.clientDocument,
    this.clientEmail,
    this.clientPhone,
    this.clientAddress,
    this.companyId,
    this.companyName,
    this.companyDocument,
    required this.title,
    required this.content,
    this.status = ContractStatus.draft,
    this.totalAmount = 0.0,
    this.servicePrice = 0.0,
    this.productsPrice = 0.0,
    this.systemKwp = 0.0,
    this.generationKwh = 0.0,
    this.roofType,
    this.supplierName,
    this.paymentTerms,
    this.validityDays = 15,
    this.deliveryTime,
    this.createdByUserId,
    this.createdByUserName,
    required this.createdAt,
    required this.updatedAt,
    this.signedAt,
  });

  factory ContractModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return ContractModel(
      id: doc.id,
      contractNumber: data['contractNumber'] as String? ?? 'CTR-${doc.id.substring(0, 6).toUpperCase()}',
      proposalId: data['proposalId'] as String? ?? '',
      proposalNumber: data['proposalNumber'] as String? ?? '',
      clientId: data['clientId'] as String? ?? '',
      clientName: data['clientName'] as String? ?? 'Cliente Não Informado',
      clientDocument: data['clientDocument'] as String?,
      clientEmail: data['clientEmail'] as String?,
      clientPhone: data['clientPhone'] as String?,
      clientAddress: data['clientAddress'] as String?,
      companyId: data['companyId'] as String?,
      companyName: data['companyName'] as String?,
      companyDocument: data['companyDocument'] as String?,
      title: data['title'] as String? ?? 'Contrato de Prestação de Serviços Fotovoltaicos',
      content: data['content'] as String? ?? '',
      status: ContractStatus.fromString(data['status'] as String?),
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
      servicePrice: (data['servicePrice'] as num?)?.toDouble() ?? 0.0,
      productsPrice: (data['productsPrice'] as num?)?.toDouble() ?? 0.0,
      systemKwp: (data['systemKwp'] as num?)?.toDouble() ?? 0.0,
      generationKwh: (data['generationKwh'] as num?)?.toDouble() ?? 0.0,
      roofType: data['roofType'] as String?,
      supplierName: data['supplierName'] as String?,
      paymentTerms: data['paymentTerms'] as String?,
      validityDays: (data['validityDays'] as num?)?.toInt() ?? 15,
      deliveryTime: data['deliveryTime'] as String?,
      createdByUserId: data['createdByUserId'] as String?,
      createdByUserName: data['createdByUserName'] as String?,
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
      signedAt: parseNullableDate(data['signedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'contractNumber': contractNumber,
      'proposalId': proposalId,
      'proposalNumber': proposalNumber,
      'clientId': clientId,
      'clientName': clientName,
      'clientDocument': clientDocument,
      'clientEmail': clientEmail,
      'clientPhone': clientPhone,
      'clientAddress': clientAddress,
      'companyId': companyId,
      'companyName': companyName,
      'companyDocument': companyDocument,
      'title': title,
      'content': content,
      'status': status.name,
      'totalAmount': totalAmount,
      'servicePrice': servicePrice,
      'productsPrice': productsPrice,
      'systemKwp': systemKwp,
      'generationKwh': generationKwh,
      'roofType': roofType,
      'supplierName': supplierName,
      'paymentTerms': paymentTerms,
      'validityDays': validityDays,
      'deliveryTime': deliveryTime,
      'createdByUserId': createdByUserId,
      'createdByUserName': createdByUserName,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'signedAt': signedAt != null ? Timestamp.fromDate(signedAt!) : null,
    };
  }

  ContractModel copyWith({
    String? id,
    String? contractNumber,
    String? proposalId,
    String? proposalNumber,
    String? clientId,
    String? clientName,
    String? clientDocument,
    String? clientEmail,
    String? clientPhone,
    String? clientAddress,
    String? companyId,
    String? companyName,
    String? companyDocument,
    String? title,
    String? content,
    ContractStatus? status,
    double? totalAmount,
    double? servicePrice,
    double? productsPrice,
    double? systemKwp,
    double? generationKwh,
    String? roofType,
    String? supplierName,
    String? paymentTerms,
    int? validityDays,
    String? deliveryTime,
    String? createdByUserId,
    String? createdByUserName,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? signedAt,
  }) {
    return ContractModel(
      id: id ?? this.id,
      contractNumber: contractNumber ?? this.contractNumber,
      proposalId: proposalId ?? this.proposalId,
      proposalNumber: proposalNumber ?? this.proposalNumber,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      clientDocument: clientDocument ?? this.clientDocument,
      clientEmail: clientEmail ?? this.clientEmail,
      clientPhone: clientPhone ?? this.clientPhone,
      clientAddress: clientAddress ?? this.clientAddress,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      companyDocument: companyDocument ?? this.companyDocument,
      title: title ?? this.title,
      content: content ?? this.content,
      status: status ?? this.status,
      totalAmount: totalAmount ?? this.totalAmount,
      servicePrice: servicePrice ?? this.servicePrice,
      productsPrice: productsPrice ?? this.productsPrice,
      systemKwp: systemKwp ?? this.systemKwp,
      generationKwh: generationKwh ?? this.generationKwh,
      roofType: roofType ?? this.roofType,
      supplierName: supplierName ?? this.supplierName,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      validityDays: validityDays ?? this.validityDays,
      deliveryTime: deliveryTime ?? this.deliveryTime,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      createdByUserName: createdByUserName ?? this.createdByUserName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      signedAt: signedAt ?? this.signedAt,
    );
  }
}
