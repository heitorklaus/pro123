// ignore_for_file: library_private_types_in_public_api
import 'package:mobx/mobx.dart';
import '../../data/repositories/auth_repository.dart';

part 'login_store.g.dart';

class LoginStore = _LoginStoreBase with _$LoginStore;

abstract class _LoginStoreBase with Store {
  final AuthRepository _authRepository;

  _LoginStoreBase({AuthRepository? authRepository})
      : _authRepository = authRepository ?? AuthRepository();

  @observable
  String email = '';

  @observable
  String password = '';

  @observable
  bool isLoading = false;

  @observable
  bool isGoogleLoading = false;

  @observable
  bool obscurePassword = true;

  @observable
  String? errorMessage;

  @action
  void setEmail(String value) {
    email = value;
    errorMessage = null;
  }

  @action
  void setPassword(String value) {
    password = value;
    errorMessage = null;
  }

  @action
  void toggleObscurePassword() {
    obscurePassword = !obscurePassword;
  }

  @action
  Future<bool> login() async {
    if (email.trim().isEmpty) {
      errorMessage = 'Por favor, informe seu e-mail.';
      return false;
    }
    if (password.trim().isEmpty) {
      errorMessage = 'Por favor, informe sua senha.';
      return false;
    }

    isLoading = true;
    errorMessage = null;

    try {
      await _authRepository.loginUser(
        email: email,
        password: password,
      );
      isLoading = false;
      return true;
    } catch (e) {
      isLoading = false;
      errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    }
  }

  @action
  Future<bool> loginWithGoogle() async {
    isGoogleLoading = true;
    errorMessage = null;

    try {
      final user = await _authRepository.signInWithGoogle();
      isGoogleLoading = false;

      if (user == null) {
        // Usuário cancelou a seleção da conta Google
        return false;
      }

      return true;
    } catch (e) {
      isGoogleLoading = false;
      errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    }
  }
}
