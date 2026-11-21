import 'package:cloud_firestore/cloud_firestore.dart';

/// Permissões Granuladas do Usuário (RBAC)
class UserPermissions {
  // Clientes
  final bool viewClients;
  final bool createClients;
  final bool viewAllClients;

  // Produtos & Usinas Solares
  final bool viewProducts;
  final bool createProducts;
  final bool viewAllProducts;

  // Propostas Comerciais
  final bool viewProposals;
  final bool createProposals;
  final bool viewAllProposals; // Ver propostas de todos os operadores (se false, apenas as suas)

  // Contratos & Jurídico
  final bool viewContracts;
  final bool createContracts;
  final bool viewAllContracts;
  final bool deleteContracts;

  // Fornecedores & Parceiros
  final bool viewSuppliers;
  final bool createSuppliers;
  final bool viewAllSuppliers;

  // Inteligência Artificial
  final bool useAi; // Acesso à leitura de faturas, PDF de usinas e assistente de propostas IA

  // Sistema & Administração
  final bool manageSettings;
  final bool manageUsers;

  const UserPermissions({
    this.viewClients = true,
    this.createClients = true,
    this.viewAllClients = false,
    this.viewProducts = true,
    this.createProducts = true,
    this.viewAllProducts = false,
    this.viewProposals = true,
    this.createProposals = true,
    this.viewAllProposals = false,
    this.viewContracts = true,
    this.createContracts = true,
    this.viewAllContracts = false,
    this.deleteContracts = false,
    this.viewSuppliers = true,
    this.createSuppliers = true,
    this.viewAllSuppliers = false,
    this.useAi = true,
    this.manageSettings = false,
    this.manageUsers = false,
  });

  /// Retorna as permissões padrão de acordo com o papel do usuário
  factory UserPermissions.defaultForRole(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return const UserPermissions(
          viewClients: true,
          createClients: true,
          viewAllClients: true,
          viewProducts: true,
          createProducts: true,
          viewAllProducts: true,
          viewProposals: true,
          createProposals: true,
          viewAllProposals: true,
          viewContracts: true,
          createContracts: true,
          viewAllContracts: true,
          deleteContracts: true,
          viewSuppliers: true,
          createSuppliers: true,
          viewAllSuppliers: true,
          useAi: true,
          manageSettings: true,
          manageUsers: true,
        );
      case 'manager':
        return const UserPermissions(
          viewClients: true,
          createClients: true,
          viewAllClients: false,
          viewProducts: true,
          createProducts: true,
          viewAllProducts: false,
          viewProposals: true,
          createProposals: true,
          viewAllProposals: false,
          viewContracts: true,
          createContracts: true,
          viewAllContracts: false,
          deleteContracts: false,
          viewSuppliers: true,
          createSuppliers: true,
          viewAllSuppliers: false,
          useAi: true,
          manageSettings: false,
          manageUsers: false,
        );
      case 'user':
      default:
        return const UserPermissions(
          viewClients: true,
          createClients: true,
          viewAllClients: false,
          viewProducts: true,
          createProducts: false,
          viewAllProducts: false,
          viewProposals: true,
          createProposals: true,
          viewAllProposals: false,
          viewContracts: true,
          createContracts: true,
          viewAllContracts: false,
          deleteContracts: false,
          viewSuppliers: true,
          createSuppliers: false,
          viewAllSuppliers: false,
          useAi: true,
          manageSettings: false,
          manageUsers: false,
        );
    }
  }

  factory UserPermissions.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const UserPermissions();
    return UserPermissions(
      viewClients: map['viewClients'] as bool? ?? true,
      createClients: map['createClients'] as bool? ?? (map['editLeads'] as bool? ?? true),
      viewAllClients: map['viewAllClients'] as bool? ?? false,
      viewProducts: map['viewProducts'] as bool? ?? true,
      createProducts: map['createProducts'] as bool? ?? (map['editLeads'] as bool? ?? true),
      viewAllProducts: map['viewAllProducts'] as bool? ?? false,
      viewProposals: map['viewProposals'] as bool? ?? true,
      createProposals: map['createProposals'] as bool? ?? true,
      viewAllProposals: map['viewAllProposals'] as bool? ?? (map['viewReports'] as bool? ?? false),
      viewContracts: map['viewContracts'] as bool? ?? (map['viewProposals'] as bool? ?? true),
      createContracts: map['createContracts'] as bool? ?? (map['createProposals'] as bool? ?? true),
      viewAllContracts: map['viewAllContracts'] as bool? ?? (map['viewAllProposals'] as bool? ?? false),
      deleteContracts: map['deleteContracts'] as bool? ?? false,
      viewSuppliers: map['viewSuppliers'] as bool? ?? true,
      createSuppliers: map['createSuppliers'] as bool? ?? (map['editLeads'] as bool? ?? false),
      viewAllSuppliers: map['viewAllSuppliers'] as bool? ?? false,
      useAi: map['useAi'] as bool? ?? true,
      manageSettings: map['manageSettings'] as bool? ?? false,
      manageUsers: map['manageUsers'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'viewClients': viewClients,
      'createClients': createClients,
      'viewAllClients': viewAllClients,
      'viewProducts': viewProducts,
      'createProducts': createProducts,
      'viewAllProducts': viewAllProducts,
      'viewProposals': viewProposals,
      'createProposals': createProposals,
      'viewAllProposals': viewAllProposals,
      'viewContracts': viewContracts,
      'createContracts': createContracts,
      'viewAllContracts': viewAllContracts,
      'deleteContracts': deleteContracts,
      'viewSuppliers': viewSuppliers,
      'createSuppliers': createSuppliers,
      'viewAllSuppliers': viewAllSuppliers,
      'useAi': useAi,
      'manageSettings': manageSettings,
      'manageUsers': manageUsers,
    };
  }

  UserPermissions copyWith({
    bool? viewClients,
    bool? createClients,
    bool? viewAllClients,
    bool? viewProducts,
    bool? createProducts,
    bool? viewAllProducts,
    bool? viewProposals,
    bool? createProposals,
    bool? viewAllProposals,
    bool? viewContracts,
    bool? createContracts,
    bool? viewAllContracts,
    bool? deleteContracts,
    bool? viewSuppliers,
    bool? createSuppliers,
    bool? viewAllSuppliers,
    bool? useAi,
    bool? manageSettings,
    bool? manageUsers,
  }) {
    return UserPermissions(
      viewClients: viewClients ?? this.viewClients,
      createClients: createClients ?? this.createClients,
      viewAllClients: viewAllClients ?? this.viewAllClients,
      viewProducts: viewProducts ?? this.viewProducts,
      createProducts: createProducts ?? this.createProducts,
      viewAllProducts: viewAllProducts ?? this.viewAllProducts,
      viewProposals: viewProposals ?? this.viewProposals,
      createProposals: createProposals ?? this.createProposals,
      viewAllProposals: viewAllProposals ?? this.viewAllProposals,
      viewContracts: viewContracts ?? this.viewContracts,
      createContracts: createContracts ?? this.createContracts,
      viewAllContracts: viewAllContracts ?? this.viewAllContracts,
      deleteContracts: deleteContracts ?? this.deleteContracts,
      viewSuppliers: viewSuppliers ?? this.viewSuppliers,
      createSuppliers: createSuppliers ?? this.createSuppliers,
      viewAllSuppliers: viewAllSuppliers ?? this.viewAllSuppliers,
      useAi: useAi ?? this.useAi,
      manageSettings: manageSettings ?? this.manageSettings,
      manageUsers: manageUsers ?? this.manageUsers,
    );
  }
}

