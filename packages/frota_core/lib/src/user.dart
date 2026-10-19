/// Data sem horário no formato `AAAA-MM-DD` (o mesmo do tipo `date` do banco).
String formatDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Perfil de acesso no sistema.
///
/// O documento (seção 2) define Padrão e Aprovador. O grupo separou as
/// funções em três perfis, um por pessoa (segregação de funções):
/// - Padrão: solicita e usa veículos.
/// - Aprovador: aprova/recusa e aloca veículos. NÃO solicita (regra do
///   professor: ninguém aprova o próprio pedido).
/// - Administrador: cadastra veículos e usuários. Não solicita nem aprova.
enum UserProfile { padrao, aprovador, administrador }

extension UserProfileX on UserProfile {
  String get label {
    switch (this) {
      case UserProfile.padrao:
        return 'Padrão';
      case UserProfile.aprovador:
        return 'Aprovador';
      case UserProfile.administrador:
        return 'Administrador';
    }
  }

  /// Solicitar veículo, check-out e check-in.
  bool get canRequest => this == UserProfile.padrao;

  /// Aprovar/recusar solicitações e alocar veículos.
  bool get canApprove => this == UserProfile.aprovador;

  /// Cadastrar e gerenciar veículos e usuários.
  bool get canManageRegistry => this == UserProfile.administrador;

  /// Ver a frota (status, km, vencimentos). Só o Administrador altera.
  bool get canViewFleet =>
      this == UserProfile.aprovador || this == UserProfile.administrador;
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

  /// Usuário desativado não consegue entrar no app. Nunca é apagado,
  /// para manter o histórico de solicitações (mesma ideia do veículo).
  bool active;

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
    this.active = true,
  });

  /// Formato JSON trocado entre a API e o app.
  /// Datas sem horário (validade da CNH) vão como `AAAA-MM-DD`.
  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] as int,
    name: json['name'] as String,
    email: json['email'] as String,
    phone: json['phone'] as String?,
    role: json['role'] as String,
    department: json['department'] as String,
    cnhNumber: json['cnhNumber'] as String?,
    cnhCategory: json['cnhCategory'] as String?,
    cnhExpiry: json['cnhExpiry'] == null
        ? null
        : DateTime.parse(json['cnhExpiry'] as String),
    profile: UserProfile.values.byName(json['profile'] as String),
    active: json['active'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'role': role,
    'department': department,
    'cnhNumber': cnhNumber,
    'cnhCategory': cnhCategory,
    'cnhExpiry': cnhExpiry == null ? null : formatDate(cnhExpiry!),
    'profile': profile.name,
    'active': active,
  };

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

  /// Pode solicitar veículo? Só o perfil Padrão, com CNH válida (5.2.4).
  bool get canRequestVehicle => profile.canRequest && hasValidCnh;

  /// CNH válida ou vencendo (ainda dentro da validade).
  bool get hasValidCnh =>
      cnhStatus == CnhStatus.valida || cnhStatus == CnhStatus.vencendo;

  /// Iniciais para o avatar. Ex.: "Felipe Soares" → "FS".
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
