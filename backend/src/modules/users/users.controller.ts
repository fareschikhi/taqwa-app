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
  // No @Roles — every signed-in role may edit its own account, and the id
  // comes from the token rather than the URL.
  @Patch('me')
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
