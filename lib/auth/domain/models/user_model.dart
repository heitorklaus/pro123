import 'package:cloud_firestore/cloud_firestore.dart';

/// Permissões Granuladas do Usuário (RBAC)
class UserPermissions {
  // Clientes
  final bool viewClients;
  final bool createClients;

  // Produtos & Usinas Solares
  final bool viewProducts;
  final bool createProducts;

  // Propostas Comerciais
  final bool viewProposals;
  final bool createProposals;
  final bool viewAllProposals; // Ver propostas de todos os operadores (se false, apenas as suas)

  // Fornecedores & Parceiros
  final bool viewSuppliers;
  final bool createSuppliers;

  // Sistema & Administração
  final bool manageSettings;
  final bool manageUsers;

  const UserPermissions({
    this.viewClients = true,
    this.createClients = true,
    this.viewProducts = true,
    this.createProducts = true,
    this.viewProposals = true,
    this.createProposals = true,
    this.viewAllProposals = false,
    this.viewSuppliers = true,
    this.createSuppliers = true,
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
          viewProducts: true,
          createProducts: true,
          viewProposals: true,
          createProposals: true,
          viewAllProposals: true,
          viewSuppliers: true,
          createSuppliers: true,
          manageSettings: true,
          manageUsers: true,
        );
      case 'manager':
        return const UserPermissions(
          viewClients: true,
          createClients: true,
          viewProducts: true,
          createProducts: true,
          viewProposals: true,
          createProposals: true,
          viewAllProposals: true,
          viewSuppliers: true,
          createSuppliers: true,
          manageSettings: false,
          manageUsers: false,
        );
      case 'user':
      default:
        return const UserPermissions(
          viewClients: true,
          createClients: true,
          viewProducts: true,
          createProducts: false,
          viewProposals: true,
          createProposals: true,
          viewAllProposals: false,
          viewSuppliers: true,
          createSuppliers: false,
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
      viewProducts: map['viewProducts'] as bool? ?? true,
      createProducts: map['createProducts'] as bool? ?? (map['editLeads'] as bool? ?? true),
      viewProposals: map['viewProposals'] as bool? ?? true,
      createProposals: map['createProposals'] as bool? ?? true,
      viewAllProposals: map['viewAllProposals'] as bool? ?? (map['viewReports'] as bool? ?? false),
      viewSuppliers: map['viewSuppliers'] as bool? ?? true,
      createSuppliers: map['createSuppliers'] as bool? ?? (map['editLeads'] as bool? ?? false),
      manageSettings: map['manageSettings'] as bool? ?? false,
      manageUsers: map['manageUsers'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'viewClients': viewClients,
      'createClients': createClients,
      'viewProducts': viewProducts,
      'createProducts': createProducts,
      'viewProposals': viewProposals,
      'createProposals': createProposals,
      'viewAllProposals': viewAllProposals,
      'viewSuppliers': viewSuppliers,
      'createSuppliers': createSuppliers,
      'manageSettings': manageSettings,
      'manageUsers': manageUsers,
    };
  }

  UserPermissions copyWith({
    bool? viewClients,
    bool? createClients,
    bool? viewProducts,
    bool? createProducts,
    bool? viewProposals,
    bool? createProposals,
    bool? viewAllProposals,
    bool? viewSuppliers,
    bool? createSuppliers,
    bool? manageSettings,
    bool? manageUsers,
  }) {
    return UserPermissions(
      viewClients: viewClients ?? this.viewClients,
      createClients: createClients ?? this.createClients,
      viewProducts: viewProducts ?? this.viewProducts,
      createProducts: createProducts ?? this.createProducts,
      viewProposals: viewProposals ?? this.viewProposals,
      createProposals: createProposals ?? this.createProposals,
      viewAllProposals: viewAllProposals ?? this.viewAllProposals,
      viewSuppliers: viewSuppliers ?? this.viewSuppliers,
      createSuppliers: createSuppliers ?? this.createSuppliers,
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

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.role = 'user',
    this.status = 'active',
    this.companyId,
    required this.permissions,
    required this.createdAt,
    required this.updatedAt,
    this.lastLoginAt,
  });

  bool get isAdmin => role.toLowerCase() == 'admin';
  bool get isManager => role.toLowerCase() == 'manager' || isAdmin;
  bool get isActive => status == 'active';
  String get effectiveCompanyId => (companyId != null && companyId!.isNotEmpty) ? companyId! : uid;

  // Verificações diretas de permissão com respeito estrito às configurações do RBAC
  bool get canViewClients => permissions.viewClients;
  bool get canCreateClients => permissions.createClients;
  bool get canViewProducts => permissions.viewProducts;
  bool get canCreateProducts => permissions.createProducts;
  bool get canViewProposals => permissions.viewProposals;
  bool get canCreateProposals => permissions.createProposals;
  bool get canViewAllProposals => permissions.viewAllProposals || isAdmin || isManager;
  bool get canViewSuppliers => permissions.viewSuppliers;
  bool get canCreateSuppliers => permissions.createSuppliers;
  bool get canManageSettings => permissions.manageSettings;
  bool get canManageUsers => permissions.manageUsers;

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
    );
  }
}
