import { Body, Controller, Delete, Get, Param, ParseIntPipe, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { Role } from '@prisma/client';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { ManagerPermissionGuard } from '../../common/guards/manager-permission.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import {
  ManagerPermission,
  RequirePermission,
} from '../../common/decorators/permissions.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { UsersService } from './users.service';
import { CreateUserDto, UpdateMeDto, UpdateUserDto } from './dto/user.dto';

@UseGuards(JwtAuthGuard, RolesGuard, ManagerPermissionGuard)
@Controller('users')
export class UsersController {
  constructor(private usersService: UsersService) {}

  @Get('stats')
  @Roles(Role.ADMIN)
  getStats() { return this.usersService.getStats(); }

  @Get()
  @Roles(Role.ADMIN)
  findAll() { return this.usersService.findAll(); }

  @Get('me')
  getMe(@CurrentUser() user: any) {
    return this.usersService.findOne(user.id);
  }

  // Above @Get(':id') like 'me'. Open to whoever fills in account forms.
  @Get('contact-owners')
  @Roles(Role.ADMIN, Role.MANAGER)
  @RequirePermission(ManagerPermission.MANAGE_ACCOUNTS)
  contactOwners(
    @Query('phone') phone?: string,
    @Query('email') email?: string,
    @Query('excludeUserId') excludeUserId?: string,
  ) {
    const exclude = Number(excludeUserId);
    return this.usersService.contactOwners({
      phone,
      email,
      excludeUserId: Number.isInteger(exclude) && exclude > 0 ? exclude : undefined,
    });
  }

  @Get(':id')
  @Roles(Role.ADMIN)
  findOne(@Param('id', ParseIntPipe) id: number) { return this.usersService.findOne(id); }

  @Post()
  @Roles(Role.ADMIN)
  create(@Body() dto: CreateUserDto) { return this.usersService.create(dto); }

  // Declared above @Patch(':id') for the same reason @Get('me') sits above
  // @Get(':id'): otherwise Nest matches "me" as the id and ParseIntPipe 400s.
  //
  // ADMIN-only: changing account details is an administrator's job, and an
  // admin edits everyone else through the per-role forms. This route exists
  // because there is no admins-management page, so it is the only way an
  // admin can correct their own record. Passwords are separate — any role
  // changes its own through PATCH /auth/password.
  @Patch('me')
  @Roles(Role.ADMIN)
  updateMe(@CurrentUser() user: any, @Body() dto: UpdateMeDto) {
    return this.usersService.updateMe(user.id, dto);
  }

  @Patch(':id')
  @Roles(Role.ADMIN)
  update(@Param('id', ParseIntPipe) id: number, @Body() dto: UpdateUserDto) {
    return this.usersService.update(id, dto);
  }

  @Delete(':id')
  @Roles(Role.ADMIN)
  remove(@Param('id', ParseIntPipe) id: number) { return this.usersService.remove(id); }
}
