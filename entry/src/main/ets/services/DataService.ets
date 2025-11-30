import { preferences } from '@kit.ArkData';
import { Transaction, TransactionJson } from '../models/Transaction';
import { Category, CategoryJson, PRESET_CATEGORIES } from '../models/Category';
import { Budget, BudgetJson } from '../models/Budget';
import { Settings, SettingsJson } from '../models/Settings';
import { ChatMessage, ChatMessageJson } from '../models/ChatMessage';

/**
 * 导出数据的完整结构接口
 */
interface ExportData {
  transactions: TransactionJson[];
  categories: CategoryJson[];
  budgets: BudgetJson[];
  settings: SettingsJson;
  exportTime: number;
  version: string;
}

/**
 * 数据持久化服务
 * 使用 Preferences 实现简单的本地存储
 */
export class DataService {
  private static instance: DataService;
  private preferencesInstance: preferences.Preferences | null = null;
  private readonly TRANSACTION_KEY = 'transactions';
  private readonly CATEGORY_KEY = 'categories';
  private readonly BUDGET_KEY = 'budgets';
  private readonly SETTINGS_KEY = 'settings';
  private readonly CHAT_MESSAGES_KEY = 'chat_messages';
  private readonly PREFERENCES_NAME = 'budget_data';
  private isInitialized: boolean = false;
  private initializationPromise: Promise<void> | null = null;

  private constructor() {}

  public static getInstance(): DataService {
    if (!DataService.instance) {
      DataService.instance = new DataService();
    }
    return DataService.instance;
  }

  /**
   * 检查是否已初始化
   */
  public getIsInitialized(): boolean {
    return this.isInitialized;
  }

  /**
   * 等待初始化完成
   */
  public async waitForInitialization(): Promise<void> {
    if (this.isInitialized) {
      return;
    }
    if (this.initializationPromise) {
      await this.initializationPromise;
    }
  }

  /**
   * 初始化数据存储
   */
  public async initialize(context: Context): Promise<void> {
    if (this.isInitialized) {
      return;
    }
    
    if (this.initializationPromise) {
      await this.initializationPromise;
      return;
    }
    
    this.initializationPromise = this.doInitialize(context);
    await this.initializationPromise;
  }

  private async doInitialize(context: Context): Promise<void> {
    try {
      this.preferencesInstance = await preferences.getPreferences(context, this.PREFERENCES_NAME);
      
      // 初始化分类数据（如果不存在）
      const categories = await this.getAllCategories();
      if (categories.length === 0) {
        await this.initializeCategories();
      }
      
      this.isInitialized = true;
      console.info('DataService initialized successfully');
    } catch (err) {
      console.error('DataService initialize failed:', err);
      this.isInitialized = false;
    }
  }

  /**
   * 初始化预设分类
   */
  private async initializeCategories(): Promise<void> {
    try {
      const jsonArray = PRESET_CATEGORIES.map(cat => cat.toJson());
      await this.preferencesInstance?.put(this.CATEGORY_KEY, JSON.stringify(jsonArray));
      await this.preferencesInstance?.flush();
    } catch (err) {
      console.error('Initialize categories failed:', err);
    }
  }

  // ==================== Transaction CRUD ====================

  /**
   * 创建新交易
   */
  public async createTransaction(transaction: Transaction): Promise<boolean> {
    try {
      const transactions = await this.getAllTransactions();
      transactions.push(transaction);
      return await this.saveTransactions(transactions);
    } catch (err) {
      console.error('Create transaction failed:', err);
      return false;
    }
  }

  /**
   * 获取所有交易
   */
  public async getAllTransactions(): Promise<Transaction[]> {
    try {
      const jsonStr = await this.preferencesInstance?.get(this.TRANSACTION_KEY, '[]') as string;
      const jsonArray = JSON.parse(jsonStr) as Array<TransactionJson>;
      return jsonArray.map(json => Transaction.fromJson(json));
    } catch (err) {
      console.error('Get all transactions failed:', err);
      return [];
    }
  }

  /**
   * 根据ID获取交易
   */
  public async getTransactionById(id: string): Promise<Transaction | null> {
    const transactions = await this.getAllTransactions();
    const found = transactions.find(t => t.id === id);
    return found ? found : null;
  }

  /**
   * 更新交易
   */
  public async updateTransaction(transaction: Transaction): Promise<boolean> {
    try {
      const transactions = await this.getAllTransactions();
      const index = transactions.findIndex(t => t.id === transaction.id);
      if (index !== -1) {
        transactions[index] = transaction;
        return await this.saveTransactions(transactions);
      }
      return false;
    } catch (err) {
      console.error('Update transaction failed:', err);
      return false;
    }
  }