/// Modelo de Dados do Usuário no Cloud Firestore (`users/{userId}`)
class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final String role; // 'admin' | 'manager' | 'user'
  final String status; // 'active' | 'pending' | 'blocked'
  final String? companyId;
  final UserPermissions permissions;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLoginAt;

  // Controle de Cota e Utilização de IA
  final int aiUsageCount; // Quantidade de análises consumidas hoje
  final String? aiUsageDate; // Data do contador no formato 'yyyy-MM-dd'
  final int? customDailyAiQuota; // Cota personalizada de IA (se null, usa a da empresa ou global)
  final String aiPlanTier; // Grupo de cota de IA: 'premium' (default) | 'gold' | 'diamond'
  final int? customDailyTokenQuota; // Sobrescrita opcional de tokens/dia para este dono/usuário
  final double? customDailyBrlQuota; // Sobrescrita opcional de R$/dia para este dono/usuário

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.phone,
    this.avatarUrl,
    required this.role,
    this.status = 'active',
    this.companyId,
    this.permissions = const UserPermissions(),
    required this.createdAt,
    required this.updatedAt,
    this.lastLoginAt,
    this.aiUsageCount = 0,
    this.aiUsageDate,
    this.customDailyAiQuota,
    this.aiPlanTier = 'premium',
    this.customDailyTokenQuota,
    this.customDailyBrlQuota,
  });

  static const Set<String> masterEmails = {
    'heitorklaus@hotmail.com',
  };

  static bool isMasterEmail(String? email) =>
      email != null && masterEmails.contains(email.toLowerCase().trim());

  bool get isSuperAdmin =>
      role.toLowerCase() == 'superadmin' ||
      role.toLowerCase() == 'master' ||
      isMasterEmail(email);
  bool get isAdmin => isSuperAdmin || role.toLowerCase() == 'admin';
  bool get isManager => isSuperAdmin || role.toLowerCase() == 'manager' || isAdmin;
  bool get isActive => status == 'active';
  String get effectiveCompanyId => (companyId != null && companyId!.isNotEmpty) ? companyId! : uid;

  // Verificações diretas de permissão com respeito estrito às configurações do RBAC (SuperAdmin sempre tem tudo liberado)
  bool get canViewClients => isSuperAdmin || permissions.viewClients;
  bool get canCreateClients => isSuperAdmin || permissions.createClients;
  bool get canViewAllClients => isSuperAdmin || permissions.viewAllClients || isAdmin;
  bool get canViewProducts => isSuperAdmin || permissions.viewProducts;
  bool get canCreateProducts => isSuperAdmin || permissions.createProducts;
  bool get canViewAllProducts => isSuperAdmin || permissions.viewAllProducts || isAdmin;
  bool get canViewProposals => isSuperAdmin || permissions.viewProposals;
  bool get canCreateProposals => isSuperAdmin || permissions.createProposals;
  bool get canViewAllProposals => isSuperAdmin || permissions.viewAllProposals || isAdmin;
  bool get canViewContracts => isSuperAdmin || permissions.viewContracts;
  bool get canCreateContracts => isSuperAdmin || permissions.createContracts;
  bool get canViewAllContracts => isSuperAdmin || permissions.viewAllContracts || isAdmin;
  bool get canDeleteContracts => isSuperAdmin || permissions.deleteContracts || isAdmin;
  bool get canViewSuppliers => isSuperAdmin || permissions.viewSuppliers;
  bool get canCreateSuppliers => isSuperAdmin || permissions.createSuppliers;
  bool get canViewAllSuppliers => isSuperAdmin || permissions.viewAllSuppliers || isAdmin;
  bool get canUseAi => isSuperAdmin || permissions.useAi;
  bool get canManageSettings => isSuperAdmin || permissions.manageSettings;
  bool get canManageUsers => isSuperAdmin || permissions.manageUsers;

  /// Verifica se o usuário pode visualizar um registro específico com base em RBAC + compartilhamento.
  bool canAccessRecord({
    required bool viewAllPermission,
    String? createdByUserId,
    bool isPublicForCompany = false,
    List<String> sharedWithUserIds = const [],
  }) {
    if (isSuperAdmin || isAdmin || viewAllPermission) return true;
    if (createdByUserId != null && createdByUserId == uid) return true;
    if (isPublicForCompany) return true;
    if (sharedWithUserIds.contains(uid)) return true;
    return false;
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String?,
      avatarUrl: map['avatarUrl'] as String?,
      role: map['role'] as String? ?? 'user',
      status: map['status'] as String? ?? 'active',
      companyId: map['companyId'] as String?,
      permissions: UserPermissions.fromMap(map['permissions'] as Map<String, dynamic>?),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLoginAt: (map['lastLoginAt'] as Timestamp?)?.toDate(),
      aiUsageCount: map['aiUsageCount'] as int? ?? 0,
      aiUsageDate: map['aiUsageDate'] as String?,
      customDailyAiQuota: map['customDailyAiQuota'] as int?,
      aiPlanTier: (map['aiPlanTier'] as String?)?.toLowerCase().trim().isNotEmpty == true
          ? (map['aiPlanTier'] as String).toLowerCase().trim()
          : 'premium',
      customDailyTokenQuota: (map['customDailyTokenQuota'] as num?)?.toInt(),
      customDailyBrlQuota: (map['customDailyBrlQuota'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'avatarUrl': avatarUrl,
      'role': role,
      'status': status,
      'companyId': companyId,
      'permissions': permissions.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
      'aiUsageCount': aiUsageCount,
      'aiUsageDate': aiUsageDate,
      'customDailyAiQuota': customDailyAiQuota,
      'aiPlanTier': aiPlanTier,
      'customDailyTokenQuota': customDailyTokenQuota,
      'customDailyBrlQuota': customDailyBrlQuota,
    };
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? phone,
    String? avatarUrl,
    String? role,
    String? status,
    String? companyId,
    UserPermissions? permissions,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
    int? aiUsageCount,
    String? aiUsageDate,
    int? customDailyAiQuota,
    String? aiPlanTier,
    int? customDailyTokenQuota,
    double? customDailyBrlQuota,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      status: status ?? this.status,
      companyId: companyId ?? this.companyId,
      permissions: permissions ?? this.permissions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      aiUsageCount: aiUsageCount ?? this.aiUsageCount,
      aiUsageDate: aiUsageDate ?? this.aiUsageDate,
      customDailyAiQuota: customDailyAiQuota ?? this.customDailyAiQuota,
      aiPlanTier: aiPlanTier ?? this.aiPlanTier,
      customDailyTokenQuota: customDailyTokenQuota ?? this.customDailyTokenQuota,
      customDailyBrlQuota: customDailyBrlQuota ?? this.customDailyBrlQuota,
    );
  }
}
