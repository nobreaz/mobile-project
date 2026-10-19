# Imagem de produção da API. Rode a partir da RAIZ do monorepo:
#   docker build -f server/Dockerfile -t frota-api .
#
# Por que não usar o Dockerfile do `dart_frog build`: ele não leva junto o
# pacote `packages/frota_core` (dependência por caminho num workspace).
# Aqui montamos um workspace só com server + frota_core (sem o app Flutter,
# que exigiria o SDK do Flutter) e compilamos o entrypoint gerado pelo
# Dart Frog com o package_config desse workspace.

FROM dart:stable AS build
WORKDIR /repo

COPY packages/frota_core packages/frota_core
COPY server server

RUN printf 'name: frota_workspace\npublish_to: none\nenvironment:\n  sdk: ^3.13.0\nworkspace:\n  - server\n  - packages/frota_core\n' > pubspec.yaml \
 && dart pub get

WORKDIR /repo/server
RUN dart pub global activate dart_frog_cli \
 && dart pub global run dart_frog_cli:dart_frog build \
 && dart compile exe build/bin/server.dart \
      --packages=/repo/.dart_tool/package_config.json \
      -o /repo/frota-api

# Imagem mínima: só o executável nativo e as libs de sistema necessárias.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /repo/frota-api /app/frota-api

EXPOSE 8080
CMD ["/app/frota-api"]
