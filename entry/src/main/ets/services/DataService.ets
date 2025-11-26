import { preferences } from '@kit.ArkData';
import { Transaction, TransactionJson } from '../models/Transaction';
import { Category, CategoryJson, PRESET_CATEGORIES } from '../models/Category';
import { Budget, BudgetJson } from '../models/Budget';

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
  private readonly PREFERENCES_NAME = 'budget_data';

  private constructor() {}

  public static getInstance(): DataService {
    if (!DataService.instance) {
      DataService.instance = new DataService();
    }
    return DataService.instance;
  }

  /**
   * 初始化数据存储
   */
  public async initialize(context: Context): Promise<void> {
    try {
      this.preferencesInstance = await preferences.getPreferences(context, this.PREFERENCES_NAME);
      
      // 初始化分类数据（如果不存在）
      const categories = await this.getAllCategories();
      if (categories.length === 0) {
        await this.initializeCategories();
      }
    } catch (err) {
      console.error('DataService initialize failed:', err);
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
}
