import { Controller, Get, Param, ParseUUIDPipe } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { requestUserId } from '../../../common/logger';
import { Review } from './reviews.dto';
import { ReviewsService } from './reviews.service';

@ApiTags('reviews')
@ApiBearerAuth()
@Controller()
export class ReviewsController {
  constructor(private readonly service: ReviewsService) {}

  @Get('users/:id/reviews')
  @ApiOkResponse({ type: [Review] })
  listUserReviews(@Param('id', ParseUUIDPipe) id: string): Promise<Review[]> {
    return this.service.listForUser(requestUserId(), id);
  }
}
