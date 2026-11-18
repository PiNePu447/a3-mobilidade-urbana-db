-- =============================================================================
-- 06_seed.sql – Dados de teste realistas (São Paulo) – fictícios, claramente fake
-- Fatores de emissão e fontes EXATAMENTE como em docs/normalizacao.md
-- Geometrias: SRID 4326 com axis-order=long-lat
-- =============================================================================

USE mobilidade_urbana;
SET time_zone = '+00:00';
SET NAMES utf8mb4;

-- Limpeza idempotente (mantém estrutura)
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE sugestao_modal;
TRUNCATE TABLE trecho_segmento;
TRUNCATE TABLE trecho_viagem;
TRUNCATE TABLE viagem;
TRUNCATE TABLE leitura_trafego;
TRUNCATE TABLE sensor;
TRUNCATE TABLE linha_transporte;
TRUNCATE TABLE segmento_via;
TRUNCATE TABLE local;
TRUNCATE TABLE fator_emissao;
TRUNCATE TABLE fonte_referencia;
TRUNCATE TABLE usuario;
TRUNCATE TABLE modal_transporte;
SET FOREIGN_KEY_CHECKS = 1;

-- -----------------------------------------------------------------------------
-- Modais
-- -----------------------------------------------------------------------------
INSERT INTO modal_transporte (id_modal, codigo, nome, categoria, sustentavel, referencia_comparacao) VALUES
(1, 'A_PE',              'A pé',                    'ativo',      TRUE,  FALSE),
(2, 'BICICLETA',         'Bicicleta',               'ativo',      TRUE,  FALSE),
(3, 'BIKE_ELETRICA',     'Bicicleta/patinete elétrico', 'ativo',  TRUE,  FALSE),
(4, 'ONIBUS',            'Ônibus municipal',        'coletivo',   TRUE,  FALSE),
(5, 'METRO',             'Metrô',                   'coletivo',   TRUE,  FALSE),
(6, 'TREM',              'Trem metropolitano (CPTM)','coletivo',   TRUE,  FALSE),
(7, 'CARRO_GASOLINA',    'Carro a gasolina',        'individual', FALSE, TRUE),
(8, 'MOTOCICLETA',       'Motocicleta',             'individual', FALSE, FALSE);

-- -----------------------------------------------------------------------------
-- Fontes (normalizacao.md)
-- -----------------------------------------------------------------------------
INSERT INTO fonte_referencia (id_fonte, orgao, titulo, ano_publicacao, url) VALUES
(1, 'Metrô-SP',
 'Inventário de Emissões de GEE 2025 (RT-9.EA.25.00/0IV-001)',
 2025,
 'https://transparencia.metrosp.com.br/sites/default/files/2025_RT9EA25000IV001_IVEmissoesGEEass.pdf'),
(2, 'Metrô-SP',
 'Funcionamento do Metrô evita a emissão de 842 mil toneladas de CO2 em apenas um ano (RMSP: ônibus 80g, carro 120g)',
 2020,
 'https://www.metro.sp.gov.br/2020/09/22/funcionamento-do-metro-evita-a-emissao-de-842-mil-toneladas-de-co2-em-apenas-um-ano/'),
(3, 'UK DESNZ',
 'Greenhouse gas reporting: conversion factors 2024 – Passenger vehicles – Motorbike Average',
 2024,
 'https://www.gov.uk/government/publications/greenhouse-gas-reporting-conversion-factors-2024'),
(4, 'MCTI/SIRENE',
 'Fator médio anual do SIN 2025 (Inventários Corporativos) – 0,0461 tCO2/MWh',
 2025,
 'https://www.gov.br/mcti/pt-br/acompanhe-o-mcti/sirene/dados-e-ferramentas/fatores-de-emissao');

