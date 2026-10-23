import { randomUUID } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { Inject, Injectable } from '@nestjs/common';
import { eq } from 'drizzle-orm';
import { AppError } from '../../../common/errors';
import { DATABASE, type Database } from '../../../db/client';
import type { FileRef, StoredFile } from './files.dto';
import { files } from './schema';

const MAX_BYTES = 10 * 1024 * 1024;
const EXTENSIONS: Record<string, string> = { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp' };

/** Каталог файлов: `FILES_DIR`, по умолчанию `data/files` в `apps/api` (строка `.gitignore` есть). */
function filesDir(): string {
  return process.env.FILES_DIR || resolve(__dirname, '../../../../data/files');
}

/**
 * Загрузка и выдача изображений (A3). Размер (`file_too_large`) и тип (`file_type`) проверяет
 * сервис: у перехватчика multer предела нет. `file` — `undefined`, если поле не пришло.
 */
@Injectable()
export class FilesService {
  constructor(@Inject(DATABASE) private readonly db: Database) {}

  async upload(viewerId: string, file: Express.Multer.File | undefined): Promise<FileRef> {
    if (!file) throw new AppError('validation', 'Нет поля file');
    const extension = EXTENSIONS[file.mimetype];
    if (!extension) throw new AppError('file_type', 'Допустимы jpeg, png, webp');
    if (file.buffer.length > MAX_BYTES) throw new AppError('file_too_large', 'Файл больше 10 МБ');

    const id = randomUUID();
    const path = `${id}.${extension}`;
    const dir = filesDir();
    await mkdir(dir, { recursive: true });
    await writeFile(resolve(dir, path), file.buffer);
    await this.db.insert(files).values({ id, ownerId: viewerId, mime: file.mimetype, path, size: file.buffer.length });
    return { id, url: `/files/${id}` };
  }

  /** Читает любой вошедший: фото водителя и авто видят пассажиры. */
  async read(_viewerId: string, fileId: string): Promise<StoredFile> {
    const [row] = await this.db.select().from(files).where(eq(files.id, fileId));
    if (!row) throw new AppError('not_found', 'Файл не найден');
    try {
      return { mime: row.mime, bytes: await readFile(resolve(filesDir(), row.path)) };
    } catch {
      throw new AppError('not_found', 'Файл не найден');
    }
  }
}
