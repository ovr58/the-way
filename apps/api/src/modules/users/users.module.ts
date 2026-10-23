import { Module } from '@nestjs/common';
import { UsersController } from './internal/users.controller';
import { UsersService } from './internal/users.service';

@Module({
  controllers: [UsersController],
  providers: [UsersService],
})
export class UsersModule {}
