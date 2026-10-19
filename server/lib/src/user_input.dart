import 'package:frota_core/frota_core.dart';
import 'package:frota_server/src/api_exception.dart';

/// Lê e valida o JSON das rotas de usuário.
///
/// Os nomes dos campos são os do [UserModel.toJson] (os mesmos que o app usa).
/// Todos os erros são juntados e devolvidos de uma vez (HTTP 400), para o app
/// marcar todos os campos inválidos.
class _Reader {
  _Reader(this.json);

  final Map<String, dynamic> json;
  final errors = <String, String>{};

  bool has(String key) => json.containsKey(key);

  /// Texto obrigatório e não vazio.
  String requiredText(String key, String label) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
    errors[key] = '$label é obrigatório.';
    return '';
  }

  /// Texto opcional: vazio ou `null` vira `null` (apaga o valor).
  String? optionalText(String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! String) {
      errors[key] = 'Deve ser um texto.';
      return null;
    }
    return value.trim().isEmpty ? null : value.trim();
  }

  /// Data `AAAA-MM-DD` opcional.
  DateTime? optionalDate(String key) {
    final value = json[key];
    if (value == null) return null;
    final parsed = value is String ? DateTime.tryParse(value) : null;
    if (parsed == null) {
      errors[key] = 'Data inválida. Use o formato AAAA-MM-DD.';
      return null;
    }
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  UserProfile? profile(String key) {
    final value = json[key];
    for (final p in UserProfile.values) {
      if (p.name == value) return p;
    }
    errors[key] =
        'Perfil deve ser '
        '${UserProfile.values.map((p) => '"${p.name}"').join(', ')}.';
    return null;
  }

  bool? boolean(String key) {
    final value = json[key];
    if (value is bool) return value;
    errors[key] = 'Deve ser true ou false.';
    return null;
  }

  void throwIfInvalid() {
    if (errors.isNotEmpty) {
      throw ApiException.badRequest(
        'Verifique os campos destacados.',
        fields: errors,
      );
    }
  }
}

/// Corpo de `POST /usuarios`: o Administrador cadastra um colaborador
/// com uma senha inicial (RF 3.1.3; senha segue a RNF 6.2).
class NewUserInput {
  NewUserInput._(this.user, this.password);

  factory NewUserInput.fromJson(Map<String, dynamic> json) {
    final r = _Reader(json);

    final email = r.requiredText('email', 'E-mail').toLowerCase();
    if (email.isNotEmpty && !isValidEmail(email)) {
      r.errors['email'] = 'E-mail inválido.';
    }

    final password = json['password'];
    if (password is! String || !PasswordRules(password).isValid) {
      r.errors['password'] =
          'A senha precisa ter ao menos ${PasswordRules.minLength} '
          'caracteres, 1 número e 1 caractere especial.';
    }

    final user = UserModel(
      id: 0, // definido pelo banco
      name: r.requiredText('name', 'Nome'),
      email: email,
      role: r.requiredText('role', 'Cargo'),
      department: r.requiredText('department', 'Setor'),
      phone: r.optionalText('phone'),
      cnhNumber: r.optionalText('cnhNumber'),
      cnhCategory: r.optionalText('cnhCategory'),
      cnhExpiry: r.optionalDate('cnhExpiry'),
      profile: r.has('profile')
          ? r.profile('profile') ?? UserProfile.padrao
          : UserProfile.padrao,
    );

    r.throwIfInvalid();
    return NewUserInput._(user, password as String);
  }

  final UserModel user;
  final String password;
}

/// Corpo de `PATCH /usuarios/{id}` (Administrador). Só os campos enviados mudam.
/// O e-mail não muda aqui: ele é o login no Supabase Auth.
///
/// Devolve as alterações já com os nomes das colunas do banco.
Map<String, Object?> parseUserUpdate(Map<String, dynamic> json) {
  final r = _Reader(json);
  final changes = <String, Object?>{};

  if (r.has('email')) r.errors['email'] = 'O e-mail não pode ser alterado.';
  if (r.has('name')) changes['nome'] = r.requiredText('name', 'Nome');
  if (r.has('role')) changes['cargo'] = r.requiredText('role', 'Cargo');
  if (r.has('department')) {
    changes['setor'] = r.requiredText('department', 'Setor');
  }
  if (r.has('phone')) changes['telefone'] = r.optionalText('phone');
  if (r.has('cnhNumber')) changes['cnh_numero'] = r.optionalText('cnhNumber');
  if (r.has('cnhCategory')) {
    changes['cnh_categoria'] = r.optionalText('cnhCategory');
  }
  if (r.has('cnhExpiry')) changes['cnh_validade'] = r.optionalDate('cnhExpiry');
  if (r.has('profile')) changes['perfil'] = r.profile('profile')?.name;
  if (r.has('active')) changes['ativo'] = r.boolean('active');

  r.throwIfInvalid();
  return changes;
}

/// Corpo de `PATCH /me`: o próprio usuário só altera o telefone.
Map<String, Object?> parseMeUpdate(Map<String, dynamic> json) {
  final r = _Reader(json);
  final others = json.keys.where((k) => k != 'phone');
  for (final key in others) {
    r.errors[key] = 'Só o telefone pode ser alterado pelo próprio usuário.';
  }
  final changes = {if (r.has('phone')) 'telefone': r.optionalText('phone')};
  r.throwIfInvalid();
  return changes;
}
