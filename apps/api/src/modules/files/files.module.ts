import { Module } from '@nestjs/common';
import { FilesController } from './internal/files.controller';
import { FilesService } from './internal/files.service';

@Module({
  controllers: [FilesController],
  providers: [FilesService],
})
export class FilesModule {}
