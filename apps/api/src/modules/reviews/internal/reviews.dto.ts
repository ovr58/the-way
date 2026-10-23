import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class Review {
  @ApiProperty({ format: 'uuid' })
  id!: string;

  @ApiPropertyOptional({ type: String, nullable: true })
  authorName?: string | null;

  @ApiProperty({ type: 'integer' })
  rating!: number;

  @ApiPropertyOptional({ type: String, nullable: true })
  body?: string | null;

  @ApiProperty({ type: String, format: 'date-time' })
  createdAt!: string;
}
