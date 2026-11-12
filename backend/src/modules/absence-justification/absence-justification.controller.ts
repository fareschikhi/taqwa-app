import {
  Body,
  Controller,
  ForbiddenException,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { Role } from '@prisma/client';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { AbsenceJustificationService } from './absence-justification.service';
import {
  CreateAbsenceJustificationDto,
  UpdateAbsenceJustificationDto,
} from './dto/absence-justification.dto';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('absence-justifications')
export class AbsenceJustificationController {
  constructor(
    private absenceJustificationService: AbsenceJustificationService,
  ) {}

  @Get()
  @Roles(Role.ADMIN, Role.MANAGER)
  findAll(
    @CurrentUser() user: AuthUser,
    @Query('managerId') managerId?: string,
    @Query('studentId') studentId?: string,
  ) {
    return this.absenceJustificationService.findAll(
      ownManagerId(user) ?? (managerId ? parseInt(managerId) : undefined),
      studentId ? parseInt(studentId) : undefined,
    );
  }

  // Declared before @Get(':id') so 'unjustified' isn't parsed as an id.
  // An admin may leave managerId out to see every halaqa at once.
  @Get('unjustified')
  @Roles(Role.ADMIN, Role.MANAGER)
  findUnjustified(
    @CurrentUser() user: AuthUser,
    @Query('managerId', new ParseIntPipe({ optional: true }))
    managerId?: number,
  ) {
    return this.absenceJustificationService.findUnjustified(
      ownManagerId(user) ?? managerId,
    );
  }

  @Get(':id')
  @Roles(Role.ADMIN, Role.MANAGER)
  findOne(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.absenceJustificationService.findOne(id, ownManagerId(user));
  }

  @Post()
  @Roles(Role.ADMIN, Role.MANAGER)
  create(
    @CurrentUser() user: AuthUser,
    @Body() dto: CreateAbsenceJustificationDto,
  ) {
    const own = ownManagerId(user);
    return this.absenceJustificationService.create(
      own === undefined ? dto : { ...dto, managerId: own },
      own,
    );
  }

  @Patch(':id')
  @Roles(Role.ADMIN, Role.MANAGER)
  update(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateAbsenceJustificationDto,
  ) {
    return this.absenceJustificationService.update(id, dto, ownManagerId(user));
  }
}

/// The part of request.user (built in AuthService.validateUser) read here.
type AuthUser = { role: Role; manager?: { id: number } | null };

/// The manager row a signed-in manager is pinned to, whatever id the request
/// names: a client-sent managerId is never trusted for a manager. Undefined
/// for an admin, who may look at any manager or none.
function ownManagerId(user: AuthUser): number | undefined {
  if (user.role === Role.ADMIN) return undefined;
  if (!user.manager) throw new ForbiddenException('حساب المدير غير مكتمل');
  return user.manager.id;
}
