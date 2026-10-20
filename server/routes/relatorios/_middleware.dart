import 'package:dart_frog/dart_frog.dart';
import 'package:frota_core/frota_core.dart';
import 'package:frota_server/src/middleware.dart';

/// Relatórios: Aprovador e Administrador (o Padrão só vê as próprias
/// viagens, e o relatório tem dados de todos).
Handler middleware(Handler handler) => handler
    .use(requireProfile({UserProfile.aprovador, UserProfile.administrador}))
    .use(requireUser());
