import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import '../../domain/models/user_model.dart';

/// Repositório responsável pela Autenticação no Firebase Auth e gestão de Usuários no Cloud Firestore
class AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  AuthRepository({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// Coleção principal de usuários no Firestore
  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  /// Efetua o login via Conta Google, sincronizando com Firebase Auth e Cloud Firestore
  Future<UserModel?> signInWithGoogle() async {
    try {
      UserCredential userCredential;

      if (kIsWeb) {
        // Na Web, o Firebase Auth gerencia nativamente a janela de popup do Google
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        userCredential = await _firebaseAuth.signInWithPopup(googleProvider);
      } else {
        // No Android / iOS nativo
        final GoogleSignIn googleSignIn = GoogleSignIn();
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

        if (googleUser == null) {
          // Usuário cancelou o fluxo de login
          return null;
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCredential = await _firebaseAuth.signInWithCredential(credential);
      }

      final User? user = userCredential.user;
      if (user == null) return null;

      final String uid = user.uid;
      final DateTime now = DateTime.now();

      // Verificar se o documento do usuário já existe no Firestore
      final DocumentSnapshot<Map<String, dynamic>> doc =
          await _usersRef.doc(uid).get();

      if (!doc.exists || doc.data() == null) {
        // Primeiro acesso via Google: Criar conta de Empresa (Admin) no Firestore
        final UserModel newUser = UserModel(
          uid: uid,
          name: user.displayName ?? 'Usuário Google',
          email: user.email ?? '',
          avatarUrl: user.photoURL,
          role: 'admin',
          status: 'active',
          companyId: uid,
          permissions: UserPermissions.defaultForRole('admin'),
          createdAt: now,
          updatedAt: now,
          lastLoginAt: now,
        );

        await _usersRef.doc(uid).set(newUser.toMap());
        return newUser;
      } else {
        // Usuário existente: Atualizar timestamp de acesso
        await _usersRef.doc(uid).update({
          'lastLoginAt': FieldValue.serverTimestamp(),
          if (user.photoURL != null) 'avatarUrl': user.photoURL,
        });

        return UserModel.fromMap(doc.data()!, uid);
      }
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseAuthError(e.code));
    } catch (e) {
      throw Exception('Erro ao autenticar com Google: $e');
    }
  }

  /// Registra um novo usuário no Firebase Auth e cria seu perfil no Cloud Firestore
  Future<UserModel> registerUser({
    required String name,
    required String email,
    required String password,
    String role = 'user',
    String? phone,
    String? companyId,
  }) async {
    try {
      // 1. Criar a conta no Firebase Authentication
      final UserCredential credential =
          await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final String uid = credential.user!.uid;
      final DateTime now = DateTime.now();

      // 2. Atualizar o nome de exibição no perfil do Firebase Auth
      await credential.user?.updateDisplayName(name.trim());

      // Se não foi fornecido companyId (ex: registro público), este usuário é o Admin/Owner de sua nova Conta
      final effectiveCompanyId = (companyId != null && companyId.trim().isNotEmpty)
          ? companyId.trim()
          : uid;
      final effectiveRole = (companyId != null && companyId.trim().isNotEmpty)
          ? role
          : 'admin';

      // 3. Montar o Modelo do Usuário com as permissões padrão do seu papel (role)
      final UserModel newUser = UserModel(
        uid: uid,
        name: name.trim(),
        email: email.trim(),
        phone: phone?.trim(),
        role: effectiveRole,
        status: 'active',
        companyId: effectiveCompanyId,
        permissions: UserPermissions.defaultForRole(effectiveRole),
        createdAt: now,
        updatedAt: now,
        lastLoginAt: now,
      );

      // 4. Salvar o documento no Cloud Firestore em users/{uid}
      await _usersRef.doc(uid).set(newUser.toMap());

      return newUser;
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseAuthError(e.code));
    } catch (e) {
      throw Exception('Falha ao cadastrar usuário no Firestore: $e');
    }
  }

  /// Realiza o login do usuário e busca seus dados/permissões atualizados no Firestore
  Future<UserModel> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential credential =
          await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final String uid = credential.user!.uid;

      // Buscar o perfil completo no Firestore
      final DocumentSnapshot<Map<String, dynamic>> doc =
          await _usersRef.doc(uid).get();

      if (!doc.exists || doc.data() == null) {
        throw Exception('Perfil do usuário não encontrado no Firestore.');
      }

      final UserModel user = UserModel.fromMap(doc.data()!, uid);

      if (!user.isActive) {
        throw Exception('Sua conta está inativa ou bloqueada. Entre em contato com o suporte.');
      }

      // Atualizar o timestamp de último login
      await _usersRef.doc(uid).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });

      return user;
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseAuthError(e.code));
    } catch (e) {
      throw Exception('Erro ao realizar login: $e');
    }
  }

  /// Retorna os dados do usuário atualmente logado
  Future<UserModel?> getCurrentUser() async {
    final User? currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) return null;

    final DocumentSnapshot<Map<String, dynamic>> doc =
        await _usersRef.doc(currentUser.uid).get();

    if (!doc.exists || doc.data() == null) return null;

    return UserModel.fromMap(doc.data()!, currentUser.uid);
  }

  /// Retorna o Stream em tempo real do perfil do usuário logado (atualiza permissões instantaneamente)
  Stream<UserModel?> getCurrentUserStream() {
    final User? currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) return Stream.value(null);

    return _usersRef.doc(currentUser.uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserModel.fromMap(doc.data()!, currentUser.uid);
    });
  }

  /// Retorna o companyId da conta de empresa ativa do usuário autenticado
  Future<String?> getCurrentCompanyId() async {
    final user = await getCurrentUser();
    return user?.effectiveCompanyId;
  }

  /// Atualiza as permissões de um usuário específico (Ação restrita ao Admin)
  Future<void> updateUserPermissions(
    String uid,
    UserPermissions permissions,
  ) async {
    await _usersRef.doc(uid).update({
      'permissions': permissions.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Atualiza o papel/função de um usuário (ex: promover a manager ou admin)
  Future<void> updateUserRole(String uid, String newRole, {UserPermissions? permissions}) async {
    final permsToSave = permissions ?? UserPermissions.defaultForRole(newRole);
    await _usersRef.doc(uid).update({
      'role': newRole,
      'permissions': permsToSave.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Retorna o Stream em tempo real da lista de usuários cadastrados no Firestore para a empresa
  Stream<List<UserModel>> getUsersStream({String? companyId}) {
    if (companyId == null || companyId.isEmpty) {
      return Stream.value([]);
    }
    final query = _usersRef.where('companyId', isEqualTo: companyId);
    return query.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Remove o documento do usuário no Firestore
  Future<void> deleteUser(String uid) async {
    await _usersRef.doc(uid).delete();
  }

  /// Atualiza o status do usuário (ex: 'active' ou 'blocked')
  Future<void> updateUserStatus(String uid, String status) async {
    await _usersRef.doc(uid).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Efetua o logout do Firebase Auth
  Future<void> logout() async {
    await _firebaseAuth.signOut();
  }

  /// Tradução amigável de erros do Firebase Auth
  String _mapFirebaseAuthError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Este e-mail já está em uso por outra conta.';
      case 'invalid-email':
        return 'O endereço de e-mail informado não é válido.';
      case 'weak-password':
        return 'A senha é muito fraca. Escolha uma senha mais forte.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou senha incorretos.';
      case 'user-disabled':
        return 'Esta conta foi desativada pelo administrador.';
      default:
        return 'Ocorreu um erro de autenticação. Tente novamente.';
    }
  }
}