  /**
   * 删除交易
   */
  public async deleteTransaction(id: string): Promise<boolean> {
    try {
      const transactions = await this.getAllTransactions();
      const filtered = transactions.filter(t => t.id !== id);
      return await this.saveTransactions(filtered);
    } catch (err) {
      console.error('Delete transaction failed:', err);
      return false;
    }
  }

  /**
   * 批量删除交易
   */
  public async deleteTransactions(ids: string[]): Promise<boolean> {
    try {
      const transactions = await this.getAllTransactions();
      const filtered = transactions.filter(t => !ids.includes(t.id));
      return await this.saveTransactions(filtered);
    } catch (err) {
      console.error('Delete transactions failed:', err);
      return false;
    }
  }

  /**
   * 保存交易列表
   */
  private async saveTransactions(transactions: Transaction[]): Promise<boolean> {
    try {
      const jsonArray = transactions.map(t => t.toJson());
      await this.preferencesInstance?.put(this.TRANSACTION_KEY, JSON.stringify(jsonArray));
      await this.preferencesInstance?.flush();
      return true;
    } catch (err) {
      console.error('Save transactions failed:', err);
      return false;
    }
  }

  // ==================== Category CRUD ====================

  /**
   * 创建新分类
   */
  public async createCategory(category: Category): Promise<boolean> {
    try {
      const categories = await this.getAllCategories();
      categories.push(category);
      return await this.saveCategories(categories);
    } catch (err) {
      console.error('Create category failed:', err);
      return false;
    }
  }

  /**
   * 获取所有分类
   */
  public async getAllCategories(): Promise<Category[]> {
    try {
      const jsonStr = await this.preferencesInstance?.get(this.CATEGORY_KEY, '[]') as string;
      const jsonArray = JSON.parse(jsonStr) as Array<CategoryJson>;
      return jsonArray.map(json => Category.fromJson(json));
    } catch (err) {
      console.error('Get all categories failed:', err);
      return [];
    }
  }

  /**
   * 根据类型获取分类
   */
  public async getCategoriesByType(type: string): Promise<Category[]> {
    const categories = await this.getAllCategories();
    return categories.filter(c => c.type === type);
  }

  /**
   * 根据ID获取分类
   */
  public async getCategoryById(id: string): Promise<Category | null> {
    const categories = await this.getAllCategories();
    const found = categories.find(c => c.id === id);
    return found ? found : null;
  }

  /**
   * 更新分类
   */
  public async updateCategory(category: Category): Promise<boolean> {
    try {
      const categories = await this.getAllCategories();
      const index = categories.findIndex(c => c.id === category.id);
      if (index !== -1) {
        categories[index] = category;
        return await this.saveCategories(categories);
      }
      return false;
    } catch (err) {
      console.error('Update category failed:', err);
      return false;
    }
  }

  /**
   * 删除分类（仅能删除非预设分类）
   */
  public async deleteCategory(id: string): Promise<boolean> {
    try {
      const categories = await this.getAllCategories();
      const category = categories.find(c => c.id === id);
      
      if (category && category.isPreset) {
        console.error('Cannot delete preset category');
        return false;
      }
      
      const filtered = categories.filter(c => c.id !== id);
      return await this.saveCategories(filtered);
    } catch (err) {
      console.error('Delete category failed:', err);
      return false;
    }
  }

  /**
   * 保存分类列表
   */
  private async saveCategories(categories: Category[]): Promise<boolean> {
    try {
      const jsonArray = categories.map(c => c.toJson());
      await this.preferencesInstance?.put(this.CATEGORY_KEY, JSON.stringify(jsonArray));
      await this.preferencesInstance?.flush();
      return true;
    } catch (err) {
      console.error('Save categories failed:', err);
      return false;
    }
  }

  /**
   * 生成唯一ID
   */
  public generateId(): string {
    return Date.now().toString() + Math.random().toString(36).substr(2, 9);
  }

  // ==================== Budget CRUD ====================

  /**
   * 创建新预算
   */
  public async createBudget(budget: Budget): Promise<boolean> {
    try {
      const budgets = await this.getAllBudgets();
      budgets.push(budget);
      return await this.saveBudgets(budgets);
    } catch (err) {
      console.error('Create budget failed:', err);
      return false;
    }
  }

  /**
   * 获取所有预算
   */
  public async getAllBudgets(): Promise<Budget[]> {
    try {
      const jsonStr = await this.preferencesInstance?.get(this.BUDGET_KEY, '[]') as string;
      const jsonArray = JSON.parse(jsonStr) as Array<BudgetJson>;
      return jsonArray.map(json => Budget.fromJson(json));
    } catch (err) {
      console.error('Get all budgets failed:', err);
      return [];
    }
  }

