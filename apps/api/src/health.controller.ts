import { Controller, Get } from '@nestjs/common';

/// La app lo usa para comprobar que la dirección configurada es este
/// servidor antes de iniciar sesión.
@Controller('health')
export class HealthController {
  @Get()
  check(): { status: 'ok'; service: 'anfybio' } {
    return { status: 'ok', service: 'anfybio' };
  }
}
