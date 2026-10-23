import { Inject, Injectable } from '@nestjs/common';
import { desc, eq } from 'drizzle-orm';
import { DATABASE, type Database } from '../../../db/client';
import { users } from '../../users/internal/schema';
import type { Review } from './reviews.dto';
import { reviews } from './schema';

/** Отзывы о пользователе (A3): только чтение, новые сверху. Записи отзывов в приложении нет (seed). */
@Injectable()
export class ReviewsService {
  constructor(@Inject(DATABASE) private readonly db: Database) {}

  async listForUser(_viewerId: string, userId: string): Promise<Review[]> {
    const rows = await this.db
      .select({
        id: reviews.id,
        authorName: users.name,
        rating: reviews.rating,
        body: reviews.body,
        createdAt: reviews.createdAt,
      })
      .from(reviews)
      .innerJoin(users, eq(users.id, reviews.authorId))
      .where(eq(reviews.targetId, userId))
      .orderBy(desc(reviews.createdAt), desc(reviews.id));
    return rows.map((r) => ({ ...r, createdAt: r.createdAt.toISOString() }));
  }
}