-- -----------------------------------------------------------------------------
-- Fatores de emissão (exatos do dicionário)
-- -----------------------------------------------------------------------------
INSERT INTO fator_emissao (id_modal, id_fonte, g_co2_pkm, estimativa, vigencia_inicio, vigencia_fim) VALUES
-- A pé / bicicleta: 0 (convenção)
(1, NULL, 0.000, TRUE,  '2015-01-01', NULL),
(2, NULL, 0.000, TRUE,  '2015-01-01', NULL),
-- Bike elétrica ≈ 0,7 (estimativa: 0,015 kWh/km × 46,1 g/kWh SIN 2025)
(3, 4,    0.700, TRUE,  '2025-01-01', NULL),
-- Ônibus RMSP 80 g (oficial Metrô-SP 2020)
(4, 2,   80.000, FALSE, '2020-01-01', NULL),
-- Metrô: histórico 6 g (2020) depois 3 g (2025 inventário)
(5, 2,    6.000, FALSE, '2020-01-01', '2025-01-01'),
(5, 1,    3.000, FALSE, '2025-01-01', NULL),
-- Trem CPTM 6 g (estimativa)
(6, 2,    6.000, TRUE,  '2020-01-01', NULL),
-- Carro gasolina 120 g (oficial)
(7, 2,  120.000, FALSE, '2020-01-01', NULL),
-- Motocicleta 113,67 g (DESNZ 2024)
(8, 3,  113.670, FALSE, '2024-01-01', NULL);

-- -----------------------------------------------------------------------------
-- Locais (coordenadas reais aproximadas de SP)
-- -----------------------------------------------------------------------------
INSERT INTO local (id_local, nome, tipo, geom) VALUES
(1,  'Estação Sé',                    'estacao',
 ST_GeomFromText('POINT(-46.6336 -23.5505)', 4326, 'axis-order=long-lat')),
(2,  'Estação Paulista (Linha 4)',     'estacao',
 ST_GeomFromText('POINT(-46.6622 -23.5553)', 4326, 'axis-order=long-lat')),
(3,  'Estação Consolação',            'estacao',
 ST_GeomFromText('POINT(-46.6608 -23.5577)', 4326, 'axis-order=long-lat')),
(4,  'Estação Pinheiros',             'estacao',
 ST_GeomFromText('POINT(-46.7020 -23.5674)', 4326, 'axis-order=long-lat')),
(5,  'Estação Luz',                   'estacao',
 ST_GeomFromText('POINT(-46.6356 -23.5362)', 4326, 'axis-order=long-lat')),
(6,  'Terminal Parque Dom Pedro II',  'ponto_onibus',
 ST_GeomFromText('POINT(-46.6270 -23.5460)', 4326, 'axis-order=long-lat')),
(7,  'Ponto Av. Paulista x Augusta',  'ponto_onibus',
 ST_GeomFromText('POINT(-46.6605 -23.5614)', 4326, 'axis-order=long-lat')),
(8,  'Ponto Av. Rebouças x Faria Lima','ponto_onibus',
 ST_GeomFromText('POINT(-46.6880 -23.5670)', 4326, 'axis-order=long-lat')),
(9,  'Rua Fictícia das Acácias, 100 – Vila Madalena (FAKE)', 'endereco',
 ST_GeomFromText('POINT(-46.6910 -23.5465)', 4326, 'axis-order=long-lat')),
(10, 'Av. Inventada do Sol, 250 – Moema (FAKE)', 'endereco',
 ST_GeomFromText('POINT(-46.6620 -23.6010)', 4326, 'axis-order=long-lat')),
(11, 'Estação República',             'estacao',
 ST_GeomFromText('POINT(-46.6428 -23.5439)', 4326, 'axis-order=long-lat')),
(12, 'Estação Ana Rosa',              'estacao',
 ST_GeomFromText('POINT(-46.6389 -23.5814)', 4326, 'axis-order=long-lat'));

-- -----------------------------------------------------------------------------
-- Segmentos de via
-- -----------------------------------------------------------------------------
INSERT INTO segmento_via (id_segmento, nome_via, geom, velocidade_max_kmh, possui_ciclovia, faixa_onibus) VALUES
(1, 'Av. Paulista (Consolação → Brigadeiro)',
 ST_GeomFromText('LINESTRING(-46.6608 -23.5577, -46.6550 -23.5610, -46.6500 -23.5635)', 4326, 'axis-order=long-lat'),
 50, TRUE, TRUE),
(2, 'Av. Rebouças (Paulista → Pinheiros)',
 ST_GeomFromText('LINESTRING(-46.6622 -23.5553, -46.6800 -23.5620, -46.7020 -23.5674)', 4326, 'axis-order=long-lat'),
 60, TRUE, TRUE),
