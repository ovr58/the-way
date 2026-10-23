/**
 * Фото seed (IM.2): аватары пользователей, фото авто и образцы СТС из `seed/data/media`
 * загружаются тем же методом, что `POST /files` (`FilesService.upload`), и привязываются к профилю
 * (`PATCH /me`), к авто (`POST /cars`) и к документам авто (`POST /cars/{id}/documents`) — `seed/index.ts`. Источники и лицензии — `seed/data/media/README.md`.
 * Каталог `FILES_DIR` seed очищает: после `truncate` таблицы `files` в нём остаются только
 * осиротевшие файлы.
 */
import { mkdir, readFile, readdir, rm } from 'node:fs/promises';
import { extname, resolve } from 'node:path';
import type { FilesService } from '../src/modules/files/internal/files.service';

const MIME: Record<string, string> = { '.jpg': 'image/jpeg', '.png': 'image/png', '.webp': 'image/webp' };
const MEDIA_DIR = resolve(__dirname, 'data/media');

/** Телефон пользователя → файл аватара. */
export const AVATARS: Record<string, string> = {
  '+79000000001': 'avatar-alexey.webp',
  '+79000000002': 'avatar-maria.webp',
  '+79000000003': 'avatar-dmitry.webp',
  '+79000000004': 'avatar-sergey.webp',
  '+79000000005': 'avatar-nikolay.webp',
  '+79000000006': 'avatar-igor.jpg',
  '+79000000007': 'avatar-elena.jpg',
  '+79000000008': 'avatar-roman.jpg',
  '+79000000011': 'avatar-ivan.webp',
  '+79000000012': 'avatar-olga.jpg',
};
/** Госномер авто → файл фото. */
export const CAR_PHOTOS: Record<string, string> = {
  'А111АА76': 'car-vesta.jpg',
  'В222ВВ76': 'car-solaris.jpg',
  'Е333ЕЕ76': 'car-rio.jpg',
  'К444КК76': 'car-octavia.jpg',
  'М555ММ76': 'bus-gazelle-next.jpg',
  'Р777РР76': 'bus-paz-vector-next.jpg',
  'С999СС76': 'car-camry.jpg',
  'Н888НН76': 'car-polo.jpg',
  'Т666ТТ76': 'car-rapid.jpg',
};
/** Госномер авто → образец СТС (`tools/make-sts-samples.ps1`). */
export const CAR_STS: Record<string, string> = {
  'А111АА76': 'sts-vesta.png',
  'В222ВВ76': 'sts-solaris.png',
  'Е333ЕЕ76': 'sts-rio.png',
  'К444КК76': 'sts-octavia.png',
  'М555ММ76': 'sts-gazelle.png',
  'Р777РР76': 'sts-paz.png',
  'С999СС76': 'sts-camry.png',
  'Н888НН76': 'sts-polo.png',
  'Т666ТТ76': 'sts-rapid.png',
};

/** `FILES_DIR`, по умолчанию `apps/api/data/files` — как в `files.service.ts`. */
function filesDir(): string {
  return process.env.FILES_DIR || resolve(__dirname, '../data/files');
}

/** Очищает каталог файлов seed. */
export async function clearFilesDir(): Promise<void> {
  const dir = filesDir();
  await mkdir(dir, { recursive: true });
  for (const entry of await readdir(dir)) await rm(resolve(dir, entry), { recursive: true, force: true });
}

/** Загружает файл из `seed/data/media` от имени владельца; возвращает id файла. */
export async function uploadMedia(files: FilesService, ownerId: string, name: string): Promise<string> {
  const buffer = await readFile(resolve(MEDIA_DIR, name));
  const file = { fieldname: 'file', originalname: name, mimetype: MIME[extname(name)], size: buffer.length, buffer };
  const ref = await files.upload(ownerId, file as Express.Multer.File);
  return ref.id;
}
