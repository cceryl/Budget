import { Settings } from '../models/Settings';
import { DataService } from '../services/DataService';
import { picker } from '@kit.CoreFileKit';
import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { common, ConfigurationConstant } from '@kit.AbilityKit';

/**
 * 设置项组件
 */
@Component
struct SettingItemView {
  @Prop title: string = '';
  @Prop value: string = '';
  onItemClick: (() => void) | null = null;

  build() {
    Row() {
      Text(this.title)
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)

      if (this.value !== '') {
        Text(this.value)
          .fontSize(14)
          .fontColor($r('app.color.text_tertiary'))
          .margin({ right: 8 })
      }

      if (this.onItemClick !== null) {
        Text('›')
          .fontSize(20)
          .fontColor($r('app.color.text_disabled'))
      }
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.card_background'))
    .onClick(() => {
      if (this.onItemClick !== null) {
        this.onItemClick();
      }
    })
  }
}

/**
 * 危险操作设置项组件
 */
@Component
struct SettingItemDangerView {
  @Prop title: string = '';
  onItemClick: () => void = () => {};

  build() {
    Row() {
      Text(this.title)
        .fontSize(16)
        .fontColor($r('app.color.accent_danger'))
        .layoutWeight(1)
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.card_background'))
    .onClick(this.onItemClick)
  }
}

@Component
export struct SettingsPage {
  @State settings: Settings = Settings.getDefault();
  @State themeModeDisplay: string = '跟随系统';
  @State currencyDisplay: string = '人民币 (¥)';
  @State defaultPageDisplay: string = '明细';
  @State showThemeDialog: boolean = false;
  @State showCurrencyDialog: boolean = false;
  @State showDefaultPageDialog: boolean = false;
  @State showAboutDialog: boolean = false;
  @State showConfirmClearDialog: boolean = false;
  @Prop @Watch('onRefreshTriggerChange') refreshTrigger: number = 0;
  private dataService: DataService = DataService.getInstance();
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;

  aboutToAppear(): void {
    this.loadSettings();
  }

  onRefreshTriggerChange(): void {
    this.loadSettings();
  }

  async loadSettings(): Promise<void> {
    const loadedSettings = await this.dataService.getSettings();

    // 创建新实例以触发UI更新
    this.settings = new Settings(
      loadedSettings.themeMode,
      loadedSettings.currency,
      loadedSettings.defaultPage,
      loadedSettings.language
    );
    // 更新显示文本
    this.themeModeDisplay = this.settings.getThemeModeDisplayName();
    this.currencyDisplay = this.settings.getCurrencyDisplayName();
    this.defaultPageDisplay = this.settings.getDefaultPageDisplayName();
  }

  async updateSettings(): Promise<void> {
    await this.dataService.saveSettings(this.settings);
    
    // 应用主题模式
    this.applyThemeMode();
    
    // 保存后重新加载以确保状态同步
    await this.loadSettings();
  }

  /**
   * 应用主题模式
   */
  applyThemeMode(): void {
    try {
      let colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
      
      if (this.settings.themeMode === 'light') {
        colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
      } else if (this.settings.themeMode === 'dark') {
        colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
      } else {
        // 'system' - 跟随系统
        colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
      }
      
      // 使用动画上下文包装颜色模式切换
      animateTo({
        duration: 300,
        curve: Curve.EaseInOut
      }, () => {
        this.context.getApplicationContext().setColorMode(colorMode);
      });
      
      console.info('[SettingsPage] Applied color mode:', this.settings.themeMode, colorMode);
    } catch (err) {
      console.error('[SettingsPage] Failed to apply theme mode:', JSON.stringify(err));
      this.showToast('主题切换失败');
    }
  }

