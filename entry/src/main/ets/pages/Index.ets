import { TransactionListPage } from './TransactionListPage';

@Entry
@Component
struct Index {
  @State currentTab: string = 'details'; // 'details' | 'stats' | 'budget' | 'settings'
  @State refreshKey: number = 0; // 用于强制刷新子组件

  onPageShow(): void {
    // 从编辑页返回时刷新明细页面
    this.refreshKey++;
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
          Column() {
            Text('统计（空）')
              .fontSize(18)
              .fontColor('#666666')
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor('#f5f5f5')
        } else if (this.currentTab === 'budget') {
          Column() {
            Text('预算（空）')
              .fontSize(18)
              .fontColor('#666666')
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor('#f5f5f5')
        } else if (this.currentTab === 'settings') {
          Column() {
            Text('设置（空）')
              .fontSize(18)
              .fontColor('#666666')
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor('#f5f5f5')
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