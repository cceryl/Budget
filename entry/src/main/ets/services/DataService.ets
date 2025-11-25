import { preferences } from '@kit.ArkData';
import { Transaction, TransactionJson } from '../models/Transaction';
import { Category, CategoryJson, PRESET_CATEGORIES } from '../models/Category';

/**
 * 数据持久化服务
 * 使用 Preferences 实现简单的本地存储
 */
export class DataService {
  private static instance: DataService;
  private preferencesInstance: preferences.Preferences | null = null;
  private readonly TRANSACTION_KEY = 'transactions';
  private readonly CATEGORY_KEY = 'categories';
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
    const jsonArray = PRESET_CATEGORIES.map(cat => cat.toJson());
    await this.preferencesInstance?.put(this.CATEGORY_KEY, JSON.stringify(jsonArray));
    await this.preferencesInstance?.flush();
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
}
