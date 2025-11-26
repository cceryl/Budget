import { TransactionListPage } from './TransactionListPage';
import { BudgetPage } from './BudgetPage';
import { StatisticsPage } from './StatisticsPage';
import { SettingsPage } from './SettingsPage';
import { DataService } from '../services/DataService';
import { Settings } from '../models/Settings';

@Entry
@Component
struct Index {
  @State currentTab: string = 'details'; // 'details' | 'stats' | 'budget' | 'settings'
  @State refreshKey: number = 0; // 用于强制刷新子组件
  private dataService: DataService = DataService.getInstance();
  private hasLoadedSettings: boolean = false;

  async aboutToAppear(): Promise<void> {
    // 加载设置并应用默认页面
    if (!this.hasLoadedSettings) {
      const settings: Settings = await this.dataService.getSettings();
      this.currentTab = settings.defaultPage;
      this.hasLoadedSettings = true;
    }
  }

  async onPageShow(): Promise<void> {
    // 从编辑页或设置页返回时刷新
    this.refreshKey++;
    
    // 重新加载设置（可能在设置页修改了默认页面，但不切换当前标签）
    const settings: Settings = await this.dataService.getSettings();
    // 注意：不在这里切换currentTab，因为用户可能正在浏览其他页面
  }

  navigateToEdit(): void {
    const router = this.getUIContext().getRouter();
    router.pushUrl({ url: 'pages/TransactionEditPage' }).catch((err: Error) => {
      console.error('Navigate failed:', err);
    });
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // 主内容区（使用Stack让内容填充整个空间）
      Column() {
        if (this.currentTab === 'details') {
          TransactionListPage({ refreshTrigger: this.refreshKey })
        } else if (this.currentTab === 'stats') {
          StatisticsPage({ refreshTrigger: this.refreshKey })
        } else if (this.currentTab === 'budget') {
          BudgetPage({ refreshTrigger: this.refreshKey })
        } else if (this.currentTab === 'settings') {
          SettingsPage({ refreshTrigger: this.refreshKey })
        }
      }
      .width('100%')
      .height('100%')
      .padding({ bottom: 64 })

      // 底部导航区域（固定在底部）
      Column() {
        Row() {
          // 明细
          Column() {
            Text('📊')
              .fontSize(20)
              .margin({ bottom: 4 })
            Text('明细')
              .fontSize(12)
              .fontColor(this.currentTab === 'details' ? '#4CAF50' : '#999999')
          }
          .width('20%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .padding({ top: 8, bottom: 8 })
          .onClick(() => { this.currentTab = 'details'; })

          // 统计
          Column() {
            Text('📈')
              .fontSize(20)
              .margin({ bottom: 4 })
            Text('统计')
              .fontSize(12)
              .fontColor(this.currentTab === 'stats' ? '#4CAF50' : '#999999')
          }
          .width('20%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .padding({ top: 8, bottom: 8 })
          .onClick(() => { this.currentTab = 'stats'; })

          // 中间快捷记账占位（空列，用于居中悬浮按钮）
          Column() {
            Text('')
              .fontSize(12)
          }
          .width('20%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)

          // 预算
          Column() {
            Text('💰')
              .fontSize(20)
              .margin({ bottom: 4 })
            Text('预算')
              .fontSize(12)
              .fontColor(this.currentTab === 'budget' ? '#4CAF50' : '#999999')
          }
          .width('20%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .padding({ top: 8, bottom: 8 })
          .onClick(() => { this.currentTab = 'budget'; })

          // 设置
          Column() {
            Text('⚙️')
              .fontSize(20)
              .margin({ bottom: 4 })
            Text('设置')
              .fontSize(12)
              .fontColor(this.currentTab === 'settings' ? '#4CAF50' : '#999999')
          }
          .width('20%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .padding({ top: 8, bottom: 8 })
          .onClick(() => { this.currentTab = 'settings'; })
        }
        .width('100%')
        .height(64)
        .backgroundColor('#ffffff')
        .borderWidth({ top: 1 })
        .borderColor('#f0f0f0')
        .shadow({ radius: 4, color: '#00000010', offsetY: -2 })

        // 底部中央快捷记账悬浮按钮
        Button() {
          Text('+')
            .fontSize(32)
            .fontColor('#ffffff')
            .fontWeight(FontWeight.Bold)
        }
        .width(64)
        .height(64)
        .borderRadius(32)
        .backgroundColor('#4CAF50')
        .shadow({ radius: 8, color: '#00000020', offsetY: 2 })
        .position({ x: '50%', y: 20 })
        .translate({ x: '-50%', y: '-50%' })
        .onClick(() => this.navigateToEdit())
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
  }
}