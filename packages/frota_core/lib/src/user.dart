/// Perfil de acesso no sistema (seção 2 do documento).
enum UserProfile { padrao, aprovador }

extension UserProfileX on UserProfile {
  String get label {
    switch (this) {
      case UserProfile.padrao:
        return 'Padrão';
      case UserProfile.aprovador:
        return 'Aprovador';
    }
  }
}

/// Situação da CNH (regra 5.2.4: CNH vencida não pode solicitar veículo).
enum CnhStatus { valida, vencendo, vencida, naoInformada }

extension CnhStatusX on CnhStatus {
  String get label {
    switch (this) {
      case CnhStatus.valida:
        return 'Válida';
      case CnhStatus.vencendo:
        return 'Vencendo';
      case CnhStatus.vencida:
        return 'Vencida';
      case CnhStatus.naoInformada:
        return 'Não informada';
    }
  }
}

/// Representa um usuário (entidade "Usuário" — seção 5.2).
class UserModel {
  final int id;
  String name;
  String email;
  String? phone;
  String role; // cargo
  String department; // setor
  String? cnhNumber;
  String? cnhCategory;
  DateTime? cnhExpiry;
  UserProfile profile;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.department,
    this.phone,
    this.cnhNumber,
    this.cnhCategory,
    this.cnhExpiry,
    this.profile = UserProfile.padrao,
  });

  /// Dias até o vencimento da CNH (negativo = já venceu).
  int? get daysToCnhExpiry {
    final expiry = cnhExpiry;
    if (expiry == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(expiry.year, expiry.month, expiry.day);
    return end.difference(today).inDays;
  }

  /// Válida, vencendo (até 30 dias), vencida ou não informada.
  CnhStatus get cnhStatus {
    final days = daysToCnhExpiry;
    if (cnhNumber == null || days == null) return CnhStatus.naoInformada;
    if (days < 0) return CnhStatus.vencida;
    if (days <= 30) return CnhStatus.vencendo;
    return CnhStatus.valida;
  }

  /// Pode solicitar veículo? (regra 5.2.4)
  bool get canRequestVehicle =>
      cnhStatus == CnhStatus.valida || cnhStatus == CnhStatus.vencendo;

  /// Iniciais para o avatar. Ex.: "Felipe Soares" → "FS".
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
