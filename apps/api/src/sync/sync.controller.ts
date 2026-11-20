import {
  Body,
  Controller,
  Get,
  HttpCode,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard, CurrentAccount } from '../auth/auth.guard';
import type { TokenPayload } from '../auth/auth.service';
import {
  PullQueryDto,
  PushDto,
  type PullResult,
  type PushResult,
} from './sync.dto';
import { SyncService } from './sync.service';

@Controller('sync')
@UseGuards(AuthGuard)
export class SyncController {
  constructor(private readonly sync: SyncService) {}

  @Post('push')
  @HttpCode(200)
  push(
    @CurrentAccount() account: TokenPayload,
    @Body() dto: PushDto,
  ): Promise<PushResult> {
    return this.sync.push(account.sub, dto.rows);
  }

  @Get('pull')
  pull(
    @CurrentAccount() account: TokenPayload,
    @Query() query: PullQueryDto,
  ): Promise<PullResult> {
    return this.sync.pull(account.sub, query.since, query.limit);
  }
}
