import 'package:dart_frog/dart_frog.dart';
import 'package:frota_server/src/middleware.dart';

/// Veículos: qualquer usuário logado consulta (o Padrão vê o carro alocado
/// a ele; o Aprovador, a frota). Só o Administrador altera (conferido na rota).
Handler middleware(Handler handler) => handler.use(requireUser());