(3, 'Av. 23 de Maio (centro → sul)',
 ST_GeomFromText('LINESTRING(-46.6336 -23.5505, -46.6360 -23.5650, -46.6389 -23.5814)', 4326, 'axis-order=long-lat'),
 70, FALSE, TRUE),
(4, 'Rua da Consolação',
 ST_GeomFromText('LINESTRING(-46.6428 -23.5439, -46.6520 -23.5500, -46.6608 -23.5577)', 4326, 'axis-order=long-lat'),
 40, TRUE, FALSE),
(5, 'Marginal Pinheiros (trecho oeste)',
 ST_GeomFromText('LINESTRING(-46.7020 -23.5674, -46.7100 -23.5800, -46.7150 -23.5950)', 4326, 'axis-order=long-lat'),
 90, FALSE, FALSE);

-- -----------------------------------------------------------------------------
-- Sensores
-- -----------------------------------------------------------------------------
INSERT INTO sensor (id_sensor, id_segmento, tipo, geom, instalado_em, status) VALUES
(1, 1, 'camera',
 ST_GeomFromText('POINT(-46.6550 -23.5610)', 4326, 'axis-order=long-lat'), '2023-03-15', 'ativo'),
(2, 2, 'laco',
 ST_GeomFromText('POINT(-46.6800 -23.5620)', 4326, 'axis-order=long-lat'), '2022-11-01', 'ativo'),
(3, 3, 'camera',
 ST_GeomFromText('POINT(-46.6360 -23.5650)', 4326, 'axis-order=long-lat'), '2021-06-20', 'ativo'),
(4, 4, 'gps_frota',
 ST_GeomFromText('POINT(-46.6520 -23.5500)', 4326, 'axis-order=long-lat'), '2024-01-10', 'ativo'),
(5, 5, 'laco',
 ST_GeomFromText('POINT(-46.7100 -23.5800)', 4326, 'axis-order=long-lat'), '2020-08-05', 'manutencao');

-- -----------------------------------------------------------------------------
-- Leituras de tráfego (UTC, milissegundos)
-- -----------------------------------------------------------------------------
INSERT INTO leitura_trafego (id_sensor, registrado_em, velocidade_media_kmh, volume_veiculos, nivel_congestionamento) VALUES
(1, '2026-11-18 11:00:00.000', 18.5, 420, 4),
(1, '2026-11-18 11:05:00.000', 16.2, 455, 5),
(1, '2026-11-18 12:00:00.000', 22.0, 380, 3),
(2, '2026-11-18 11:00:00.000', 25.0, 510, 3),
(2, '2026-11-18 11:05:00.000', 20.5, 540, 4),
(2, '2026-11-18 12:00:00.000', 35.0, 390, 2),
(3, '2026-11-18 11:00:00.000', 40.0, 600, 2),
(3, '2026-11-18 12:00:00.000', 28.0, 650, 3),
(4, '2026-11-18 11:00:00.000', 12.0, 180, 4),
(4, '2026-11-18 12:00:00.000', 15.5, 160, 3),
(5, '2026-11-10 08:00:00.000', 55.0, 800, 1);

-- -----------------------------------------------------------------------------
-- Linhas (inspiradas em SPTrans / Metrô / CPTM – nomes reais, traçados simplificados)
-- -----------------------------------------------------------------------------
INSERT INTO linha_transporte (id_linha, id_modal, codigo, nome, operadora, geom_trajeto) VALUES
(1, 5, 'L1-AZUL', 'Linha 1-Azul (Tucuruvi ↔ Jabaquara)', 'Metrô-SP',
 ST_GeomFromText('LINESTRING(-46.6030 -23.4800, -46.6336 -23.5505, -46.6389 -23.5814, -46.6450 -23.6450)', 4326, 'axis-order=long-lat')),
(2, 5, 'L2-VERDE', 'Linha 2-Verde (Vila Madalena ↔ Vila Prudente)', 'Metrô-SP',
 ST_GeomFromText('LINESTRING(-46.6910 -23.5465, -46.6608 -23.5577, -46.6389 -23.5814, -46.5800 -23.5900)', 4326, 'axis-order=long-lat')),
(3, 5, 'L4-AMARELA', 'Linha 4-Amarela (Luz ↔ Vila Sônia)', 'ViaQuatro',
 ST_GeomFromText('LINESTRING(-46.6356 -23.5362, -46.6428 -23.5439, -46.6622 -23.5553, -46.7020 -23.5674, -46.7350 -23.5900)', 4326, 'axis-order=long-lat')),
