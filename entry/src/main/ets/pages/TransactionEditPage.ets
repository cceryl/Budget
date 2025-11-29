import { Transaction } from '../models/Transaction';
import { Category } from '../models/Category';
import { DataService } from '../services/DataService';
import { Router, PromptAction } from '@kit.ArkUI';

@Entry
@Component
struct TransactionEditPage {
  @State transactionId: string = '';
  @State transactionType: string = 'expense'; // 'income' 或 'expense'
  @State amount: string = '';
  @State selectedCategoryId: string = '';
  @State description: string = '';
  @State selectedDate: number = Date.now();
  @State categories: Category[] = [];
  @State isEditMode: boolean = false;
  @State currencySymbol: string = '¥'; // 货币符号
  private dataService: DataService = DataService.getInstance();

  aboutToAppear(): void {
    this.loadSettings();
    this.loadCategories();
    
    // 检查是否是编辑模式
    const router: Router = this.getUIContext().getRouter();
    const params = router.getParams() as Record<string, string>;
    if (params && params['transactionId']) {
      this.transactionId = params['transactionId'] as string;
      this.isEditMode = true;
      this.loadTransaction();
    }
  }

  async loadSettings(): Promise<void> {
    const settings = await this.dataService.getSettings();
    this.currencySymbol = settings.currency;
  }

  async loadCategories(): Promise<void> {
    this.categories = await this.dataService.getAllCategories();
    if (this.categories.length > 0 && this.selectedCategoryId === '') {
      // 默认选择第一个支出分类
      const firstExpense = this.categories.find(c => c.type === 'expense');
      if (firstExpense) {
        this.selectedCategoryId = firstExpense.id;
      }
    }
  }

  async loadTransaction(): Promise<void> {
    const transaction = await this.dataService.getTransactionById(this.transactionId);
    if (transaction) {
      this.transactionType = transaction.type;
      // 将分转换为元显示
      this.amount = (transaction.amount / 100).toFixed(2);
      this.selectedCategoryId = transaction.categoryId;
      this.description = transaction.description;
      this.selectedDate = transaction.date;
    }
  }

  getFilteredCategories(): Category[] {
    return this.categories.filter(c => c.type === this.transactionType);
  }

  async saveTransaction(): Promise<void> {
    // 验证输入
    if (this.amount === '' || parseFloat(this.amount) <= 0) {
      this.showToast('请输入有效金额');
      return;
    }

    if (this.selectedCategoryId === '') {
      this.showToast('请选择分类');
      return;
    }

    // 将金额转换为分
    const amountInCents = Math.round(parseFloat(this.amount) * 100);

    if (this.isEditMode) {
      // 更新现有交易
      const transaction = new Transaction(
        this.transactionId,
        this.transactionType,
        amountInCents,
        this.selectedCategoryId,
        this.description,
        this.selectedDate
      );
      const success = await this.dataService.updateTransaction(transaction);
      if (success) {
        this.showToast('更新成功');
        const router: Router = this.getUIContext().getRouter();
        router.back();
      } else {
        this.showToast('更新失败');
      }
    } else {
      // 创建新交易
      const transaction = new Transaction(
        this.dataService.generateId(),
        this.transactionType,
        amountInCents,
        this.selectedCategoryId,
        this.description,
        this.selectedDate
      );
      const success = await this.dataService.createTransaction(transaction);
      if (success) {
        this.showToast('添加成功');
        const router: Router = this.getUIContext().getRouter();
        router.back();
      } else {
        this.showToast('添加失败');
      }
    }
  }

  async deleteTransaction(): Promise<void> {
    const uiContext = this.getUIContext();
    uiContext.showAlertDialog({
      title: '确认删除',
      message: '确定要删除这笔交易吗?',
      buttons: [
        {
          value: '取消',
          fontColor: '#666666',
          action: () => {}
        },
        {
          value: '删除',
          fontColor: '#F44336',
          action: async () => {
            const success = await this.dataService.deleteTransaction(this.transactionId);
            if (success) {
              this.showToast('删除成功');
              const router: Router = this.getUIContext().getRouter();
              router.back();
            } else {
              this.showToast('删除失败');
            }
          }
        }
      ]
    });
  }

  showToast(message: string): void {
    // 使用 UIContext 的 PromptAction
    try {
      const uiContext = this.getUIContext();
      const promptAction = uiContext.getPromptAction();
      promptAction.showToast({
        message: message,
        duration: 2000
      });
    } catch (err) {
      console.error('Show toast failed:', err);
    }
  }

  showDatePicker(): void {
    const uiContext = this.getUIContext();
    const currentDate = new Date(this.selectedDate);
    uiContext.showDatePickerDialog({
      start: new Date('1970-1-1'),
      end: new Date('2100-12-31'),
      selected: currentDate,
      lunar: false,
      onDateAccept: (value: Date) => {
        this.selectedDate = value.getTime();
      }
    });
  }

  formatDate(timestamp: number): string {
    const date = new Date(timestamp);
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }

