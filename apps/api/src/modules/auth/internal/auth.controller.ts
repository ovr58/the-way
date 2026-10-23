import { Body, Controller, Get, Headers, HttpCode, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiNoContentResponse, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { HealthResult, RequestCodeBody, RequestCodeResult, VerifyBody, VerifyResult } from './auth.dto';
import { AuthService } from './auth.service';

@ApiTags('auth')
@Controller()
export class AuthController {
  constructor(private readonly service: AuthService) {}

  @Post('auth/request-code')
  @HttpCode(200)
  @ApiOkResponse({ type: RequestCodeResult })
  requestCode(@Body() body: RequestCodeBody): Promise<RequestCodeResult> {
    return this.service.requestCode(body);
  }

  @Post('auth/verify')
  @HttpCode(200)
  @ApiOkResponse({ type: VerifyResult })
  verify(@Body() body: VerifyBody): Promise<VerifyResult> {
    return this.service.verify(body);
  }

  @Post('auth/logout')
  @HttpCode(204)
  @ApiBearerAuth()
  @ApiNoContentResponse()
  logout(@Headers('authorization') authorization: string | undefined): Promise<void> {
    return this.service.logout(authorization);
  }

  @Get('health')
  @ApiOkResponse({ type: HealthResult })
  health(): Promise<HealthResult> {
    return this.service.health();
  }
}
