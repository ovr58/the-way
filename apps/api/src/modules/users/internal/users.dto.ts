import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsInt, IsNotEmpty, IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';
import { COMPLAINT_STATUSES, USER_MODES, type ComplaintStatus, type UserMode } from '../../../common/enums';

/** `PATCH /me` — только названные поля; `mode` переключает режим («Профиль - сменить режим»). */
export class PatchMeBody {
  @ApiPropertyOptional({ type: String, nullable: true })
  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  name?: string | null;

  @ApiPropertyOptional({ type: String, format: 'uuid', nullable: true })
  @IsOptional()
  @IsUUID()
  photoFileId?: string | null;

  @ApiPropertyOptional({ type: 'integer', nullable: true })
  @IsOptional()
  @IsInt()
  cityId?: number | null;

  @ApiPropertyOptional({ enum: USER_MODES, enumName: 'UserMode', nullable: true })
  @IsOptional()
  @IsIn(USER_MODES)
  mode?: UserMode | null;
}

export class Complaint {
  @ApiProperty({ format: 'uuid' })
  id!: string;

  @ApiProperty()
  reason!: string;

  @ApiProperty({ enum: COMPLAINT_STATUSES, enumName: 'ComplaintStatus' })
  status!: ComplaintStatus;

  @ApiProperty({ type: String, format: 'date-time' })
  createdAt!: string;
}
