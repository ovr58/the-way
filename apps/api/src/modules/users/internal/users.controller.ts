import { Body, Controller, Get, Param, ParseUUIDPipe, Patch } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { Me, UserBrief } from '../../../common/forms';
import { requestUserId } from '../../../common/logger';
import { Complaint, PatchMeBody } from './users.dto';
import { UsersService } from './users.service';

@ApiTags('users')
@ApiBearerAuth()
@Controller()
export class UsersController {
  constructor(private readonly service: UsersService) {}

  @Get('me')
  @ApiOkResponse({ type: Me })
  getMe(): Promise<Me> {
    return this.service.getMe(requestUserId());
  }

  @Patch('me')
  @ApiOkResponse({ type: Me })
  patchMe(@Body() body: PatchMeBody): Promise<Me> {
    return this.service.patchMe(requestUserId(), body);
  }

  @Get('me/complaints')
  @ApiOkResponse({ type: [Complaint] })
  myComplaints(): Promise<Complaint[]> {
    return this.service.myComplaints(requestUserId());
  }

  @Get('users/:id/public')
  @ApiOkResponse({ type: UserBrief })
  getPublicUser(@Param('id', ParseUUIDPipe) id: string): Promise<UserBrief> {
    return this.service.getPublic(requestUserId(), id);
  }
}
