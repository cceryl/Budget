import { Transaction } from '../models/Transaction';
import { Category } from '../models/Category';
import { Budget, PeriodTime } from '../models/Budget';
import { DataService } from '../services/DataService';

/**
 * 分类统计视图模型
 */
@Observed
class CategoryStatViewModel {
  public categoryId: string;
  public categoryName: string;
  public amount: number; // 金额（分）
  public percentage: number; // 占比
  public color: string; // 显示颜色

  constructor(categoryId: string, categoryName: string, amount: number, percentage: number, color: string) {
    this.categoryId = categoryId;
    this.categoryName = categoryName;
    this.amount = amount;
    this.percentage = percentage;
    this.color = color;
  }
}

/**
 * 趋势数据点
 */
@Observed
class TrendDataPoint {
  public date: string; // 日期标签
  public amount: number; // 金额（分）
  public timestamp: number; // 时间戳

  constructor(date: string, amount: number, timestamp: number) {
    this.date = date;
    this.amount = amount;
    this.timestamp = timestamp;
  }
}

@Component
export struct StatisticsPage {
  @State currentPeriod: string = 'month'; // 'week', 'month', 'year'
  @State totalIncome: number = 0; // 收入总额（分）
  @State totalExpense: number = 0; // 支出总额（分）
  @State balance: number = 0; // 结余（分）
  @State expenseCategories: CategoryStatViewModel[] = []; // 支出分类统计
  @State incomeCategories: CategoryStatViewModel[] = []; // 收入分类统计
  @State trendData: TrendDataPoint[] = []; // 趋势数据
  @State showIncomeStats: boolean = false; // 是否显示收入统计（默认显示支出）
  @State currencySymbol: string = '¥'; // 货币符号
  @State showIncomeTrend: boolean = false; // 是否显示收入趋势（默认显示支出）
  @State dataRefreshKey: number = 0; // 数据刷新计数器，用于强制刷新UI
  @Prop @Watch('onRefreshTriggerChange') refreshTrigger: number = 0;
  
  private dataService: DataService = DataService.getInstance();
  private categories: Category[] = [];
  private readonly CHART_COLORS: string[] = [
    '#FF6384', '#36A2EB', '#FFCE56', '#4BC0C0', '#9966FF',
    '#FF9F40', '#FF6384', '#C9CBCF', '#4BC0C0', '#FF9F40'
  ];

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
    // 先清空所有数据，确保UI完全刷新
    this.trendData = [];
    this.expenseCategories = [];
    this.incomeCategories = [];
    this.totalIncome = 0;
    this.totalExpense = 0;
    this.balance = 0;
    
    // 加载货币设置
    const settings = await this.dataService.getSettings();
    this.currencySymbol = settings.currency;
    
    // 加载分类数据
    this.categories = await this.dataService.getAllCategories();
    
    // 计算当前周期
    const periodTime = Budget.calculatePeriod(this.currentPeriod);
    
    // 加载交易数据
    const allTransactions = await this.dataService.getAllTransactions();
    
    // 筛选当前周期的交易
    const periodTransactions = allTransactions.filter(t =>
      t.date >= periodTime.start && t.date < periodTime.end
    );

    // 计算总览数据
    this.calculateOverview(periodTransactions);
    
    // 计算分类统计
    this.calculateCategoryStats(periodTransactions);
    
    // 计算趋势数据
    this.calculateTrendData(periodTransactions, periodTime);
    
