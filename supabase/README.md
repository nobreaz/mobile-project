# Banco de dados (Supabase)

O Supabase fornece o **PostgreSQL** e o **login** (Supabase Auth). O app nunca acessa as tabelas diretamente: tudo passa pela API (`server/`), que confere login, perfil e regras de negócio.

```
App ──login──► Supabase Auth ──token──► App ──token──► API ──SQL──► PostgreSQL
```

## Estrutura
- `migrations/`: o esquema do banco, em arquivos SQL numerados por data. **Nunca edite uma migration já aplicada**; crie uma nova.

## Configuração inicial (uma vez)

### 1. Criar o projeto
1. Em https://supabase.com/dashboard, crie um projeto. Região sugerida: **South America (São Paulo)**.
2. Guarde a **senha do banco** que você definir (vai no `DATABASE_URL`).

### 2. Criar as tabelas
**Sem a CLI:** abra **SQL Editor**, cole o conteúdo de `migrations/20261019120000_esquema_inicial.sql` e clique em **Run**.

**Com a CLI** (requer Node.js): `npx supabase link --project-ref SEU_PROJETO` e depois `npx supabase db push`.

### 3. Ajustar o login
Em **Authentication → Sign In / Providers**:
- Desligue **Allow new users to sign up**. Só o Aprovador cadastra usuários, pela API.
- Em **Email**, defina o tamanho mínimo de senha **6**. A regra completa (número e caractere especial, RNF 6.2) é validada pelo app e pela API.

### 4. Preencher o `server/.env`
Copie `server/.env.example` para `server/.env` e preencha:

| Variável | Onde achar |
|---|---|
| `DATABASE_URL` | Botão **Connect** (topo do painel) → **Session pooler**. Troque `[YOUR-PASSWORD]` pela senha do banco |
| `SUPABASE_URL` | **Project Settings → Data API** (`https://xxxx.supabase.co`) |
| `SUPABASE_PUBLISHABLE_KEY` | **Project Settings → API Keys** (`sb_publishable_...`) |
| `SUPABASE_SECRET_KEY` | **Project Settings → API Keys** → crie uma secret key (`sb_secret_...`). **Nunca** coloque esta chave no app |

Use o **Session pooler** e não a conexão direta: a conexão direta só funciona em IPv6, e muitas redes e hospedagens não suportam.

### 5. Criar o primeiro Aprovador
Como só um Aprovador pode cadastrar usuários, o primeiro é criado à mão:
1. **Authentication → Users → Add user → Create new user**: e-mail e senha, marcando **Auto Confirm User**.
2. No **SQL Editor**, rode trocando os dados:
```sql
insert into usuarios (auth_id, nome, email, cargo, setor, perfil)
select id, 'Seu Nome', email, 'Seu Cargo', 'Administrativo', 'aprovador'
from auth.users
where email = 'seu.email@empresa.com';
```
Depois disso, os demais usuários são cadastrados pelo app ou pela API (`POST /usuarios`).

## Decisões do esquema
- **Login separado do cadastro.** `auth.users` (Supabase) guarda e-mail e senha; `usuarios` guarda perfil, cargo, CNH etc., ligados por `auth_id`.
- **Nada é apagado.** Usuários e veículos são desativados, para preservar o histórico de solicitações.
- **Regras garantidas pelo banco**, mesmo com acessos simultâneos (RNF 6.5):
  - RN 4.3: um veículo não tem dois agendamentos aprovados/em uso sobrepostos (`veiculo_sem_conflito`).
  - RN 4.4: um usuário não tem dois agendamentos ativos sobrepostos (`usuario_sem_conflito`).
  - RN 4.7: recusa exige justificativa. RN 4.8: km de retorno ≥ km de saída.
- **RLS ligado sem políticas.** A API REST automática do Supabase não expõe nenhuma tabela; o único caminho até os dados é a nossa API.
