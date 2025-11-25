import { Transaction } from '../models/Transaction';
import { Category } from '../models/Category';
import { DataService } from '../services/DataService';
import { Router } from '@kit.ArkUI';

@Entry
@Component
struct TransactionListPage {
  @State transactions: Transaction[] = [];
  @State categories: Category[] = [];
  @State filteredTransactions: Transaction[] = [];
  @State filterType: string = 'all'; // 'all', 'income', 'expense'
  @State searchText: string = '';
  @State selectedCategoryId: string = 'all';
  private dataService: DataService = DataService.getInstance();

  aboutToAppear(): void {
    this.loadData();
  }

  onPageShow(): void {
    // 每次页面显示时重新加载数据（从编辑页返回时）
    this.loadData();
  }

  async loadData(): Promise<void> {
    this.transactions = await this.dataService.getAllTransactions();
    this.categories = await this.dataService.getAllCategories();
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
        Text('智能记账本')
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
              this.applyFilter();
            })

          Blank()

          // 按分类过滤下拉选择
          Text('分类: ' + (this.selectedCategoryId === 'all' ? '全部' : this.getCategoryName(this.selectedCategoryId)))
            .fontSize(14)
            .fontColor('#666666')
            .padding(8)
            .backgroundColor('#f0f0f0')
            .borderRadius(4)
            .onClick(() => {
              // 这里可以弹出分类选择对话框
              // 简化实现：循环切换
              if (this.selectedCategoryId === 'all') {
                if (this.categories.length > 0) {
                  this.selectedCategoryId = this.categories[0].id;
                }
              } else {
                const currentIndex = this.categories.findIndex(c => c.id === this.selectedCategoryId);
                if (currentIndex < this.categories.length - 1) {
                  this.selectedCategoryId = this.categories[currentIndex + 1].id;
                } else {
                  this.selectedCategoryId = 'all';
                }
              }
              this.applyFilter();
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
        }, (transaction: Transaction) => transaction.id)
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

      // 底部添加按钮
      Button() {
        Row() {
          Text('+')
            .fontSize(28)
            .fontColor('#ffffff')
            .margin({ right: 8 })
          Text('添加交易')
            .fontSize(16)
            .fontColor('#ffffff')
        }
      }
      .width('90%')
      .height(56)
      .margin({ left: '5%', right: '5%', bottom: 16, top: 8 })
      .backgroundColor('#4CAF50')
      .borderRadius(28)
      .onClick(() => this.navigateToEdit())
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f5f5')
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
        Text((transaction.type === 'income' ? '+' : '-') + '¥' + transaction.getAmountInYuan())
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
        .fontSize(14)
        .fontColor('#ffffff')
    }
    .height('100%')
    .backgroundColor('#F44336')
    .onClick(() => this.deleteTransaction(id))
  }
}
