import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { randomUUID } from 'crypto';
import { APP_INSTANCE_ID_TOKEN } from './constants';

@Module({
  imports: [],
  controllers: [AppController],
  providers: [
    AppService,
    {
      provide: APP_INSTANCE_ID_TOKEN,
      useValue: randomUUID(), // Generate the ID using crypto
    },
  ],
})
export class AppModule {}
