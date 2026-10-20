import 'package:frota_core/frota_core.dart';
import 'package:frota_server/src/api_exception.dart';

/// Lê e valida o corpo JSON das rotas.
///
/// Os nomes dos campos são os do `toJson` dos modelos do frota_core
/// (os mesmos que o app usa). Todos os erros são juntados e devolvidos de
/// uma vez (HTTP 400), para o app marcar todos os campos inválidos.
class JsonReader {
  JsonReader(this.json);

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

  /// Data `AAAA-MM-DD` obrigatória.
  DateTime? requiredDate(String key, String label) {
    if (json[key] == null) {
      errors[key] = '$label é obrigatório.';
      return null;
    }
    return optionalDate(key);
  }

  /// Momento exato em ISO 8601 COM fuso (`...Z` ou `...-03:00`), como o
  /// app envia. Sem fuso seria ambíguo: o servidor pode estar em outro.
  DateTime? instant(String key, String label) {
    final value = json[key];
    if (value == null) {
      errors[key] = '$label é obrigatório.';
      return null;
    }
    final parsed = value is String && _hasTimeZone.hasMatch(value)
        ? DateTime.tryParse(value)
        : null;
    if (parsed == null) {
      errors[key] =
          'Data e hora inválidas. Use ISO 8601 com fuso '
          '(ex.: 2026-11-10T11:00:00.000Z).';
      return null;
    }
    return parsed.toUtc();
  }

  static final _hasTimeZone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$');

  /// Número inteiro entre [min] e [max] (inclusive).
  int? integer(String key, String label, {int min = 0, int? max}) {
    final value = json[key];
    final number = value is num && value == value.truncate()
        ? value.toInt()
        : null;
    if (number == null) {
      errors[key] = '$label deve ser um número inteiro.';
      return null;
    }
    if (number < min || (max != null && number > max)) {
      errors[key] = max == null
          ? '$label deve ser no mínimo $min.'
          : '$label deve estar entre $min e $max.';
      return null;
    }
    return number;
  }

  /// Inteiro opcional: ausente ou `null` vira `null` (apaga o valor).
  int? optionalInteger(String key, String label, {int min = 0, int? max}) =>
      json[key] == null ? null : integer(key, label, min: min, max: max);

  /// Um dos valores de um enum do frota_core, pelo nome (`name`).
  T? choice<T extends Enum>(String key, List<T> values, String label) {
    final value = json[key];
    for (final v in values) {
      if (v.name == value) return v;
    }
    errors[key] =
        '$label deve ser ${values.map((v) => '"${v.name}"').join(', ')}.';
    return null;
  }

  UserProfile? profile(String key) => choice(key, UserProfile.values, 'Perfil');

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
