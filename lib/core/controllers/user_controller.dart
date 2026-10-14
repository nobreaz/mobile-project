import 'package:flutter/material.dart';
import 'package:project/core/models/user_model.dart';

/// Guarda os usuários em memória e indica quem está logado.
///
/// Quando o login com Firebase entrar, ele só vai preencher
/// estes dados — as telas não mudam.
class UserController extends ChangeNotifier {
  UserController._();
  static final UserController instance = UserController._();

  // Usuários de exemplo (remover quando houver autenticação).
  final List<UserModel> _users = [
    UserModel(
      id: 1,
      name: 'Nome Sobrenome',
      email: 'nome.sobrenome@empresa.com',
      phone: '(22) 99999-0000',
      role: 'Cargo',
      department: 'Setor',
      cnhNumber: '01234567890',
      cnhCategory: 'B',
      cnhExpiry: DateTime(2028, 5, 15),
      profile: UserProfile.aprovador,
    ),
    UserModel(
      id: 2,
      name: 'Ana Ribeiro',
      email: 'ana.ribeiro@empresa.com',
      phone: '(22) 98888-1111',
      role: 'Técnica de Campo',
      department: 'Operações',
      cnhNumber: '11122233344',
      cnhCategory: 'B',
      cnhExpiry: DateTime(2029, 3, 10),
    ),
    UserModel(
      id: 3,
      name: 'Carlos Mendes',
      email: 'carlos.mendes@empresa.com',
      phone: '(22) 97777-2222',
      role: 'Analista de Logística',
      department: 'Logística',
      cnhNumber: '55566677788',
      cnhCategory: 'D',
      cnhExpiry: DateTime.now().add(const Duration(days: 20)),
    ),
    UserModel(
      id: 4,
      name: 'Juliana Costa',
      email: 'juliana.costa@empresa.com',
      role: 'Assistente Administrativa',
      department: 'Administrativo',
      cnhNumber: '99988877766',
      cnhCategory: 'B',
      cnhExpiry: DateTime(2025, 1, 5),
    ),
  ];

  /// Usuário logado (por enquanto, sempre o primeiro da lista).
  UserModel get currentUser => _users.first;

  /// Todos os usuários, para a Gestão de Usuários.
  List<UserModel> get users => List.unmodifiable(_users);

  UserModel? userById(int id) {
    for (final u in _users) {
      if (u.id == id) return u;
    }
    return null;
  }

  /// Único dado pessoal que o próprio usuário pode alterar.
  void updatePhone(String? phone) {
    currentUser.phone = (phone == null || phone.trim().isEmpty)
        ? null
        : phone.trim();
    notifyListeners();
  }
}
