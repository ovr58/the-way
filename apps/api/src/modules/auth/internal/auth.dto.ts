import { ApiProperty } from '@nestjs/swagger';
import { IsString } from 'class-validator';
import { Me } from '../../../common/forms';

/** Номер в любой записи: сервис приводит его `normalizePhone` к E.164 или отвечает `validation`. */
export class RequestCodeBody {
  @ApiProperty({ example: '+375 25 777 44 20' })
  @IsString()
  phone!: string;
}

export class RequestCodeResult {
  @ApiProperty({ type: 'integer', example: 60 })
  resendAfterSec!: number;
}

export class VerifyBody {
  @ApiProperty({ example: '+375 25 777 44 20' })
  @IsString()
  phone!: string;

  @ApiProperty({ example: '111111' })
  @IsString()
  code!: string;
}

export class VerifyResult {
  @ApiProperty()
  token!: string;

  /** `users.name IS NULL`. */
  @ApiProperty()
  isNew!: boolean;

  @ApiProperty({ type: Me })
  me!: Me;
}

export class HealthResult {
  @ApiProperty()
  ok!: boolean;
}
