import { ExceptionFilter, Catch, ArgumentsHost, HttpStatus } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { Response } from 'express';

@Catch(Prisma.PrismaClientKnownRequestError)
export class PrismaClientExceptionFilter implements ExceptionFilter {
  catch(exception: Prisma.PrismaClientKnownRequestError, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();

    if (exception.code === 'P2002') {
      const target = (exception.meta?.target as string[] | string) || '';
      const targetStr = Array.isArray(target) ? target.join(',') : String(target);

      let message = 'قيمة حقل محدد مستخدمة بالفعل';
      if (targetStr.includes('phone') || targetStr.includes('users_phone_key')) {
        message = 'رقم الهاتف مستخدم بالفعل';
      } else if (targetStr.includes('email') || targetStr.includes('users_email_key')) {
        message = 'البريد الإلكتروني مستخدم بالفعل';
      }

      return response.status(HttpStatus.CONFLICT).json({
        statusCode: HttpStatus.CONFLICT,
        message,
        error: 'Conflict',
      });
    }

    return response.status(HttpStatus.BAD_REQUEST).json({
      statusCode: HttpStatus.BAD_REQUEST,
      message: exception.message,
      error: 'Bad Request',
    });
  }
}
