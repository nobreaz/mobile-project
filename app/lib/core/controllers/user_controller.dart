import 'package:flutter/material.dart';
import 'package:project/core/models/user_model.dart';
import 'package:project/core/services/api_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Login e usuários.
///
/// - Login, logout e senha: direto no Supabase Auth.
/// - Dados do usuário e gestão de usuários: pela API (`/me`, `/usuarios`),
///   que confere perfil e regras no servidor.
///
/// Mesmo padrão dos outros controllers: singleton + ChangeNotifier,
/// então as telas continuam usando `currentUser`, `users` e `userById`.
class UserController extends ChangeNotifier {
  UserController._();
  static final UserController instance = UserController._();

  GoTrueClient get _auth => Supabase.instance.client.auth;
  ApiClient get _api => ApiClient.instance;

  UserModel? _currentUser;
  List<UserModel> _users = [];

  /// Estado da lista da Gestão de Usuários.
  bool loadingUsers = false;
  String? usersError;

  bool get isLoggedIn => _currentUser != null;

  /// Usuário logado. As telas internas só abrem depois do login.
  UserModel get currentUser =>
      _currentUser ?? (throw StateError('Nenhum usuário logado.'));

  /// Usuários carregados por [loadUsers] (só Aprovador).
  List<UserModel> get users => List.unmodifiable(_users);

  UserModel? userById(int id) {
    for (final u in _users) {
      if (u.id == id) return u;
    }
    return _currentUser?.id == id ? _currentUser : null;
  }

  // ---------------------------------------------------------------------
  // Sessão
  // ---------------------------------------------------------------------

  /// Login (RF 3.1.1). Depois do Supabase, busca o cadastro na API:
  /// se o usuário estiver desativado ou sem cadastro, a sessão é desfeita.
  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithPassword(email: email.trim(), password: password);
    } on AuthException catch (e) {
      throw ApiError(_authMessage(e), statusCode: 401);
    }

    try {
      await _loadMe();
    } catch (_) {
      await _auth.signOut();
      rethrow;
    }
  }

  /// Ao abrir o app: se já havia uma sessão salva, entra direto.
  Future<bool> restoreSession() async {
    if (_auth.currentSession == null) return false;
    try {
      await _loadMe();
      return true;
    } on ApiError {
      await signOut();
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on AuthException {
      // Sem rede: a sessão local é apagada mesmo assim.
    }
    _currentUser = null;
    _users = [];
    notifyListeners();
  }

  Future<void> _loadMe() async {
    _currentUser = UserModel.fromJson(await _api.get('/me'));
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Dados e senha do próprio usuário
  // ---------------------------------------------------------------------

  /// Único dado pessoal que o próprio usuário pode alterar.
  Future<void> updatePhone(String? phone) async {
    final json = await _api.patch('/me', {'phone': phone?.trim()});
    _currentUser = UserModel.fromJson(json);
    notifyListeners();
  }

  /// Troca de senha: confirma a senha atual entrando de novo e só então
  /// grava a nova (a regra 6.2 já foi conferida na tela).
  Future<void> changePassword(String current, String newPassword) async {
    try {
      await _auth.signInWithPassword(
        email: currentUser.email,
        password: current,
      );
    } on AuthException {
      throw const ApiError('A senha atual está incorreta.');
    }
    try {
      await _auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      throw ApiError(_authMessage(e));
    }
  }

  /// Envia o e-mail de redefinição de senha (se o e-mail existir).
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.resetPasswordForEmail(email.trim());
    } on AuthException catch (e) {
      throw ApiError(_authMessage(e));
    }
  }

  // ---------------------------------------------------------------------
  // Gestão de usuários (Aprovador)
  // ---------------------------------------------------------------------

  Future<void> loadUsers() async {
    loadingUsers = true;
    usersError = null;
    notifyListeners();
    try {
      final list = await _api.get('/usuarios') as List;
      _users = [
        for (final json in list)
          UserModel.fromJson(json as Map<String, dynamic>),
      ];
    } on ApiError catch (e) {
      usersError = e.message;
    } finally {
      loadingUsers = false;
      notifyListeners();
    }
  }

  /// Cadastra um colaborador com senha inicial (RF 3.1.3).
  Future<UserModel> createUser(Map<String, dynamic> data) async {
    final created = UserModel.fromJson(await _api.post('/usuarios', data));
    _users = [..._users, created]..sort(_byActiveThenName);
    notifyListeners();
    return created;
  }

  /// Altera dados, perfil ou ativa/desativa (só os campos enviados).
  Future<UserModel> updateUser(int id, Map<String, dynamic> changes) async {
    final updated = UserModel.fromJson(
      await _api.patch('/usuarios/$id', changes),
    );
    _users = [for (final u in _users) u.id == id ? updated : u]
      ..sort(_byActiveThenName);
    if (_currentUser?.id == id) _currentUser = updated;
    notifyListeners();
    return updated;
  }

  static int _byActiveThenName(UserModel a, UserModel b) {
    if (a.active != b.active) return a.active ? -1 : 1;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  static String _authMessage(AuthException e) {
    switch (e.code) {
      case 'invalid_credentials':
        return 'E-mail ou senha incorretos.';
      case 'user_banned':
        return 'Seu acesso está desativado. Procure o Aprovador.';
      case 'over_request_rate_limit':
      case 'over_email_send_rate_limit':
        return 'Muitas tentativas. Aguarde alguns minutos.';
      case 'same_password':
        return 'A nova senha precisa ser diferente da atual.';
      case 'weak_password':
        return 'Senha fraca. Use ao menos 6 caracteres, 1 número e 1 '
            'caractere especial.';
    }
    if (e is AuthRetryableFetchException) {
      return 'Não foi possível conectar. Verifique sua conexão.';
    }
    return 'Não foi possível concluir: ${e.message}';
  }
}
