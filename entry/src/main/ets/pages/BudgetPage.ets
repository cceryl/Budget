import { Budget } from '../models/Budget';
import { Category } from '../models/Category';
import { DataService } from '../services/DataService';
import { Router } from '@kit.ArkUI';

/**
 * 预算项视图模型（用于展示）
 */
@Observed
class BudgetViewModel {
  public budget: Budget;
  public categoryName: string;
  public spent: number; // 已消耗金额
  public percentage: number; // 消耗百分比
  public status: string; // 'normal', 'warning', 'danger'

  constructor(budget: Budget, categoryName: string, spent: number) {
    this.budget = budget;
    this.categoryName = categoryName;
    this.spent = spent;
    this.percentage = budget.amount > 0 ? (spent / budget.amount) * 100 : 0;
    
    // 根据消耗百分比确定状态
    if (this.percentage >= 100) {
      this.status = 'danger';
    } else if (this.percentage >= 80) {
      this.status = 'warning';
    } else {
      this.status = 'normal';
    }
  }
}

@Component
export struct BudgetPage {
  @State budgets: Budget[] = [];
  @State categories: Category[] = [];
  @State budgetViewModels: BudgetViewModel[] = [];
  @State currentPeriod: string = 'month'; // 'week', 'month', 'year'
  @State currencySymbol: string = '¥'; // 货币符号
  @Prop @Watch('onRefreshTriggerChange') refreshTrigger: number = 0;
  private dataService: DataService = DataService.getInstance();

  aboutToAppear(): void {
    this.loadData();
  }

  onRefreshTriggerChange(): void {
    this.loadData();
  }

  async loadData(): Promise<void> {
    // 加载货币设置
    const settings = await this.dataService.getSettings();
    this.currencySymbol = settings.currency;
    
    // 加载分类数据
    this.categories = await this.dataService.getAllCategories();
    
    // 加载预算数据
    this.budgets = await this.dataService.getAllBudgets();
    
    // 筛选当前周期的预算
    const periodBudgets = this.budgets.filter(b => 
      b.period === this.currentPeriod && !b.isExpired()
    );

    // 创建视图模型数组
    const viewModels: BudgetViewModel[] = [];
    for (const budget of periodBudgets) {
      const spent = await this.dataService.calculateBudgetSpent(budget);
      let categoryName = '';
      
      if (budget.type === 'global') {
        categoryName = '总预算';
      } else {
        const category = this.categories.find(c => c.id === budget.categoryId);
        categoryName = category ? category.name : '未知分类';
      }
      
      viewModels.push(new BudgetViewModel(budget, categoryName, spent));
    }

    // 按消耗比例从高到低排序
    viewModels.sort((a, b) => b.percentage - a.percentage);
    
    this.budgetViewModels = viewModels;
  }

  navigateToEdit(budgetId?: string): void {
    try {
      const router: Router = this.getUIContext().getRouter();
      if (budgetId) {
        router.pushUrl({
          url: 'pages/BudgetEditPage',
          params: { budgetId: budgetId, period: this.currentPeriod }
        }).catch((err: Error) => {
          console.error('Navigate failed:', err);
        });
      } else {
        router.pushUrl({
          url: 'pages/BudgetEditPage',
          params: { period: this.currentPeriod }
        }).catch((err: Error) => {
          console.error('Navigate failed:', err);
        });
      }
    } catch (err) {
      console.error('Get router failed:', err);
    }
  }

  async deleteBudget(id: string): Promise<void> {
    const success = await this.dataService.deleteBudget(id);
    try {
      const promptAction = this.getUIContext().getPromptAction();
      if (success) {
        promptAction.showToast({ message: '删除成功' });
        this.loadData();
      } else {
        promptAction.showToast({ message: '删除失败' });
      }
    } catch (err) {
      console.error('Show toast failed:', err);
    }
  }

  getPeriodText(): string {
    if (this.currentPeriod === 'week') {
      return '本周预算';
    } else if (this.currentPeriod === 'month') {
      return '本月预算';
    } else if (this.currentPeriod === 'year') {
      return '本年预算';
    }
    return '预算';
  }

