import { ApiProperty } from '@nestjs/swagger';

/** Тело `POST /files` — multipart, поле `file` (≤ 10 МБ, `image/jpeg|png|webp`). */
export class FileUploadBody {
  @ApiProperty({ type: 'string', format: 'binary' })
  file!: unknown;
}

export class FileRef {
  @ApiProperty({ format: 'uuid' })
  id!: string;

  /** `/files/{id}`. */
  @ApiProperty()
  url!: string;
}

/** Байты файла для ответа `GET /files/{id}`. */
export interface StoredFile {
  mime: string;
  bytes: Buffer;
}
