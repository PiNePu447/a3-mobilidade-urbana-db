-- =============================================================================
-- script_completo.sql – GERADO AUTOMATICAMENTE
-- NÃO edite à mão. Fonte da verdade: sql/01_*.sql … sql/08_*.sql
-- Regenerar: ./scripts/build_script_completo.sh
-- Executa do zero: DROP/CREATE DATABASE → schema → views → triggers →
-- procedures/events → roles → seed → relatórios → testes
-- =============================================================================

SET NAMES utf8mb4;
SET time_zone = '+00:00';

DROP DATABASE IF EXISTS mobilidade_urbana;


-- ##########################################################################
-- INÍCIO: 01_schema.sql
-- ##########################################################################

-- =============================================================================
-- 01_schema.sql – Banco, tabelas, PK/FK/UNIQUE/CHECK e índices (idempotente)
-- Projeto A3 – Mobilidade Urbana Sustentável – MySQL 8.0 / InnoDB / utf8mb4
-- =============================================================================

SET NAMES utf8mb4;
SET time_zone = '+00:00';

CREATE DATABASE IF NOT EXISTS mobilidade_urbana
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE mobilidade_urbana;

-- Ordem de drop respeitando FKs (reexecução limpa)
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS sugestao_modal;
DROP TABLE IF EXISTS trecho_segmento;
DROP TABLE IF EXISTS trecho_viagem;
DROP TABLE IF EXISTS viagem;
DROP TABLE IF EXISTS leitura_trafego;
DROP TABLE IF EXISTS sensor;
DROP TABLE IF EXISTS linha_transporte;
DROP TABLE IF EXISTS segmento_via;
DROP TABLE IF EXISTS local;
DROP TABLE IF EXISTS fator_emissao;
DROP TABLE IF EXISTS fonte_referencia;
DROP TABLE IF EXISTS usuario;
DROP TABLE IF EXISTS modal_transporte;
SET FOREIGN_KEY_CHECKS = 1;

