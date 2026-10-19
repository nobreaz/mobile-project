import 'package:dart_frog/dart_frog.dart';
import 'package:frota_core/frota_core.dart';
import 'package:frota_server/src/middleware.dart';

/// Gestão de usuários: só Administrador (o login é conferido antes do perfil).
Handler middleware(Handler handler) =>
    handler.use(requireProfile({UserProfile.administrador})).use(requireUser());
