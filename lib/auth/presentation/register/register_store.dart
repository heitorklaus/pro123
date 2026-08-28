// ignore_for_file: library_private_types_in_public_api
import 'package:mobx/mobx.dart';
import '../../data/repositories/auth_repository.dart';

part 'register_store.g.dart';

class RegisterStore = _RegisterStoreBase with _$RegisterStore;

abstract class _RegisterStoreBase with Store {
  final AuthRepository _authRepository;

  _RegisterStoreBase({AuthRepository? authRepository})
      : _authRepository = authRepository ?? AuthRepository();

  @observable
  String name = '';

  @observable
  String email = '';

  @observable
  String password = '';

  @observable
  String confirmPassword = '';

  @observable
  bool isLoading = false;

  @observable
  bool obscurePassword = true;

  @observable
  bool obscureConfirmPassword = true;

  @observable
  String? errorMessage;

  @action
  void setName(String value) {
    name = value;
    errorMessage = null;
  }

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
  void setConfirmPassword(String value) {
    confirmPassword = value;
    errorMessage = null;
  }

  @action
  void toggleObscurePassword() {
    obscurePassword = !obscurePassword;
  }

  @action
  void toggleObscureConfirmPassword() {
    obscureConfirmPassword = !obscureConfirmPassword;
  }

  @action
  Future<bool> register({String? companyId, String? role}) async {
    if (name.trim().isEmpty) {
      errorMessage = 'Por favor, informe seu nome completo.';
      return false;
    }
    if (email.trim().isEmpty || !email.contains('@')) {
      errorMessage = 'Por favor, informe um e-mail válido.';
      return false;
    }
    if (password.length < 6) {
      errorMessage = 'A senha deve ter pelo menos 6 caracteres.';
      return false;
    }
    if (password != confirmPassword) {
      errorMessage = 'As senhas não coincidem.';
      return false;
    }

    isLoading = true;
    errorMessage = null;

    try {
      await _authRepository.registerUser(
        name: name,
        email: email,
        password: password,
        role: role ?? 'user',
        companyId: companyId,
      );
      isLoading = false;
      return true;
    } catch (e) {
      isLoading = false;
      errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    }
  }
}
