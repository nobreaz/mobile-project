# Gestor de Frotas

App mobile para agendamento e controle da frota de veículos da empresa: o colaborador solicita, o Aprovador aloca o veículo e o uso é registrado por check-out e check-in.

Monorepo com o app, a API e o domínio compartilhado entre os dois.

```
.
├─ app/                   App Flutter
├─ server/                API REST (Dart Frog)
├─ packages/frota_core/   Domínio em Dart puro: modelos, enums e regras
├─ supabase/              Esquema do banco (migrations) e guia de configuração
└─ pubspec.yaml           Workspace (um único pubspec.lock para tudo)
```

O banco (PostgreSQL) e o login ficam no **Supabase**. Para configurar do zero, veja [supabase/README.md](supabase/README.md).

## API
| Rota | Quem | O que faz |
|---|---|---|
| `GET /health` | público | API no ar |
| `GET /me` | logado | dados do usuário logado |
| `PATCH /me` | logado | altera o próprio telefone |
| `GET /usuarios` | Administrador | lista os usuários |
| `POST /usuarios` | Administrador | cadastra colaborador e cria o login (senha inicial) |
| `GET /usuarios/{id}` | Administrador | detalhe |
| `PATCH /usuarios/{id}` | Administrador | altera dados e perfil, ativa ou desativa (nunca apaga) |
| `GET /solicitacoes` | logado | Padrão vê só as próprias; Aprovador e Administrador veem todas. Filtros: `status=aprovada,emUso`, `aprovadorId=7` |

Perfis e permissões: veja [supabase/README.md](supabase/README.md#perfis-um-por-pessoa).

Rotas protegidas exigem o cabeçalho `Authorization: Bearer <token do Supabase>`. Erros sempre vêm como `{"erro": "...", "campos": {...}}`.

## Por que um pacote compartilhado
As regras de negócio (sobreposição de horários, prazo de devolução, status que ocupam a agenda, validade de documentos) estão escritas **uma vez** em `frota_core`. O app usa essas regras para responder na hora, e a API usa as mesmas para validar de verdade antes de gravar.

Regra do pacote: **nada de Flutter dentro do `frota_core`**. Cores e ícones ficam no app, como extensões (`app/lib/core/models/*_model.dart`).

## Pré-requisitos
- Flutter (stable) com Dart 3.13 ou superior
- Dart Frog CLI: `dart pub global activate dart_frog_cli`

## Configuração local (uma vez)
1. **API:** copie `server/.env.example` para `server/.env` e preencha (guia em [supabase/README.md](supabase/README.md)). Para conferir: `dart run tool/verificar_conexao.dart` dentro de `server/`.
2. **App:** copie `app/env/example.json` para `app/env/dev.json`. A URL e a chave *publishable* são as mesmas do `server/.env`. Em `API_URL`, use:
   - `http://localhost:8080` no navegador ou no desktop;
   - `http://10.0.2.2:8080` no emulador Android;
   - `http://IP-DO-PC:8080` num celular na mesma rede Wi-Fi.

Os dois arquivos ficam fora do Git. A chave **secreta** do Supabase existe só no `server/.env`, nunca no app.

## Comandos
Instalar as dependências de tudo (rodar na raiz):
```sh
flutter pub get
```

| O quê | Onde | Comando |
|---|---|---|
| Rodar o app (ou F5 no VS Code) | `app/` | `flutter run --dart-define-from-file=env/dev.json` |
| Rodar a API em desenvolvimento (recarrega sozinha; requer `server/.env`) | `server/` | `dart_frog dev` → http://localhost:8080/health |
| Testes do domínio | `packages/frota_core/` | `dart test` |
| Testes da API | `server/` | `dart test` |
| Testes do app | `app/` | `flutter test` |

Se o comando `dart_frog` não for encontrado, use `dart pub global run dart_frog_cli:dart_frog dev` ou adicione `%LOCALAPPDATA%\Pub\Cache\bin` ao PATH.

## Deploy da API
A imagem Docker é gerada **a partir da raiz** (precisa de `server/` e de `packages/`):
```sh
docker build -f server/Dockerfile -t frota-api .
docker run -p 8080:8080 --env-file server/.env frota-api
```
O resultado é um executável nativo numa imagem mínima, que roda em qualquer servidor Linux.

## Documentação
- Requisitos originais: documento da disciplina (`Gestor-de-frotas_Documentacao_FINAL.docx`)
- Grupo: Felipe Ribeiro, Lualinda Andrade e João Nobre
