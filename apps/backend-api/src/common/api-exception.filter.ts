import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import type { Request, Response } from 'express';

@Catch()
export class ApiExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost) {
    const response = host.switchToHttp().getResponse<Response>();
    const request = host.switchToHttp().getRequest<Request>();
    const status =
      exception instanceof HttpException
        ? exception.getStatus()
        : HttpStatus.INTERNAL_SERVER_ERROR;
    const rawMessage = this.message(exception, status);
    const code = this.code(rawMessage, status);
    const message =
      code === 'IDEMPOTENCY_KEY_REUSED'
        ? 'Kunci idempotensi sudah digunakan untuk permintaan yang berbeda.'
        : rawMessage;
    const requestId =
      this.header(request.headers['x-request-id']) ?? randomUUID();
    response.setHeader('x-request-id', requestId);
    response.status(status).json({
      error: {
        code,
        message,
        details: {},
        requestId,
      },
    });
  }

  private message(exception: unknown, status: number): string {
    if (!(exception instanceof HttpException)) {
      return 'Internal server error.';
    }
    const value = exception.getResponse();
    if (typeof value === 'string') return value;
    if (value && typeof value === 'object' && 'message' in value) {
      const message = (value as { message: unknown }).message;
      return Array.isArray(message) ? message.join('; ') : String(message);
    }
    return status === 500 ? 'Internal server error.' : exception.message;
  }

  private code(message: string, status: number): string {
    if (message.includes('IDEMPOTENCY_KEY_REUSED')) {
      return 'IDEMPOTENCY_KEY_REUSED';
    }
    if (message.includes('ACTION_REJECTED')) return 'ACTION_REJECTED';
    if (message.includes('FEATURE_DISABLED')) return 'FEATURE_DISABLED';
    if (status === HttpStatus.BAD_REQUEST) return 'VALIDATION_FAILED';
    if (status === HttpStatus.UNAUTHORIZED) return 'AUTH_REQUIRED';
    if (status === HttpStatus.FORBIDDEN) return 'FORBIDDEN';
    if (status === HttpStatus.NOT_FOUND) return 'NOT_FOUND';
    if (status === HttpStatus.CONFLICT) return 'CONFLICT';
    return 'INTERNAL_ERROR';
  }

  private header(value: string | string[] | undefined): string | null {
    const selected = Array.isArray(value) ? value[0] : value;
    if (!selected) return null;
    const normalized = selected.trim();
    return normalized.length > 0 && normalized.length <= 160
      ? normalized
      : null;
  }
}
