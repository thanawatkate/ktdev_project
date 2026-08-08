-- =============================================================
-- aihubproject — Seed Data
-- =============================================================

-- Global billing package (no project scope — applies as default)
INSERT INTO `ai_billing_packages`
  (`package_key`, `package_name`, `scope_type`, `scope_id`, `request_limit_monthly`,
   `token_limit_monthly`, `cost_limit_monthly`, `currency`, `alert_thresholds_json`,
   `hard_limit_enabled`, `is_current`)
VALUES
  ('global_default', 'Global Default', 'global', '', 10000, 5000000, 50.000000,
   'USD', JSON_ARRAY(70, 90, 100), 1, 1)
ON DUPLICATE KEY UPDATE `package_key` = VALUES(`package_key`);

-- Default model pricing (costs = 0 until admin sets real prices)
INSERT INTO `ai_model_pricing`
  (`provider`, `model`, `input_cost_per_1k_tokens`, `output_cost_per_1k_tokens`, `currency`, `is_active`, `effective_from`)
VALUES
  ('openai',            'gpt-4.1-mini',       0, 0, 'USD', 1, CURRENT_DATE),
  ('openai',            'gpt-4o',             0, 0, 'USD', 1, CURRENT_DATE),
  ('gemini',            'gemini-2.5-flash',   0, 0, 'USD', 1, CURRENT_DATE),
  ('gemini',            'gemini-2.5-pro',     0, 0, 'USD', 1, CURRENT_DATE),
  ('openai_compatible', '*',                  0, 0, 'USD', 1, CURRENT_DATE),
  ('custom',            '*',                  0, 0, 'USD', 1, CURRENT_DATE)
ON DUPLICATE KEY UPDATE `provider` = VALUES(`provider`);

-- Default usage mapping (points to providers that don't exist yet — admin must configure)
INSERT INTO `ai_usage_mapping` (`usage_key`, `provider_id`, `model_type`)
VALUES
  ('text_default',    'openai_main',  'text'),
  ('carousel_image',  'openai_main',  'image')
ON DUPLICATE KEY UPDATE `usage_key` = VALUES(`usage_key`);
