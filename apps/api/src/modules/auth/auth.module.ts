import { Module } from '@nestjs/common';
import { AuthController } from './internal/auth.controller';
import { AuthService } from './internal/auth.service';

@Module({
  controllers: [AuthController],
  providers: [AuthService],
})
export class AuthModule {}
