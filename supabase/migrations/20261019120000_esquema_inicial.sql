-- Esquema inicial do Gestor de Frotas.
-- Entidades da seção 5 do documento de requisitos.
--
-- Convenções:
-- * Tabelas e colunas em português (snake_case), como no documento.
-- * Os valores dos enums são IGUAIS aos nomes dos enums do frota_core
--   (ex.: 'emUso'), para a API converter sem tabela de tradução.
-- * O acesso aos dados é SÓ pela API (Dart Frog), que conecta como dono
--   do banco. Por isso o RLS fica ligado SEM políticas: a API REST
--   automática do Supabase (chave publishable) não lê nem grava nada.

-- Necessária para as restrições de exclusão com "=" em colunas bigint.
create extension if not exists btree_gist;

-- ---------------------------------------------------------------------
-- Tipos
-- ---------------------------------------------------------------------
create type perfil_usuario as enum ('padrao', 'aprovador');
create type status_veiculo as enum ('disponivel', 'emUso', 'emManutencao', 'inativo');
create type tipo_veiculo as enum ('passeio', 'utilitario', 'van');
create type status_solicitacao as enum (
  'pendente', 'aprovada', 'emUso', 'finalizada', 'recusada', 'cancelada'
);
create type periodo_retorno as enum ('manha', 'tarde');
create type tipo_notificacao as enum ('sent', 'approved', 'rejected', 'canceled', 'reverted');

-- Mantém atualizado_em em dia em qualquer UPDATE.
create function definir_atualizado_em() returns trigger
language plpgsql as $$
begin
  new.atualizado_em := now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------
-- 5.2 Usuário
-- Login e senha ficam no Supabase Auth (auth.users). Esta tabela guarda
-- o perfil e liga ao login por auth_id.
-- ---------------------------------------------------------------------
create table usuarios (
  id             bigint generated always as identity primary key,
  -- "restrict": o login não pode ser apagado enquanto o usuário existir.
  -- Usuário nunca é apagado, só desativado (ativo = false).
  auth_id        uuid not null unique references auth.users (id) on delete restrict,
  nome           text not null check (length(trim(nome)) > 0),
  email          text not null unique check (email = lower(email)),
  telefone       text,
  cargo          text not null,
  setor          text not null,
  cnh_numero     text,
  cnh_categoria  text,
  cnh_validade   date,
  perfil         perfil_usuario not null default 'padrao',
  ativo          boolean not null default true,
  criado_em      timestamptz not null default now(),
  atualizado_em  timestamptz not null default now()
);

create trigger usuarios_atualizado_em before update on usuarios
  for each row execute function definir_atualizado_em();

-- ---------------------------------------------------------------------
-- 5.1 Veículo
-- ---------------------------------------------------------------------
create table veiculos (
  id                        bigint generated always as identity primary key,
  placa                     text not null unique,
  chassi                    text not null unique,
  modelo                    text not null,
  cor                       text not null,
  ano                       int not null check (ano between 1950 and 2100),
  lugares                   int not null check (lugares > 0),
  quilometragem             int not null default 0 check (quilometragem >= 0),
  tipo                      tipo_veiculo not null default 'passeio',
  status                    status_veiculo not null default 'disponivel',
  vencimento_licenciamento  date not null,  -- 5.1.5 (licenciamento/IPVA)
  vencimento_seguro         date not null,  -- 5.1.5
  criado_em                 timestamptz not null default now(),
  atualizado_em             timestamptz not null default now()
);

create trigger veiculos_atualizado_em before update on veiculos
  for each row execute function definir_atualizado_em();

-- ---------------------------------------------------------------------
-- 5.3 Solicitação de agendamento
-- ---------------------------------------------------------------------
create table solicitacoes (
  id                   bigint generated always as identity primary key,
  solicitante_id       bigint not null references usuarios (id),
  motivo               text not null,
  destino              text not null,
  passageiros          int not null check (passageiros >= 1),
  saida                timestamptz not null,
  data_retorno         date not null,
  periodo_retorno      periodo_retorno not null,
  -- data_retorno + 12h (manhã) ou 18h (tarde), calculado pela API com a
  -- mesma regra do app (RequestModel.returnDeadline no frota_core).
  prazo_retorno        timestamptz not null,
  status               status_solicitacao not null default 'pendente',
  veiculo_id           bigint references veiculos (id),
  justificativa_recusa text,
  km_saida             int check (km_saida >= 0),
  km_retorno           int check (km_retorno >= 0),
  check_out_em         timestamptz,
  check_in_em          timestamptz,
  obs_check_out        text,
  obs_check_in         text,
  criado_em            timestamptz not null default now(),
  atualizado_em        timestamptz not null default now(),

  constraint prazo_depois_da_saida check (prazo_retorno > saida),

  -- RN 4.7: negar exige justificativa.
  constraint recusa_com_justificativa check (
    status <> 'recusada'
    or length(trim(coalesce(justificativa_recusa, ''))) > 0
  ),

  -- Aprovada, em uso ou finalizada sempre tem veículo alocado (4.1.3).
  constraint aprovada_tem_veiculo check (
    status not in ('aprovada', 'emUso', 'finalizada') or veiculo_id is not null
  ),

  -- RN 4.8: km de retorno nunca menor que a de saída.
  constraint km_retorno_valida check (
    km_retorno is null or km_saida is null or km_retorno >= km_saida
  ),

  -- RN 4.3: um veículo não pode ter dois agendamentos sobrepostos.
  -- Vale para aprovadas e em uso (pendente ainda não tem veículo, ver a
  -- decisão sobre a RN 4.5). O banco recusa mesmo se dois aprovadores
  -- aprovarem ao mesmo tempo (RNF 6.5). '[)': encostar não conflita.
  constraint veiculo_sem_conflito exclude using gist (
    veiculo_id with =,
    tstzrange(saida, prazo_retorno, '[)') with &&
  ) where (status in ('aprovada', 'emUso')),

  -- RN 4.4: o usuário não pode ter dois agendamentos ativos sobrepostos.
  constraint usuario_sem_conflito exclude using gist (
    solicitante_id with =,
    tstzrange(saida, prazo_retorno, '[)') with &&
  ) where (status in ('pendente', 'aprovada', 'emUso'))
);

create index solicitacoes_solicitante_idx on solicitacoes (solicitante_id);
create index solicitacoes_status_idx on solicitacoes (status);

create trigger solicitacoes_atualizado_em before update on solicitacoes
  for each row execute function definir_atualizado_em();

-- ---------------------------------------------------------------------
-- Notificações (RF 3.3.7)
-- ---------------------------------------------------------------------
create table notificacoes (
  id              bigint generated always as identity primary key,
  usuario_id      bigint not null references usuarios (id),
  solicitacao_id  bigint not null references solicitacoes (id),
  tipo            tipo_notificacao not null,
  destino         text not null,
  mensagem        text not null,
  lida            boolean not null default false,
  criada_em       timestamptz not null default now()
);

create index notificacoes_usuario_idx on notificacoes (usuario_id, lida);

-- ---------------------------------------------------------------------
-- Segurança: só a API acessa as tabelas (ver cabeçalho).
-- ---------------------------------------------------------------------
alter table usuarios     enable row level security;
alter table veiculos     enable row level security;
alter table solicitacoes enable row level security;
alter table notificacoes enable row level security;
