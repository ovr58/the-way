import {
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  StreamableFile,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import {
  ApiBearerAuth,
  ApiBody,
  ApiConsumes,
  ApiCreatedResponse,
  ApiOkResponse,
  ApiProduces,
  ApiTags,
} from '@nestjs/swagger';
import { requestUserId } from '../../../common/logger';
import { FileRef, FileUploadBody } from './files.dto';
import { FilesService } from './files.service';

@ApiTags('files')
@ApiBearerAuth()
@Controller()
export class FilesController {
  constructor(private readonly service: FilesService) {}

  @Post('files')
  @UseInterceptors(FileInterceptor('file'))
  @ApiConsumes('multipart/form-data')
  @ApiBody({ type: FileUploadBody })
  @ApiCreatedResponse({ type: FileRef })
  uploadFile(@UploadedFile() file: Express.Multer.File | undefined): Promise<FileRef> {
    return this.service.upload(requestUserId(), file);
  }

  @Get('files/:id')
  @ApiProduces('image/jpeg', 'image/png', 'image/webp')
  @ApiOkResponse({ schema: { type: 'string', format: 'binary' } })
  async getFile(@Param('id', ParseUUIDPipe) id: string): Promise<StreamableFile> {
    const stored = await this.service.read(requestUserId(), id);
    return new StreamableFile(stored.bytes, { type: stored.mime });
  }
}
