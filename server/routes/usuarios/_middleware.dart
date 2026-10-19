import 'package:dart_frog/dart_frog.dart';
import 'package:frota_server/src/middleware.dart';

/// Gestão de usuários: só Aprovador (o login é conferido antes do perfil).
Handler middleware(Handler handler) =>
    handler.use(requireApprover()).use(requireUser());
