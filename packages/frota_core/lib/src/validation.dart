/// Regra 6.2: mínimo de 6 caracteres, 1 número e 1 caractere especial.
/// Usada na tela de troca de senha (app) e no cadastro de usuário (API).
class PasswordRules {
  const PasswordRules(this.password);

  final String password;

  static const minLength = 6;

  bool get hasMinLength => password.length >= minLength;
  bool get hasNumber => RegExp('[0-9]').hasMatch(password);
  bool get hasSpecial => RegExp(r'[^A-Za-z0-9\s]').hasMatch(password);

  bool get isValid => hasMinLength && hasNumber && hasSpecial;
}

/// Formato básico de e-mail (algo@algo.algo). Quem confirma que ele
/// existe de verdade é o Supabase Auth.
bool isValidEmail(String email) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim());
