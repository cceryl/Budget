import { Budget } from '../models/Budget';
import { Category } from '../models/Category';
import { DataService } from '../services/DataService';
import { Router } from '@kit.ArkUI';

@Entry
@Component
struct BudgetEditPage {
  @State budgetType: string = 'category'; // 'global' 或 'category'
  @State selectedCategoryId: string = '';
  @State amount: string = '';
  @State period: string = 'month'; // 'week', 'month', 'year'
  @State categories: Category[] = [];
  @State showCategorySelector: boolean = false;
  @State isEditMode: boolean = false;
  @State currentBudgetId: string = '';
  private dataService: DataService = DataService.getInstance();

  async aboutToAppear(): Promise<void> {
    // 加载分类数据（只加载支出分类）
    const allCategories = await this.dataService.getAllCategories();
    this.categories = allCategories.filter(c => c.type === 'expense');
    
    // 如果有分类，默认选择第一个
    if (this.categories.length > 0) {
      this.selectedCategoryId = this.categories[0].id;
    }

    // 检查是否是编辑模式
    try {
      const params = this.getUIContext().getRouter().getParams() as Record<string, Object>;
      if (params && params['budgetId']) {
        this.isEditMode = true;
        this.currentBudgetId = params['budgetId'] as string;
        await this.loadBudget();
      }
      
      // 获取传入的周期参数
      if (params && params['period']) {
        this.period = params['period'] as string;
      }
    } catch (err) {
      console.error('Get router params failed:', err);
    }
  }

  async loadBudget(): Promise<void> {
    const budget = await this.dataService.getBudgetById(this.currentBudgetId);
    if (budget) {
      this.budgetType = budget.type;
      this.selectedCategoryId = budget.categoryId;
      // 将分转换为元，保留两位小数
      const amountInYuan = budget.amount / 100;
      this.amount = amountInYuan.toFixed(2);
      this.period = budget.period;
      console.info(`Load budget: ${budget.amount} cents = ${this.amount} yuan`);
    }
  }

  getCategoryName(categoryId: string): string {
    const category = this.categories.find(c => c.id === categoryId);
    return category ? category.name : '请选择分类';
  }

  async saveBudget(): Promise<void> {
    try {
      const promptAction = this.getUIContext().getPromptAction();

      // 验证输入
      if (this.budgetType === 'category' && !this.selectedCategoryId) {
        promptAction.showToast({ message: '请选择分类' });
        return;
      }

      if (!this.amount || parseFloat(this.amount) <= 0) {
        promptAction.showToast({ message: '请输入有效的预算金额' });
        return;
      }

      // 检查是否已存在同分类同周期的预算
      if (!this.isEditMode) {
        let existingBudget: Budget | null = null;
        
        if (this.budgetType === 'global') {
          existingBudget = await this.dataService.getGlobalBudget(this.period);
        } else {
          existingBudget = await this.dataService.getBudgetByCategoryAndPeriod(
            this.selectedCategoryId,
            this.period
          );
        }

        if (existingBudget) {
          promptAction.showToast({ message: '该分类在此周期已存在预算，请编辑现有预算' });
          return;
        }
      }

      // 创建或更新预算
      // 将用户输入的元转换为分（数据库存储单位）
      const amountInYuan = parseFloat(this.amount);
      const amountInCents = Math.round(amountInYuan * 100);
      console.info(`Save budget: ${this.amount} yuan = ${amountInCents} cents`);
      let success = false;

      if (this.isEditMode) {
        // 更新现有预算
        const budget = await this.dataService.getBudgetById(this.currentBudgetId);
        if (budget) {
          budget.type = this.budgetType;
          budget.categoryId = this.budgetType === 'global' ? '' : this.selectedCategoryId;
          budget.amount = amountInCents;
          budget.period = this.period;
          
          // 重新计算周期时间
          const periodTime = Budget.calculatePeriod(this.period);
          budget.periodStart = periodTime.start;
          budget.periodEnd = periodTime.end;
          
          success = await this.dataService.updateBudget(budget);
        }
      } else {
        // 创建新预算
        const budget = Budget.createNew(
          this.dataService.generateId(),
          this.budgetType,
          this.budgetType === 'global' ? '' : this.selectedCategoryId,
          amountInCents,
          this.period
        );
        success = await this.dataService.createBudget(budget);
      }

      if (success) {
        promptAction.showToast({ message: this.isEditMode ? '更新成功' : '添加成功' });
        this.navigateBack();
      } else {
        promptAction.showToast({ message: this.isEditMode ? '更新失败' : '添加失败' });
      }
    } catch (err) {
      console.error('Save budget failed:', err);
    }
  }

