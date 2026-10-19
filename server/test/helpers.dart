import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:frota_core/frota_core.dart';
import 'package:frota_server/src/solicitacoes_repository.dart';
import 'package:frota_server/src/supabase_auth.dart';
import 'package:frota_server/src/usuarios_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockRequestContext extends Mock implements RequestContext {}

class MockUsuariosRepository extends Mock implements UsuariosRepository {}

class MockSupabaseAuth extends Mock implements SupabaseAuth {}

class MockSolicitacoesRepository extends Mock
    implements SolicitacoesRepository {}

UserModel user({
  int id = 1,
  UserProfile profile = UserProfile.padrao,
  bool active = true,
}) => UserModel(
  id: id,
  name: 'Usuário $id',
  email: 'u$id@empresa.com',
  role: 'Cargo',
  department: 'Setor',
  profile: profile,
  active: active,
);

/// Contexto falso com a requisição e as dependências que a rota lê.
MockRequestContext contextFor(
  Request request, {
  UsuariosRepository? repository,
  SupabaseAuth? auth,
  UserModel? me,
  SolicitacoesRepository? requests,
}) {
  final context = MockRequestContext();
  when(() => context.request).thenReturn(request);
  if (requests != null) {
    when(() => context.read<SolicitacoesRepository>()).thenReturn(requests);
  }
  if (repository != null) {
    when(() => context.read<UsuariosRepository>()).thenReturn(repository);
  }
  if (auth != null) when(() => context.read<SupabaseAuth>()).thenReturn(auth);
  if (me != null) when(() => context.read<UserModel>()).thenReturn(me);
  return context;
}

Request jsonRequest(String method, String path, [Object? body]) => Request(
  method,
  Uri.parse('http://localhost$path'),
  body: body == null ? null : jsonEncode(body),
  headers: {'content-type': 'application/json'},
);
