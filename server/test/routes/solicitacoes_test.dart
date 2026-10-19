import 'package:frota_core/frota_core.dart';
import 'package:frota_server/src/api_exception.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../routes/solicitacoes/index.dart' as route;
import '../helpers.dart';

void main() {
  late MockSolicitacoesRepository requests;

  final approved = RequestModel(
    id: 1,
    requesterId: 3,
    requester: 'Ana',
    reason: 'Visita',
    destination: 'Macaé',
    passengers: 1,
    returnPeriod: ReturnPeriod.manha,
    status: RequestStatus.aprovada,
    approverId: 2,
    approverName: 'Bruno',
  );

  setUp(() {
    requests = MockSolicitacoesRepository();
    when(
      () => requests.list(
        statuses: any(named: 'statuses'),
        requesterId: any(named: 'requesterId'),
        approverId: any(named: 'approverId'),
      ),
    ).thenAnswer((_) async => [approved]);
  });

  Future<List<dynamic>> get(String path, UserModel me) async {
    final response = await route.onRequest(
      contextFor(jsonRequest('GET', path), me: me, requests: requests),
    );
    return await response.json() as List<dynamic>;
  }

  test('aprovador vê todas, com filtro de status e "só as minhas"', () async {
    final body = await get(
      '/solicitacoes?status=aprovada,emUso,finalizada&aprovadorId=2',
      user(id: 2, profile: UserProfile.aprovador),
    );

    expect(body.single, containsPair('approverName', 'Bruno'));
    verify(
      () => requests.list(
        statuses: {
          RequestStatus.aprovada,
          RequestStatus.emUso,
          RequestStatus.finalizada,
        },
        approverId: 2,
      ),
    ).called(1);
  });

  test('padrão só vê as próprias (filtro forçado pelo servidor)', () async {
    await get('/solicitacoes', user(id: 9));

    verify(() => requests.list(requesterId: 9)).called(1);
  });

  test('status desconhecido → 400', () {
    expect(
      () => get(
        '/solicitacoes?status=aprovadas',
        user(profile: UserProfile.aprovador),
      ),
      throwsA(
        isA<ApiException>().having((e) => e.statusCode, 'status', 400),
      ),
    );
  });
}