  async handleExportCSV(): Promise<void> {
    try {
      const csv = await this.dataService.exportTransactionsCSV();
      if (csv === '') {
        this.showToast('导出失败');
        return;
      }

      // 生成文件名
      const timestamp = new Date().getTime();
      const fileName = `budget_transactions_${timestamp}.csv`;

      // 使用文件选择器保存文件
      try {
        const documentSaveOptions = new picker.DocumentSaveOptions();
        documentSaveOptions.newFileNames = [fileName];
        const documentPicker = new picker.DocumentViewPicker();
        const uris = await documentPicker.save(documentSaveOptions);
        if (uris && uris.length > 0) {
          const file = fileIo.openSync(uris[0], fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE);
          fileIo.writeSync(file.fd, csv);
          fileIo.closeSync(file);
          this.showToast('导出成功');
        }
      } catch (err) {
        console.error('Save CSV failed:', err);
        this.showToast('导出失败');
      }
    } catch (err) {
      console.error('Export CSV failed:', err);
      this.showToast('导出失败');
    }
  }

  async handleBackup(): Promise<void> {
    try {
      const jsonData = await this.dataService.exportAllData();
      if (jsonData === '') {
        this.showToast('备份失败');
        return;
      }

      // 生成文件名
      const timestamp = new Date().getTime();
      const fileName = `budget_backup_${timestamp}.json`;

      // 使用文件选择器保存文件
      try {
        const documentSaveOptions = new picker.DocumentSaveOptions();
        documentSaveOptions.newFileNames = [fileName];
        const documentPicker = new picker.DocumentViewPicker();
        const uris = await documentPicker.save(documentSaveOptions);
        if (uris && uris.length > 0) {
          const file = fileIo.openSync(uris[0], fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE);
          fileIo.writeSync(file.fd, jsonData);
          fileIo.closeSync(file);
          this.showToast('备份成功');
        }
      } catch (err) {
        console.error('Save backup failed:', err);
        this.showToast('备份失败');
      }
    } catch (err) {
      console.error('Backup failed:', err);
      this.showToast('备份失败');
    }
  }

  async handleRestore(): Promise<void> {
    try {
      // 使用文件选择器选择文件
      try {
        const documentSelectOptions = new picker.DocumentSelectOptions();
        documentSelectOptions.maxSelectNumber = 1;
        const documentPicker = new picker.DocumentViewPicker();
        const uris = await documentPicker.select(documentSelectOptions);
        if (uris && uris.length > 0) {
          const file = fileIo.openSync(uris[0], fileIo.OpenMode.READ_ONLY);
          const buffer = new ArrayBuffer(1024 * 1024); // 1MB buffer
          const readLen = fileIo.readSync(file.fd, buffer);
          fileIo.closeSync(file);

          // 转换为字符串
          const uint8Array = new Uint8Array(buffer, 0, readLen);
          const decoder = new util.TextDecoder('utf-8');
          const jsonData = decoder.decodeToString(uint8Array);

          // 导入数据
          const success = await this.dataService.importAllData(jsonData);
          if (success) {
            this.showToast('恢复成功');
            this.loadSettings();
          } else {
            this.showToast('恢复失败：数据格式错误');
          }
        }
      } catch (err) {
        console.error('Read restore file failed:', err);
        this.showToast('恢复失败');
      }
    } catch (err) {
      console.error('Restore failed:', err);
      this.showToast('恢复失败');
    }
  }

  handleClearData(): void {
    this.showConfirmClearDialog = true;
  }

  async confirmClearData(): Promise<void> {
    const success = await this.dataService.clearAllData();
    if (success) {
      this.showToast('已清空所有数据');
      this.loadSettings();
    } else {
      this.showToast('清空失败');
    }
    this.showConfirmClearDialog = false;
  }

  showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({
        message: message,
        duration: 2000
      });
    } catch (err) {
      console.error('Show toast failed:', err);
    }
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('设置')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')
      .height(64)
      .padding({ left: 20, right: 20 })
      .backgroundColor($r('app.color.background_primary'))

