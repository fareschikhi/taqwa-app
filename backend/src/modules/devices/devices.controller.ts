import { Body, Controller, Delete, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { DevicesService } from './devices.service';
import { RegisterDeviceDto } from './dto/device.dto';

/**
 * No @Roles decorator: every signed-in role carries a device, and a device is
 * always claimed by the caller rather than named in the request.
 */
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('devices')
export class DevicesController {
  constructor(private devices: DevicesService) {}

  @Post('token')
  register(@CurrentUser() user: any, @Body() dto: RegisterDeviceDto) {
    return this.devices.register(user.id, dto.token, dto.platform ?? 'android');
  }

  @Delete('token')
  unregister(@CurrentUser() user: any, @Body() dto: RegisterDeviceDto) {
    return this.devices.unregister(user.id, dto.token);
  }
}
