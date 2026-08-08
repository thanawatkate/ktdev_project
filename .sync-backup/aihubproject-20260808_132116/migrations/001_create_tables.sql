-- =============================================================
-- aihubproject — Database Schema
-- =============================================================

CREATE TABLE IF NOT EXISTS `ai_projects` (
  `project_id`       INT UNSIGNED     NOT NULL AUTO_INCREMENT,
  `project_key`      VARCHAR(60)      NOT NULL,
  `project_name`     VARCHAR(100)     NOT NULL,
  `api_key_hash`     VARCHAR(128)     NOT NULL,
  `api_key_prefix`   VARCHAR(20)      NOT NULL,
  `is_active`        TINYINT(1)       NOT NULL DEFAULT 1,
  `allowed_features` JSON             NULL     COMMENT 'null = all features allowed',
  `created_at`       TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`       TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`project_id`),
  UNIQUE KEY `uq_ai_projects_key` (`project_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Provider configs — replaces sitebase's KV settings table for AI
CREATE TABLE IF NOT EXISTS `ai_provider_configs` (
  `id`                    VARCHAR(60)   NOT NULL,
  `provider`              VARCHAR(30)   NOT NULL,
  `name`                  VARCHAR(100)  NOT NULL,
  `api_key_encrypted`     TEXT          NULL     COMMENT 'AES-256-GCM: iv:tag:ciphertext (hex)',
  `base_url`              VARCHAR(255)  NOT NULL DEFAULT '',
  `text_model`            VARCHAR(100)  NOT NULL DEFAULT '',
  `image_model`           VARCHAR(100)  NOT NULL DEFAULT '',
  `enabled`               TINYINT(1)   NOT NULL DEFAULT 1,
  `capabilities`          JSON          NULL,
  `adapter_type`          VARCHAR(50)   NOT NULL DEFAULT 'openai_chat',
  `auth_config`           JSON          NULL,
  `image_request_config`  JSON          NULL,
  `test_request_config`   JSON          NULL,
  `sort_order`            INT           NOT NULL DEFAULT 0,
  `created_at`            TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`            TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Which provider to use for which feature
CREATE TABLE IF NOT EXISTS `ai_usage_mapping` (
  `usage_key`   VARCHAR(60)  NOT NULL,
  `provider_id` VARCHAR(60)  NOT NULL,
  `model_type`  VARCHAR(10)  NOT NULL DEFAULT 'text',
  `updated_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`usage_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Quota/billing packages — scope_id = project_key (or '' for global default)
CREATE TABLE IF NOT EXISTS `ai_billing_packages` (
  `package_id`              INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `package_key`             VARCHAR(80)  NOT NULL,
  `package_name`            VARCHAR(100) NOT NULL DEFAULT 'Default',
  `scope_type`              VARCHAR(30)  NOT NULL DEFAULT 'global',
  `scope_id`                VARCHAR(100) NULL,
  `request_limit_monthly`   BIGINT       NULL,
  `token_limit_monthly`     BIGINT       NULL,
  `cost_limit_monthly`      DECIMAL(12,6) NULL,
  `currency`                VARCHAR(10)  NOT NULL DEFAULT 'USD',
  `alert_thresholds_json`   JSON         NULL,
  `hard_limit_enabled`      TINYINT(1)   NOT NULL DEFAULT 1,
  `is_current`              TINYINT(1)   NOT NULL DEFAULT 1,
  `deleted_at`              TIMESTAMP    NULL,
  `created_at`              TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`package_id`),
  UNIQUE KEY `uq_ai_billing_packages_key` (`package_key`),
  KEY `idx_ai_billing_packages_current` (`scope_type`, `scope_id`, `is_current`, `deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ai_model_pricing` (
  `pricing_id`                INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  `provider`                  VARCHAR(50)     NOT NULL,
  `model`                     VARCHAR(100)    NOT NULL,
  `input_cost_per_1k_tokens`  DECIMAL(12,8)   NOT NULL DEFAULT 0,
  `output_cost_per_1k_tokens` DECIMAL(12,8)   NOT NULL DEFAULT 0,
  `currency`                  VARCHAR(10)     NOT NULL DEFAULT 'USD',
  `is_active`                 TINYINT(1)      NOT NULL DEFAULT 1,
  `effective_from`            DATE            NOT NULL,
  `deleted_at`                TIMESTAMP       NULL,
  `created_at`                TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`pricing_id`),
  UNIQUE KEY `uq_ai_model_pricing_model_date` (`provider`, `model`, `effective_from`),
  KEY `idx_ai_model_pricing_lookup` (`provider`, `model`, `is_active`, `deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Per-request log — scope_id = project_key
CREATE TABLE IF NOT EXISTS `ai_usage_ledger` (
  `id`              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `request_id`      VARCHAR(64)     NOT NULL,
  `scope_type`      VARCHAR(30)     NOT NULL DEFAULT 'project',
  `scope_id`        VARCHAR(100)    NOT NULL DEFAULT '',
  `user_id`         VARCHAR(100)    NULL,
  `feature`         VARCHAR(60)     NOT NULL DEFAULT 'unknown',
  `action`          VARCHAR(60)     NOT NULL DEFAULT 'unknown',
  `provider`        VARCHAR(50)     NOT NULL DEFAULT '',
  `model`           VARCHAR(100)    NOT NULL DEFAULT '',
  `input_tokens`    INT UNSIGNED    NOT NULL DEFAULT 0,
  `output_tokens`   INT UNSIGNED    NOT NULL DEFAULT 0,
  `total_tokens`    INT UNSIGNED    NOT NULL DEFAULT 0,
  `estimated_cost`  DECIMAL(12,8)   NOT NULL DEFAULT 0,
  `currency`        VARCHAR(10)     NOT NULL DEFAULT 'USD',
  `status`          VARCHAR(20)     NOT NULL DEFAULT 'success',
  `error_code`      VARCHAR(80)     NULL,
  `http_status`     SMALLINT        NULL,
  `duration_ms`     INT UNSIGNED    NOT NULL DEFAULT 0,
  `created_at`      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_ai_usage_ledger_request_id` (`request_id`),
  KEY `idx_ai_usage_ledger_created` (`created_at`),
  KEY `idx_ai_usage_ledger_scope` (`scope_type`, `scope_id`, `created_at`),
  KEY `idx_ai_usage_ledger_status` (`status`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daily aggregates per project
CREATE TABLE IF NOT EXISTS `ai_usage_daily_rollups` (
  `id`              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `usage_date`      DATE            NOT NULL,
  `usage_month`     VARCHAR(7)      NOT NULL,
  `scope_type`      VARCHAR(30)     NOT NULL DEFAULT 'project',
  `scope_id`        VARCHAR(100)    NOT NULL DEFAULT '',
  `feature`         VARCHAR(60)     NOT NULL DEFAULT '',
  `action`          VARCHAR(60)     NOT NULL DEFAULT '',
  `provider`        VARCHAR(50)     NOT NULL DEFAULT '',
  `model`           VARCHAR(100)    NOT NULL DEFAULT '',
  `requests_count`  INT UNSIGNED    NOT NULL DEFAULT 0,
  `success_count`   INT UNSIGNED    NOT NULL DEFAULT 0,
  `error_count`     INT UNSIGNED    NOT NULL DEFAULT 0,
  `input_tokens`    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `output_tokens`   BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `total_tokens`    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `estimated_cost`  DECIMAL(14,8)   NOT NULL DEFAULT 0,
  `updated_at`      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_ai_usage_daily_rollups_dim` (`usage_date`, `scope_type`, `scope_id`, `feature`, `action`, `provider`, `model`),
  KEY `idx_ai_usage_daily_rollups_month` (`usage_month`, `scope_type`, `scope_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ai_usage_alert_events` (
  `id`                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `usage_month`       VARCHAR(7)      NOT NULL,
  `scope_type`        VARCHAR(30)     NOT NULL DEFAULT 'project',
  `scope_id`          VARCHAR(100)    NOT NULL DEFAULT '',
  `package_key`       VARCHAR(80)     NOT NULL DEFAULT '',
  `metric`            VARCHAR(30)     NOT NULL,
  `threshold_percent` TINYINT UNSIGNED NOT NULL,
  `current_value`     DECIMAL(14,4)   NOT NULL DEFAULT 0,
  `limit_value`       DECIMAL(14,4)   NOT NULL DEFAULT 0,
  `created_at`        TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_ai_usage_alert_events_once` (`usage_month`, `scope_type`, `scope_id`, `metric`, `threshold_percent`),
  KEY `idx_ai_usage_alert_events_month` (`usage_month`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
