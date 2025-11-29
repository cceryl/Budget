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
    this.initializeAndLoadData();
  }

  async initializeAndLoadData(): Promise<void> {
    await this.dataService.waitForInitialization();
    await this.loadData();
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
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))

        Blank()

        Button('新增预算')
          .fontSize(14)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .borderRadius(20)
          .backgroundColor($r('app.color.primary_color'))
          .fontColor('#FFFFFF')
          .onClick(() => this.navigateToEdit())
      }
      .width('100%')
      .height(64)
      .padding({ left: 20, right: 20 })
      .backgroundColor($r('app.color.background_primary'))

      // 周期选择器
      Row({ space: 12 }) {
        Button('周')
          .fontSize(14)
          .height(36)
          .padding({ left: 16, right: 16 })
          .backgroundColor(this.currentPeriod === 'week' ? $r('app.color.primary_color') : $r('app.color.button_secondary_bg'))
          .fontColor(this.currentPeriod === 'week' ? '#FFFFFF' : $r('app.color.button_secondary_text'))
          .borderRadius(18)
          .onClick(async () => {
            this.currentPeriod = 'week';
            await this.loadData();
          })

        Button('月')
          .fontSize(14)
          .height(36)
          .padding({ left: 16, right: 16 })
          .backgroundColor(this.currentPeriod === 'month' ? $r('app.color.primary_color') : $r('app.color.button_secondary_bg'))
          .fontColor(this.currentPeriod === 'month' ? '#FFFFFF' : $r('app.color.button_secondary_text'))
          .borderRadius(18)
          .onClick(async () => {
            this.currentPeriod = 'month';
            await this.loadData();
          })

        Button('年')
          .fontSize(14)
          .height(36)
          .padding({ left: 16, right: 16 })
          .backgroundColor(this.currentPeriod === 'year' ? $r('app.color.primary_color') : $r('app.color.button_secondary_bg'))
          .fontColor(this.currentPeriod === 'year' ? '#FFFFFF' : $r('app.color.button_secondary_text'))
          .borderRadius(18)
          .onClick(async () => {
            this.currentPeriod = 'year';
            await this.loadData();
          })
      }
      .width('100%')
      .padding(16)
      .backgroundColor($r('app.color.background_primary'))

      // 预算列表
      if (this.budgetViewModels.length > 0) {
        List({ space: 12 }) {
          ForEach(this.budgetViewModels, (viewModel: BudgetViewModel) => {
            ListItem() {
              this.BudgetItem(viewModel)
            }
            .swipeAction({ end: this.DeleteButton(viewModel.budget.id) })
          }, (viewModel: BudgetViewModel) => JSON.stringify(viewModel))
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16, top: 12, bottom: 16 })
        .backgroundColor($r('app.color.background_secondary'))
      } else {
        // 空状态
        Column() {
          Text('暂无预算')
            .fontSize(16)
            .fontColor($r('app.color.text_tertiary'))
            .margin({ top: 100 })
          Text('点击右上角按钮添加预算')
            .fontSize(14)
            .fontColor($r('app.color.text_disabled'))
            .margin({ top: 8 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor($r('app.color.background_secondary'))
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background_secondary'))
  }

  @Builder
  BudgetItem(viewModel: BudgetViewModel) {
    Column({ space: 12 }) {
      // 标题行
      Row() {
        Text(viewModel.categoryName)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))

        Blank()

        if (viewModel.budget.type === 'global') {
          Text('总')
            .fontSize(12)
            .fontColor($r('app.color.text_tertiary'))
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor($r('app.color.button_secondary_bg'))
            .borderRadius(6)
        }
      }
      .width('100%')

      // 进度条
      Stack({ alignContent: Alignment.Start }) {
        // 背景条
        Row()
          .width('100%')
          .height(10)
          .backgroundColor($r('app.color.button_secondary_bg'))
          .borderRadius(5)

        // 进度条
        Row()
          .width(`${Math.min(viewModel.percentage, 100)}%`)
          .height(10)
          .backgroundColor(this.getStatusColor(viewModel.status))
          .borderRadius(5)
      }
      .width('100%')

      // 金额和百分比
      Row() {
        Text(`${this.currencySymbol}${(viewModel.spent / 100).toFixed(2)} / ${this.currencySymbol}${(viewModel.budget.amount / 100).toFixed(2)}`)
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))

        Blank()

        Text(`${viewModel.percentage.toFixed(1)}%`)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getStatusColor(viewModel.status))
      }
      .width('100%')

      // 状态提示
      if (viewModel.status === 'danger') {
        Text('已超支！')
          .fontSize(12)
          .fontColor($r('app.color.accent_danger'))
          .width('100%')
      } else if (viewModel.status === 'warning') {
        Text('接近预算上限')
          .fontSize(12)
          .fontColor($r('app.color.accent_warning'))
          .width('100%')
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(12)
    .shadow({ radius: 4, color: $r('app.color.shadow_light'), offsetY: 2 })
    .onClick(() => this.navigateToEdit(viewModel.budget.id))
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
    .onClick(() => this.deleteBudget(id))
  }
}
