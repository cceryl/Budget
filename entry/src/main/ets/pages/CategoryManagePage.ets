import { Category } from '../models/Category';
import { DataService } from '../services/DataService';
import { Router, PromptAction } from '@kit.ArkUI';

@Entry
@Component
struct CategoryManagePage {
  @State categories: Category[] = [];
  @State selectedTab: number = 0; // 0: 支出, 1: 收入
  @State showAddDialog: boolean = false;
  @State newCategoryName: string = '';
  private dataService: DataService = DataService.getInstance();

  aboutToAppear(): void {
    this.initializeAndLoadCategories();
  }

  async initializeAndLoadCategories(): Promise<void> {
    await this.dataService.waitForInitialization();
    await this.loadCategories();
  }

  async loadCategories(): Promise<void> {
    this.categories = await this.dataService.getAllCategories();
  }

  getFilteredCategories(): Category[] {
    const type = this.selectedTab === 0 ? 'expense' : 'income';
    return this.categories.filter(c => c.type === type);
  }

  async deleteCategory(id: string): Promise<void> {
    const success = await this.dataService.deleteCategory(id);
    if (success) {
      // 同时删除该分类关联的所有预算
      await this.dataService.deleteBudgetsByCategoryId(id);
      this.showToast('删除成功');
      this.loadCategories();
    } else {
      this.showToast('无法删除预设分类');
    }
  }

  async addCategory(): Promise<void> {
    if (this.newCategoryName.trim() === '') {
      this.showToast('请输入分类名称');
      return;
    }

    const type = this.selectedTab === 0 ? 'expense' : 'income';
    const category = new Category(
      this.dataService.generateId(),
      this.newCategoryName.trim(),
      type,
      'custom',
      false
    );

    const success = await this.dataService.createCategory(category);
    if (success) {
      this.showToast('添加成功');
      this.newCategoryName = '';
      this.showAddDialog = false;
      this.loadCategories();
    } else {
      this.showToast('添加失败');
    }
  }

  showToast(message: string): void {
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

  build() {
    Column() {
      // 标题栏
      Row() {
        Button('返回')
          .fontSize(16)
          .backgroundColor('#f0f0f0')
          .fontColor('#666666')
          .onClick(() => {
            const router: Router = this.getUIContext().getRouter();
            router.back();
          })

        Text('分类管理')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1a1a1a')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Button('添加')
          .fontSize(16)
          .backgroundColor('#4CAF50')
          .fontColor('#ffffff')
          .onClick(() => {
            this.showAddDialog = true;
          })
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#ffffff')

      // Tab 切换
      Tabs({ barPosition: BarPosition.Start }) {
        TabContent() {
          this.CategoryList()
        }
        .tabBar('支出分类')

        TabContent() {
          this.CategoryList()
        }
        .tabBar('收入分类')
      }
      .vertical(false)
      .scrollable(false)
      .barMode(BarMode.Fixed)
      .barWidth('100%')
      .barHeight(48)
      .animationDuration(0)
      .onChange((index: number) => {
        this.selectedTab = index;
      })
      .width('100%')
      .layoutWeight(1)
      .backgroundColor('#f5f5f5')

      // 添加分类对话框
      if (this.showAddDialog) {
        this.AddCategoryDialog()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f5f5')
  }

  @Builder
  CategoryList() {
    List({ space: 1 }) {
      ForEach(this.getFilteredCategories(), (category: Category) => {
        ListItem() {
          Row() {
            Column() {
              Text(category.name)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor('#1a1a1a')

              if (category.isPreset) {
                Text('预设分类')
                  .fontSize(12)
                  .fontColor('#999999')
                  .margin({ top: 4 })
              }
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#ffffff')
        }
        .swipeAction({ end: this.DeleteButton(category.id, category.isPreset) })
      }, (category: Category) => category.id)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f5f5')
    .divider({ strokeWidth: 1, color: '#f0f0f0' })
  }

  @Builder
  DeleteButton(categoryId: string, isPreset: boolean) {
    if (!isPreset) {
      Button() {
        Text('删除')
          .fontSize(16)
          .fontColor('#FFFFFF')
      }
      .width(80)
      .height('100%')
      .backgroundColor('#F44336')
      .borderRadius(12)
      .onClick(() => {
        this.deleteCategory(categoryId);
      })
    }
  }

  @Builder
  AddCategoryDialog() {
    Column() {
      // 遮罩层
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')
        .opacity(0.5)
        .onClick(() => {
          this.showAddDialog = false;
          this.newCategoryName = '';
        })

      // 对话框
      Column() {
        Text('添加' + (this.selectedTab === 0 ? '支出' : '收入') + '分类')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1a1a1a')
          .margin({ bottom: 16 })

        TextInput({ text: this.newCategoryName, placeholder: '请输入分类名称' })
          .width('100%')
          .height(48)
          .fontSize(16)
          .backgroundColor('#f5f5f5')
          .borderRadius(8)
          .onChange((value: string) => {
            this.newCategoryName = value;
          })
          .margin({ bottom: 24 })

        Row() {
          Button('取消')
            .fontSize(16)
            .layoutWeight(1)
            .height(44)
            .backgroundColor('#f0f0f0')
            .fontColor('#666666')
            .onClick(() => {
              this.showAddDialog = false;
              this.newCategoryName = '';
            })

          Button('确定')
            .fontSize(16)
            .layoutWeight(1)
            .height(44)
            .margin({ left: 12 })
            .backgroundColor('#4CAF50')
            .fontColor('#ffffff')
            .onClick(() => this.addCategory())
        }
        .width('100%')
      }
      .width('80%')
      .padding(24)
      .backgroundColor('#ffffff')
      .borderRadius(12)
      .position({ x: '10%', y: '35%' })
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
    .zIndex(999)
  }
}
