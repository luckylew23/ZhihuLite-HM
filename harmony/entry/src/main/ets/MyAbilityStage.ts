// MyAbilityStage —— 应用级 AbilityStage，用于注入 RN OHOS 能力包。
import { AbilityStage, Want } from '@kit.AbilityKit';
import { RNAbilityPackage } from '@rnoh/react-native-openharmony';

export default class MyAbilityStage extends AbilityStage {
  configure() {
    this.context.getApplicationContext().setColorMode(0);
  }

  onCreate() {
    const abilityPackage = new RNAbilityPackage();
    this.context.abilityPackage = abilityPackage;
  }
}
