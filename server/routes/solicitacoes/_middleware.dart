import 'package:dart_frog/dart_frog.dart';
import 'package:frota_server/src/middleware.dart';

/// Solicitações: qualquer usuário logado. O que cada perfil vê é decidido
/// na própria rota (Padrão só as suas; Aprovador e Administrador, todas).
Handler middleware(Handler handler) => handler.use(requireUser());