    // 递增刷新计数器，强制刷新UI
    this.dataRefreshKey++;
  }

  /**
   * 计算总览数据
   */
  calculateOverview(transactions: Transaction[]): void {
    let income = 0;
    let expense = 0;

    for (const t of transactions) {
      if (t.type === 'income') {
        income += t.amount;
      } else if (t.type === 'expense') {
        expense += t.amount;
      }
    }

    this.totalIncome = income;
    this.totalExpense = expense;
    this.balance = income - expense;
  }

  /**
   * 计算分类统计
   */
  calculateCategoryStats(transactions: Transaction[]): void {
    // 分别统计收入和支出
    const expenseMap = new Map<string, number>();
    const incomeMap = new Map<string, number>();

    for (const t of transactions) {
      if (t.type === 'expense') {
        const current = expenseMap.get(t.categoryId);
        if (current !== undefined) {
          expenseMap.set(t.categoryId, current + t.amount);
        } else {
          expenseMap.set(t.categoryId, t.amount);
        }
      } else if (t.type === 'income') {
        const current = incomeMap.get(t.categoryId);
        if (current !== undefined) {
          incomeMap.set(t.categoryId, current + t.amount);
        } else {
          incomeMap.set(t.categoryId, t.amount);
        }
      }
    }

    // 构建支出分类视图模型
    const expenseVMs: CategoryStatViewModel[] = [];
    let colorIndex = 0;
    
    const expenseEntries: Array<[string, number]> = [];
    expenseMap.forEach((value, key) => {
      expenseEntries.push([key, value]);
    });
    
    for (const entry of expenseEntries) {
      const categoryId = entry[0];
      const amount = entry[1];
      const category = this.categories.find(c => c.id === categoryId);
      const categoryName = category ? category.name : '未知分类';
      const percentage = this.totalExpense > 0 ? (amount / this.totalExpense) * 100 : 0;
      const color = this.CHART_COLORS[colorIndex % this.CHART_COLORS.length];
      
      expenseVMs.push(new CategoryStatViewModel(categoryId, categoryName, amount, percentage, color));
      colorIndex++;
    }
    
    // 按金额降序排序
    expenseVMs.sort((a, b) => b.amount - a.amount);
    this.expenseCategories = expenseVMs;

    // 构建收入分类视图模型
    const incomeVMs: CategoryStatViewModel[] = [];
    colorIndex = 0;
    
    const incomeEntries: Array<[string, number]> = [];
    incomeMap.forEach((value, key) => {
      incomeEntries.push([key, value]);
    });
    
    for (const entry of incomeEntries) {
      const categoryId = entry[0];
      const amount = entry[1];
      const category = this.categories.find(c => c.id === categoryId);
      const categoryName = category ? category.name : '未知分类';
      const percentage = this.totalIncome > 0 ? (amount / this.totalIncome) * 100 : 0;
      const color = this.CHART_COLORS[colorIndex % this.CHART_COLORS.length];
      
      incomeVMs.push(new CategoryStatViewModel(categoryId, categoryName, amount, percentage, color));
      colorIndex++;
    }
    
    // 按金额降序排序
    incomeVMs.sort((a, b) => b.amount - a.amount);
    this.incomeCategories = incomeVMs;
  }

  /**
   * 计算趋势数据
   */
  calculateTrendData(transactions: Transaction[], periodTime: PeriodTime): void {
    const dataMap = new Map<string, number>();
    const targetType = this.showIncomeTrend ? 'income' : 'expense';
    
    // 根据周期类型决定分组粒度
    if (this.currentPeriod === 'week') {
      // 按天分组
      for (const t of transactions) {
        if (t.type === targetType) {
          const date = new Date(t.date);
          const dateKey = `${date.getMonth() + 1}/${date.getDate()}`;
          const current = dataMap.get(dateKey);
          if (current !== undefined) {
            dataMap.set(dateKey, current + t.amount);
          } else {
            dataMap.set(dateKey, t.amount);
          }
        }
      }
      
      // 填充完整的7天数据
      const points: TrendDataPoint[] = [];
      const startDate = new Date(periodTime.start);
      for (let i = 0; i < 7; i++) {
        const currentDate = new Date(startDate.getTime());
        currentDate.setDate(currentDate.getDate() + i);
        const dateKey = `${currentDate.getMonth() + 1}/${currentDate.getDate()}`;
        const amount = dataMap.get(dateKey);
        points.push(new TrendDataPoint(dateKey, amount !== undefined ? amount : 0, currentDate.getTime()));
      }
      this.trendData = points;
    } else if (this.currentPeriod === 'month') {
      // 按天分组（显示本月每一天）
      const startDate = new Date(periodTime.start);
      const targetMonth = startDate.getMonth();
      const targetYear = startDate.getFullYear();
      
      for (const t of transactions) {
        if (t.type === targetType) {
          const date = new Date(t.date);
          // 确保是同一个月
          if (date.getMonth() === targetMonth && date.getFullYear() === targetYear) {
            const dateKey = `${date.getDate()}`;
            const current = dataMap.get(dateKey);
            if (current !== undefined) {
              dataMap.set(dateKey, current + t.amount);
            } else {
              dataMap.set(dateKey, t.amount);
            }
          }
        }
      }
      
      // 填充完整的月份数据
      const points: TrendDataPoint[] = [];
      const endDate = new Date(periodTime.end);
      const daysInMonth = Math.floor((endDate.getTime() - startDate.getTime()) / (24 * 60 * 60 * 1000));
      
      for (let i = 0; i < daysInMonth; i++) {
        const currentDate = new Date(startDate.getTime());
        currentDate.setDate(currentDate.getDate() + i);
        const dateKey = `${currentDate.getDate()}`;
        const amount = dataMap.get(dateKey);
        points.push(new TrendDataPoint(dateKey, amount !== undefined ? amount : 0, currentDate.getTime()));
      }
      this.trendData = points;
    } else if (this.currentPeriod === 'year') {
      // 按月分组
      for (const t of transactions) {
        if (t.type === targetType) {
          const date = new Date(t.date);
          const month = date.getMonth() + 1;
          const dateKey = `${month}`;
          const current = dataMap.get(dateKey);
          if (current !== undefined) {
            dataMap.set(dateKey, current + t.amount);
          } else {
            dataMap.set(dateKey, t.amount);
          }
        }
      }
      
      // 填充完整的12个月数据
      const points: TrendDataPoint[] = [];
      for (let i = 1; i <= 12; i++) {
        const dateKey = `${i}`;
        const displayKey = `${i}月`;
        const amount = dataMap.get(dateKey);
        const timestamp = new Date(periodTime.start).setMonth(i - 1);
        points.push(new TrendDataPoint(displayKey, amount !== undefined ? amount : 0, timestamp));
      }
      this.trendData = points;
    }
  }

  getPeriodText(): string {
    if (this.currentPeriod === 'week') {
      return '本周统计';
    } else if (this.currentPeriod === 'month') {
      return '本月统计';
    } else if (this.currentPeriod === 'year') {
      return '本年统计';
    }
    return '统计';
  }

  /**
   * 根据金额长度计算合适的字号（保持卡片高度一致）
   */
  calculateAmountFontSize(amount: number): number {
    const amountStr = `${this.currencySymbol}${(Math.abs(amount) / 100).toFixed(2)}`;
    const length = amountStr.length;
    
    if (length <= 8) {
      return 18; // 短金额
    } else if (length <= 10) {
      return 16; // 中等长度
    } else if (length <= 12) {
      return 14; // 较长
    } else {
      return 10; // 超长金额
    }
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text(this.getPeriodText())
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
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

      // 滚动内容区
      Scroll() {
        Column() {
          // 总览模块
          this.OverviewSection()

          // 分类统计模块
          this.CategoryStatsSection()

          // 趋势图模块
          this.TrendSection()
        }
        .width('100%')
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor($r('app.color.background_secondary'))
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background_secondary'))
  }

  /**
   * 总览模块
   */
  @Builder
  OverviewSection() {
    Column() {
      Text('总览')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .margin({ bottom: 16 })

      // 三个指标卡片
      Row({ space: 12 }) {
        // 收入
        Column({ space: 8 }) {
          Text('收入')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
          Text(`${this.currencySymbol}${(this.totalIncome / 100).toFixed(2)}`)
            .fontSize(this.calculateAmountFontSize(this.totalIncome))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.income_color'))
            .maxLines(1)
            .height(32)
            .width('100%')
            .textAlign(TextAlign.Center)
        }
        .layoutWeight(1)
        .padding(14)
        .backgroundColor($r('app.color.card_background'))
        .borderRadius(12)
        .shadow({ radius: 4, color: $r('app.color.shadow_light'), offsetY: 2 })
        .alignItems(HorizontalAlign.Center)

        // 支出
        Column({ space: 8 }) {
          Text('支出')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
          Text(`${this.currencySymbol}${(this.totalExpense / 100).toFixed(2)}`)
            .fontSize(this.calculateAmountFontSize(this.totalExpense))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.expense_color'))
            .maxLines(1)
            .height(32)
            .width('100%')
            .textAlign(TextAlign.Center)
        }
        .layoutWeight(1)
        .padding(14)
        .backgroundColor($r('app.color.card_background'))
        .borderRadius(12)
        .shadow({ radius: 4, color: $r('app.color.shadow_light'), offsetY: 2 })
        .alignItems(HorizontalAlign.Center)

        // 结余
        Column({ space: 8 }) {
          Text('结余')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
          Text(`${this.currencySymbol}${(this.balance / 100).toFixed(2)}`)
            .fontSize(this.calculateAmountFontSize(this.balance))
            .fontWeight(FontWeight.Bold)
            .fontColor(this.balance >= 0 ? $r('app.color.income_color') : $r('app.color.expense_color'))
            .maxLines(1)
            .height(32)
            .width('100%')
            .textAlign(TextAlign.Center)
        }
        .layoutWeight(1)
        .padding(14)
        .backgroundColor($r('app.color.card_background'))
        .borderRadius(12)
        .shadow({ radius: 4, color: $r('app.color.shadow_light'), offsetY: 2 })
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
  }

  /**
   * 分类统计模块
   */
  @Builder
  CategoryStatsSection() {
    Column() {
      // 标题和切换按钮
      Row() {
        Text('分类统计')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))

        Blank()

        // 收入/支出切换
        Row({ space: 8 }) {
          Button('支出')
            .fontSize(12)
            .height(32)
            .padding({ left: 14, right: 14 })
            .backgroundColor(!this.showIncomeStats ? $r('app.color.primary_color') : $r('app.color.button_secondary_bg'))
            .fontColor(!this.showIncomeStats ? '#FFFFFF' : $r('app.color.button_secondary_text'))
            .borderRadius(16)
            .onClick(() => {
              this.showIncomeStats = false;
            })

          Button('收入')
            .fontSize(12)
            .height(32)
            .padding({ left: 14, right: 14 })
            .backgroundColor(this.showIncomeStats ? $r('app.color.primary_color') : $r('app.color.button_secondary_bg'))
            .fontColor(this.showIncomeStats ? '#FFFFFF' : $r('app.color.button_secondary_text'))
            .borderRadius(16)
            .onClick(() => {
              this.showIncomeStats = true;
            })
        }
      }
      .width('100%')
      .margin({ bottom: 16 })

      // 饼图（简化版 - 使用圆环图）
      if (this.showIncomeStats) {
        if (this.incomeCategories.length > 0) {
          this.SimplePieChart()
        } else {
          this.EmptyDataPlaceholder('暂无收入数据')
        }
      } else {
        if (this.expenseCategories.length > 0) {
          this.SimplePieChart()
        } else {
          this.EmptyDataPlaceholder('暂无支出数据')
        }
      }

      // 分类列表
      if (this.showIncomeStats) {
        this.CategoryList()
      } else {
        this.CategoryList()
      }
    }
    .width('100%')
    .padding(16)
    .margin({ top: 8 })
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(12)
    .shadow({ radius: 4, color: $r('app.color.shadow_light'), offsetY: 2 })
  }

  /**
   * 简化版饼图（使用堆叠的进度条表示）
   */
  @Builder
  SimplePieChart() {
    Column() {
      // 圆环图的替代方案：横向堆叠条
      Row() {
        ForEach(this.showIncomeStats ? this.incomeCategories : this.expenseCategories, (cat: CategoryStatViewModel, index: number) => {
          if (index < 5) { // 只显示前5个分类
            Row()
              .width(`${cat.percentage}%`)
              .height(12)
              .backgroundColor(cat.color)
          }
        }, (cat: CategoryStatViewModel) => `${this.dataRefreshKey}-${cat.categoryId}`)
      }
      .width('100%')
      .borderRadius(6)
      .margin({ top: 16, bottom: 16 })

      // 图例
      Column() {
        ForEach(this.showIncomeStats ? this.incomeCategories : this.expenseCategories, (cat: CategoryStatViewModel, index: number) => {
          if (index < 5) { // 只显示前5个分类
            Row() {
              Row()
                .width(12)
                .height(12)
                .backgroundColor(cat.color)
                .borderRadius(2)

              Text(cat.categoryName)
                .fontSize(14)
                .fontColor('#666666')
                .margin({ left: 8 })

              Blank()

              Text(`${cat.percentage.toFixed(1)}%`)
                .fontSize(14)
                .fontColor('#999999')
            }
            .width('100%')
            .margin({ bottom: 8 })
          }
        }, (cat: CategoryStatViewModel) => `${this.dataRefreshKey}-${cat.categoryId}`)

        // 如果分类超过5个，显示"其他"
        if ((this.showIncomeStats ? this.incomeCategories.length : this.expenseCategories.length) > 5) {
          Text(`...还有${(this.showIncomeStats ? this.incomeCategories.length : this.expenseCategories.length) - 5}个分类`)
            .fontSize(12)
            .fontColor('#999999')
            .margin({ top: 4 })
        }
      }
      .width('100%')
    }
    .width('100%')
  }

  /**
   * 分类列表
   */
  @Builder
  CategoryList() {
    Column() {
      Text('详细列表')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .margin({ top: 20, bottom: 14 })

      ForEach(this.showIncomeStats ? this.incomeCategories : this.expenseCategories, (cat: CategoryStatViewModel) => {
        Column({ space: 8 }) {
          Row() {
            Row()
              .width(4)
              .height(16)
              .backgroundColor(cat.color)
              .borderRadius(2)
              .margin({ right: 10 })

            Text(cat.categoryName)
              .fontSize(15)
              .fontColor($r('app.color.text_primary'))

            Blank()

            Text(`${this.currencySymbol}${(cat.amount / 100).toFixed(2)}`)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
          }
          .width('100%')

          // 占比条
          Stack({ alignContent: Alignment.Start }) {
            Row()
              .width('100%')
              .height(6)
              .backgroundColor($r('app.color.button_secondary_bg'))
              .borderRadius(3)

            Row()
              .width(`${cat.percentage}%`)
              .height(6)
              .backgroundColor(cat.color)
              .borderRadius(3)
          }
          .width('100%')

          Text(`${cat.percentage.toFixed(1)}%`)
            .fontSize(12)
            .fontColor($r('app.color.text_tertiary'))
            .width('100%')
        }
        .width('100%')
        .padding({ top: 12, bottom: 12 })
        .borderWidth({ bottom: 1 })
        .borderColor($r('app.color.divider'))
      }, (cat: CategoryStatViewModel) => `${this.dataRefreshKey}-${cat.categoryId}`)
    }
    .width('100%')
  }

  /**
   * 趋势图模块
   */
  @Builder
  TrendSection() {
    Column() {
      // 标题和切换按钮
      Row() {
        Text('趋势分析')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))

        Blank()

        // 收入/支出切换
        Row({ space: 8 }) {
          Button('支出')
            .fontSize(12)
            .height(32)
            .padding({ left: 14, right: 14 })
            .backgroundColor(!this.showIncomeTrend ? $r('app.color.primary_color') : $r('app.color.button_secondary_bg'))
            .fontColor(!this.showIncomeTrend ? '#FFFFFF' : $r('app.color.button_secondary_text'))
            .borderRadius(16)
            .onClick(() => {
              this.showIncomeTrend = false;
              this.loadData();
            })

          Button('收入')
            .fontSize(12)
            .height(32)
            .padding({ left: 14, right: 14 })
            .backgroundColor(this.showIncomeTrend ? $r('app.color.primary_color') : $r('app.color.button_secondary_bg'))
            .fontColor(this.showIncomeTrend ? '#FFFFFF' : $r('app.color.button_secondary_text'))
            .borderRadius(16)
            .onClick(() => {
              this.showIncomeTrend = true;
              this.loadData();
            })
        }
      }
      .width('100%')
      .margin({ bottom: 16 })

      if (this.trendData.length > 0) {
        this.SimpleTrendChart()
      } else {
        this.EmptyDataPlaceholder(this.showIncomeTrend ? '暂无收入数据' : '暂无支出数据')
      }
    }
    .width('100%')
    .padding(16)
    .margin({ top: 8, bottom: 16 })
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(12)
    .shadow({ radius: 4, color: $r('app.color.shadow_light'), offsetY: 2 })
  }

  /**
   * 获取趋势数据的最大值
   */
  getMaxTrendAmount(): number {
    let maxAmount = 0;
    for (const point of this.trendData) {
      if (point.amount > maxAmount) {
        maxAmount = point.amount;
      }
    }
    return maxAmount;
  }

  /**
   * 判断是否应该显示日期标签（用于月视图优化）
   * 只显示1号和被5整除的日期
   */
  shouldShowDateLabel(dateStr: string): boolean {
    // 周视图和年视图的日期包含非数字字符，全部显示
    if (dateStr.includes('/') || dateStr.includes('月')) {
      return true;
    }
    
    // 月视图：只显示纯数字日期
    const day = parseInt(dateStr);
    if (isNaN(day)) {
      return true;
    }
    
    // 显示1号和被5整除的日期（5, 10, 15, 20, 25, 30）
    return day === 1 || day % 5 === 0;
  }

  /**
   * 简化版趋势图（使用柱状图）
   */
  @Builder
  SimpleTrendChart() {
    Column() {
      if (this.getMaxTrendAmount() === 0) {
        this.EmptyDataPlaceholder(this.showIncomeTrend ? '暂无收入数据' : '暂无支出数据')
      } else {
        // 柱状图
        Row({ space: 2 }) {
          ForEach(this.trendData, (point: TrendDataPoint) => {
            Column() {
              // 柱子容器（固定高度区域）
              Column() {
                Column()
                  .width('100%')
                  .height(point.amount > 0 ? `${(point.amount / this.getMaxTrendAmount()) * 100}%` : '2%')
                  .backgroundColor(this.showIncomeTrend ? $r('app.color.income_color') : $r('app.color.accent_info'))
                  .borderRadius(5)
              }
              .width('100%')
              .height(170)
              .justifyContent(FlexAlign.End)

              // 日期标签容器
              Stack() {
                if (this.shouldShowDateLabel(point.date)) {
                  Text(point.date)
                    .fontSize(10)
                    .fontColor($r('app.color.text_tertiary'))
                    .textAlign(TextAlign.Center)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.None })
                    .clip(false)
                }
              }
              .width('200%')
              .height(24)
              .margin({ top: 6 })
              .clip(false)
            }
            .layoutWeight(1)
            .justifyContent(FlexAlign.End)
            .clip(false)
          }, (point: TrendDataPoint) => `${this.dataRefreshKey}-${point.timestamp}`)
        }
        .width('100%')
        .margin({ top: 16 })
        .height(200)

        // 显示最大值参考
        Text(`最高: ${this.currencySymbol}${(this.getMaxTrendAmount() / 100).toFixed(2)}`)
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'))
          .margin({ top: 12 })
          .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  EmptyDataPlaceholder(message: string) {
    Column() {
      Text(message)
        .fontSize(14)
        .fontColor($r('app.color.text_tertiary'))
        .margin({ top: 40, bottom: 40 })
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
