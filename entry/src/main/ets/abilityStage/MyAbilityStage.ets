import AbilityStage from '@ohos.app.ability.AbilityStage';
import { InternalPlugin, preInit, setLogEnabled } from '@umeng/analytics';
import { PushPlugin } from '@umeng/push';
import { UmengConfig } from '../config/UmengConfig';

setLogEnabled(true);

export default class MyAbilityStage extends AbilityStage {
  onCreate(): void {
    preInit({
      context: this.context.getApplicationContext(),
      enableLog: true,
      plugins: [
        new InternalPlugin(),
        new PushPlugin({
          appMessageSecret: UmengConfig.APP_MESSAGE_SECRET
        })
      ]
    });
  }
}
