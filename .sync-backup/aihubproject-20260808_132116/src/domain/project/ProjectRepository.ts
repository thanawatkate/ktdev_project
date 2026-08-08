import type { Pool, RowDataPacket } from 'mysql2/promise';
import type { Project } from '../../types/index.js';

export class ProjectRepository {
  constructor(private readonly db: Pool) {}

  async findByKey(projectKey: string): Promise<Project | null> {
    const [rows] = await this.db.execute<RowDataPacket[]>(
      `SELECT project_id, project_key, project_name, api_key_hash, api_key_prefix,
              is_active, allowed_features
       FROM ai_projects
       WHERE project_key = ? AND is_active = 1
       LIMIT 1`,
      [projectKey],
    );
    const row = rows[0];
    if (!row) return null;
    return this.mapRow(row);
  }

  async findByApiKeyHash(hash: string): Promise<(Project & { apiKeyHash: string }) | null> {
    const [rows] = await this.db.execute<RowDataPacket[]>(
      `SELECT project_id, project_key, project_name, api_key_hash, api_key_prefix,
              is_active, allowed_features
       FROM ai_projects
       WHERE api_key_hash = ? AND is_active = 1
       LIMIT 1`,
      [hash],
    );
    const row = rows[0];
    if (!row) return null;
    return { ...this.mapRow(row), apiKeyHash: row['api_key_hash'] as string };
  }

  async listAll(): Promise<Project[]> {
    const [rows] = await this.db.execute<RowDataPacket[]>(
      `SELECT project_id, project_key, project_name, api_key_prefix, is_active, allowed_features, created_at
       FROM ai_projects ORDER BY project_id ASC`,
    );
    return (rows as RowDataPacket[]).map(r => this.mapRow(r));
  }

  async create(data: {
    projectKey: string;
    projectName: string;
    apiKeyHash: string;
    apiKeyPrefix: string;
    allowedFeatures: string[] | null;
  }): Promise<void> {
    await this.db.execute(
      `INSERT INTO ai_projects (project_key, project_name, api_key_hash, api_key_prefix, allowed_features)
       VALUES (?, ?, ?, ?, ?)`,
      [
        data.projectKey,
        data.projectName,
        data.apiKeyHash,
        data.apiKeyPrefix,
        data.allowedFeatures ? JSON.stringify(data.allowedFeatures) : null,
      ],
    );
  }

  async setActive(projectKey: string, isActive: boolean): Promise<void> {
    await this.db.execute(
      'UPDATE ai_projects SET is_active = ? WHERE project_key = ?',
      [isActive ? 1 : 0, projectKey],
    );
  }

  async rotateApiKey(projectKey: string, newHash: string, newPrefix: string): Promise<void> {
    await this.db.execute(
      'UPDATE ai_projects SET api_key_hash = ?, api_key_prefix = ? WHERE project_key = ?',
      [newHash, newPrefix, projectKey],
    );
  }

  private mapRow(row: RowDataPacket): Project {
    let allowedFeatures: string[] | null = null;
    const raw = row['allowed_features'];
    if (raw) {
      allowedFeatures = typeof raw === 'string' ? JSON.parse(raw) : raw;
    }
    return {
      projectId:       row['project_id'] as number,
      projectKey:      row['project_key'] as string,
      projectName:     row['project_name'] as string,
      isActive:        Boolean(row['is_active']),
      allowedFeatures,
    };
  }
}