      // 设置内容
      List({ space: 1 }) {
        // 外观设置分组
        ListItemGroup({ header: this.GroupHeader('外观') }) {
          ListItem() {
            SettingItemView({
              title: '深色模式',
              value: this.themeModeDisplay,
              onItemClick: () => {
                this.showThemeDialog = true;
              }
            })
          }
        }

        // 通用设置分组
        ListItemGroup({ header: this.GroupHeader('通用') }) {
          ListItem() {
            SettingItemView({
              title: '货币单位',
              value: this.currencyDisplay,
              onItemClick: () => {
                this.showCurrencyDialog = true;
              }
            })
          }

          ListItem() {
            SettingItemView({
              title: '默认页面',
              value: this.defaultPageDisplay,
              onItemClick: () => {
                this.showDefaultPageDialog = true;
              }
            })
          }

          ListItem() {
            SettingItemView({
              title: '本地化',
              value: '中文',
              onItemClick: null
            })
          }
        }

        // 数据管理分组
        ListItemGroup({ header: this.GroupHeader('数据') }) {
          ListItem() {
            SettingItemView({
              title: '导出数据 (CSV)',
              value: '',
              onItemClick: () => {
                this.handleExportCSV();
              }
            })
          }

          ListItem() {
            SettingItemView({
              title: '备份数据',
              value: '',
              onItemClick: () => {
                this.handleBackup();
              }
            })
          }

          ListItem() {
            SettingItemView({
              title: '恢复数据',
              value: '',
              onItemClick: () => {
                this.handleRestore();
              }
            })
          }

          ListItem() {
            SettingItemDangerView({
              title: '清空数据',
              onItemClick: () => {
                this.handleClearData();
              }
            })
          }
        }

        // 关于分组
        ListItemGroup({ header: this.GroupHeader('关于') }) {
          ListItem() {
            SettingItemView({
              title: '关于此应用',
              value: '',
              onItemClick: () => {
                this.showAboutDialog = true;
              }
            })
          }
        }
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor($r('app.color.background_secondary'))
      .divider({ strokeWidth: 1, color: $r('app.color.divider') })

      // 主题选择对话框
      if (this.showThemeDialog) {
        this.ThemeDialog()
      }

      // 货币选择对话框
      if (this.showCurrencyDialog) {
        this.CurrencyDialog()
      }

      // 默认页面选择对话框
      if (this.showDefaultPageDialog) {
        this.DefaultPageDialog()
      }

      // 关于对话框
      if (this.showAboutDialog) {
        this.AboutDialog()
      }

      // 确认清空数据对话框
      if (this.showConfirmClearDialog) {
        this.ConfirmClearDialog()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background_secondary'))
  }

  @Builder
  GroupHeader(title: string) {
    Text(title)
      .fontSize(13)
      .fontColor($r('app.color.text_tertiary'))
      .fontWeight(FontWeight.Medium)
      .padding({ left: 16, top: 20, bottom: 10 })
  }

  @Builder
  ThemeDialog() {
    Column() {
      // 遮罩层
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.overlay_background'))
        .opacity(0.5)
        .onClick(() => {
          this.showThemeDialog = false;
        })

      // 对话框
      Column() {
        Text('选择主题')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
          .padding({ bottom: 16 })
          .borderWidth({ bottom: 1 })
          .borderColor($r('app.color.divider'))

        // 选项列表
        Column() {
          this.DialogOption('跟随系统', this.settings.themeMode === 'system', () => {
            this.settings.themeMode = 'system';
            this.updateSettings();
            this.showThemeDialog = false;
          })

          this.DialogOption('明亮模式', this.settings.themeMode === 'light', () => {
            this.settings.themeMode = 'light';
            this.updateSettings();
            this.showThemeDialog = false;
          })

          this.DialogOption('深色模式', this.settings.themeMode === 'dark', () => {
            this.settings.themeMode = 'dark';
            this.updateSettings();
            this.showThemeDialog = false;
          })
        }
        .width('100%')

        // 关闭按钮
        Button('关闭')
          .width('100%')
          .height(44)
          .margin({ top: 16 })
          .backgroundColor($r('app.color.button_secondary_bg'))
          .fontColor($r('app.color.button_secondary_text'))
          .borderRadius(12)
          .onClick(() => {
            this.showThemeDialog = false;
          })
      }
      .width('80%')
      .padding(16)
      .backgroundColor($r('app.color.card_background'))
      .borderRadius(16)
      .shadow({ radius: 16, color: $r('app.color.shadow_medium'), offsetY: 8 })
      .position({ x: '10%', y: '30%' })
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
    .zIndex(999)
  }

  @Builder
  CurrencyDialog() {
    Column() {
      // 遮罩层
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.overlay_background'))
        .opacity(0.5)
        .onClick(() => {
          this.showCurrencyDialog = false;
        })

      // 对话框
      Column() {
        Text('选择货币单位')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
          .padding({ bottom: 16 })
          .borderWidth({ bottom: 1 })
          .borderColor($r('app.color.divider'))

        // 选项列表
        Column() {
          this.DialogOption('人民币 (¥)', this.settings.currency === '¥', () => {
            this.settings.currency = '¥';
            this.updateSettings();
            this.showCurrencyDialog = false;
          })

          this.DialogOption('美元 ($)', this.settings.currency === '$', () => {
            this.settings.currency = '$';
            this.updateSettings();
            this.showCurrencyDialog = false;
          })

          this.DialogOption('欧元 (€)', this.settings.currency === '€', () => {
            this.settings.currency = '€';
            this.updateSettings();
            this.showCurrencyDialog = false;
          })

          this.DialogOption('英镑 (£)', this.settings.currency === '£', () => {
            this.settings.currency = '£';
            this.updateSettings();
            this.showCurrencyDialog = false;
          })
        }
        .width('100%')

        // 关闭按钮
        Button('关闭')
          .width('100%')
          .height(44)
          .margin({ top: 16 })
          .backgroundColor($r('app.color.button_secondary_bg'))
          .fontColor($r('app.color.button_secondary_text'))
          .borderRadius(12)
          .onClick(() => {
            this.showCurrencyDialog = false;
          })
      }
      .width('80%')
      .padding(16)
      .backgroundColor($r('app.color.card_background'))
      .borderRadius(16)
      .shadow({ radius: 16, color: $r('app.color.shadow_medium'), offsetY: 8 })
      .position({ x: '10%', y: '25%' })
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
    .zIndex(999)
  }

  @Builder
  DefaultPageDialog() {
    Column() {
      // 遮罩层
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.overlay_background'))
        .opacity(0.5)
        .onClick(() => {
          this.showDefaultPageDialog = false;
        })

      // 对话框
      Column() {
        Text('选择默认页面')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
          .padding({ bottom: 16 })
          .borderWidth({ bottom: 1 })
          .borderColor($r('app.color.divider'))

        // 选项列表
        Column() {
          this.DialogOption('明细', this.settings.defaultPage === 'details', () => {
            this.settings.defaultPage = 'details';
            this.updateSettings();
            this.showDefaultPageDialog = false;
          })

          this.DialogOption('预算', this.settings.defaultPage === 'budget', () => {
            this.settings.defaultPage = 'budget';
            this.updateSettings();
            this.showDefaultPageDialog = false;
          })

          this.DialogOption('统计', this.settings.defaultPage === 'stats', () => {
            this.settings.defaultPage = 'stats';
            this.updateSettings();
            this.showDefaultPageDialog = false;
          })
        }
        .width('100%')

        // 关闭按钮
        Button('关闭')
          .width('100%')
          .height(44)
          .margin({ top: 16 })
          .backgroundColor('#f0f0f0')
          .fontColor('#666666')
          .onClick(() => {
            this.showDefaultPageDialog = false;
          })
      }
      .width('80%')
      .padding(16)
      .backgroundColor('#ffffff')
      .borderRadius(12)
      .position({ x: '10%', y: '30%' })
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
    .zIndex(999)
  }

  @Builder
  AboutDialog() {
    Column() {
      // 遮罩层
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.overlay_background'))
        .opacity(0.5)
        .onClick(() => {
          this.showAboutDialog = false;
        })

      // 对话框
      Column() {
        Text('关于')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .margin({ bottom: 20 })

        Text('记账本')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.primary_color'))
          .margin({ bottom: 8 })

        Text('版本 v1.0.0')
          .fontSize(14)
          .fontColor($r('app.color.text_tertiary'))
          .margin({ bottom: 20 })

        Divider()
          .margin({ top: 10, bottom: 10 })

        Text('一款简洁实用的个人记账应用')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)
          .margin({ bottom: 10 })

        Text('帮助您轻松管理个人财务')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)
          .margin({ bottom: 20 })

        Divider()
          .margin({ top: 10, bottom: 10 })

        Text('开发团队')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .margin({ bottom: 8 })

        Text('开源项目 • MIT License')
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'))
          .margin({ bottom: 20 })

        // 关闭按钮
        Button('关闭')
          .width('100%')
          .height(44)
          .backgroundColor($r('app.color.primary_color'))
          .fontColor('#FFFFFF')
          .borderRadius(12)
          .onClick(() => {
            this.showAboutDialog = false;
          })
      }
      .width('80%')
      .padding(24)
      .backgroundColor($r('app.color.card_background'))
      .borderRadius(16)
      .shadow({ radius: 16, color: $r('app.color.shadow_medium'), offsetY: 8 })
      .position({ x: '10%', y: '20%' })
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
    .zIndex(999)
  }

  @Builder
  ConfirmClearDialog() {
    Column() {
      // 遮罩层
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.overlay_background'))
        .opacity(0.5)
        .onClick(() => {
          this.showConfirmClearDialog = false;
        })

      // 对话框
      Column() {
        Text('⚠️ 警告')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.accent_danger'))
          .margin({ bottom: 16 })

        Text('此操作将清空所有数据，包括：')
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .margin({ bottom: 12 })

        Text('• 所有交易记录')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .margin({ bottom: 4 })

        Text('• 自定义分类')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .margin({ bottom: 4 })

        Text('• 预算设置')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .margin({ bottom: 16 })

        Text('此操作不可恢复，是否继续？')
          .fontSize(14)
          .fontColor($r('app.color.accent_danger'))
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 20 })

        // 按钮
        Row() {
          Button('取消')
            .width('48%')
            .height(44)
            .backgroundColor($r('app.color.button_secondary_bg'))
            .fontColor($r('app.color.button_secondary_text'))
            .borderRadius(12)
            .onClick(() => {
              this.showConfirmClearDialog = false;
            })

          Button('确认清空')
            .width('48%')
            .height(44)
            .backgroundColor($r('app.color.accent_danger'))
            .fontColor('#FFFFFF')
            .borderRadius(12)
            .onClick(() => {
              this.confirmClearData();
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
      }
      .width('85%')
      .padding(24)
      .backgroundColor($r('app.color.card_background'))
      .borderRadius(16)
      .shadow({ radius: 16, color: $r('app.color.shadow_medium'), offsetY: 8 })
      .position({ x: '7.5%', y: '25%' })
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
    .zIndex(999)
  }

  @Builder
  DialogOption(title: string, isSelected: boolean, onClick: () => void) {
    Row() {
      Text(title)
        .fontSize(16)
        .fontColor(isSelected ? $r('app.color.primary_color') : $r('app.color.text_primary'))
        .fontWeight(isSelected ? FontWeight.Bold : FontWeight.Normal)
        .layoutWeight(1)

      if (isSelected) {
        Text('✓')
          .fontSize(18)
          .fontColor($r('app.color.primary_color'))
      }
    }
    .width('100%')
    .height(48)
    .padding({ left: 8, right: 8 })
    .onClick(onClick)
  }
}
