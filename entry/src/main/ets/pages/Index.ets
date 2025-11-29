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
  private isFirstShow: boolean = true; // 标记是否是首次显示

  async aboutToAppear(): Promise<void> {
    // 加载设置并应用默认页面
    if (!this.hasLoadedSettings) {
      const settings: Settings = await this.dataService.getSettings();
      this.currentTab = settings.defaultPage;
      this.hasLoadedSettings = true;
    }
  }

  async onPageShow(): Promise<void> {
    // 每次页面显示时都刷新数据
    // 首次显示或从后台恢复/其他页面返回时都会触发
    this.refreshKey++;
    
    // 首次显示后，标记为false
    if (this.isFirstShow) {
      this.isFirstShow = false;
    }
    
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
      // 主内容区
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
      .padding({ bottom: 72 })
      .backgroundColor($r('app.color.background_secondary'))

      // 底部导航栏
      Column() {
        Row() {
          // 明细
          Column({ space: 4 }) {
            Image($r('app.media.icon_list'))
              .width(24)
              .height(24)
              .fillColor(this.currentTab === 'details' ? $r('app.color.tab_active') : $r('app.color.tab_inactive'))
            Text('明细')
              .fontSize(11)
              .fontColor(this.currentTab === 'details' ? $r('app.color.tab_active') : $r('app.color.tab_inactive'))
              .fontWeight(this.currentTab === 'details' ? FontWeight.Medium : FontWeight.Regular)
          }
          .width('20%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .onClick(() => { this.currentTab = 'details'; })

          // 统计
          Column({ space: 4 }) {
            Image($r('app.media.icon_chart'))
              .width(24)
              .height(24)
              .fillColor(this.currentTab === 'stats' ? $r('app.color.tab_active') : $r('app.color.tab_inactive'))
            Text('统计')
              .fontSize(11)
              .fontColor(this.currentTab === 'stats' ? $r('app.color.tab_active') : $r('app.color.tab_inactive'))
              .fontWeight(this.currentTab === 'stats' ? FontWeight.Medium : FontWeight.Regular)
          }
          .width('20%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .onClick(() => { this.currentTab = 'stats'; })

          // 中间占位
          Column()
            .width('20%')

          // 预算
          Column({ space: 4 }) {
            Image($r('app.media.icon_wallet'))
              .width(24)
              .height(24)
              .fillColor(this.currentTab === 'budget' ? $r('app.color.tab_active') : $r('app.color.tab_inactive'))
            Text('预算')
              .fontSize(11)
              .fontColor(this.currentTab === 'budget' ? $r('app.color.tab_active') : $r('app.color.tab_inactive'))
              .fontWeight(this.currentTab === 'budget' ? FontWeight.Medium : FontWeight.Regular)
          }
          .width('20%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .onClick(() => { this.currentTab = 'budget'; })

          // 设置
          Column({ space: 4 }) {
            Image($r('app.media.icon_settings'))
              .width(24)
              .height(24)
              .fillColor(this.currentTab === 'settings' ? $r('app.color.tab_active') : $r('app.color.tab_inactive'))
            Text('设置')
              .fontSize(11)
              .fontColor(this.currentTab === 'settings' ? $r('app.color.tab_active') : $r('app.color.tab_inactive'))
              .fontWeight(this.currentTab === 'settings' ? FontWeight.Medium : FontWeight.Regular)
          }
          .width('20%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .onClick(() => { this.currentTab = 'settings'; })
        }
        .width('100%')
        .height(72)
        .backgroundColor($r('app.color.navbar_background'))
        .borderWidth({ top: 1 })
        .borderColor($r('app.color.navbar_border'))
        .shadow({ radius: 8, color: $r('app.color.shadow_light'), offsetY: -4 })

        // 中央悬浮按钮
        Button() {
          Image($r('app.media.icon_add'))
            .width(24)
            .height(24)
        }
        .width(56)
        .height(56)
        .borderRadius(28)
        .backgroundColor($r('app.color.primary_color'))
        .shadow({ radius: 12, color: $r('app.color.shadow_medium'), offsetY: 4 })
        .position({ x: '50%', y: 24 })
        .translate({ x: '-50%', y: '-50%' })
        .onClick(() => this.navigateToEdit())
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background_secondary'))
  }
}