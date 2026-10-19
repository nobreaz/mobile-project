-- Quem decidiu cada solicitação e quando (aprovação ou recusa).
-- Permite ao Aprovador ver as solicitações aprovadas/recusadas por ele
-- e pelos colegas ("Aprovada por: Nome").

alter table solicitacoes
  add column aprovador_id bigint references usuarios (id),
  add column decidido_em  timestamptz;

-- Toda solicitação decidida (aprovada, em uso, finalizada ou recusada)
-- registra quem decidiu e quando; pendente e cancelada não têm decisão.
-- Se uma aprovada volta para pendente (datas alteradas, veículo
-- indisponível), a decisão anterior é apagada junto.
alter table solicitacoes add constraint decisao_registrada check (
  (status in ('aprovada', 'emUso', 'finalizada', 'recusada'))
  = (aprovador_id is not null and decidido_em is not null)
);

create index solicitacoes_aprovador_idx on solicitacoes (aprovador_id);
