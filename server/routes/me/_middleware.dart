import 'package:dart_frog/dart_frog.dart';
import 'package:frota_server/src/middleware.dart';

Handler middleware(Handler handler) => handler.use(requireUser());
