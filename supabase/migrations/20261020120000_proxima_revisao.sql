-- Quilometragem da próxima revisão do veículo (opcional).
-- Usada nos alertas da tela de Relatórios: "revisão em X km" quando
-- faltam até 1.000 km (frota_core: serviceWarningKm) e "revisão atrasada"
-- quando o odômetro passa dela.
alter table veiculos
  add column proxima_revisao_km int check (proxima_revisao_km >= 0);
