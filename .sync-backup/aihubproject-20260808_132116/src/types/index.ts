// Shared domain types across the application

export interface Project {
  projectId: number;
  projectKey: string;
  projectName: string;
  isActive: boolean;
  allowedFeatures: string[] | null;
}

export interface AiProviderConfig {
  id: string;
  provider: string;
  name: string;
  apiKey: string;
  baseUrl: string;
  textModel: string;
  imageModel: string;
  enabled: boolean;
  capabilities: string[];
  adapterType: string;
  authConfig: AuthConfig;
  imageRequestConfig: ImageRequestConfig;
  testRequestConfig: TestRequestConfig;
}

export interface AuthConfig {
  type: 'bearer' | 'query' | 'none';
  header: string;
  queryKey: string;
}

export interface ImageRequestConfig {
  method: string;
  path: string;
  headers: Record<string, string>;
  bodyTemplate: Record<string, unknown>;
  response: { image_base64_path: string; image_url_path: string };
}

export interface TestRequestConfig {
  method: string;
  path: string;
  headers: Record<string, string>;
  bodyTemplate: Record<string, unknown>;
  response: Record<string, unknown>;
}

// Resolved provider config (apiKey decrypted, model resolved)
export interface ResolvedProviderSettings extends AiProviderConfig {
  providerId: string;
  modelType: 'text' | 'image';
  model: string;
}

export interface AiTextRequest {
  action: string;
  content: string;
  selectedText: string;
  prompt: string;
  language: string;
}

export interface AiMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

export interface AiGenerationResult {
  text: string;
  usage: RawUsage;
}

export interface RawUsage {
  inputTokens: number;
  outputTokens: number;
  totalTokens: number;
  source: 'provider' | 'estimated';
}

export interface AiTextResult {
  result: string;
  action: string;
  provider: string;
  providerId: string;
  model: string;
  usage: UsageInfo;
}

export interface UsageInfo {
  inputTokens: number;
  outputTokens: number;
  totalTokens: number;
  estimatedCost: number;
  currency: string;
  pricingFound: boolean;
  requestId: string;
  source: string;
}

export interface CostEstimate {
  estimatedCost: number;
  currency: string;
  pricingFound: boolean;
}

export interface UsageEntry {
  requestId: string;
  projectKey: string;
  userId?: string;
  feature: string;
  action: string;
  provider: string;
  model: string;
  inputTokens: number;
  outputTokens: number;
  totalTokens: number;
  estimatedCost: number;
  currency: string;
  status: 'success' | 'error' | 'quota_exceeded';
  errorCode?: string;
  httpStatus?: number;
  durationMs: number;
}

export interface QuotaStatus {
  month: string;
  package: PackageInfo;
  usage: UsageTotals;
  limits: QuotaLimits;
  percentages: QuotaPercentages;
}

export interface PackageInfo {
  packageKey: string;
  packageName: string;
  requestLimitMonthly: number | null;
  tokenLimitMonthly: number | null;
  costLimitMonthly: number | null;
  currency: string;
  alertThresholds: number[];
  hardLimitEnabled: boolean;
}

export interface UsageTotals {
  requestsCount: number;
  successCount: number;
  errorCount: number;
  inputTokens: number;
  outputTokens: number;
  totalTokens: number;
  estimatedCost: number;
}

export interface QuotaLimits {
  requestsCount: number | null;
  totalTokens: number | null;
  estimatedCost: number | null;
}

export interface QuotaPercentages {
  requestsCount: number;
  totalTokens: number;
  estimatedCost: number;
}
