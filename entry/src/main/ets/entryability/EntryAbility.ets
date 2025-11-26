import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { DataService } from '../services/DataService';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
    
    // 应用主题设置
    await this.applyThemeMode();
  }

  /**
   * 应用主题模式设置
   */
  async applyThemeMode(): Promise<void> {
    try {
      // 初始化数据服务
      await DataService.getInstance().initialize(this.context);
      
      // 获取用户设置
      const settings = await DataService.getInstance().getSettings();
      
      // 根据设置应用主题模式
      let colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
      
      if (settings.themeMode === 'light') {
        colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
      } else if (settings.themeMode === 'dark') {
        colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
      } else {
        // 'system' - 跟随系统
        colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
      }
      
      this.context.getApplicationContext().setColorMode(colorMode);
      hilog.info(DOMAIN, 'testTag', 'Applied color mode: %{public}s (value: %{public}d)', 
        settings.themeMode, colorMode);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to apply theme mode. Cause: %{public}s', JSON.stringify(err));
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    // 数据服务已在onCreate中初始化，直接加载页面
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}