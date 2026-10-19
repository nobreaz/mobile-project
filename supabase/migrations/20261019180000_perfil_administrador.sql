-- Novo perfil: Administrador (cadastra veículos e usuários; não solicita
-- nem aprova). Separação de funções decidida pelo grupo em 2026-10-19.
--
-- ATENÇÃO: no PostgreSQL, um valor novo de enum só pode ser USADO depois
-- que esta instrução for confirmada. Por isso a conversão do usuário
-- inicial para administrador NÃO está aqui; ela é feita à parte (ver
-- supabase/README.md, passo 5).
alter type perfil_usuario add value if not exists 'administrador';
