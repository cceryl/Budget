import { Transaction } from '../models/Transaction';
import { Category } from '../models/Category';
import { DataService } from '../services/DataService';
import { Router } from '@kit.ArkUI';

@Component
export struct TransactionListPage {
  @State transactions: Transaction[] = [];
  @State categories: Category[] = [];
  @State filteredTransactions: Transaction[] = [];
  @State filterType: string = 'all'; // 'all', 'income', 'expense'
  @State searchText: string = '';
  @State selectedCategoryId: string = 'all';
  @State showCategorySelector: boolean = false;
  @State currencySymbol: string = '¥'; // 货币符号
  @Prop @Watch('onRefreshTriggerChange') refreshTrigger: number = 0; // 接收父组件的刷新触发器
  private dataService: DataService = DataService.getInstance();
  private hasLoaded: boolean = false;

  async aboutToAppear(): Promise<void> {
    // 确保数据服务已初始化
    await this.dataService.waitForInitialization();
    await this.loadData();
    this.hasLoaded = true;
  }

  // 监听刷新触发器变化
  onRefreshTriggerChange(): void {
    this.loadData();
  }

  async loadData(): Promise<void> {
    // 先加载分类数据，确保分类列表可用
    this.categories = await this.dataService.getAllCategories();
    // 再加载交易数据
    this.transactions = await this.dataService.getAllTransactions();
    // 加载货币设置
    const settings = await this.dataService.getSettings();
    this.currencySymbol = settings.currency;
    // 按日期倒序排列
    this.transactions.sort((a, b) => b.date - a.date);
    this.applyFilter();
  }

  applyFilter(): void {
    let result = this.transactions;

    // 按类型过滤
    if (this.filterType !== 'all') {
      result = result.filter(t => t.type === this.filterType);
    }

    // 按分类过滤
    if (this.selectedCategoryId !== 'all') {
      result = result.filter(t => t.categoryId === this.selectedCategoryId);
    }

    // 按关键词搜索
    if (this.searchText.trim() !== '') {
      const keyword = this.searchText.toLowerCase();
      result = result.filter(t => t.description.toLowerCase().includes(keyword));
    }

    this.filteredTransactions = result;
  }

  getAvailableCategories(): Category[] {
    if (this.filterType === 'all') {
      return this.categories;
    }
    return this.categories.filter(c => c.type === this.filterType);
  }

  getCategoryName(categoryId: string): string {
    const category = this.categories.find(c => c.id === categoryId);
    return category ? category.name : '未知';
  }

  formatDate(timestamp: number): string {
    const date = new Date(timestamp);
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }

  async deleteTransaction(id: string): Promise<void> {
    const success = await this.dataService.deleteTransaction(id);
    if (success) {
      this.loadData();
    }
  }

  navigateToEdit(transaction?: Transaction): void {
    const router: Router = this.getUIContext().getRouter();
    if (transaction) {
      router.pushUrl({
        url: 'pages/TransactionEditPage',
        params: { transactionId: transaction.id }
      }).catch((err: Error) => {
        console.error('Navigate failed:', err);
      });
    } else {
      router.pushUrl({
        url: 'pages/TransactionEditPage'
      }).catch((err: Error) => {
        console.error('Navigate failed:', err);
      });
    }
  }

