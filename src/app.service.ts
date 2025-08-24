import { Inject, Injectable } from '@nestjs/common';
import { APP_INSTANCE_ID_TOKEN } from './constants';

@Injectable()
export class AppService {
  constructor(@Inject(APP_INSTANCE_ID_TOKEN) private readonly appInstanceId: string) {}

  getHello(): string {
    console.log(`Instance ID ${this.appInstanceId}: Return 'hello world'`);
    return 'Hello World!';
  }
}