  /**
   * 根据ID获取预算
   */
  public async getBudgetById(id: string): Promise<Budget | null> {
    const budgets = await this.getAllBudgets();
    const found = budgets.find(b => b.id === id);
    return found ? found : null;
  }

  /**
   * 根据分类ID和周期获取预算
   */
  public async getBudgetByCategoryAndPeriod(categoryId: string, period: string): Promise<Budget | null> {
    const budgets = await this.getAllBudgets();
    const found = budgets.find(b => b.categoryId === categoryId && b.period === period && !b.isExpired());
    return found ? found : null;
  }

  /**
   * 获取全局预算
   */
  public async getGlobalBudget(period: string): Promise<Budget | null> {
    const budgets = await this.getAllBudgets();
    const found = budgets.find(b => b.type === 'global' && b.period === period && !b.isExpired());
    return found ? found : null;
  }

  /**
   * 更新预算
   */
  public async updateBudget(budget: Budget): Promise<boolean> {
    try {
      const budgets = await this.getAllBudgets();
      const index = budgets.findIndex(b => b.id === budget.id);
      if (index !== -1) {
        budgets[index] = budget;
        return await this.saveBudgets(budgets);
      }
      return false;
    } catch (err) {
      console.error('Update budget failed:', err);
      return false;
    }
  }

  /**
   * 删除预算
   */
  public async deleteBudget(id: string): Promise<boolean> {
    try {
      const budgets = await this.getAllBudgets();
      const filtered = budgets.filter(b => b.id !== id);
      return await this.saveBudgets(filtered);
    } catch (err) {
      console.error('Delete budget failed:', err);
      return false;
    }
  }

  /**
   * 根据分类ID删除所有相关预算
   */
  public async deleteBudgetsByCategoryId(categoryId: string): Promise<boolean> {
    try {
      const budgets = await this.getAllBudgets();
      const filtered = budgets.filter(b => b.categoryId !== categoryId);
      return await this.saveBudgets(filtered);
    } catch (err) {
      console.error('Delete budgets by category failed:', err);
      return false;
    }
  }

  /**
   * 保存预算列表
   */
  private async saveBudgets(budgets: Budget[]): Promise<boolean> {
    try {
      const jsonArray = budgets.map(b => b.toJson());
      await this.preferencesInstance?.put(this.BUDGET_KEY, JSON.stringify(jsonArray));
      await this.preferencesInstance?.flush();
      return true;
    } catch (err) {
      console.error('Save budgets failed:', err);
      return false;
    }
  }

  /**
   * 计算预算在指定周期内的消耗金额
   */
  public async calculateBudgetSpent(budget: Budget): Promise<number> {
    try {
      const transactions = await this.getAllTransactions();
      
      // 筛选出周期内的支出交易
      const periodTransactions = transactions.filter(t => {
        if (t.type !== 'expense') {
          return false;
        }
        if (t.date < budget.periodStart || t.date >= budget.periodEnd) {
          return false;
        }
        // 如果是分类预算，只统计该分类的交易
        if (budget.type === 'category' && t.categoryId !== budget.categoryId) {
          return false;
        }
        return true;
      });

      // 计算总支出
      const totalSpent = periodTransactions.reduce((sum, t) => sum + t.amount, 0);
      return totalSpent;
    } catch (err) {
      console.error('Calculate budget spent failed:', err);
      return 0;
    }
  }

  // ==================== Settings CRUD ====================

  /**
   * 获取设置
   */
  public async getSettings(): Promise<Settings> {
    try {
      const jsonStr = await this.preferencesInstance?.get(this.SETTINGS_KEY, '') as string;
      if (jsonStr === '') {
        return Settings.getDefault();
      }
      const json = JSON.parse(jsonStr) as SettingsJson;
      return Settings.fromJson(json);
    } catch (err) {
      console.error('Get settings failed:', err);
      return Settings.getDefault();
    }
  }

  /**
   * 保存设置
   */
  public async saveSettings(settings: Settings): Promise<boolean> {
    try {
      // 使用toJsonWithApiKey保存完整设置（包含apiKey）到本地
      const json = settings.toJsonWithApiKey();
      await this.preferencesInstance?.put(this.SETTINGS_KEY, JSON.stringify(json));
      await this.preferencesInstance?.flush();
      return true;
    } catch (err) {
      console.error('Save settings failed:', err);
      return false;
    }
  }

  // ==================== Data Export/Import ====================