(4, 4, '875A-10', '875A-10 Aeroporto ↔ Metrô Barra Funda (FAKE-trajeto)', 'SPTrans',
 ST_GeomFromText('LINESTRING(-46.6560 -23.4350, -46.6605 -23.5614, -46.6622 -23.5553, -46.6670 -23.5250)', 4326, 'axis-order=long-lat')),
(5, 4, '702U-10', '702U-10 Term. Pq. D. Pedro II ↔ Butantã-USP', 'SPTrans',
 ST_GeomFromText('LINESTRING(-46.6270 -23.5460, -46.6605 -23.5614, -46.6880 -23.5670, -46.7210 -23.5610)', 4326, 'axis-order=long-lat')),
(6, 6, 'CPT-7', 'Linha 7-Rubi (Luz ↔ Francisco Morato)', 'CPTM',
 ST_GeomFromText('LINESTRING(-46.6356 -23.5362, -46.6500 -23.5200, -46.7000 -23.4800, -46.7800 -23.3100)', 4326, 'axis-order=long-lat'));

-- -----------------------------------------------------------------------------
-- Usuários fictícios (CPF = SHA-256 de strings claramente fake)
-- -----------------------------------------------------------------------------
INSERT INTO usuario (id_usuario, nome, email, cpf_hash, data_nascimento, id_modal_preferido, criado_em, ativo) VALUES
(1, 'Ana Fictícia Silva',     'ana.ficticia@exemplo.sp.br',
 SHA2('CPF-FAKE-11111111111', 256), '1992-04-12', 5, '2025-08-01 10:00:00', TRUE),
(2, 'Bruno Teste Oliveira',   'bruno.teste@exemplo.sp.br',
 SHA2('CPF-FAKE-22222222222', 256), '1988-11-03', 2, '2025-09-15 14:30:00', TRUE),
(3, 'Carla Demo Souza',       'carla.demo@exemplo.sp.br',
 SHA2('CPF-FAKE-33333333333', 256), '1995-07-22', 4, '2025-10-01 09:15:00', TRUE),
(4, 'Diego Mock Pereira',     'diego.mock@exemplo.sp.br',
 SHA2('CPF-FAKE-44444444444', 256), '1990-01-30', 7, '2025-10-20 16:45:00', TRUE),
(5, 'Elena Sample Costa',     'elena.sample@exemplo.sp.br',
 SHA2('CPF-FAKE-55555555555', 256), '1998-12-08', 5, '2026-01-05 11:20:00', TRUE);

-- -----------------------------------------------------------------------------
-- Viagens + trechos
-- -----------------------------------------------------------------------------
INSERT INTO viagem (id_viagem, id_usuario, id_local_origem, id_local_destino, inicio, fim, status) VALUES
(1, 1, 9, 1,  '2026-11-17 12:00:00', '2026-11-17 12:55:00', 'concluida'),
(2, 2, 10, 2, '2026-11-17 13:10:00', '2026-11-17 13:50:00', 'concluida'),
(3, 3, 6, 8,  '2026-11-18 11:00:00', '2026-11-18 11:45:00', 'concluida'),
(4, 4, 9, 10, '2026-11-18 12:00:00', '2026-11-18 12:40:00', 'concluida'),
(5, 5, 5, 4,  '2026-11-18 07:30:00', '2026-11-18 08:05:00', 'concluida'),
(6, 1, 1, 12, '2026-11-18 18:00:00', NULL,                   'em_curso'),
(7, 2, 7, 4,  '2026-11-19 08:00:00', NULL,                   'planejada');

-- Viagem 1: Ana – bicicleta + metrô (L2)
INSERT INTO trecho_viagem (id_trecho, id_viagem, ordem, id_modal, id_linha, inicio, fim, distancia_km, geom_percurso) VALUES
(1, 1, 1, 2, NULL, '2026-11-17 12:00:00', '2026-11-17 12:20:00', 3.200,
 ST_GeomFromText('LINESTRING(-46.6910 -23.5465, -46.6800 -23.5500, -46.6608 -23.5577)', 4326, 'axis-order=long-lat')),
