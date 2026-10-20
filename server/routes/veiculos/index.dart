import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:frota_core/frota_core.dart';
import 'package:frota_server/src/api_exception.dart';
import 'package:frota_server/src/frota_service.dart';
import 'package:frota_server/src/middleware.dart';
import 'package:frota_server/src/vehicle_input.dart';
import 'package:frota_server/src/veiculos_repository.dart';

/// `/veiculos`
/// - GET: a frota inteira (qualquer usuário logado; inativos por último).
/// - POST: cadastra um veículo (só Administrador, RF 3.2.1).
Future<Response> onRequest(RequestContext context) async {
  switch (context.request.method) {
    case HttpMethod.get:
      final vehicles = await context.read<VeiculosRepository>().list();
      return Response.json(body: [for (final v in vehicles) v.toJson()]);

    case HttpMethod.post:
      checkProfile(context.read<UserModel>(), {
        UserProfile.administrador,
      }, 'cadastrar veículos');
      final vehicle = parseNewVehicle(await readJsonObject(context));
      final created = await context.read<FrotaService>().createVehicle(
        vehicle,
      );
      return Response.json(
        statusCode: HttpStatus.created,
        body: created.toJson(),
      );

    // ignore: no_default_cases
    default:
      throw const ApiException.methodNotAllowed();
  }
}
