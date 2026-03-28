import { app } from 'electron';
import fs from 'node:fs/promises';
import path from 'node:path';

export class JsonStore<T> {
  constructor(
    private readonly fileName: string,
    private readonly fallback: () => T
  ) {}

  private get filePath(): string {
    return path.join(app.getPath('userData'), this.fileName);
  }

  async read(): Promise<T> {
    try {
      const raw = await fs.readFile(this.filePath, 'utf8');
      return JSON.parse(raw) as T;
    } catch {
      return this.fallback();
    }
  }

  async write(value: T): Promise<void> {
    const filePath = this.filePath;
    const directory = path.dirname(filePath);
    const tempPath = `${filePath}.tmp`;

    await fs.mkdir(directory, { recursive: true });
    await fs.writeFile(tempPath, JSON.stringify(value, null, 2), 'utf8');
    await fs.rename(tempPath, filePath);
  }
}
