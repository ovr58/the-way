import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { IsIn, IsInt, IsNotEmpty, IsOptional, IsString, IsUUID, MaxLength, Min } from 'class-validator';
import { CAR_DOCUMENT_KINDS, VEHICLE_KINDS, type CarDocumentKind, type VehicleKind } from '../../../common/enums';

export class CarInput {
  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  brand!: string;

  /** Модель из каталога или «Другая модель» — свободный ввод 1–40 символов. */
  @ApiProperty({ maxLength: 40 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  model!: string;

  @ApiProperty({ enum: VEHICLE_KINDS, enumName: 'VehicleKind' })
  @IsIn(VEHICLE_KINDS)
  kind!: VehicleKind;

  @ApiProperty({ type: 'integer' })
  @IsInt()
  @Min(1)
  seats!: number;

  /** Госномер (поле «Госномер» добавляет U5.3 — в кадрах его нет). */
  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  plate!: string;

  @ApiPropertyOptional({ type: String, format: 'uuid', nullable: true })
  @IsOptional()
  @IsUUID()
  photoFileId?: string | null;
}

/** Правка авто («Транспортные средства»): поля `CarInput`, все необязательные; проверки те же. */
export class CarPatch extends PartialType(CarInput) {}

export class CarDocumentInput {
  @ApiProperty({ format: 'uuid' })
  @IsUUID()
  fileId!: string;

  @ApiProperty({ enum: CAR_DOCUMENT_KINDS, enumName: 'CarDocumentKind' })
  @IsIn(CAR_DOCUMENT_KINDS)
  kind!: CarDocumentKind;
}
