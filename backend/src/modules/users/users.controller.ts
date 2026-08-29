import { Body, Controller, Delete, Get, Param, ParseIntPipe, Patch, Post, UseGuards } from '@nestjs/common';
import { Role } from '@prisma/client';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { UsersService } from './users.service';
import { CreateUserDto, UpdateMeDto, UpdateUserDto } from './dto/user.dto';

@UseGuards(JwtAuthGuard, RolesGuard)
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
