import 'package:cloud_firestore/cloud_firestore.dart';

/// Permissões Granuladas do Usuário (RBAC)
class UserPermissions {
  final bool manageUsers;
  final bool manageSettings;
  final bool viewReports;
  final bool editLeads;
  final bool deleteLeads;

  const UserPermissions({
    this.manageUsers = false,
    this.manageSettings = false,
    this.viewReports = true,
    this.editLeads = true,
    this.deleteLeads = false,
  });

  /// Retorna as permissões padrão de acordo com o papel do usuário
  factory UserPermissions.defaultForRole(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return const UserPermissions(
          manageUsers: true,
          manageSettings: true,
          viewReports: true,
          editLeads: true,
          deleteLeads: true,
        );
      case 'manager':
        return const UserPermissions(
          manageUsers: false,
          manageSettings: false,
          viewReports: true,
          editLeads: true,
          deleteLeads: true,
        );
      case 'user':
      default:
        return const UserPermissions(
          manageUsers: false,
          manageSettings: false,
          viewReports: false,
          editLeads: true,
          deleteLeads: false,
        );
    }
  }

  factory UserPermissions.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const UserPermissions();
    return UserPermissions(
      manageUsers: map['manageUsers'] as bool? ?? false,
      manageSettings: map['manageSettings'] as bool? ?? false,
      viewReports: map['viewReports'] as bool? ?? true,
      editLeads: map['editLeads'] as bool? ?? true,
      deleteLeads: map['deleteLeads'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'manageUsers': manageUsers,
      'manageSettings': manageSettings,
      'viewReports': viewReports,
      'editLeads': editLeads,
      'deleteLeads': deleteLeads,
    };
  }

  UserPermissions copyWith({
    bool? manageUsers,
    bool? manageSettings,
    bool? viewReports,
    bool? editLeads,
    bool? deleteLeads,
  }) {
    return UserPermissions(
      manageUsers: manageUsers ?? this.manageUsers,
      manageSettings: manageSettings ?? this.manageSettings,
      viewReports: viewReports ?? this.viewReports,
      editLeads: editLeads ?? this.editLeads,
      deleteLeads: deleteLeads ?? this.deleteLeads,
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

  bool get isAdmin => role == 'admin';
  bool get isManager => role == 'manager' || isAdmin;
  bool get isActive => status == 'active';
  String get effectiveCompanyId => (companyId != null && companyId!.isNotEmpty) ? companyId! : uid;

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
