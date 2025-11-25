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
  private dataService: DataService = DataService.getInstance();

  aboutToAppear(): void {
    this.loadData();
  }

  onPageShow(): void {
    // 每次页面显示时重新加载数据（从编辑页返回时）
    this.loadData();
  }

  async loadData(): Promise<void> {
    // 先加载分类数据，确保分类列表可用
    this.categories = await this.dataService.getAllCategories();
    // 再加载交易数据
    this.transactions = await this.dataService.getAllTransactions();
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
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1a1a1a')

        Blank()

        Button('分类管理')
          .fontSize(14)
          .backgroundColor('#f0f0f0')
          .fontColor('#666666')
          .onClick(() => this.navigateToCategory())
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#ffffff')

      // 搜索和过滤
      Column() {
        // 搜索框
        TextInput({ placeholder: '搜索交易描述...' })
          .width('100%')
          .height(40)
          .backgroundColor('#f5f5f5')
          .borderRadius(8)
          .onChange((value: string) => {
            this.searchText = value;
            this.applyFilter();
          })

        // 过滤按钮组
        Row() {
          Button('全部')
            .fontSize(14)
            .height(32)
            .backgroundColor(this.filterType === 'all' ? '#4CAF50' : '#f0f0f0')
            .fontColor(this.filterType === 'all' ? '#ffffff' : '#666666')
            .onClick(() => {
              this.filterType = 'all';
              this.selectedCategoryId = 'all'; // 切换类型时重置分类过滤
              this.applyFilter();
            })

          Button('收入')
            .fontSize(14)
            .height(32)
            .backgroundColor(this.filterType === 'income' ? '#4CAF50' : '#f0f0f0')
            .fontColor(this.filterType === 'income' ? '#ffffff' : '#666666')
            .margin({ left: 8 })
            .onClick(() => {
              this.filterType = 'income';
              this.selectedCategoryId = 'all'; // 切换类型时重置分类过滤
              this.applyFilter();
            })

          Button('支出')
            .fontSize(14)
            .height(32)
            .backgroundColor(this.filterType === 'expense' ? '#4CAF50' : '#f0f0f0')
            .fontColor(this.filterType === 'expense' ? '#ffffff' : '#666666')
            .margin({ left: 8 })
            .onClick(() => {
              this.filterType = 'expense';
              this.selectedCategoryId = 'all'; // 切换类型时重置分类过滤
              this.applyFilter();
            })

          Blank()

          // 分类选择下拉菜单
          Button() {
            Row() {
              Text(this.selectedCategoryId === 'all' ? '全部分类' : this.getCategoryName(this.selectedCategoryId))
                .fontSize(14)
                .fontColor('#666666')
              Text(' ▼')
                .fontSize(12)
                .fontColor('#999999')
            }
          }
          .padding({ left: 12, right: 12 })
          .height(32)
          .backgroundColor('#f0f0f0')
          .onClick(() => {
            this.showCategorySelector = true;
          })
        }
        .width('100%')
        .margin({ top: 12 })
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#ffffff')

      // 交易列表
      List({ space: 1 }) {
        ForEach(this.filteredTransactions, (transaction: Transaction) => {
          ListItem() {
            this.TransactionItem(transaction)
          }
          .swipeAction({ end: this.DeleteButton(transaction.id) })
        }, (transaction: Transaction) => JSON.stringify(transaction))
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor('#f5f5f5')
      .divider({ strokeWidth: 1, color: '#f0f0f0' })

      // 空状态提示
      if (this.filteredTransactions.length === 0) {
        Column() {
          Text('暂无交易记录')
            .fontSize(16)
            .fontColor('#999999')
            .margin({ top: 100 })
        }
        .width('100%')
        .layoutWeight(1)
      }

      // 分类选择器弹窗
      if (this.showCategorySelector) {
        this.CategorySelectorDialog()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f5f5')
  }

  @Builder
  CategorySelectorDialog() {
    Column() {
      // 遮罩层
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')
        .opacity(0.5)
        .onClick(() => {
          this.showCategorySelector = false;
        })

      // 对话框
      Column() {
        Text('选择分类')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1a1a1a')
          .width('100%')
          .padding({ bottom: 16 })
          .borderWidth({ bottom: 1 })
          .borderColor('#f0f0f0')

        // 分类列表
        List({ space: 0 }) {
          // "全部分类"选项
          ListItem() {
            Row() {
              Text('全部分类')
                .fontSize(16)
                .fontColor(this.selectedCategoryId === 'all' ? '#4CAF50' : '#1a1a1a')
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
                  .fontColor(this.selectedCategoryId === category.id ? '#4CAF50' : '#1a1a1a')
                  .fontWeight(this.selectedCategoryId === category.id ? FontWeight.Bold : FontWeight.Normal)

                Blank()

                if (this.selectedCategoryId === category.id) {
                  Text('✓')
                    .fontSize(18)
                    .fontColor('#4CAF50')
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
        .divider({ strokeWidth: 1, color: '#f0f0f0' })

        // 关闭按钮
        Button('关闭')
          .width('100%')
          .height(44)
          .margin({ top: 16 })
          .backgroundColor('#f0f0f0')
          .fontColor('#666666')
          .onClick(() => {
            this.showCategorySelector = false;
          })
      }
      .width('80%')
      .height(500)
      .padding(16)
      .backgroundColor('#ffffff')
      .borderRadius(12)
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
      Column() {
        Text(this.getCategoryName(transaction.categoryId))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1a1a1a')

        Text(transaction.description)
          .fontSize(14)
          .fontColor('#666666')
          .margin({ top: 4 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.formatDate(transaction.date))
          .fontSize(12)
          .fontColor('#999999')
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Column() {
        Text((transaction.type === 'income' ? '+' : '-') + '¥' + (transaction.amount / 100).toFixed(2))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(transaction.type === 'income' ? '#4CAF50' : '#F44336')
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#ffffff')
    .onClick(() => this.navigateToEdit(transaction))
  }

  @Builder
  DeleteButton(id: string) {
    Button() {
      Text('删除')
        .fontSize(16)
        .fontColor('#ffffff')
    }
    .width(80)
    .height('100%')
    .backgroundColor('#F44336')
    .onClick(() => this.deleteTransaction(id))
  }
}
