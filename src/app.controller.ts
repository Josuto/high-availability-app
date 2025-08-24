import { Controller, Get, Inject } from '@nestjs/common';
import { AppService } from './app.service';
import { APP_INSTANCE_ID_TOKEN } from './constants';

@Controller()
export class AppController {
  constructor(
    private readonly appService: AppService, 
    @Inject(APP_INSTANCE_ID_TOKEN) private readonly appInstanceId: string) {}

  @Get()
  getHello(): string {
    return this.appService.getHello();
  }

  @Get('/health')
  checkHealth(): boolean {
    console.log(`Instance ID ${this.appInstanceId}: Health check OK`);
    return true;
  }
}
