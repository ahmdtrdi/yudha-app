import { BadRequestException, ConflictException } from '@nestjs/common';
import { ApiExceptionFilter } from './api-exception.filter';

describe('ApiExceptionFilter stable envelope', () => {
  it.each([
    [new BadRequestException('invalid input'), 400, 'VALIDATION_FAILED'],
    [
      new ConflictException('IDEMPOTENCY_KEY_REUSED'),
      409,
      'IDEMPOTENCY_KEY_REUSED',
    ],
  ])('maps %p to a stable error code', (exception, status, code) => {
    const json = jest.fn();
    const statusMethod = jest.fn().mockReturnValue({ json });
    const setHeader = jest.fn();
    const host = {
      switchToHttp: () => ({
        getResponse: () => ({ status: statusMethod, setHeader }),
        getRequest: () => ({ headers: { 'x-request-id': 'request-1' } }),
      }),
    };
    new ApiExceptionFilter().catch(exception, host as any);
    expect(statusMethod).toHaveBeenCalledWith(status);
    expect(json).toHaveBeenCalledWith({
      error: {
        code,
        message:
          code === 'IDEMPOTENCY_KEY_REUSED'
            ? 'Kunci idempotensi sudah digunakan untuk permintaan yang berbeda.'
            : exception.message,
        details: {},
        requestId: 'request-1',
      },
    });
  });
});
