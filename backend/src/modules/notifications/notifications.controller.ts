import { Body, Controller, Get, Param, ParseIntPipe, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { Role } from '@prisma/client';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { NotificationsService } from './notifications.service';
import { CreateNotificationDto } from './dto/notification.dto';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('notifications')
export class NotificationsController {
  constructor(private notificationsService: NotificationsService) {}

  @Post()
  @Roles(Role.ADMIN)
  create(@Body() dto: CreateNotificationDto) {
    return this.notificationsService.create(dto);
  }

  // `studentId` narrows a parent's list to one child. The query stays scoped
  // to the caller's own rows, so naming someone else's child returns nothing.
  @Get('me')
  findAllForMe(
    @CurrentUser() user: any,
    @Query('studentId', new ParseIntPipe({ optional: true })) studentId?: number,
  ) {
    return this.notificationsService.findAllForUser(user.id, studentId);
  }

  @Get('me/unread')
  getUnreadCount(
    @CurrentUser() user: any,
    @Query('studentId', new ParseIntPipe({ optional: true })) studentId?: number,
  ) {
    return this.notificationsService.getUnreadCount(user.id, studentId);
  }

  @Post('me/read-all')
  markAllAsRead(
    @CurrentUser() user: any,
    @Query('studentId', new ParseIntPipe({ optional: true })) studentId?: number,
  ) {
    return this.notificationsService.markAllAsRead(user.id, studentId);
  }

  @Patch(':id/read')
  markAsRead(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: any) {
    return this.notificationsService.markAsRead(id, user.id);
  }
}
