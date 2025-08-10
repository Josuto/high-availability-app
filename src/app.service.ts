import { Injectable } from '@nestjs/common';

@Injectable()
export class AppService {
  getHello(): string {
    console.log("Return 'hello world' from the app service");
    return 'Hello World!';
  }
}