  getCategoryName(categoryId: string): string {
    const category = this.categories.find(c => c.id === categoryId);
    return category ? category.name : '请选择';
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Button('取消')
          .fontSize(16)
          .backgroundColor('#f0f0f0')
          .fontColor('#666666')
          .onClick(() => {
            const router: Router = this.getUIContext().getRouter();
            router.back();
          })

        Text(this.isEditMode ? '编辑交易' : '添加交易')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1a1a1a')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Button('保存')
          .fontSize(16)
          .backgroundColor('#4CAF50')
          .fontColor('#ffffff')
          .onClick(() => this.saveTransaction())
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#ffffff')

      Scroll() {
        Column() {
          // 交易类型选择
          Column() {
            Text('交易类型')
              .fontSize(14)
              .fontColor('#666666')
              .margin({ bottom: 8 })

            Row() {
              Button('支出')
                .fontSize(16)
                .layoutWeight(1)
                .height(48)
                .backgroundColor(this.transactionType === 'expense' ? '#F44336' : '#f0f0f0')
                .fontColor(this.transactionType === 'expense' ? '#ffffff' : '#666666')
                .onClick(() => {
                  this.transactionType = 'expense';
                  // 切换类型时重置分类选择
                  const firstCategory = this.getFilteredCategories()[0];
                  this.selectedCategoryId = firstCategory ? firstCategory.id : '';
                })

              Button('收入')
                .fontSize(16)
                .layoutWeight(1)
                .height(48)
                .margin({ left: 12 })
                .backgroundColor(this.transactionType === 'income' ? '#4CAF50' : '#f0f0f0')
                .fontColor(this.transactionType === 'income' ? '#ffffff' : '#666666')
                .onClick(() => {
                  this.transactionType = 'income';
                  // 切换类型时重置分类选择
                  const firstCategory = this.getFilteredCategories()[0];
                  this.selectedCategoryId = firstCategory ? firstCategory.id : '';
                })
            }
            .width('100%')
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#ffffff')
          .borderRadius(8)
          .margin({ top: 12 })

          // 金额输入
          Column() {
            Text('金额')
              .fontSize(14)
              .fontColor('#666666')
              .margin({ bottom: 8 })

            Row() {
              Text(this.currencySymbol)
                .fontSize(24)
                .fontColor('#1a1a1a')
                .margin({ right: 8 })

              TextInput({ text: this.amount, placeholder: '0.00' })
                .type(InputType.NUMBER_DECIMAL)
                .fontSize(24)
                .fontColor('#1a1a1a')
                .backgroundColor('#ffffff')
                .layoutWeight(1)
                .onChange((value: string) => {
                  this.amount = value;
                })
            }
            .width('100%')
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#ffffff')
          .borderRadius(8)
          .margin({ top: 12 })

          // 分类选择
          Column() {
            Text('分类')
              .fontSize(14)
              .fontColor('#666666')
              .margin({ bottom: 8 })

            // 分类网格
            Grid() {
              ForEach(this.getFilteredCategories(), (category: Category) => {
                GridItem() {
                  Column() {
                    Text(category.name)
                      .fontSize(14)
                      .fontColor(this.selectedCategoryId === category.id ? '#ffffff' : '#1a1a1a')
                  }
                  .width('100%')
                  .height(44)
                  .justifyContent(FlexAlign.Center)
                  .backgroundColor(this.selectedCategoryId === category.id ? '#4CAF50' : '#f5f5f5')
                  .borderRadius(8)
                  .onClick(() => {
                    this.selectedCategoryId = category.id;
                  })
                }
              }, (category: Category) => category.id)
            }
            .columnsTemplate('1fr 1fr 1fr')
            .rowsGap(8)
            .columnsGap(8)
            .width('100%')
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#ffffff')
          .borderRadius(8)
          .margin({ top: 12 })

          // 日期选择
          Column() {
            Text('日期')
              .fontSize(14)
              .fontColor('#666666')
              .margin({ bottom: 8 })

            Row() {
              Text(this.formatDate(this.selectedDate))
                .fontSize(16)
                .fontColor('#1a1a1a')

              Blank()

              Text('选择')
                .fontSize(14)
                .fontColor('#4CAF50')
            }
            .width('100%')
            .height(48)
            .padding({ left: 12, right: 12 })
            .backgroundColor('#f5f5f5')
            .borderRadius(8)
            .onClick(() => this.showDatePicker())
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#ffffff')
          .borderRadius(8)
          .margin({ top: 12 })

          // 备注输入
          Column() {
            Text('备注')
              .fontSize(14)
              .fontColor('#666666')
              .margin({ bottom: 8 })

            TextArea({ text: this.description, placeholder: '添加备注信息...' })
              .width('100%')
              .height(100)
              .fontSize(16)
              .backgroundColor('#f5f5f5')
              .borderRadius(8)
              .onChange((value: string) => {
                this.description = value;
              })
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#ffffff')
          .borderRadius(8)
          .margin({ top: 12, bottom: 16 })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f5f5')
  }
}
