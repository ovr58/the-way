import { Module } from '@nestjs/common';
import { ReviewsController } from './internal/reviews.controller';
import { ReviewsService } from './internal/reviews.service';

@Module({
  controllers: [ReviewsController],
  providers: [ReviewsService],
})
export class ReviewsModule {}