  /**
   * 导出所有数据为JSON格式
   */
  public async exportAllData(): Promise<string> {
    try {
      const transactions = await this.getAllTransactions();
      const categories = await this.getAllCategories();
      const budgets = await this.getAllBudgets();
      const settings = await this.getSettings();

      const data: ExportData = {
        transactions: transactions.map(t => t.toJson()),
        categories: categories.map(c => c.toJson()),
        budgets: budgets.map(b => b.toJson()),
        settings: settings.toJson(),
        exportTime: Date.now(),
        version: '1.0.0'
      };

      return JSON.stringify(data, null, 2);
    } catch (err) {
      console.error('Export data failed:', err);
      return '';
    }
  }

  /**
   * 导出交易为CSV格式
   */
  public async exportTransactionsCSV(): Promise<string> {
    try {
      const transactions = await this.getAllTransactions();
      const categories = await this.getAllCategories();

      // CSV头部
      let csv = 'date,type,category,amount,notes\n';

      // 添加每一行数据
      for (const t of transactions) {
        const category = categories.find(c => c.id === t.categoryId);
        const categoryName = category ? category.name : '未知';
        const date = new Date(t.date);
        const dateStr = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
        const amount = (t.amount / 100).toFixed(2);
        const notes = t.description.replace(/"/g, '""'); // 转义引号

        csv += `${dateStr},${t.type},${categoryName},${amount},"${notes}"\n`;
      }

      return csv;
    } catch (err) {
      console.error('Export CSV failed:', err);
      return '';
    }
  }

  /**
   * 导入数据（覆盖当前数据）
   */
  public async importAllData(jsonData: string): Promise<boolean> {
    try {
      const parsed = JSON.parse(jsonData) as object;
      const data = parsed as ExportData;

      // 验证数据格式
      if (!data.transactions || !data.categories || !data.budgets || !data.settings) {
        console.error('Invalid data format');
        return false;
      }

      // 导入交易
      const transactionJsons = data.transactions as TransactionJson[];
      const transactions = transactionJsons.map((json: TransactionJson) => Transaction.fromJson(json));
      await this.saveTransactions(transactions);

      // 导入分类
      const categoryJsons = data.categories as CategoryJson[];
      const categories = categoryJsons.map((json: CategoryJson) => Category.fromJson(json));
      await this.saveCategories(categories);

      // 导入预算
      const budgetJsons = data.budgets as BudgetJson[];
      const budgets = budgetJsons.map((json: BudgetJson) => Budget.fromJson(json));
      await this.saveBudgets(budgets);

      // 导入设置（保留当前的apiKey）
      const currentSettings = await this.getSettings();
      const settingsJson = data.settings as SettingsJson;
      const settings = Settings.fromJson(settingsJson);
      // 保留当前的apiKey，不被导入的数据覆盖
      settings.apiKey = currentSettings.apiKey;
      await this.saveSettings(settings);

      return true;
    } catch (err) {
      console.error('Import data failed:', err);
      return false;
    }
  }

  /**
   * 清空所有数据
   */
  public async clearAllData(): Promise<boolean> {
    try {
      await this.saveTransactions([]);
      await this.saveCategories([]);
      await this.saveBudgets([]);
      await this.saveSettings(Settings.getDefault());
      
      // 重新初始化预设分类
      await this.initializeCategories();
      
      return true;
    } catch (err) {
      console.error('Clear data failed:', err);
      return false;
    }
  }

  // ==================== ChatMessage CRUD ====================

  /**
   * 添加聊天消息
   */
  public async addChatMessage(message: ChatMessage): Promise<boolean> {
    try {
      const messages = await this.getAllChatMessages();
      messages.push(message);
      return await this.saveChatMessages(messages);
    } catch (err) {
      console.error('Add chat message failed:', err);
      return false;
    }
  }

  /**
   * 获取所有聊天消息
   */
  public async getAllChatMessages(): Promise<ChatMessage[]> {
    try {
      const jsonStr = await this.preferencesInstance?.get(this.CHAT_MESSAGES_KEY, '[]') as string;
      const jsonArray = JSON.parse(jsonStr) as Array<ChatMessageJson>;
      return jsonArray.map(json => ChatMessage.fromJson(json));
    } catch (err) {
      console.error('Get all chat messages failed:', err);
      return [];
    }
  }

  /**
   * 清空聊天消息
   */
  public async clearChatMessages(): Promise<boolean> {
    try {
      return await this.saveChatMessages([]);
    } catch (err) {
      console.error('Clear chat messages failed:', err);
      return false;
    }
  }

  /**
   * 保存聊天消息列表
   */
  private async saveChatMessages(messages: ChatMessage[]): Promise<boolean> {
    try {
      const jsonArray = messages.map(m => m.toJson());
      await this.preferencesInstance?.put(this.CHAT_MESSAGES_KEY, JSON.stringify(jsonArray));
      await this.preferencesInstance?.flush();
      return true;
    } catch (err) {
      console.error('Save chat messages failed:', err);
      return false;
    }
  }
}