  getStatusColor(status: string): string {
    if (status === 'danger') {
      return '#F44336';
    } else if (status === 'warning') {
      return '#FF9800';
    }
    return '#4CAF50';
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text(this.getPeriodText())
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1a1a1a')

        Blank()

        Button('新增预算')
          .fontSize(16)
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .borderRadius(20)
          .backgroundColor('#4CAF50')
          .fontColor('#ffffff')
          .onClick(() => this.navigateToEdit())
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#ffffff')

      // 周期选择器
      Row() {
        Button('周')
          .fontSize(14)
          .height(32)
          .backgroundColor(this.currentPeriod === 'week' ? '#4CAF50' : '#f0f0f0')
          .fontColor(this.currentPeriod === 'week' ? '#ffffff' : '#666666')
          .onClick(() => {
            this.currentPeriod = 'week';
            this.loadData();
          })

        Button('月')
          .fontSize(14)
          .height(32)
          .backgroundColor(this.currentPeriod === 'month' ? '#4CAF50' : '#f0f0f0')
          .fontColor(this.currentPeriod === 'month' ? '#ffffff' : '#666666')
          .margin({ left: 8 })
          .onClick(() => {
            this.currentPeriod = 'month';
            this.loadData();
          })

        Button('年')
          .fontSize(14)
          .height(32)
          .backgroundColor(this.currentPeriod === 'year' ? '#4CAF50' : '#f0f0f0')
          .fontColor(this.currentPeriod === 'year' ? '#ffffff' : '#666666')
          .margin({ left: 8 })
          .onClick(() => {
            this.currentPeriod = 'year';
            this.loadData();
          })
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#ffffff')

      // 预算列表
      if (this.budgetViewModels.length > 0) {
        List({ space: 12 }) {
          ForEach(this.budgetViewModels, (viewModel: BudgetViewModel) => {
            ListItem() {
              this.BudgetItem(viewModel)
            }
            .swipeAction({ end: this.DeleteButton(viewModel.budget.id) })
          }, (viewModel: BudgetViewModel) => JSON.stringify(viewModel.budget))
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16, top: 16, bottom: 16 })
        .backgroundColor('#f5f5f5')
      } else {
        // 空状态
        Column() {
          Text('暂无预算')
            .fontSize(16)
            .fontColor('#999999')
            .margin({ top: 100 })
          Text('点击右上角按钮添加预算')
            .fontSize(14)
            .fontColor('#cccccc')
            .margin({ top: 8 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('#f5f5f5')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f5f5')
  }

  @Builder
  BudgetItem(viewModel: BudgetViewModel) {
    Column() {
      // 标题行
      Row() {
        Text(viewModel.categoryName)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1a1a1a')

        Blank()

        if (viewModel.budget.type === 'global') {
          Text('总')
            .fontSize(12)
            .fontColor('#999999')
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .backgroundColor('#f0f0f0')
            .borderRadius(4)
        }
      }
      .width('100%')

      // 进度条
      Stack({ alignContent: Alignment.Start }) {
        // 背景条
        Row()
          .width('100%')
          .height(8)
          .backgroundColor('#f0f0f0')
          .borderRadius(4)

        // 进度条
        Row()
          .width(`${Math.min(viewModel.percentage, 100)}%`)
          .height(8)
          .backgroundColor(this.getStatusColor(viewModel.status))
          .borderRadius(4)
      }
      .width('100%')
      .margin({ top: 12, bottom: 8 })

      // 金额和百分比
      Row() {
        Text(`${this.currencySymbol}${(viewModel.spent / 100).toFixed(2)} / ${this.currencySymbol}${(viewModel.budget.amount / 100).toFixed(2)}`)
          .fontSize(14)
          .fontColor('#666666')

        Blank()

        Text(`${viewModel.percentage.toFixed(1)}%`)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getStatusColor(viewModel.status))
      }
      .width('100%')

      // 状态提示
      if (viewModel.status === 'danger') {
        Text('已超支！')
          .fontSize(12)
          .fontColor('#F44336')
          .margin({ top: 8 })
          .width('100%')
      } else if (viewModel.status === 'warning') {
        Text('接近预算上限')
          .fontSize(12)
          .fontColor('#FF9800')
          .margin({ top: 8 })
          .width('100%')
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#ffffff')
    .borderRadius(8)
    .onClick(() => this.navigateToEdit(viewModel.budget.id))
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
    .onClick(() => this.deleteBudget(id))
  }
}