  navigateBack(): void {
    try {
      const router: Router = this.getUIContext().getRouter();
      router.back();
    } catch (err) {
      console.error('Navigate back failed:', err);
    }
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Button('取消')
          .fontSize(16)
          .backgroundColor('#ffffff')
          .fontColor('#666666')
          .onClick(() => this.navigateBack())

        Blank()

        Text(this.isEditMode ? '编辑预算' : '新增预算')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1a1a1a')

        Blank()

        Button('保存')
          .fontSize(16)
          .backgroundColor('#ffffff')
          .fontColor('#4CAF50')
          .onClick(() => this.saveBudget())
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#ffffff')
      .borderWidth({ bottom: 1 })
      .borderColor('#f0f0f0')

      // 表单内容
      Column() {
        // 预算类型选择
        Row() {
          Text('预算类型：')
            .fontSize(16)
            .fontColor('#1a1a1a')
            .width(100)

          Row() {
            Row() {
              Radio({ value: 'global', group: 'budgetType' })
                .checked(this.budgetType === 'global')
                .onChange((isChecked: boolean) => {
                  if (isChecked) {
                    this.budgetType = 'global';
                  }
                })
              Text('总预算')
                .fontSize(16)
                .fontColor('#1a1a1a')
                .margin({ left: 8 })
            }
            .onClick(() => {
              this.budgetType = 'global';
            })

            Row() {
              Radio({ value: 'category', group: 'budgetType' })
                .checked(this.budgetType === 'category')
                .onChange((isChecked: boolean) => {
                  if (isChecked) {
                    this.budgetType = 'category';
                  }
                })
              Text('分类预算')
                .fontSize(16)
                .fontColor('#1a1a1a')
                .margin({ left: 8 })
            }
            .margin({ left: 24 })
            .onClick(() => {
              this.budgetType = 'category';
            })
          }
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#ffffff')

        // 分类选择（仅在分类预算时显示）
        if (this.budgetType === 'category') {
          Row() {
            Text('选择分类：')
              .fontSize(16)
              .fontColor('#1a1a1a')
              .width(100)

            Button() {
              Row() {
                Text(this.getCategoryName(this.selectedCategoryId))
                  .fontSize(16)
                  .fontColor('#1a1a1a')
                Text(' ▼')
                  .fontSize(12)
                  .fontColor('#999999')
              }
            }
            .padding({ left: 12, right: 12 })
            .height(40)
            .backgroundColor('#f5f5f5')
            .layoutWeight(1)
            .onClick(() => {
              this.showCategorySelector = true;
            })
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#ffffff')
          .margin({ top: 1 })
        }

        // 预算金额
        Row() {
          Text('预算金额：')
            .fontSize(16)
            .fontColor('#1a1a1a')
            .width(100)

          TextInput({ placeholder: '请输入金额', text: this.amount })
            .fontSize(16)
            .type(InputType.NUMBER_DECIMAL)
            .layoutWeight(1)
            .backgroundColor('#f5f5f5')
            .onChange((value: string) => {
              this.amount = value;
            })
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#ffffff')
        .margin({ top: 1 })

        // 周期选择
        Row() {
          Text('周期：')
            .fontSize(16)
            .fontColor('#1a1a1a')
            .width(100)

          Row() {
            Button('周')
              .fontSize(14)
              .height(32)
              .backgroundColor(this.period === 'week' ? '#4CAF50' : '#f0f0f0')
              .fontColor(this.period === 'week' ? '#ffffff' : '#666666')
              .onClick(() => {
                this.period = 'week';
              })

            Button('月')
              .fontSize(14)
              .height(32)
              .backgroundColor(this.period === 'month' ? '#4CAF50' : '#f0f0f0')
              .fontColor(this.period === 'month' ? '#ffffff' : '#666666')
              .margin({ left: 8 })
              .onClick(() => {
                this.period = 'month';
              })

            Button('年')
              .fontSize(14)
              .height(32)
              .backgroundColor(this.period === 'year' ? '#4CAF50' : '#f0f0f0')
              .fontColor(this.period === 'year' ? '#ffffff' : '#666666')
              .margin({ left: 8 })
              .onClick(() => {
                this.period = 'year';
              })
          }
          .layoutWeight(1)
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#ffffff')
        .margin({ top: 1 })
      }
      .width('100%')
      .margin({ top: 16 })

      Blank()

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
          ForEach(this.categories, (category: Category) => {
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
}
