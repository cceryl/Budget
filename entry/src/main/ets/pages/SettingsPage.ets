import { Settings } from '../models/Settings';
import { DataService } from '../services/DataService';
import { picker } from '@kit.CoreFileKit';
import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';

@Component
export struct SettingsPage {
  @State settings: Settings = Settings.getDefault();
  @State showThemeDialog: boolean = false;
  @State showCurrencyDialog: boolean = false;
  @State showDefaultPageDialog: boolean = false;
  @State showAboutDialog: boolean = false;
  @State showConfirmClearDialog: boolean = false;
  @Prop @Watch('onRefreshTriggerChange') refreshTrigger: number = 0;
  private dataService: DataService = DataService.getInstance();

  aboutToAppear(): void {
    this.loadSettings();
  }

  onRefreshTriggerChange(): void {
    this.loadSettings();
  }

  async loadSettings(): Promise<void> {
    this.settings = await this.dataService.getSettings();
  }

  async updateSettings(): Promise<void> {
    await this.dataService.saveSettings(this.settings);
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
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1a1a1a')
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#ffffff')

      // 设置内容
      List({ space: 1 }) {
        // 外观设置分组
        ListItemGroup({ header: this.GroupHeader('外观') }) {
          ListItem() {
            this.SettingItem('深色模式', this.settings.getThemeModeDisplayName(), () => {
              this.showThemeDialog = true;
            })
          }
        }

        // 通用设置分组
        ListItemGroup({ header: this.GroupHeader('通用') }) {
          ListItem() {
            this.SettingItem('货币单位', this.settings.getCurrencyDisplayName(), () => {
              this.showCurrencyDialog = true;
            })
          }

          ListItem() {
            this.SettingItem('默认页面', this.settings.getDefaultPageDisplayName(), () => {
              this.showDefaultPageDialog = true;
            })
          }

          ListItem() {
            this.SettingItem('本地化', '中文', null)
          }
        }

        // 数据管理分组
        ListItemGroup({ header: this.GroupHeader('数据') }) {
          ListItem() {
            this.SettingItem('导出数据 (CSV)', '', () => {
              this.handleExportCSV();
            })
          }

          ListItem() {
            this.SettingItem('备份数据', '', () => {
              this.handleBackup();
            })
          }

          ListItem() {
            this.SettingItem('恢复数据', '', () => {
              this.handleRestore();
            })
          }

          ListItem() {
            this.SettingItemDanger('清空数据', () => {
              this.handleClearData();
            })
          }
        }

        // 关于分组
        ListItemGroup({ header: this.GroupHeader('关于') }) {
          ListItem() {
            this.SettingItem('关于此应用', '', () => {
              this.showAboutDialog = true;
            })
          }
        }
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor('#f5f5f5')
      .divider({ strokeWidth: 1, color: '#f0f0f0' })

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
    .backgroundColor('#f5f5f5')
  }

  @Builder
  GroupHeader(title: string) {
    Text(title)
      .fontSize(14)
      .fontColor('#999999')
      .fontWeight(FontWeight.Bold)
      .padding({ left: 16, top: 16, bottom: 8 })
      .backgroundColor('#f5f5f5')
  }

  @Builder
  SettingItem(title: string, value: string, onClick: (() => void) | null) {
    Row() {
      Text(title)
        .fontSize(16)
        .fontColor('#1a1a1a')
        .layoutWeight(1)

      if (value !== '') {
        Text(value)
          .fontSize(14)
          .fontColor('#999999')
          .margin({ right: 8 })
      }

      if (onClick !== null) {
        Text('›')
          .fontSize(20)
          .fontColor('#cccccc')
      }
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor('#ffffff')
    .onClick(() => {
      if (onClick !== null) {
        onClick();
      }
    })
  }

  @Builder
  SettingItemDanger(title: string, onClick: () => void) {
    Row() {
      Text(title)
        .fontSize(16)
        .fontColor('#F44336')
        .layoutWeight(1)
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor('#ffffff')
    .onClick(onClick)
  }

  @Builder
  ThemeDialog() {
    Column() {
      // 遮罩层
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')
        .opacity(0.5)
        .onClick(() => {
          this.showThemeDialog = false;
        })

      // 对话框
      Column() {
        Text('选择主题')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1a1a1a')
          .width('100%')
          .padding({ bottom: 16 })
          .borderWidth({ bottom: 1 })
          .borderColor('#f0f0f0')

        // 选项列表
        Column() {
          this.DialogOption('跟随系统', this.settings.themeMode === 'system', () => {
            this.settings.themeMode = 'system';
            this.updateSettings();
            this.loadSettings(); // 重新加载以更新显示
            this.showThemeDialog = false;
          })

          this.DialogOption('明亮模式', this.settings.themeMode === 'light', () => {
            this.settings.themeMode = 'light';
            this.updateSettings();
            this.loadSettings(); // 重新加载以更新显示
            this.showThemeDialog = false;
          })

          this.DialogOption('深色模式', this.settings.themeMode === 'dark', () => {
            this.settings.themeMode = 'dark';
            this.updateSettings();
            this.loadSettings(); // 重新加载以更新显示
            this.showThemeDialog = false;
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
            this.showThemeDialog = false;
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
  CurrencyDialog() {
    Column() {
      // 遮罩层
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')
        .opacity(0.5)
        .onClick(() => {
          this.showCurrencyDialog = false;
        })

      // 对话框
      Column() {
        Text('选择货币单位')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1a1a1a')
          .width('100%')
          .padding({ bottom: 16 })
          .borderWidth({ bottom: 1 })
          .borderColor('#f0f0f0')

        // 选项列表
        Column() {
          this.DialogOption('人民币 (¥)', this.settings.currency === '¥', () => {
            this.settings.currency = '¥';
            this.updateSettings();
            this.loadSettings(); // 重新加载以更新显示
            this.showCurrencyDialog = false;
          })

          this.DialogOption('美元 ($)', this.settings.currency === '$', () => {
            this.settings.currency = '$';
            this.updateSettings();
            this.loadSettings(); // 重新加载以更新显示
            this.showCurrencyDialog = false;
          })

          this.DialogOption('欧元 (€)', this.settings.currency === '€', () => {
            this.settings.currency = '€';
            this.updateSettings();
            this.loadSettings(); // 重新加载以更新显示
            this.showCurrencyDialog = false;
          })

          this.DialogOption('英镑 (£)', this.settings.currency === '£', () => {
            this.settings.currency = '£';
            this.updateSettings();
            this.loadSettings(); // 重新加载以更新显示
            this.showCurrencyDialog = false;
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
            this.showCurrencyDialog = false;
          })
      }
      .width('80%')
      .padding(16)
      .backgroundColor('#ffffff')
      .borderRadius(12)
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
        .backgroundColor('#000000')
        .opacity(0.5)
        .onClick(() => {
          this.showDefaultPageDialog = false;
        })

      // 对话框
      Column() {
        Text('选择默认页面')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1a1a1a')
          .width('100%')
          .padding({ bottom: 16 })
          .borderWidth({ bottom: 1 })
          .borderColor('#f0f0f0')

        // 选项列表
        Column() {
          this.DialogOption('明细', this.settings.defaultPage === 'details', () => {
            this.settings.defaultPage = 'details';
            this.updateSettings();
            this.loadSettings(); // 重新加载以更新显示
            this.showDefaultPageDialog = false;
          })

          this.DialogOption('预算', this.settings.defaultPage === 'budget', () => {
            this.settings.defaultPage = 'budget';
            this.updateSettings();
            this.loadSettings(); // 重新加载以更新显示
            this.showDefaultPageDialog = false;
          })

          this.DialogOption('统计', this.settings.defaultPage === 'stats', () => {
            this.settings.defaultPage = 'stats';
            this.updateSettings();
            this.loadSettings(); // 重新加载以更新显示
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
        .backgroundColor('#000000')
        .opacity(0.5)
        .onClick(() => {
          this.showAboutDialog = false;
        })

      // 对话框
      Column() {
        Text('关于')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1a1a1a')
          .margin({ bottom: 20 })

        Text('记账本')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#4CAF50')
          .margin({ bottom: 8 })

        Text('版本 v1.0.0')
          .fontSize(14)
          .fontColor('#999999')
          .margin({ bottom: 20 })

        Divider()
          .margin({ top: 10, bottom: 10 })

        Text('一款简洁实用的个人记账应用')
          .fontSize(14)
          .fontColor('#666666')
          .textAlign(TextAlign.Center)
          .margin({ bottom: 10 })

        Text('帮助您轻松管理个人财务')
          .fontSize(14)
          .fontColor('#666666')
          .textAlign(TextAlign.Center)
          .margin({ bottom: 20 })

        Divider()
          .margin({ top: 10, bottom: 10 })

        Text('开发团队')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1a1a1a')
          .margin({ bottom: 8 })

        Text('开源项目 • MIT License')
          .fontSize(12)
          .fontColor('#999999')
          .margin({ bottom: 20 })

        // 关闭按钮
        Button('关闭')
          .width('100%')
          .height(44)
          .backgroundColor('#4CAF50')
          .fontColor('#ffffff')
          .onClick(() => {
            this.showAboutDialog = false;
          })
      }
      .width('80%')
      .padding(24)
      .backgroundColor('#ffffff')
      .borderRadius(12)
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
        .backgroundColor('#000000')
        .opacity(0.5)
        .onClick(() => {
          this.showConfirmClearDialog = false;
        })

      // 对话框
      Column() {
        Text('⚠️ 警告')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F44336')
          .margin({ bottom: 16 })

        Text('此操作将清空所有数据，包括：')
          .fontSize(16)
          .fontColor('#1a1a1a')
          .margin({ bottom: 12 })

        Text('• 所有交易记录')
          .fontSize(14)
          .fontColor('#666666')
          .width('100%')
          .margin({ bottom: 4 })

        Text('• 自定义分类')
          .fontSize(14)
          .fontColor('#666666')
          .width('100%')
          .margin({ bottom: 4 })

        Text('• 预算设置')
          .fontSize(14)
          .fontColor('#666666')
          .width('100%')
          .margin({ bottom: 16 })

        Text('此操作不可恢复，是否继续？')
          .fontSize(14)
          .fontColor('#F44336')
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 20 })

        // 按钮
        Row() {
          Button('取消')
            .width('48%')
            .height(44)
            .backgroundColor('#f0f0f0')
            .fontColor('#666666')
            .onClick(() => {
              this.showConfirmClearDialog = false;
            })

          Button('确认清空')
            .width('48%')
            .height(44)
            .backgroundColor('#F44336')
            .fontColor('#ffffff')
            .onClick(() => {
              this.confirmClearData();
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
      }
      .width('85%')
      .padding(24)
      .backgroundColor('#ffffff')
      .borderRadius(12)
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
        .fontColor(isSelected ? '#4CAF50' : '#1a1a1a')
        .fontWeight(isSelected ? FontWeight.Bold : FontWeight.Normal)
        .layoutWeight(1)

      if (isSelected) {
        Text('✓')
          .fontSize(18)
          .fontColor('#4CAF50')
      }
    }
    .width('100%')
    .height(48)
    .padding({ left: 8, right: 8 })
    .onClick(onClick)
  }
}
