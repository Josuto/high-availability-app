import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { APP_INSTANCE_ID_TOKEN } from './constants';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  const appInstanceId = app.get(APP_INSTANCE_ID_TOKEN);
  console.log(`NestJS Application with Instance ID ${appInstanceId} Started`);

  await app.listen(process.env.PORT ?? 3000);
}
bootstrap();
