import { Inject, Injectable } from '@nestjs/common';
import { and, desc, eq } from 'drizzle-orm';
import { AppError } from '../../../common/errors';
import type { Me, UserBrief } from '../../../common/forms';
import { logEvent } from '../../../common/logger';
import { meView, userBrief } from '../../../common/views';
import { DATABASE, type Database } from '../../../db/client';
import { cities } from '../../cities/internal/schema';
import { files } from '../../files/internal/schema';
import { complaints } from '../../reviews/internal/schema';
import type { Complaint, PatchMeBody } from './users.dto';
import { users } from './schema';

/** Профиль, публичная карточка, жалобы (A3.1). */
@Injectable()
export class UsersService {
  constructor(@Inject(DATABASE) private readonly db: Database) {}

  async getMe(viewerId: string): Promise<Me> {
    const me = await meView(this.db, viewerId);
    if (!me) throw new AppError('not_found', 'Пользователь не найден');
    return me;
  }

  async patchMe(viewerId: string, body: PatchMeBody): Promise<Me> {
    // `null` ≡ поле не прислано (клиент шлёт все четыре поля): не менять.
    if (body.cityId != null) {
      const [city] = await this.db.select({ id: cities.id }).from(cities).where(eq(cities.id, body.cityId));
      if (!city) throw new AppError('validation', 'Город не найден');
    }
    if (body.photoFileId != null) {
      const [file] = await this.db
        .select({ id: files.id })
        .from(files)
        .where(and(eq(files.id, body.photoFileId), eq(files.ownerId, viewerId)));
      if (!file) throw new AppError('validation', 'Файл не найден');
    }

    const changes: Partial<typeof users.$inferInsert> = {};
    const fields: string[] = [];
    if (body.name != null) (changes.name = body.name), fields.push('name');
    if (body.photoFileId != null) (changes.photoFileId = body.photoFileId), fields.push('photoFileId');
    if (body.cityId != null) (changes.cityId = body.cityId), fields.push('cityId');
    if (body.mode != null) (changes.currentMode = body.mode), fields.push('mode');
    if (fields.length > 0) {
      await this.db.update(users).set(changes).where(eq(users.id, viewerId));
      logEvent('profile_updated', { fields });
    }
    return this.getMe(viewerId);
  }

  async getPublic(viewerId: string, userId: string): Promise<UserBrief> {
    const [brief] = await userBrief(this.db, [userId], { viewerId });
    if (!brief) throw new AppError('not_found', 'Пользователь не найден');
    return brief;
  }

  /** «Жалобы» профиля — полученные пользователем, новые сверху. */
  async myComplaints(viewerId: string): Promise<Complaint[]> {
    const rows = await this.db
      .select()
      .from(complaints)
      .where(eq(complaints.targetId, viewerId))
      .orderBy(desc(complaints.createdAt), desc(complaints.id));
    return rows.map((c) => ({ id: c.id, reason: c.reason, status: c.status, createdAt: c.createdAt.toISOString() }));
  }
}