  navigateToCategory(): void {
    const router: Router = this.getUIContext().getRouter();
    router.pushUrl({
      url: 'pages/CategoryManagePage'
    }).catch((err: Error) => {
      console.error('Navigate failed:', err);
    });
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('记账本')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))

        Blank()

        Button('分类管理')
          .fontSize(14)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .backgroundColor($r('app.color.button_secondary_bg'))
          .fontColor($r('app.color.button_secondary_text'))
          .borderRadius(20)
          .onClick(() => this.navigateToCategory())
      }
      .width('100%')
      .height(64)
      .padding({ left: 20, right: 20 })
      .backgroundColor($r('app.color.background_primary'))

      // 搜索和过滤
      Column({ space: 12 }) {
        // 搜索框
        TextInput({ placeholder: '搜索交易描述...' })
          .width('100%')
          .height(44)
          .backgroundColor($r('app.color.background_secondary'))
          .borderRadius(12)
          .padding({ left: 16, right: 16 })
          .onChange((value: string) => {
            this.searchText = value;
            this.applyFilter();
          })

        // 过滤按钮组
        Row() {
          Button('全部')
            .fontSize(14)
            .height(36)
            .padding({ left: 16, right: 16 })
            .backgroundColor(this.filterType === 'all' ? $r('app.color.primary_color') : $r('app.color.button_secondary_bg'))
            .fontColor(this.filterType === 'all' ? '#FFFFFF' : $r('app.color.button_secondary_text'))
            .borderRadius(18)
            .onClick(() => {
              this.filterType = 'all';
              this.selectedCategoryId = 'all';
              this.applyFilter();
            })

          Button('收入')
            .fontSize(14)
            .height(36)
            .padding({ left: 16, right: 16 })
            .backgroundColor(this.filterType === 'income' ? $r('app.color.primary_color') : $r('app.color.button_secondary_bg'))
            .fontColor(this.filterType === 'income' ? '#FFFFFF' : $r('app.color.button_secondary_text'))
            .borderRadius(18)
            .margin({ left: 8 })
            .onClick(() => {
              this.filterType = 'income';
              this.selectedCategoryId = 'all';
              this.applyFilter();
            })

          Button('支出')
            .fontSize(14)
            .height(36)
            .padding({ left: 16, right: 16 })
            .backgroundColor(this.filterType === 'expense' ? $r('app.color.primary_color') : $r('app.color.button_secondary_bg'))
            .fontColor(this.filterType === 'expense' ? '#FFFFFF' : $r('app.color.button_secondary_text'))
            .borderRadius(18)
            .margin({ left: 8 })
            .onClick(() => {
              this.filterType = 'expense';
              this.selectedCategoryId = 'all';
              this.applyFilter();
            })

          Blank()

          // 分类选择下拉菜单
          Button() {
            Row({ space: 4 }) {
              Text(this.selectedCategoryId === 'all' ? '全部分类' : this.getCategoryName(this.selectedCategoryId))
                .fontSize(13)
                .fontColor($r('app.color.button_secondary_text'))
              Text('▼')
                .fontSize(10)
                .fontColor($r('app.color.text_tertiary'))
            }
          }
          .padding({ left: 14, right: 14 })
          .height(36)
          .backgroundColor($r('app.color.button_secondary_bg'))
          .borderRadius(18)
          .onClick(() => {
            this.showCategorySelector = true;
          })
        }
        .width('100%')
      }
      .width('100%')
      .padding(16)
      .backgroundColor($r('app.color.background_primary'))

      // 交易列表
      if (this.filteredTransactions.length > 0) {
        List({ space: 12 }) {
          ForEach(this.filteredTransactions, (transaction: Transaction) => {
            ListItem() {
              this.TransactionItem(transaction)
            }
            .swipeAction({ end: this.DeleteButton(transaction.id) })
          }, (transaction: Transaction) => JSON.stringify(transaction))
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        .backgroundColor($r('app.color.background_secondary'))
      } else {
        // 空状态提示
        Column() {
          Text('暂无交易记录')
            .fontSize(16)
            .fontColor($r('app.color.text_tertiary'))
            .margin({ top: 100 })
        }
        .width('100%')
        .layoutWeight(1)
        .backgroundColor($r('app.color.background_secondary'))
      }

      // 分类选择器弹窗
      if (this.showCategorySelector) {
        this.CategorySelectorDialog()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background_secondary'))
  }

  @Builder
  CategorySelectorDialog() {
    Column() {
      // 遮罩层
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.overlay_background'))
        .opacity(0.5)
        .onClick(() => {
          this.showCategorySelector = false;
        })

      // 对话框
      Column() {
        Text('选择分类')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
          .padding({ bottom: 16 })
          .borderWidth({ bottom: 1 })
          .borderColor($r('app.color.divider'))

        // 分类列表
        List({ space: 0 }) {
          // "全部分类"选项
          ListItem() {
            Row() {
              Text('全部分类')
                .fontSize(16)
                .fontColor(this.selectedCategoryId === 'all' ? $r('app.color.primary_color') : $r('app.color.text_primary'))
                .fontWeight(this.selectedCategoryId === 'all' ? FontWeight.Bold : FontWeight.Normal)
            }
            .width('100%')
            .height(48)
            .padding({ left: 16, right: 16 })
            .onClick(() => {
              this.selectedCategoryId = 'all';
              this.showCategorySelector = false;
              this.applyFilter();
            })
          }

          // 根据当前类型显示对应分类
          ForEach(this.getAvailableCategories(), (category: Category) => {
            ListItem() {
              Row() {
                Text(category.name)
                  .fontSize(16)
                  .fontColor(this.selectedCategoryId === category.id ? $r('app.color.primary_color') : $r('app.color.text_primary'))
                  .fontWeight(this.selectedCategoryId === category.id ? FontWeight.Bold : FontWeight.Normal)

                Blank()

                if (this.selectedCategoryId === category.id) {
                  Text('✓')
                    .fontSize(18)
                    .fontColor($r('app.color.primary_color'))
                }
              }
              .width('100%')
              .height(48)
              .padding({ left: 16, right: 16 })
              .onClick(() => {
                this.selectedCategoryId = category.id;
                this.showCategorySelector = false;
                this.applyFilter();
              })
            }
          }, (category: Category) => category.id)
        }
        .width('100%')
        .height(400)
        .divider({ strokeWidth: 1, color: $r('app.color.divider') })

        // 关闭按钮
        Button('关闭')
          .width('100%')
          .height(44)
          .margin({ top: 16 })
          .backgroundColor($r('app.color.button_secondary_bg'))
          .fontColor($r('app.color.button_secondary_text'))
          .borderRadius(12)
          .onClick(() => {
            this.showCategorySelector = false;
          })
      }
      .width('80%')
      .height(500)
      .padding(16)
      .backgroundColor($r('app.color.card_background'))
      .borderRadius(16)
      .shadow({ radius: 16, color: $r('app.color.shadow_medium'), offsetY: 8 })
      .position({ x: '10%', y: '15%' })
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
    .zIndex(999)
  }

  @Builder
  TransactionItem(transaction: Transaction) {
    Row() {
      Column({ space: 6 }) {
        Text(this.getCategoryName(transaction.categoryId))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))

        Text(transaction.description)
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.formatDate(transaction.date))
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Column() {
        Text((transaction.type === 'income' ? '+' : '-') + this.currencySymbol + (transaction.amount / 100).toFixed(2))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(transaction.type === 'income' ? $r('app.color.income_color') : $r('app.color.expense_color'))
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(12)
    .shadow({ radius: 4, color: $r('app.color.shadow_light'), offsetY: 2 })
    .onClick(() => this.navigateToEdit(transaction))
  }

  @Builder
  DeleteButton(id: string) {
    Button() {
      Text('删除')
        .fontSize(16)
        .fontColor('#FFFFFF')
    }
    .width(80)
    .height('100%')
    .backgroundColor($r('app.color.accent_danger'))
    .borderRadius(12)
    .onClick(() => this.deleteTransaction(id))
  }
}