(2, 1, 2, 5, 2,    '2026-11-17 12:25:00', '2026-11-17 12:55:00', 6.500, NULL);

-- Viagem 2: Bruno – só bicicleta
INSERT INTO trecho_viagem (id_trecho, id_viagem, ordem, id_modal, id_linha, inicio, fim, distancia_km) VALUES
(3, 2, 1, 2, NULL, '2026-11-17 13:10:00', '2026-11-17 13:50:00', 7.800);

-- Viagem 3: Carla – ônibus 702U-10
INSERT INTO trecho_viagem (id_trecho, id_viagem, ordem, id_modal, id_linha, inicio, fim, distancia_km) VALUES
(4, 3, 1, 4, 5, '2026-11-18 11:00:00', '2026-11-18 11:45:00', 9.100);

-- Viagem 4: Diego – carro (referência)
INSERT INTO trecho_viagem (id_trecho, id_viagem, ordem, id_modal, id_linha, inicio, fim, distancia_km) VALUES
(5, 4, 1, 7, NULL, '2026-11-18 12:00:00', '2026-11-18 12:40:00', 11.200);

-- Viagem 5: Elena – metrô L4-Amarela
INSERT INTO trecho_viagem (id_trecho, id_viagem, ordem, id_modal, id_linha, inicio, fim, distancia_km) VALUES
(6, 5, 1, 5, 3, '2026-11-18 07:30:00', '2026-11-18 08:05:00', 8.400);

-- Viagem 6: Ana em curso – a pé + metrô L1
INSERT INTO trecho_viagem (id_trecho, id_viagem, ordem, id_modal, id_linha, inicio, fim, distancia_km) VALUES
(7, 6, 1, 1, NULL, '2026-11-18 18:00:00', '2026-11-18 18:10:00', 0.800),
(8, 6, 2, 5, 1,    '2026-11-18 18:15:00', '2026-11-18 18:40:00', 5.200);

-- Trechos × segmentos
INSERT INTO trecho_segmento (id_trecho, id_segmento, ordem) VALUES
(1, 2, 1),
(1, 1, 2),
(3, 1, 1),
(4, 1, 1),
(4, 2, 2),
(5, 3, 1),
(5, 5, 2),
(6, 2, 1),
(8, 3, 1);

-- Sugestões
INSERT INTO sugestao_modal (
  id_sugestao, id_viagem, id_modal_sugerido, id_linha,
  distancia_estimada_km, duracao_estimada_min, motivo, gerada_em, aceita
) VALUES
(1, 4, 5, 3, 10.500, 35, 'menor_co2',         '2026-11-18 11:55:00', FALSE),
(2, 4, 2, NULL, 9.800, 40, 'congestionamento', '2026-11-18 11:56:00', FALSE),
(3, 7, 5, 3,  6.200, 28, 'menor_tempo',      '2026-11-18 20:00:00', NULL),
(4, 3, 5, 2,  8.000, 30, 'menor_co2',         '2026-11-18 10:50:00', TRUE),
(5, 2, 4, 4,  8.500, 45, 'congestionamento',  '2026-11-17 13:00:00', TRUE);

SELECT 'Seed concluído' AS status;
SELECT 'usuario' AS tabela, COUNT(*) AS n FROM usuario
UNION ALL SELECT 'modal_transporte', COUNT(*) FROM modal_transporte
UNION ALL SELECT 'fonte_referencia', COUNT(*) FROM fonte_referencia
UNION ALL SELECT 'fator_emissao', COUNT(*) FROM fator_emissao
UNION ALL SELECT 'local', COUNT(*) FROM local
UNION ALL SELECT 'segmento_via', COUNT(*) FROM segmento_via
UNION ALL SELECT 'sensor', COUNT(*) FROM sensor
UNION ALL SELECT 'leitura_trafego', COUNT(*) FROM leitura_trafego
UNION ALL SELECT 'linha_transporte', COUNT(*) FROM linha_transporte
UNION ALL SELECT 'viagem', COUNT(*) FROM viagem
UNION ALL SELECT 'trecho_viagem', COUNT(*) FROM trecho_viagem
UNION ALL SELECT 'trecho_segmento', COUNT(*) FROM trecho_segmento
UNION ALL SELECT 'sugestao_modal', COUNT(*) FROM sugestao_modal;
