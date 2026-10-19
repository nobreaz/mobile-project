# Gestor de Frotas

App mobile para agendamento e controle da frota de veículos da empresa: o colaborador solicita, o Aprovador aloca o veículo e o uso é registrado por check-out e check-in.

Monorepo com o app, a API e o domínio compartilhado entre os dois.

```
.
├─ app/                   App Flutter
├─ server/                API REST (Dart Frog)
├─ packages/frota_core/   Domínio em Dart puro: modelos, enums e regras
└─ pubspec.yaml           Workspace (um único pubspec.lock para tudo)
```

O banco (PostgreSQL) e o login ficam no **Supabase**.

## Por que um pacote compartilhado
As regras de negócio (sobreposição de horários, prazo de devolução, status que ocupam a agenda, validade de documentos) estão escritas **uma vez** em `frota_core`. O app usa essas regras para responder na hora, e a API usa as mesmas para validar de verdade antes de gravar.

Regra do pacote: **nada de Flutter dentro do `frota_core`**. Cores e ícones ficam no app, como extensões (`app/lib/core/models/*_model.dart`).

## Pré-requisitos
- Flutter (stable) com Dart 3.13 ou superior
- Dart Frog CLI: `dart pub global activate dart_frog_cli`

## Comandos
Instalar as dependências de tudo (rodar na raiz):
```sh
flutter pub get
```

| O quê | Onde | Comando |
|---|---|---|
| Rodar o app | `app/` | `flutter run` |
| Rodar a API em desenvolvimento (recarrega sozinha) | `server/` | `dart_frog dev` → http://localhost:8080/health |
| Testes do domínio | `packages/frota_core/` | `dart test` |
| Testes da API | `server/` | `dart test` |
| Testes do app | `app/` | `flutter test` |

Se o comando `dart_frog` não for encontrado, use `dart pub global run dart_frog_cli:dart_frog dev` ou adicione `%LOCALAPPDATA%\Pub\Cache\bin` ao PATH.

## Deploy da API
A imagem Docker é gerada **a partir da raiz** (precisa de `server/` e de `packages/`):
```sh
docker build -f server/Dockerfile -t frota-api .
docker run -p 8080:8080 frota-api
```
O resultado é um executável nativo numa imagem mínima, que roda em qualquer servidor Linux.

## Documentação
- Requisitos originais: documento da disciplina (`Gestor-de-frotas_Documentacao_FINAL.docx`)
- Grupo: Felipe Ribeiro, Lualinda Andrade e João Nobre
