import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { Role } from '@prisma/client';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { HalaqaAccessGuard } from '../../common/guards/halaqa-access.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { HalaqaFrom } from '../../common/decorators/halaqa-source.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { HalaqaAnnouncementsService } from './halaqa-announcements.service';
import { TeacherNewsGuard } from './teacher-news.guard';
import type { ScopedUser } from '../../common/guards/halaqa-scope';
import {
  CreateAllHalaqasAnnouncementDto,
  CreateHalaqaAnnouncementDto,
  UpdateHalaqaAnnouncementDto,
} from './dto/halaqa-announcement.dto';

/** Every role that may read announcements — see the controller spec. */
const READERS = [
  Role.ADMIN,
  Role.MANAGER,
  Role.TEACHER,
  Role.PARENT,
  Role.STUDENT,
  Role.ADULT_STUDENT,
] as const;

/**
 * Who may post, edit and delete. A teacher only with the admin's
 * `canPostNews` grant (TeacherNewsGuard), only on their own halaqas
 * (HalaqaAccessGuard), and only their own posts (the service).
 */
const WRITERS = [Role.ADMIN, Role.MANAGER, Role.TEACHER] as const;

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('halaqa-announcements')
export class HalaqaAnnouncementsController {
  constructor(private service: HalaqaAnnouncementsService) {}

  // Declared before any ':id'-shaped route would be, so the literal wins.
  @Get('mine')
  @Roles(...READERS)
  findMine(@CurrentUser() user: { role: string; id: number }) {
    return this.service.findMine(user);
  }

  @Get('halaqa/:id')
  @Roles(...READERS)
  @HalaqaFrom('param')
  @UseGuards(HalaqaAccessGuard)
  findByHalaqa(@Param('id', ParseIntPipe) id: number) {
    return this.service.findByHalaqa(id);
  }

  @Post()
  @Roles(...WRITERS)
  @HalaqaFrom('body')
  @UseGuards(TeacherNewsGuard, HalaqaAccessGuard)
  create(
    @Body() dto: CreateHalaqaAnnouncementDto,
    @CurrentUser() user: { id: number },
  ) {
    return this.service.create(dto, user.id);
  }

  // No access guard, like `mine`: there is no one halaqa to check. The
  // service picks the halaqas from the caller's own scope instead.
  @Post('all')
  @Roles(...WRITERS)
  @UseGuards(TeacherNewsGuard)
  createForAll(
    @Body() dto: CreateAllHalaqasAnnouncementDto,
    @CurrentUser() user: ScopedUser & { id: number },
  ) {
    return this.service.createForAll(dto, user);
  }

  @Patch(':id')
  @Roles(...WRITERS)
  @HalaqaFrom('announcement')
  @UseGuards(TeacherNewsGuard, HalaqaAccessGuard)
  update(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateHalaqaAnnouncementDto,
    @CurrentUser() user: ScopedUser & { id: number },
  ) {
    return this.service.update(id, dto, user);
  }

  @Delete(':id')
  @Roles(...WRITERS)
  @HalaqaFrom('announcement')
  @UseGuards(TeacherNewsGuard, HalaqaAccessGuard)
  remove(
    @Param('id', ParseIntPipe) id: number,
    @CurrentUser() user: ScopedUser & { id: number },
  ) {
    return this.service.remove(id, user);
  }
}
