import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:frota_core/frota_core.dart';
import 'package:frota_server/src/frota_service.dart';
import 'package:frota_server/src/notificacoes_repository.dart';
import 'package:frota_server/src/solicitacoes_repository.dart';
import 'package:frota_server/src/supabase_auth.dart';
import 'package:frota_server/src/usuarios_repository.dart';
import 'package:frota_server/src/veiculos_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockRequestContext extends Mock implements RequestContext {}

class MockUsuariosRepository extends Mock implements UsuariosRepository {}

class MockSupabaseAuth extends Mock implements SupabaseAuth {}

class MockSolicitacoesRepository extends Mock
    implements SolicitacoesRepository {}

class MockVeiculosRepository extends Mock implements VeiculosRepository {}

class MockNotificacoesRepository extends Mock
    implements NotificacoesRepository {}

class MockFrotaService extends Mock implements FrotaService {}

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

VehicleModel vehicle({int id = 1, int seats = 5}) => VehicleModel(
  id: id,
  plate: 'ABC1D2$id',
  chassis: 'CHASSI$id',
  model: 'Gol',
  color: 'Branco',
  year: 2022,
  seats: seats,
  mileage: 1000,
  licensingExpiry: DateTime(2027, 3, 31),
  insuranceExpiry: DateTime(2027, 6, 10),
);

RequestModel request({
  int id = 1,
  int requesterId = 3,
  RequestStatus status = RequestStatus.pendente,
}) => RequestModel(
  id: id,
  requesterId: requesterId,
  requester: 'Ana',
  reason: 'Visita',
  destination: 'Macaé',
  passengers: 1,
  departure: DateTime.utc(2026, 11, 10, 11),
  returnDate: DateTime(2026, 11, 10),
  returnPeriod: ReturnPeriod.tarde,
  status: status,
);

/// Contexto falso com a requisição e as dependências que a rota lê.
MockRequestContext contextFor(
  Request request, {
  UsuariosRepository? repository,
  SupabaseAuth? auth,
  UserModel? me,
  SolicitacoesRepository? requests,
  VeiculosRepository? vehicles,
  NotificacoesRepository? notifications,
  FrotaService? frota,
}) {
  final context = MockRequestContext();
  when(() => context.request).thenReturn(request);
  if (requests != null) {
    when(() => context.read<SolicitacoesRepository>()).thenReturn(requests);
  }
  if (repository != null) {
    when(() => context.read<UsuariosRepository>()).thenReturn(repository);
  }
  if (vehicles != null) {
    when(() => context.read<VeiculosRepository>()).thenReturn(vehicles);
  }
  if (notifications != null) {
    when(
      () => context.read<NotificacoesRepository>(),
    ).thenReturn(notifications);
  }
  if (frota != null) when(() => context.read<FrotaService>()).thenReturn(frota);
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
