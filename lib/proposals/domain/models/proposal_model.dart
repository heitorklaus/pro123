import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'proposal_item_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// STATUS DA PROPOSTA COMERCIAL
// ─────────────────────────────────────────────────────────────────────────────
enum ProposalStatus {
  draft('Rascunho', Color(0xFF64748B), Color(0xFFF1F5F9)),
  sent('Enviada', Color(0xFF0284C7), Color(0xFFE0F2FE)),
  approved('Aprovada', Color(0xFF059669), Color(0xFFD1FAE5)),
  rejected('Recusada', Color(0xFFDC2626), Color(0xFFFEE2E2)),
  expired('Expirada', Color(0xFFD97706), Color(0xFFFEF3C7));

  final String label;
  final Color textColor;
  final Color bgColor;

  const ProposalStatus(this.label, this.textColor, this.bgColor);

  static ProposalStatus fromString(String? val) {
    if (val == null) return ProposalStatus.draft;
    return ProposalStatus.values.firstWhere(
      (s) => s.name == val,
      orElse: () => ProposalStatus.draft,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TEMAS DE CORES PARA O DOCUMENTO PDF
// ─────────────────────────────────────────────────────────────────────────────
class ProposalPdfThemeOption {
  final String label;
  final int primaryColorValue;
  final int secondaryColorValue;

  const ProposalPdfThemeOption({
    required this.label,
    required this.primaryColorValue,
    required this.secondaryColorValue,
  });

  Color get primaryColor => Color(primaryColorValue);
  Color get secondaryColor => Color(secondaryColorValue);

  static const List<ProposalPdfThemeOption> allThemes = [
    ProposalPdfThemeOption(
      label: 'Indigo Moderno (Padrão)',
      primaryColorValue: 0xFF4F46E5, // Indigo 600
      secondaryColorValue: 0xFF312E81, // Indigo 900
    ),
    ProposalPdfThemeOption(
      label: 'Azul Executivo',
      primaryColorValue: 0xFF0284C7, // Sky 600
      secondaryColorValue: 0xFF0369A1, // Sky 700
    ),
    ProposalPdfThemeOption(
      label: 'Verde Esmeralda',
      primaryColorValue: 0xFF059669, // Emerald 600
      secondaryColorValue: 0xFF065F46, // Emerald 800
    ),
    ProposalPdfThemeOption(
      label: 'Grafite Slate',
      primaryColorValue: 0xFF334155, // Slate 700
      secondaryColorValue: 0xFF0F172A, // Slate 900
    ),
    ProposalPdfThemeOption(
      label: 'Rubi Corporativo',
      primaryColorValue: 0xFFE11D48, // Rose 600
      secondaryColorValue: 0xFF9F1239, // Rose 800
    ),
    ProposalPdfThemeOption(
      label: 'Âmbar Premium',
      primaryColorValue: 0xFFD97706, // Amber 600
      secondaryColorValue: 0xFF92400E, // Amber 800
    ),
  ];

  static ProposalPdfThemeOption get defaultTheme => allThemes.first;

  static ProposalPdfThemeOption fromColorValue(int? val) {
    if (val == null) return defaultTheme;
    return allThemes.firstWhere(
      (t) => t.primaryColorValue == val,
      orElse: () => defaultTheme,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELO PRINCIPAL DA PROPOSTA COMERCIAL
// ─────────────────────────────────────────────────────────────────────────────
class ProposalModel {
  final String id;
  final String proposalNumber;
  final String title;

  // Dados do Cliente (Vinculado ou Avulso)
  final String? clientId;
  final String clientName;
  final String? clientEmail;
  final String? clientPhone;
  final String? clientDocument;
  final String? clientAddress;

  // Itens da Proposta
  final List<ProposalItemModel> items;

  // Valores Financeiros
  final double subtotal;
  final double discount;
  final double shippingFee;
  final double totalAmount;

  // Condições Comerciais
  final String paymentTerms;
  final int validityDays;
  final String? deliveryTime;
  final String? notes;

  // Customização Visual do PDF
  final int themeColorValue;

  // Status e Auditoria
  final ProposalStatus status;
  final String? companyId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProposalModel({
    required this.id,
    required this.proposalNumber,
    required this.title,
    this.clientId,
    required this.clientName,
    this.clientEmail,
    this.clientPhone,
    this.clientDocument,
    this.clientAddress,
    this.items = const [],
    required this.subtotal,
    this.discount = 0.0,
    this.shippingFee = 0.0,
    required this.totalAmount,
    this.paymentTerms = 'À vista via PIX',
    this.validityDays = 15,
    this.deliveryTime,
    this.notes,
    this.themeColorValue = 0xFF4F46E5,
    this.status = ProposalStatus.draft,
    this.companyId,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Retorna a data em que a proposta expira
  DateTime get expirationDate => createdAt.add(Duration(days: validityDays));

  /// Indica se a proposta está vinculada a um cliente cadastrado
  bool get isClientLinked => clientId != null && clientId!.isNotEmpty;

  ProposalModel copyWith({
    String? id,
    String? proposalNumber,
    String? title,
    String? clientId,
    String? clientName,
    String? clientEmail,
    String? clientPhone,
    String? clientDocument,
    String? clientAddress,
    List<ProposalItemModel>? items,
    double? subtotal,
    double? discount,
    double? shippingFee,
    double? totalAmount,
    String? paymentTerms,
    int? validityDays,
    String? deliveryTime,
    String? notes,
    int? themeColorValue,
    ProposalStatus? status,
    String? companyId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProposalModel(
      id: id ?? this.id,
      proposalNumber: proposalNumber ?? this.proposalNumber,
      title: title ?? this.title,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      clientEmail: clientEmail ?? this.clientEmail,
      clientPhone: clientPhone ?? this.clientPhone,
      clientDocument: clientDocument ?? this.clientDocument,
      clientAddress: clientAddress ?? this.clientAddress,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      shippingFee: shippingFee ?? this.shippingFee,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      validityDays: validityDays ?? this.validityDays,
      deliveryTime: deliveryTime ?? this.deliveryTime,
      notes: notes ?? this.notes,
      themeColorValue: themeColorValue ?? this.themeColorValue,
      status: status ?? this.status,
      companyId: companyId ?? this.companyId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'proposalNumber': proposalNumber,
      'title': title,
      'clientId': clientId,
      'clientName': clientName,
      'clientEmail': clientEmail,
      'clientPhone': clientPhone,
      'clientDocument': clientDocument,
      'clientAddress': clientAddress,
      'items': items.map((i) => i.toMap()).toList(),
      'subtotal': subtotal,
      'discount': discount,
      'shippingFee': shippingFee,
      'totalAmount': totalAmount,
      'paymentTerms': paymentTerms,
      'validityDays': validityDays,
      'deliveryTime': deliveryTime,
      'notes': notes,
      'themeColorValue': themeColorValue,
      'status': status.name,
      'companyId': companyId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory ProposalModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final rawItems = map['items'] as List<dynamic>? ?? [];
    final itemsList = rawItems
        .map((item) => ProposalItemModel.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();

    return ProposalModel(
      id: id,
      proposalNumber: map['proposalNumber'] as String? ?? 'PROP-000',
      title: map['title'] as String? ?? 'Proposta Comercial',
      clientId: map['clientId'] as String?,
      clientName: map['clientName'] as String? ?? 'Consumidor Final',
      clientEmail: map['clientEmail'] as String?,
      clientPhone: map['clientPhone'] as String?,
      clientDocument: map['clientDocument'] as String?,
      clientAddress: map['clientAddress'] as String?,
      items: itemsList,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      shippingFee: (map['shippingFee'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paymentTerms: map['paymentTerms'] as String? ?? 'À vista via PIX',
      validityDays: (map['validityDays'] as num?)?.toInt() ?? 15,
      deliveryTime: map['deliveryTime'] as String?,
      notes: map['notes'] as String?,
      themeColorValue: (map['themeColorValue'] as num?)?.toInt() ?? 0xFF4F46E5,
      status: ProposalStatus.fromString(map['status'] as String?),
      companyId: map['companyId'] as String?,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }
}