-- -----------------------------------------------------------------------------
-- modal_transporte
-- -----------------------------------------------------------------------------
CREATE TABLE modal_transporte (
  id_modal              SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
  codigo                VARCHAR(20)  NOT NULL,
  nome                  VARCHAR(60)  NOT NULL,
  categoria             ENUM('ativo','coletivo','individual') NOT NULL,
  sustentavel           BOOLEAN      NOT NULL,
  referencia_comparacao BOOLEAN      NOT NULL DEFAULT FALSE,
  ref_unica             TINYINT
    GENERATED ALWAYS AS (IF(referencia_comparacao, 1, NULL)) STORED,
  PRIMARY KEY (id_modal),
  UNIQUE KEY uk_modal_codigo (codigo),
  UNIQUE KEY uk_modal_ref_unica (ref_unica)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- -----------------------------------------------------------------------------
-- usuario
-- -----------------------------------------------------------------------------
CREATE TABLE usuario (
  id_usuario         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  nome               VARCHAR(120) NOT NULL,
  email              VARCHAR(254) NOT NULL,
  cpf_hash           CHAR(64)     NULL,
  data_nascimento    DATE         NULL,
  id_modal_preferido SMALLINT UNSIGNED NULL,
  criado_em          DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ativo              BOOLEAN      NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id_usuario),
  UNIQUE KEY uk_usuario_email (email),
  UNIQUE KEY uk_usuario_cpf_hash (cpf_hash),
  CONSTRAINT fk_usuario_modal
    FOREIGN KEY (id_modal_preferido) REFERENCES modal_transporte (id_modal)
    ON DELETE SET NULL
    ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- -----------------------------------------------------------------------------
-- fonte_referencia
-- -----------------------------------------------------------------------------
CREATE TABLE fonte_referencia (
  id_fonte         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  orgao            VARCHAR(80)  NOT NULL,
  titulo           VARCHAR(250) NOT NULL,
  ano_publicacao   SMALLINT UNSIGNED NOT NULL,
  url              VARCHAR(500) NOT NULL,
  PRIMARY KEY (id_fonte),
  CONSTRAINT chk_fonte_ano
    CHECK (ano_publicacao BETWEEN 1990 AND 2100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- -----------------------------------------------------------------------------
-- fator_emissao
-- id_fonte SEM ação referencial (participa de CHECK)
-- -----------------------------------------------------------------------------
CREATE TABLE fator_emissao (
  id_fator         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_modal         SMALLINT UNSIGNED NOT NULL,
  id_fonte         INT UNSIGNED NULL,
  g_co2_pkm        DECIMAL(8,3) NOT NULL,
  estimativa       BOOLEAN NOT NULL,
  vigencia_inicio  DATE NOT NULL,
  vigencia_fim     DATE NULL,
  PRIMARY KEY (id_fator),
  KEY idx_fator_modal_inicio (id_modal, vigencia_inicio),
  CONSTRAINT fk_fator_modal
    FOREIGN KEY (id_modal) REFERENCES modal_transporte (id_modal)
    ON DELETE RESTRICT
    ON UPDATE RESTRICT,
  CONSTRAINT fk_fator_fonte
    FOREIGN KEY (id_fonte) REFERENCES fonte_referencia (id_fonte),
  CONSTRAINT chk_fator_g_co2
    CHECK (g_co2_pkm >= 0),
  CONSTRAINT chk_fator_estimativa_fonte
    CHECK (estimativa OR id_fonte IS NOT NULL),
  CONSTRAINT chk_fator_vigencia
    CHECK (vigencia_fim IS NULL OR vigencia_fim > vigencia_inicio)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- -----------------------------------------------------------------------------
-- local (SRID 4326 + índice espacial)
-- -----------------------------------------------------------------------------
CREATE TABLE local (
  id_local BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  nome     VARCHAR(150) NOT NULL,
  tipo     ENUM('estacao','ponto_onibus','endereco') NOT NULL,
  geom     POINT SRID 4326 NOT NULL,
  PRIMARY KEY (id_local),
  SPATIAL KEY spx_local_geom (geom)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- -----------------------------------------------------------------------------
-- segmento_via
-- -----------------------------------------------------------------------------
CREATE TABLE segmento_via (
  id_segmento         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  nome_via            VARCHAR(150) NOT NULL,
  geom                LINESTRING SRID 4326 NOT NULL,
  velocidade_max_kmh  SMALLINT UNSIGNED NOT NULL,
  possui_ciclovia     BOOLEAN NOT NULL,
  faixa_onibus        BOOLEAN NOT NULL,
  PRIMARY KEY (id_segmento),
  SPATIAL KEY spx_segmento_geom (geom),
  CONSTRAINT chk_segmento_vel
    CHECK (velocidade_max_kmh > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- -----------------------------------------------------------------------------
-- sensor
-- -----------------------------------------------------------------------------
CREATE TABLE sensor (
  id_sensor     INT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_segmento   BIGINT UNSIGNED NOT NULL,
  tipo          ENUM('laco','camera','gps_frota') NOT NULL,
  geom          POINT SRID 4326 NOT NULL,
  instalado_em  DATE NOT NULL,
  status        ENUM('ativo','manutencao','inativo') NOT NULL DEFAULT 'ativo',
  PRIMARY KEY (id_sensor),
  KEY idx_sensor_segmento (id_segmento),
  SPATIAL KEY spx_sensor_geom (geom),
  CONSTRAINT fk_sensor_segmento
    FOREIGN KEY (id_segmento) REFERENCES segmento_via (id_segmento)
    ON DELETE RESTRICT
    ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- -----------------------------------------------------------------------------
-- leitura_trafego (NÃO particionada — mantém FK)
-- -----------------------------------------------------------------------------
CREATE TABLE leitura_trafego (
  id_leitura              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_sensor               INT UNSIGNED NOT NULL,
  registrado_em           DATETIME(3) NOT NULL,
  velocidade_media_kmh    DECIMAL(5,1) NULL,
  volume_veiculos         INT UNSIGNED NULL,
  nivel_congestionamento  TINYINT UNSIGNED NOT NULL,
  PRIMARY KEY (id_leitura),
  UNIQUE KEY uk_leitura_sensor_ts (id_sensor, registrado_em),
  KEY idx_leitura_registrado_em (registrado_em),
  CONSTRAINT fk_leitura_sensor
    FOREIGN KEY (id_sensor) REFERENCES sensor (id_sensor)
    ON DELETE RESTRICT
    ON UPDATE RESTRICT,
  CONSTRAINT chk_leitura_vel
    CHECK (velocidade_media_kmh IS NULL OR velocidade_media_kmh >= 0),
  CONSTRAINT chk_leitura_nivel
    CHECK (nivel_congestionamento BETWEEN 0 AND 5)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- -----------------------------------------------------------------------------
-- linha_transporte
-- -----------------------------------------------------------------------------
CREATE TABLE linha_transporte (
  id_linha      INT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_modal      SMALLINT UNSIGNED NOT NULL,
  codigo        VARCHAR(20)  NOT NULL,
  nome          VARCHAR(150) NOT NULL,
  operadora     VARCHAR(100) NULL,
  geom_trajeto  LINESTRING SRID 4326 NOT NULL,
  PRIMARY KEY (id_linha),
  UNIQUE KEY uk_linha_codigo (codigo),
  KEY idx_linha_modal (id_modal),
  SPATIAL KEY spx_linha_trajeto (geom_trajeto),
  CONSTRAINT fk_linha_modal
    FOREIGN KEY (id_modal) REFERENCES modal_transporte (id_modal)
    ON DELETE RESTRICT
    ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- -----------------------------------------------------------------------------
-- viagem
-- locais SEM ação referencial (CHECK destino <> origem)
-- -----------------------------------------------------------------------------
CREATE TABLE viagem (
  id_viagem         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_usuario        BIGINT UNSIGNED NOT NULL,
  id_local_origem   BIGINT UNSIGNED NOT NULL,
  id_local_destino  BIGINT UNSIGNED NOT NULL,
  inicio            DATETIME NOT NULL,
  fim               DATETIME NULL,
  status            ENUM('planejada','em_curso','concluida','cancelada')
                    NOT NULL DEFAULT 'planejada',
  PRIMARY KEY (id_viagem),
  KEY idx_viagem_usuario_inicio (id_usuario, inicio),
  KEY idx_viagem_origem (id_local_origem),
  KEY idx_viagem_destino (id_local_destino),
  CONSTRAINT fk_viagem_usuario
    FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario)
    ON DELETE RESTRICT
    ON UPDATE RESTRICT,
  CONSTRAINT fk_viagem_origem
    FOREIGN KEY (id_local_origem) REFERENCES local (id_local),
  CONSTRAINT fk_viagem_destino
    FOREIGN KEY (id_local_destino) REFERENCES local (id_local),
  CONSTRAINT chk_viagem_destino_diff
    CHECK (id_local_destino <> id_local_origem),
  CONSTRAINT chk_viagem_fim
    CHECK (fim IS NULL OR fim > inicio)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- -----------------------------------------------------------------------------
-- trecho_viagem
-- -----------------------------------------------------------------------------
CREATE TABLE trecho_viagem (
  id_trecho      BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_viagem      BIGINT UNSIGNED NOT NULL,
  ordem          TINYINT UNSIGNED NOT NULL,
  id_modal       SMALLINT UNSIGNED NOT NULL,
  id_linha       INT UNSIGNED NULL,
  inicio         DATETIME NOT NULL,
  fim            DATETIME NOT NULL,
  distancia_km   DECIMAL(7,3) NOT NULL,
  geom_percurso  LINESTRING SRID 4326 NULL,
  PRIMARY KEY (id_trecho),
  UNIQUE KEY uk_trecho_viagem_ordem (id_viagem, ordem),
  KEY idx_trecho_modal (id_modal),
  KEY idx_trecho_linha (id_linha),
  CONSTRAINT fk_trecho_viagem
    FOREIGN KEY (id_viagem) REFERENCES viagem (id_viagem)
    ON DELETE CASCADE
    ON UPDATE RESTRICT,
  CONSTRAINT fk_trecho_modal
    FOREIGN KEY (id_modal) REFERENCES modal_transporte (id_modal)
    ON DELETE RESTRICT
    ON UPDATE RESTRICT,
  CONSTRAINT fk_trecho_linha
    FOREIGN KEY (id_linha) REFERENCES linha_transporte (id_linha)
    ON DELETE RESTRICT
    ON UPDATE RESTRICT,
  CONSTRAINT chk_trecho_fim
    CHECK (fim > inicio),
  CONSTRAINT chk_trecho_dist
    CHECK (distancia_km > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- -----------------------------------------------------------------------------
-- trecho_segmento (N:N)
-- -----------------------------------------------------------------------------
CREATE TABLE trecho_segmento (
  id_trecho    BIGINT UNSIGNED NOT NULL,
  id_segmento  BIGINT UNSIGNED NOT NULL,
  ordem        SMALLINT UNSIGNED NOT NULL,
  PRIMARY KEY (id_trecho, id_segmento),
  KEY idx_ts_segmento (id_segmento),
  CONSTRAINT fk_ts_trecho
    FOREIGN KEY (id_trecho) REFERENCES trecho_viagem (id_trecho)
    ON DELETE CASCADE
    ON UPDATE RESTRICT,
  CONSTRAINT fk_ts_segmento
    FOREIGN KEY (id_segmento) REFERENCES segmento_via (id_segmento)
    ON DELETE RESTRICT
    ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- -----------------------------------------------------------------------------
-- sugestao_modal
-- -----------------------------------------------------------------------------
CREATE TABLE sugestao_modal (
  id_sugestao             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_viagem               BIGINT UNSIGNED NOT NULL,
  id_modal_sugerido       SMALLINT UNSIGNED NOT NULL,
  id_linha                INT UNSIGNED NULL,
  distancia_estimada_km   DECIMAL(7,3) NOT NULL,
  duracao_estimada_min    SMALLINT UNSIGNED NOT NULL,
  motivo                  ENUM('congestionamento','menor_co2','menor_tempo') NOT NULL,
  gerada_em               DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  aceita                  BOOLEAN NULL,
  PRIMARY KEY (id_sugestao),
  KEY idx_sugestao_viagem (id_viagem),
  KEY idx_sugestao_modal (id_modal_sugerido),
  KEY idx_sugestao_linha (id_linha),
  CONSTRAINT fk_sugestao_viagem
    FOREIGN KEY (id_viagem) REFERENCES viagem (id_viagem)
    ON DELETE CASCADE
    ON UPDATE RESTRICT,
  CONSTRAINT fk_sugestao_modal
    FOREIGN KEY (id_modal_sugerido) REFERENCES modal_transporte (id_modal)
    ON DELETE RESTRICT
    ON UPDATE RESTRICT,
  CONSTRAINT fk_sugestao_linha
    FOREIGN KEY (id_linha) REFERENCES linha_transporte (id_linha)
    ON DELETE RESTRICT
    ON UPDATE RESTRICT,
  CONSTRAINT chk_sugestao_dist
    CHECK (distancia_estimada_km > 0),
  CONSTRAINT chk_sugestao_duracao
    CHECK (duracao_estimada_min > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ### FIM: 01_schema.sql ###


-- ##########################################################################
-- INÍCIO: 02_views.sql
-- ##########################################################################

-- =============================================================================
-- 02_views.sql – Views de emissão de CO₂, economia vs carro e congestionamento
-- Fator vigente na data do trecho (DATE(trecho.inicio))
-- =============================================================================

USE mobilidade_urbana;

DROP VIEW IF EXISTS vw_emissao_trecho;
DROP VIEW IF EXISTS vw_emissao_viagem;
DROP VIEW IF EXISTS vw_emissao_usuario;
DROP VIEW IF EXISTS vw_emissao_modal;
DROP VIEW IF EXISTS vw_emissao_linha;
DROP VIEW IF EXISTS vw_economia_vs_carro;
DROP VIEW IF EXISTS vw_economia_usuario_mes;
DROP VIEW IF EXISTS vw_congestionamento_atual;
DROP VIEW IF EXISTS vw_taxa_aceitacao_sugestao;

-- CO₂ por trecho: distancia_km × fator vigente na data do trecho
CREATE OR REPLACE VIEW vw_emissao_trecho AS
SELECT
  t.id_trecho,
  t.id_viagem,
  t.ordem,
  t.id_modal,
  m.codigo AS codigo_modal,
  m.nome   AS nome_modal,
  t.id_linha,
  l.codigo AS codigo_linha,
  t.inicio,
  t.fim,
  t.distancia_km,
  f.id_fator,
  f.g_co2_pkm,
  ROUND(t.distancia_km * f.g_co2_pkm, 3) AS co2_trecho_g
FROM trecho_viagem t
JOIN modal_transporte m ON m.id_modal = t.id_modal
LEFT JOIN linha_transporte l ON l.id_linha = t.id_linha
JOIN fator_emissao f
  ON f.id_modal = t.id_modal
 AND f.vigencia_inicio <= DATE(t.inicio)
 AND (f.vigencia_fim IS NULL OR f.vigencia_fim > DATE(t.inicio));

-- CO₂ por viagem
CREATE OR REPLACE VIEW vw_emissao_viagem AS
SELECT
  v.id_viagem,
  v.id_usuario,
  u.nome AS nome_usuario,
  v.inicio,
  v.fim,
  v.status,
  COUNT(e.id_trecho) AS qtd_trechos,
  ROUND(SUM(e.distancia_km), 3) AS distancia_total_km,
  ROUND(SUM(e.co2_trecho_g), 3) AS co2_viagem_g
FROM viagem v
JOIN usuario u ON u.id_usuario = v.id_usuario
LEFT JOIN vw_emissao_trecho e ON e.id_viagem = v.id_viagem
GROUP BY v.id_viagem, v.id_usuario, u.nome, v.inicio, v.fim, v.status;

-- CO₂ por usuário (agregado)
CREATE OR REPLACE VIEW vw_emissao_usuario AS
SELECT
  u.id_usuario,
  u.nome,
  u.email,
  COUNT(DISTINCT ev.id_viagem) AS qtd_viagens,
  ROUND(COALESCE(SUM(ev.distancia_total_km), 0), 3) AS distancia_total_km,
  ROUND(COALESCE(SUM(ev.co2_viagem_g), 0), 3) AS co2_total_g
FROM usuario u
LEFT JOIN vw_emissao_viagem ev
  ON ev.id_usuario = u.id_usuario
 AND ev.status = 'concluida'
GROUP BY u.id_usuario, u.nome, u.email;

-- CO₂ por modal
CREATE OR REPLACE VIEW vw_emissao_modal AS
SELECT
  m.id_modal,
  m.codigo,
  m.nome,
  m.categoria,
  COUNT(e.id_trecho) AS qtd_trechos,
  ROUND(COALESCE(SUM(e.distancia_km), 0), 3) AS distancia_total_km,
  ROUND(COALESCE(SUM(e.co2_trecho_g), 0), 3) AS co2_total_g
FROM modal_transporte m
LEFT JOIN vw_emissao_trecho e ON e.id_modal = m.id_modal
GROUP BY m.id_modal, m.codigo, m.nome, m.categoria;

-- CO₂ por linha / rota
CREATE OR REPLACE VIEW vw_emissao_linha AS
SELECT
  l.id_linha,
  l.codigo,
  l.nome,
  l.operadora,
  m.codigo AS codigo_modal,
  COUNT(e.id_trecho) AS qtd_trechos,
  ROUND(COALESCE(SUM(e.distancia_km), 0), 3) AS distancia_total_km,
  ROUND(COALESCE(SUM(e.co2_trecho_g), 0), 3) AS co2_total_g
FROM linha_transporte l
JOIN modal_transporte m ON m.id_modal = l.id_modal
LEFT JOIN vw_emissao_trecho e ON e.id_linha = l.id_linha
GROUP BY l.id_linha, l.codigo, l.nome, l.operadora, m.codigo;

-- Economia vs carro: mesma distância × (fator_carro − fator_modal)
CREATE OR REPLACE VIEW vw_economia_vs_carro AS
SELECT
  e.id_trecho,
  e.id_viagem,
  e.id_modal,
  e.codigo_modal,
  e.distancia_km,
  e.g_co2_pkm AS fator_modal_g,
  fc.g_co2_pkm AS fator_carro_g,
  e.co2_trecho_g,
  ROUND(e.distancia_km * fc.g_co2_pkm, 3) AS co2_se_carro_g,
  ROUND(e.distancia_km * (fc.g_co2_pkm - e.g_co2_pkm), 3) AS economia_vs_carro_g
FROM vw_emissao_trecho e
JOIN modal_transporte mc ON mc.referencia_comparacao = TRUE
JOIN fator_emissao fc
  ON fc.id_modal = mc.id_modal
 AND fc.vigencia_inicio <= DATE(e.inicio)
 AND (fc.vigencia_fim IS NULL OR fc.vigencia_fim > DATE(e.inicio));

-- Economia mensal por usuário
CREATE OR REPLACE VIEW vw_economia_usuario_mes AS
SELECT
  v.id_usuario,
  u.nome AS nome_usuario,
  DATE_FORMAT(v.inicio, '%Y-%m') AS ano_mes,
  COUNT(DISTINCT v.id_viagem) AS qtd_viagens,
  ROUND(SUM(ec.distancia_km), 3) AS distancia_km,
  ROUND(SUM(ec.co2_trecho_g), 3) AS co2_emitido_g,
  ROUND(SUM(ec.co2_se_carro_g), 3) AS co2_se_carro_g,
  ROUND(SUM(ec.economia_vs_carro_g), 3) AS economia_vs_carro_g
FROM viagem v
JOIN usuario u ON u.id_usuario = v.id_usuario
JOIN vw_economia_vs_carro ec ON ec.id_viagem = v.id_viagem
WHERE v.status = 'concluida'
GROUP BY v.id_usuario, u.nome, DATE_FORMAT(v.inicio, '%Y-%m');

-- Última leitura de congestionamento por segmento
CREATE OR REPLACE VIEW vw_congestionamento_atual AS
SELECT
  s.id_segmento,
  s.nome_via,
  s.velocidade_max_kmh,
  s.possui_ciclovia,
  s.faixa_onibus,
  sens.id_sensor,
  sens.tipo AS tipo_sensor,
  lt.registrado_em,
  lt.velocidade_media_kmh,
  lt.volume_veiculos,
  lt.nivel_congestionamento
FROM segmento_via s
JOIN sensor sens ON sens.id_segmento = s.id_segmento AND sens.status = 'ativo'
JOIN leitura_trafego lt ON lt.id_sensor = sens.id_sensor
JOIN (
  SELECT lt2.id_sensor, MAX(lt2.registrado_em) AS max_ts
  FROM leitura_trafego lt2
  GROUP BY lt2.id_sensor
) ult ON ult.id_sensor = lt.id_sensor AND ult.max_ts = lt.registrado_em;

-- Taxa de aceitação de sugestões
CREATE OR REPLACE VIEW vw_taxa_aceitacao_sugestao AS
SELECT
  COUNT(*) AS total_sugestoes,
  SUM(CASE WHEN aceita = TRUE  THEN 1 ELSE 0 END) AS aceitas,
  SUM(CASE WHEN aceita = FALSE THEN 1 ELSE 0 END) AS recusadas,
  SUM(CASE WHEN aceita IS NULL THEN 1 ELSE 0 END) AS sem_resposta,
  ROUND(
    100 * SUM(CASE WHEN aceita = TRUE THEN 1 ELSE 0 END)
      / NULLIF(SUM(CASE WHEN aceita IS NOT NULL THEN 1 ELSE 0 END), 0),
    2
  ) AS taxa_aceitacao_pct
FROM sugestao_modal;

-- ### FIM: 02_views.sql ###


-- ##########################################################################
-- INÍCIO: 03_triggers.sql
-- ##########################################################################

-- =============================================================================
-- 03_triggers.sql – Triggers do modelo + complementares
-- =============================================================================

USE mobilidade_urbana;

DELIMITER $$

-- -----------------------------------------------------------------------------
-- Fator de emissão: bloquear sobreposição de vigência no mesmo modal
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_fator_emissao_sem_sobreposicao_bi$$
CREATE TRIGGER trg_fator_emissao_sem_sobreposicao_bi
BEFORE INSERT ON fator_emissao
FOR EACH ROW
BEGIN
  DECLARE v_conflitos INT DEFAULT 0;
  SELECT COUNT(*) INTO v_conflitos
  FROM fator_emissao f
  WHERE f.id_modal = NEW.id_modal
    AND f.vigencia_inicio < IFNULL(NEW.vigencia_fim, '9999-12-31')
    AND IFNULL(f.vigencia_fim, '9999-12-31') > NEW.vigencia_inicio;
  IF v_conflitos > 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Sobreposição de vigência de fator_emissao para o mesmo modal.';
  END IF;
END$$

DROP TRIGGER IF EXISTS trg_fator_emissao_sem_sobreposicao_bu$$
CREATE TRIGGER trg_fator_emissao_sem_sobreposicao_bu
BEFORE UPDATE ON fator_emissao
FOR EACH ROW
BEGIN
  DECLARE v_conflitos INT DEFAULT 0;
  SELECT COUNT(*) INTO v_conflitos
  FROM fator_emissao f
  WHERE f.id_modal = NEW.id_modal
    AND f.id_fator <> NEW.id_fator
    AND f.vigencia_inicio < IFNULL(NEW.vigencia_fim, '9999-12-31')
    AND IFNULL(f.vigencia_fim, '9999-12-31') > NEW.vigencia_inicio;
  IF v_conflitos > 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Sobreposição de vigência de fator_emissao para o mesmo modal.';
  END IF;
END$$

-- -----------------------------------------------------------------------------
-- trecho_viagem: modal coerente com linha_transporte
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_trecho_modal_coerente_linha_bi$$
CREATE TRIGGER trg_trecho_modal_coerente_linha_bi
BEFORE INSERT ON trecho_viagem
FOR EACH ROW
BEGIN
  DECLARE v_modal_linha SMALLINT UNSIGNED;
  IF NEW.id_linha IS NOT NULL THEN
    SELECT id_modal INTO v_modal_linha
    FROM linha_transporte
    WHERE id_linha = NEW.id_linha;
    IF v_modal_linha IS NULL THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Linha informada em trecho_viagem não existe.';
    END IF;
    IF v_modal_linha <> NEW.id_modal THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'id_modal do trecho deve coincidir com id_modal da linha.';
    END IF;
  END IF;
END$$

DROP TRIGGER IF EXISTS trg_trecho_modal_coerente_linha_bu$$
CREATE TRIGGER trg_trecho_modal_coerente_linha_bu
BEFORE UPDATE ON trecho_viagem
FOR EACH ROW
BEGIN
  DECLARE v_modal_linha SMALLINT UNSIGNED;
  IF NEW.id_linha IS NOT NULL THEN
    SELECT id_modal INTO v_modal_linha
    FROM linha_transporte
    WHERE id_linha = NEW.id_linha;
    IF v_modal_linha IS NULL THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Linha informada em trecho_viagem não existe.';
    END IF;
    IF v_modal_linha <> NEW.id_modal THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'id_modal do trecho deve coincidir com id_modal da linha.';
    END IF;
  END IF;
END$$

-- -----------------------------------------------------------------------------
-- sugestao_modal: modal deve ser sustentável + coerência com linha
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_sugestao_modal_sustentavel_bi$$
CREATE TRIGGER trg_sugestao_modal_sustentavel_bi
BEFORE INSERT ON sugestao_modal
FOR EACH ROW
BEGIN
  DECLARE v_sust BOOLEAN;
  DECLARE v_modal_linha SMALLINT UNSIGNED;
  SELECT sustentavel INTO v_sust
  FROM modal_transporte
  WHERE id_modal = NEW.id_modal_sugerido;
  IF v_sust IS NULL OR v_sust = FALSE THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Só é permitido sugerir modal com sustentavel = TRUE.';
  END IF;
  IF NEW.id_linha IS NOT NULL THEN
    SELECT id_modal INTO v_modal_linha
    FROM linha_transporte
    WHERE id_linha = NEW.id_linha;
    IF v_modal_linha IS NULL OR v_modal_linha <> NEW.id_modal_sugerido THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'id_modal_sugerido deve coincidir com id_modal da linha.';
    END IF;
  END IF;
END$$

DROP TRIGGER IF EXISTS trg_sugestao_modal_sustentavel_bu$$
CREATE TRIGGER trg_sugestao_modal_sustentavel_bu
BEFORE UPDATE ON sugestao_modal
FOR EACH ROW
BEGIN
  DECLARE v_sust BOOLEAN;
  DECLARE v_modal_linha SMALLINT UNSIGNED;
  SELECT sustentavel INTO v_sust
  FROM modal_transporte
  WHERE id_modal = NEW.id_modal_sugerido;
  IF v_sust IS NULL OR v_sust = FALSE THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Só é permitido sugerir modal com sustentavel = TRUE.';
  END IF;
  IF NEW.id_linha IS NOT NULL THEN
    SELECT id_modal INTO v_modal_linha
    FROM linha_transporte
    WHERE id_linha = NEW.id_linha;
    IF v_modal_linha IS NULL OR v_modal_linha <> NEW.id_modal_sugerido THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'id_modal_sugerido deve coincidir com id_modal da linha.';
    END IF;
  END IF;
END$$

-- -----------------------------------------------------------------------------
-- Complementar: viagem concluída exige ao menos um trecho
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_viagem_concluida_tem_trecho_bu$$
CREATE TRIGGER trg_viagem_concluida_tem_trecho_bu
BEFORE UPDATE ON viagem
FOR EACH ROW
BEGIN
  DECLARE v_qtd INT DEFAULT 0;
  IF NEW.status = 'concluida' AND (OLD.status <> 'concluida' OR OLD.status IS NULL) THEN
    SELECT COUNT(*) INTO v_qtd FROM trecho_viagem WHERE id_viagem = NEW.id_viagem;
    IF v_qtd = 0 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Viagem concluída precisa ter ao menos um trecho.';
    END IF;
    IF NEW.fim IS NULL THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Viagem concluída precisa ter fim preenchido.';
    END IF;
  END IF;
END$$

DELIMITER ;

-- ### FIM: 03_triggers.sql ###


-- ##########################################################################
-- INÍCIO: 04_procedures.sql
-- ##########################################################################

-- =============================================================================
-- 04_procedures.sql – Procedures, functions e EVENT de retenção
-- =============================================================================

USE mobilidade_urbana;

DELIMITER $$

-- -----------------------------------------------------------------------------
-- Função: fator vigente (g CO₂e/pkm) para modal em uma data
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_fator_vigente$$
CREATE FUNCTION fn_fator_vigente(p_id_modal SMALLINT UNSIGNED, p_data DATE)
RETURNS DECIMAL(8,3)
READS SQL DATA
DETERMINISTIC
BEGIN
  DECLARE v_fator DECIMAL(8,3);
  SELECT f.g_co2_pkm INTO v_fator
  FROM fator_emissao f
  WHERE f.id_modal = p_id_modal
    AND f.vigencia_inicio <= p_data
    AND (f.vigencia_fim IS NULL OR f.vigencia_fim > p_data)
  ORDER BY f.vigencia_inicio DESC
  LIMIT 1;
  RETURN v_fator;
END$$

-- -----------------------------------------------------------------------------
-- Função: CO₂ estimado (g) para distância × modal na data
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_co2_estimado_g$$
CREATE FUNCTION fn_co2_estimado_g(
  p_id_modal SMALLINT UNSIGNED,
  p_distancia_km DECIMAL(7,3),
  p_data DATE
)
RETURNS DECIMAL(12,3)
READS SQL DATA
DETERMINISTIC
BEGIN
  DECLARE v_fator DECIMAL(8,3);
  SET v_fator = fn_fator_vigente(p_id_modal, p_data);
  IF v_fator IS NULL THEN
    RETURN NULL;
  END IF;
  RETURN ROUND(p_distancia_km * v_fator, 3);
END$$

-- -----------------------------------------------------------------------------
-- Procedure: registrar viagem + trechos em transação (rollback em erro)
-- p_trechos_json: array JSON
--   [{"ordem":1,"id_modal":3,"id_linha":1,"inicio":"...","fim":"...","distancia_km":4.2}, ...]
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_registrar_viagem$$
CREATE PROCEDURE sp_registrar_viagem(
  IN  p_id_usuario       BIGINT UNSIGNED,
  IN  p_id_local_origem  BIGINT UNSIGNED,
  IN  p_id_local_destino BIGINT UNSIGNED,
  IN  p_inicio           DATETIME,
  IN  p_fim              DATETIME,
  IN  p_status           VARCHAR(20),
  IN  p_trechos_json     JSON,
  OUT p_id_viagem        BIGINT UNSIGNED,
  OUT p_mensagem         VARCHAR(255)
)
proc_body: BEGIN
  DECLARE v_i INT DEFAULT 0;
  DECLARE v_n INT DEFAULT 0;
  DECLARE v_ordem TINYINT UNSIGNED;
  DECLARE v_id_modal SMALLINT UNSIGNED;
  DECLARE v_id_linha INT UNSIGNED;
  DECLARE v_inicio DATETIME;
  DECLARE v_fim DATETIME;
  DECLARE v_dist DECIMAL(7,3);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    GET DIAGNOSTICS CONDITION 1 p_mensagem = MESSAGE_TEXT;
    ROLLBACK;
    SET p_id_viagem = NULL;
    IF p_mensagem IS NULL OR p_mensagem = '' THEN
      SET p_mensagem = 'Erro na transação; rollback efetuado.';
    END IF;
  END;

  IF p_trechos_json IS NULL OR JSON_TYPE(p_trechos_json) <> 'ARRAY'
     OR JSON_LENGTH(p_trechos_json) = 0 THEN
    SET p_id_viagem = NULL;
    SET p_mensagem = 'Informe ao menos um trecho no JSON.';
    LEAVE proc_body;
  END IF;

  START TRANSACTION;

  INSERT INTO viagem (
    id_usuario, id_local_origem, id_local_destino, inicio, fim, status
  ) VALUES (
    p_id_usuario, p_id_local_origem, p_id_local_destino,
    p_inicio, p_fim, IFNULL(p_status, 'planejada')
  );
  SET p_id_viagem = LAST_INSERT_ID();

  SET v_n = JSON_LENGTH(p_trechos_json);
  SET v_i = 0;
  WHILE v_i < v_n DO
    SET v_ordem    = JSON_UNQUOTE(JSON_EXTRACT(p_trechos_json, CONCAT('$[', v_i, '].ordem')));
    SET v_id_modal = JSON_UNQUOTE(JSON_EXTRACT(p_trechos_json, CONCAT('$[', v_i, '].id_modal')));
    SET v_id_linha = JSON_UNQUOTE(JSON_EXTRACT(p_trechos_json, CONCAT('$[', v_i, '].id_linha')));
    SET v_inicio   = JSON_UNQUOTE(JSON_EXTRACT(p_trechos_json, CONCAT('$[', v_i, '].inicio')));
    SET v_fim      = JSON_UNQUOTE(JSON_EXTRACT(p_trechos_json, CONCAT('$[', v_i, '].fim')));
    SET v_dist     = JSON_UNQUOTE(JSON_EXTRACT(p_trechos_json, CONCAT('$[', v_i, '].distancia_km')));

    IF v_id_linha = 'null' OR v_id_linha = '' THEN
      SET v_id_linha = NULL;
    END IF;

    INSERT INTO trecho_viagem (
      id_viagem, ordem, id_modal, id_linha, inicio, fim, distancia_km
    ) VALUES (
      p_id_viagem, v_ordem, v_id_modal, v_id_linha, v_inicio, v_fim, v_dist
    );
    SET v_i = v_i + 1;
  END WHILE;

  COMMIT;
  SET p_mensagem = 'Viagem registrada com sucesso.';
END$$

-- -----------------------------------------------------------------------------
-- Procedure: gerar sugestão sustentável a partir do congestionamento atual
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_gerar_sugestao_sustentavel$$
CREATE PROCEDURE sp_gerar_sugestao_sustentavel(
  IN  p_id_viagem BIGINT UNSIGNED,
  OUT p_id_sugestao BIGINT UNSIGNED,
  OUT p_mensagem VARCHAR(255)
)
proc_sug: BEGIN
  DECLARE v_nivel_medio DECIMAL(5,2);
  DECLARE v_tem_ciclovia TINYINT DEFAULT 0;
  DECLARE v_tem_faixa_onibus TINYINT DEFAULT 0;
  DECLARE v_id_modal SMALLINT UNSIGNED;
  DECLARE v_id_linha INT UNSIGNED;
  DECLARE v_motivo ENUM('congestionamento','menor_co2','menor_tempo');
  DECLARE v_dist DECIMAL(7,3);
  DECLARE v_duracao SMALLINT UNSIGNED;
  DECLARE v_existe INT DEFAULT 0;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SET p_id_sugestao = NULL;
    GET DIAGNOSTICS CONDITION 1 p_mensagem = MESSAGE_TEXT;
  END;

  SELECT COUNT(*) INTO v_existe FROM viagem WHERE id_viagem = p_id_viagem;
  IF v_existe = 0 THEN
    SET p_id_sugestao = NULL;
    SET p_mensagem = 'Viagem não encontrada.';
    LEAVE proc_sug;
  END IF;

  -- Congestionamento médio nos segmentos cobertos (ou geral se sem trecho ainda)
  SELECT
    AVG(c.nivel_congestionamento),
    MAX(c.possui_ciclovia),
    MAX(c.faixa_onibus)
  INTO v_nivel_medio, v_tem_ciclovia, v_tem_faixa_onibus
  FROM vw_congestionamento_atual c
  WHERE c.id_segmento IN (
    SELECT ts.id_segmento
    FROM trecho_viagem t
    JOIN trecho_segmento ts ON ts.id_trecho = t.id_trecho
    WHERE t.id_viagem = p_id_viagem
  )
  OR NOT EXISTS (
    SELECT 1
    FROM trecho_viagem t2
    JOIN trecho_segmento ts2 ON ts2.id_trecho = t2.id_trecho
    WHERE t2.id_viagem = p_id_viagem
  );

  IF v_nivel_medio IS NULL THEN
    SELECT AVG(nivel_congestionamento) INTO v_nivel_medio FROM vw_congestionamento_atual;
    SELECT MAX(possui_ciclovia), MAX(faixa_onibus)
      INTO v_tem_ciclovia, v_tem_faixa_onibus
    FROM vw_congestionamento_atual;
  END IF;

  SET v_dist = 5.000; -- estimativa padrão quando ainda sem trechos
  SELECT COALESCE(SUM(distancia_km), 5.000) INTO v_dist
  FROM trecho_viagem WHERE id_viagem = p_id_viagem;

  -- Heurística: congestionamento alto → prioriza metrô/trem; senão bicicleta se ciclovia
  IF IFNULL(v_nivel_medio, 0) >= 3 THEN
    SET v_motivo = 'congestionamento';
    SELECT m.id_modal, (
      SELECT l.id_linha FROM linha_transporte l
      WHERE l.id_modal = m.id_modal ORDER BY l.id_linha LIMIT 1
    )
    INTO v_id_modal, v_id_linha
    FROM modal_transporte m
    WHERE m.codigo = 'METRO' AND m.sustentavel = TRUE
    LIMIT 1;
    SET v_duracao = GREATEST(10, ROUND(v_dist * 3));
  ELSEIF IFNULL(v_tem_ciclovia, 0) = 1 AND v_dist <= 8 THEN
    SET v_motivo = 'menor_co2';
    SELECT id_modal INTO v_id_modal FROM modal_transporte WHERE codigo = 'BICICLETA' LIMIT 1;
    SET v_id_linha = NULL;
    SET v_duracao = GREATEST(10, ROUND(v_dist * 5));
  ELSEIF IFNULL(v_tem_faixa_onibus, 0) = 1 THEN
    SET v_motivo = 'menor_tempo';
    SELECT m.id_modal, (
      SELECT l.id_linha FROM linha_transporte l
      WHERE l.id_modal = m.id_modal ORDER BY l.id_linha LIMIT 1
    )
    INTO v_id_modal, v_id_linha
    FROM modal_transporte m
    WHERE m.codigo = 'ONIBUS' AND m.sustentavel = TRUE
    LIMIT 1;
    SET v_duracao = GREATEST(10, ROUND(v_dist * 4));
  ELSE
    SET v_motivo = 'menor_co2';
    SELECT m.id_modal, (
      SELECT l.id_linha FROM linha_transporte l
      WHERE l.id_modal = m.id_modal ORDER BY l.id_linha LIMIT 1
    )
    INTO v_id_modal, v_id_linha
    FROM modal_transporte m
    WHERE m.codigo = 'METRO' AND m.sustentavel = TRUE
    LIMIT 1;
    SET v_duracao = GREATEST(10, ROUND(v_dist * 3));
  END IF;

  IF v_id_modal IS NULL THEN
    SET p_id_sugestao = NULL;
    SET p_mensagem = 'Nenhum modal sustentável disponível para sugestão.';
    LEAVE proc_sug;
  END IF;

  START TRANSACTION;
  INSERT INTO sugestao_modal (
    id_viagem, id_modal_sugerido, id_linha,
    distancia_estimada_km, duracao_estimada_min, motivo
  ) VALUES (
    p_id_viagem, v_id_modal, v_id_linha,
    v_dist, v_duracao, v_motivo
  );
  SET p_id_sugestao = LAST_INSERT_ID();
  COMMIT;
  SET p_mensagem = CONCAT('Sugestão gerada (motivo=', v_motivo, ').');
END$$

-- -----------------------------------------------------------------------------
-- Procedure: limpeza em lotes de leituras antigas
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_limpar_leituras_antigas$$
CREATE PROCEDURE sp_limpar_leituras_antigas(
  IN p_dias_retencao INT,
  IN p_lote INT
)
BEGIN
  DECLARE v_afetados INT DEFAULT 1;
  DECLARE v_total INT DEFAULT 0;
  IF p_dias_retencao IS NULL OR p_dias_retencao < 1 THEN
    SET p_dias_retencao = 90;
  END IF;
  IF p_lote IS NULL OR p_lote < 1 THEN
    SET p_lote = 5000;
  END IF;

  WHILE v_afetados > 0 DO
    DELETE FROM leitura_trafego
    WHERE registrado_em < (UTC_TIMESTAMP(3) - INTERVAL p_dias_retencao DAY)
    LIMIT p_lote;
    SET v_afetados = ROW_COUNT();
    SET v_total = v_total + v_afetados;
  END WHILE;

  SELECT v_total AS leituras_removidas, p_dias_retencao AS dias_retencao;
END$$

DELIMITER ;

-- EVENT mensal de retenção (habilita o scheduler na sessão/servidor)
SET GLOBAL event_scheduler = ON;

DROP EVENT IF EXISTS ev_limpeza_mensal_leituras;
CREATE EVENT ev_limpeza_mensal_leituras
ON SCHEDULE EVERY 1 MONTH
STARTS TIMESTAMP(DATE_FORMAT(DATE_ADD(UTC_DATE(), INTERVAL 1 MONTH), '%Y-%m-01 03:00:00'))
DO
  CALL sp_limpar_leituras_antigas(90, 5000);

-- ### FIM: 04_procedures.sql ###


-- ##########################################################################
-- INÍCIO: 05_security.sql
-- ##########################################################################

-- =============================================================================
-- 05_security.sql – Roles, usuários e GRANTs (menor privilégio)
-- Senhas apenas para ambiente acadêmico/local — trocar em produção.
-- =============================================================================

USE mobilidade_urbana;

-- Roles (idempotente via DROP/CREATE)
DROP ROLE IF EXISTS 'role_app';
DROP ROLE IF EXISTS 'role_analista';
DROP ROLE IF EXISTS 'role_admin_dados';

CREATE ROLE 'role_app';
CREATE ROLE 'role_analista';
CREATE ROLE 'role_admin_dados';

-- Aplicação: CRUD operacional nas tabelas de negócio; EXECUTE em procedures
GRANT SELECT, INSERT, UPDATE, DELETE ON mobilidade_urbana.usuario TO 'role_app';
GRANT SELECT ON mobilidade_urbana.modal_transporte TO 'role_app';
GRANT SELECT ON mobilidade_urbana.fonte_referencia TO 'role_app';
GRANT SELECT ON mobilidade_urbana.fator_emissao TO 'role_app';
GRANT SELECT ON mobilidade_urbana.local TO 'role_app';
GRANT SELECT ON mobilidade_urbana.segmento_via TO 'role_app';
GRANT SELECT ON mobilidade_urbana.sensor TO 'role_app';
GRANT SELECT, INSERT ON mobilidade_urbana.leitura_trafego TO 'role_app';
GRANT SELECT ON mobilidade_urbana.linha_transporte TO 'role_app';
GRANT SELECT, INSERT, UPDATE ON mobilidade_urbana.viagem TO 'role_app';
GRANT SELECT, INSERT, UPDATE, DELETE ON mobilidade_urbana.trecho_viagem TO 'role_app';
GRANT SELECT, INSERT, DELETE ON mobilidade_urbana.trecho_segmento TO 'role_app';
GRANT SELECT, INSERT, UPDATE ON mobilidade_urbana.sugestao_modal TO 'role_app';

GRANT SELECT ON mobilidade_urbana.vw_emissao_trecho TO 'role_app';
GRANT SELECT ON mobilidade_urbana.vw_emissao_viagem TO 'role_app';
GRANT SELECT ON mobilidade_urbana.vw_emissao_usuario TO 'role_app';
GRANT SELECT ON mobilidade_urbana.vw_emissao_modal TO 'role_app';
GRANT SELECT ON mobilidade_urbana.vw_emissao_linha TO 'role_app';
GRANT SELECT ON mobilidade_urbana.vw_economia_vs_carro TO 'role_app';
GRANT SELECT ON mobilidade_urbana.vw_economia_usuario_mes TO 'role_app';
GRANT SELECT ON mobilidade_urbana.vw_congestionamento_atual TO 'role_app';
GRANT SELECT ON mobilidade_urbana.vw_taxa_aceitacao_sugestao TO 'role_app';

GRANT EXECUTE ON PROCEDURE mobilidade_urbana.sp_registrar_viagem TO 'role_app';
GRANT EXECUTE ON PROCEDURE mobilidade_urbana.sp_gerar_sugestao_sustentavel TO 'role_app';
GRANT EXECUTE ON FUNCTION mobilidade_urbana.fn_fator_vigente TO 'role_app';
GRANT EXECUTE ON FUNCTION mobilidade_urbana.fn_co2_estimado_g TO 'role_app';

-- Analista: somente leitura (tabelas + views)
GRANT SELECT ON mobilidade_urbana.* TO 'role_analista';

-- Admin de dados: DDL/DML completo no schema + procedures de manutenção
GRANT ALL PRIVILEGES ON mobilidade_urbana.* TO 'role_admin_dados';
GRANT EXECUTE ON PROCEDURE mobilidade_urbana.sp_limpar_leituras_antigas TO 'role_admin_dados';
GRANT EVENT ON mobilidade_urbana.* TO 'role_admin_dados';

-- Usuários de exemplo (localhost e % para Docker)
DROP USER IF EXISTS 'app_mobilidade'@'localhost';
DROP USER IF EXISTS 'app_mobilidade'@'%';
DROP USER IF EXISTS 'analista_mobilidade'@'localhost';
DROP USER IF EXISTS 'analista_mobilidade'@'%';
DROP USER IF EXISTS 'admin_mobilidade'@'localhost';
DROP USER IF EXISTS 'admin_mobilidade'@'%';

CREATE USER 'app_mobilidade'@'localhost' IDENTIFIED BY 'App#Mob2026';
CREATE USER 'app_mobilidade'@'%'         IDENTIFIED BY 'App#Mob2026';
CREATE USER 'analista_mobilidade'@'localhost' IDENTIFIED BY 'Analista#Mob2026';
CREATE USER 'analista_mobilidade'@'%'         IDENTIFIED BY 'Analista#Mob2026';
CREATE USER 'admin_mobilidade'@'localhost' IDENTIFIED BY 'Admin#Mob2026';
CREATE USER 'admin_mobilidade'@'%'         IDENTIFIED BY 'Admin#Mob2026';

GRANT 'role_app' TO 'app_mobilidade'@'localhost', 'app_mobilidade'@'%';
GRANT 'role_analista' TO 'analista_mobilidade'@'localhost', 'analista_mobilidade'@'%';
GRANT 'role_admin_dados' TO 'admin_mobilidade'@'localhost', 'admin_mobilidade'@'%';

SET DEFAULT ROLE 'role_app' TO 'app_mobilidade'@'localhost', 'app_mobilidade'@'%';
SET DEFAULT ROLE 'role_analista' TO 'analista_mobilidade'@'localhost', 'analista_mobilidade'@'%';
SET DEFAULT ROLE 'role_admin_dados' TO 'admin_mobilidade'@'localhost', 'admin_mobilidade'@'%';

FLUSH PRIVILEGES;

-- ### FIM: 05_security.sql ###


-- ##########################################################################
-- INÍCIO: 06_seed.sql
-- ##########################################################################

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

-- ### FIM: 06_seed.sql ###


-- ##########################################################################
-- INÍCIO: 07_relatorios.sql
-- ##########################################################################

-- =============================================================================
-- 07_relatorios.sql – Consultas de relatório do projeto
-- =============================================================================

USE mobilidade_urbana;

SELECT '=== 1) CO₂ por usuário ===' AS relatorio;
SELECT id_usuario, nome, qtd_viagens, distancia_total_km, co2_total_g
FROM vw_emissao_usuario
ORDER BY co2_total_g DESC;

SELECT '=== 2) CO₂ por modal ===' AS relatorio;
SELECT codigo, nome, categoria, qtd_trechos, distancia_total_km, co2_total_g
FROM vw_emissao_modal
ORDER BY co2_total_g DESC;

SELECT '=== 3) CO₂ por linha/rota ===' AS relatorio;
SELECT codigo, nome, operadora, codigo_modal, qtd_trechos, distancia_total_km, co2_total_g
FROM vw_emissao_linha
ORDER BY co2_total_g DESC;

SELECT '=== 4) Economia vs carro (por trecho) ===' AS relatorio;
SELECT id_viagem, codigo_modal, distancia_km, co2_trecho_g, co2_se_carro_g, economia_vs_carro_g
FROM vw_economia_vs_carro
ORDER BY economia_vs_carro_g DESC;

SELECT '=== 5) Economia mensal por usuário ===' AS relatorio;
SELECT id_usuario, nome_usuario, ano_mes, qtd_viagens, distancia_km,
       co2_emitido_g, co2_se_carro_g, economia_vs_carro_g
FROM vw_economia_usuario_mes
ORDER BY ano_mes, economia_vs_carro_g DESC;

SELECT '=== 6) Ranking de congestionamento atual ===' AS relatorio;
SELECT id_segmento, nome_via, nivel_congestionamento, velocidade_media_kmh,
       volume_veiculos, registrado_em, possui_ciclovia, faixa_onibus
FROM vw_congestionamento_atual
ORDER BY nivel_congestionamento DESC, velocidade_media_kmh ASC;

SELECT '=== 7) Taxa de aceitação de sugestões ===' AS relatorio;
SELECT total_sugestoes, aceitas, recusadas, sem_resposta, taxa_aceitacao_pct
FROM vw_taxa_aceitacao_sugestao;

SELECT '=== 8) Emissão detalhada por trecho ===' AS relatorio;
SELECT id_viagem, ordem, codigo_modal, codigo_linha, distancia_km, g_co2_pkm, co2_trecho_g
FROM vw_emissao_trecho
ORDER BY id_viagem, ordem;

SELECT '=== 9) Top usuários por economia de CO₂ ===' AS relatorio;
SELECT
  u.id_usuario,
  u.nome,
  ROUND(SUM(ec.economia_vs_carro_g), 3) AS economia_total_g,
  ROUND(SUM(ec.economia_vs_carro_g) / 1000, 3) AS economia_total_kg
FROM usuario u
JOIN viagem v ON v.id_usuario = u.id_usuario AND v.status = 'concluida'
JOIN vw_economia_vs_carro ec ON ec.id_viagem = v.id_viagem
GROUP BY u.id_usuario, u.nome
ORDER BY economia_total_g DESC;

-- ### FIM: 07_relatorios.sql ###


-- ##########################################################################
-- INÍCIO: 08_testes.sql
-- ##########################################################################

-- =============================================================================
-- 08_testes.sql – Provas de constraints/triggers + rollback de transação
-- Cada caso negativo deve ser REJEITADO; T11 deve ser OK.
-- =============================================================================

USE mobilidade_urbana;
SET time_zone = '+00:00';

DROP TEMPORARY TABLE IF EXISTS tmp_resultado_teste;
CREATE TEMPORARY TABLE tmp_resultado_teste (
  id INT AUTO_INCREMENT PRIMARY KEY,
  teste VARCHAR(120) NOT NULL,
  esperado VARCHAR(40) NOT NULL,
  obtido VARCHAR(40) NOT NULL,
  detalhe VARCHAR(500) NULL
);

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_rodar_testes$$
CREATE PROCEDURE sp_rodar_testes()
BEGIN
  DECLARE v_msg TEXT DEFAULT NULL;
  DECLARE v_failed INT DEFAULT 0;

  -- T1: CHECK distancia_km > 0
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
      GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
      SET v_failed = 1;
    END;
    SET v_failed = 0; SET v_msg = NULL;
    INSERT INTO trecho_viagem (id_viagem, ordem, id_modal, inicio, fim, distancia_km)
    VALUES (7, 99, 2, '2026-11-19 08:00:00', '2026-11-19 08:30:00', 0);
    IF v_failed = 1 THEN
      INSERT INTO tmp_resultado_teste(teste, esperado, obtido, detalhe)
      VALUES ('T1 CHECK distancia_km > 0', 'REJEITADO', 'REJEITADO', LEFT(v_msg, 500));
    ELSE
      INSERT INTO tmp_resultado_teste(teste, esperado, obtido, detalhe)
      VALUES ('T1 CHECK distancia_km > 0', 'REJEITADO', 'ACEITO', 'FALHOU: insert indevido');
      DELETE FROM trecho_viagem WHERE id_viagem = 7 AND ordem = 99;
    END IF;
  END;

  -- T2: CHECK destino <> origem
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
      GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
      SET v_failed = 1;
    END;
    SET v_failed = 0; SET v_msg = NULL;
    INSERT INTO viagem (id_usuario, id_local_origem, id_local_destino, inicio, status)
    VALUES (1, 1, 1, '2026-11-19 09:00:00', 'planejada');
    IF v_failed = 1 THEN
      INSERT INTO tmp_resultado_teste(teste, esperado, obtido, detalhe)
      VALUES ('T2 CHECK destino <> origem', 'REJEITADO', 'REJEITADO', LEFT(v_msg, 500));
    ELSE
      INSERT INTO tmp_resultado_teste(teste, esperado, obtido, detalhe)
      VALUES ('T2 CHECK destino <> origem', 'REJEITADO', 'ACEITO', 'FALHOU');
      DELETE FROM viagem WHERE id_usuario = 1 AND id_local_origem = 1 AND id_local_destino = 1
        AND inicio = '2026-11-19 09:00:00';
    END IF;
  END;

  -- T3: CHECK nivel_congestionamento 0..5
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
      GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
      SET v_failed = 1;
    END;
    SET v_failed = 0; SET v_msg = NULL;
    INSERT INTO leitura_trafego (id_sensor, registrado_em, velocidade_media_kmh, volume_veiculos, nivel_congestionamento)
    VALUES (1, '2026-11-18 15:00:00.000', 10.0, 100, 9);
    IF v_failed = 1 THEN
      INSERT INTO tmp_resultado_teste(teste, esperado, obtido, detalhe)
      VALUES ('T3 CHECK nivel_congestionamento', 'REJEITADO', 'REJEITADO', LEFT(v_msg, 500));
    ELSE
      INSERT INTO tmp_resultado_teste(teste, esperado, obtido, detalhe)
      VALUES ('T3 CHECK nivel_congestionamento', 'REJEITADO', 'ACEITO', 'FALHOU');
      DELETE FROM leitura_trafego WHERE id_sensor = 1 AND registrado_em = '2026-11-18 15:00:00.000';
    END IF;
  END;

  -- T4: UNIQUE email
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
      GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
      SET v_failed = 1;
    END;
    SET v_failed = 0; SET v_msg = NULL;
    INSERT INTO usuario (nome, email, ativo)
    VALUES ('Duplicado', 'ana.ficticia@exemplo.sp.br', TRUE);
    IF v_failed = 1 THEN
      INSERT INTO tmp_resultado_teste(teste, esperado, obtido, detalhe)
      VALUES ('T4 UNIQUE email', 'REJEITADO', 'REJEITADO', LEFT(v_msg, 500));
    ELSE
      INSERT INTO tmp_resultado_teste(teste, esperado, obtido, detalhe)
      VALUES ('T4 UNIQUE email', 'REJEITADO', 'ACEITO', 'FALHOU');
      DELETE FROM usuario WHERE nome = 'Duplicado';
    END IF;
  END;

  -- T5: UNIQUE ref_unica (segundo carro referência)
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
      GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
      SET v_failed = 1;
    END;
    SET v_failed = 0; SET v_msg = NULL;
    INSERT INTO modal_transporte (codigo, nome, categoria, sustentavel, referencia_comparacao)
    VALUES ('CARRO2', 'Outro carro ref', 'individual', FALSE, TRUE);
    IF v_failed = 1 THEN
      INSERT INTO tmp_resultado_teste(teste, esperado, obtido, detalhe)
      VALUES ('T5 UNIQUE ref_unica (1 carro)', 'REJEITADO', 'REJEITADO', LEFT(v_msg, 500));
    ELSE
      INSERT INTO tmp_resultado_teste(teste, esperado, obtido, detalhe)
      VALUES ('T5 UNIQUE ref_unica (1 carro)', 'REJEITADO', 'ACEITO', 'FALHOU');
      DELETE FROM modal_transporte WHERE codigo = 'CARRO2';
    END IF;
  END;

  -- T6: Trigger sobreposição fator_emissao
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
      GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
      SET v_failed = 1;
    END;
    SET v_failed = 0; SET v_msg = NULL;
    INSERT INTO fator_emissao (id_modal, id_fonte, g_co2_pkm, estimativa, vigencia_inicio, vigencia_fim)
    VALUES (4, 2, 85.000, FALSE, '2022-01-01', '2024-01-01');
    IF v_failed = 1 THEN
      INSERT INTO tmp_resultado_teste(teste, esperado, obtido, detalhe)
      VALUES ('T6 Trigger sobreposição fator', 'REJEITADO', 'REJEITADO', LEFT(v_msg, 500));
    ELSE
      INSERT INTO tmp_resultado_teste(teste, esperado, obtido, detalhe)
      VALUES ('T6 Trigger sobreposição fator', 'REJEITADO', 'ACEITO', 'FALHOU');
      DELETE FROM fator_emissao WHERE id_modal = 4 AND g_co2_pkm = 85.000;
    END IF;
  END;

  -- T7: Trigger modal trecho ≠ modal linha
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
      GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
      SET v_failed = 1;
    END;
    SET v_failed = 0; SET v_msg = NULL;
    INSERT INTO trecho_viagem (id_viagem, ordem, id_modal, id_linha, inicio, fim, distancia_km)
    VALUES (7, 50, 4, 1, '2026-11-19 08:00:00', '2026-11-19 08:30:00', 2.000);
    IF v_failed = 1 THEN
      INSERT INTO tmp_resultado_teste(teste, esperado, obtido, detalhe)
      VALUES ('T7 Trigger modal≠linha no trecho', 'REJEITADO', 'REJEITADO', LEFT(v_msg, 500));
    ELSE
      INSERT INTO tmp_resultado_teste(teste, esperado, obtido, detalhe)
      VALUES ('T7 Trigger modal≠linha no trecho', 'REJEITADO', 'ACEITO', 'FALHOU');
      DELETE FROM trecho_viagem WHERE id_viagem = 7 AND ordem = 50;
    END IF;
  END;

  -- T8: Trigger sugestão de modal não sustentável (carro)
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
      GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
      SET v_failed = 1;
    END;
    SET v_failed = 0; SET v_msg = NULL;
    INSERT INTO sugestao_modal (id_viagem, id_modal_sugerido, distancia_estimada_km, duracao_estimada_min, motivo)
    VALUES (7, 7, 5.000, 20, 'menor_co2');
    IF v_failed = 1 THEN
      INSERT INTO tmp_resultado_teste(teste, esperado, obtido, detalhe)
      VALUES ('T8 Trigger sugestão sustentavel', 'REJEITADO', 'REJEITADO', LEFT(v_msg, 500));
    ELSE
      INSERT INTO tmp_resultado_teste(teste, esperado, obtido, detalhe)
      VALUES ('T8 Trigger sugestão sustentavel', 'REJEITADO', 'ACEITO', 'FALHOU');
      DELETE FROM sugestao_modal WHERE id_viagem = 7 AND id_modal_sugerido = 7;
    END IF;
  END;

  -- T9: FK inválida (sensor inexistente)
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
      GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
      SET v_failed = 1;
    END;
    SET v_failed = 0; SET v_msg = NULL;
    INSERT INTO leitura_trafego (id_sensor, registrado_em, velocidade_media_kmh, volume_veiculos, nivel_congestionamento)
    VALUES (9999, '2026-11-18 16:00:00.000', 10.0, 10, 1);
    IF v_failed = 1 THEN
      INSERT INTO tmp_resultado_teste(teste, esperado, obtido, detalhe)
      VALUES ('T9 FK leitura→sensor', 'REJEITADO', 'REJEITADO', LEFT(v_msg, 500));
    ELSE
      INSERT INTO tmp_resultado_teste(teste, esperado, obtido, detalhe)
      VALUES ('T9 FK leitura→sensor', 'REJEITADO', 'ACEITO', 'FALHOU');
      DELETE FROM leitura_trafego WHERE id_sensor = 9999;
    END IF;
  END;

  -- T10: Transação sp_registrar_viagem com trecho inválido → ROLLBACK
  BEGIN
    DECLARE v_id BIGINT UNSIGNED;
    DECLARE v_mensagem VARCHAR(255);
    DECLARE v_antes INT;
    DECLARE v_depois INT;
    SELECT COUNT(*) INTO v_antes FROM viagem WHERE id_usuario = 5 AND inicio = '2026-11-20 10:00:00';
    CALL sp_registrar_viagem(
      5, 1, 2,
      '2026-11-20 10:00:00', '2026-11-20 10:40:00', 'concluida',
      JSON_ARRAY(
        JSON_OBJECT(
          'ordem', 1,
          'id_modal', 4,
          'id_linha', 1,
          'inicio', '2026-11-20 10:00:00',
          'fim', '2026-11-20 10:40:00',
          'distancia_km', 4.5
        )
      ),
      v_id, v_mensagem
    );
    SELECT COUNT(*) INTO v_depois FROM viagem WHERE id_usuario = 5 AND inicio = '2026-11-20 10:00:00';
    IF v_id IS NULL AND v_depois = v_antes THEN
      INSERT INTO tmp_resultado_teste(teste, esperado, obtido, detalhe)
      VALUES ('T10 ROLLBACK sp_registrar_viagem', 'ROLLBACK', 'ROLLBACK',
              LEFT(IFNULL(v_mensagem, 'sem viagem residual (rollback ok)'), 500));
    ELSE
      INSERT INTO tmp_resultado_teste(teste, esperado, obtido, detalhe)
      VALUES ('T10 ROLLBACK sp_registrar_viagem', 'ROLLBACK', 'COMMIT',
              CONCAT('id=', IFNULL(v_id,'NULL'), ' msg=', IFNULL(v_mensagem,'')));
      IF v_id IS NOT NULL THEN
        DELETE FROM viagem WHERE id_viagem = v_id;
      END IF;
    END IF;
  END;

  -- T11: Transação válida (sucesso)
  BEGIN
    DECLARE v_id BIGINT UNSIGNED;
    DECLARE v_mensagem VARCHAR(255);
    CALL sp_registrar_viagem(
      5, 1, 2,
      '2026-11-20 11:00:00', '2026-11-20 11:40:00', 'concluida',
      JSON_ARRAY(
        JSON_OBJECT(
          'ordem', 1,
          'id_modal', 5,
          'id_linha', 1,
          'inicio', '2026-11-20 11:00:00',
          'fim', '2026-11-20 11:40:00',
          'distancia_km', 4.5
        )
      ),
      v_id, v_mensagem
    );
    IF v_id IS NOT NULL THEN
      INSERT INTO tmp_resultado_teste(teste, esperado, obtido, detalhe)
      VALUES ('T11 sp_registrar_viagem sucesso', 'OK', 'OK',
              CONCAT('id_viagem=', v_id, ' ', IFNULL(v_mensagem,'')));
    ELSE
      INSERT INTO tmp_resultado_teste(teste, esperado, obtido, detalhe)
      VALUES ('T11 sp_registrar_viagem sucesso', 'OK', 'FALHOU', LEFT(IFNULL(v_mensagem,''), 500));
    END IF;
  END;

  -- T12: CHECK estimativa exige fonte (período sem sobreposição na motocicleta)
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
      GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
      SET v_failed = 1;
    END;
    SET v_failed = 0; SET v_msg = NULL;
    INSERT INTO fator_emissao (id_modal, id_fonte, g_co2_pkm, estimativa, vigencia_inicio, vigencia_fim)
    VALUES (8, NULL, 100.000, FALSE, '2010-01-01', '2015-01-01');
    IF v_failed = 1 THEN
      INSERT INTO tmp_resultado_teste(teste, esperado, obtido, detalhe)
      VALUES ('T12 CHECK estimativa/fonte', 'REJEITADO', 'REJEITADO', LEFT(v_msg, 500));
    ELSE
      INSERT INTO tmp_resultado_teste(teste, esperado, obtido, detalhe)
      VALUES ('T12 CHECK estimativa/fonte', 'REJEITADO', 'ACEITO', 'FALHOU');
      DELETE FROM fator_emissao WHERE id_modal = 8 AND g_co2_pkm = 100.000 AND vigencia_inicio = '2010-01-01';
    END IF;
  END;

  SELECT * FROM tmp_resultado_teste ORDER BY id;

  SELECT
    SUM(esperado = obtido) AS testes_ok,
    SUM(esperado <> obtido) AS testes_falhos,
    COUNT(*) AS total
  FROM tmp_resultado_teste;
END$$

DELIMITER ;

CALL sp_rodar_testes();

-- ### FIM: 08_testes.sql ###

