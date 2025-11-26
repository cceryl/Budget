/**
 * 周期时间接口
 */
export interface PeriodTime {
  start: number;
  end: number;
}

/**
 * 预算 JSON 数据接口
 */
export interface BudgetJson {
  id: string;
  type: string; // 'global' 或 'category'
  categoryId: string; // 对于分类预算，存储分类ID；对于全局预算，存储空字符串
  amount: number; // 预算金额（以分为单位）
  period: string; // 'month', 'week', 'year'
  periodStart: number; // 周期开始时间戳
  periodEnd: number; // 周期结束时间戳
}

/**
 * 预算数据模型
 */
@Observed
export class Budget {
  public id: string;
  public type: string; // 'global' 或 'category'
  public categoryId: string;
  public amount: number; // 以分为单位存储
  public period: string; // 'month', 'week', 'year'
  public periodStart: number; // 周期开始时间戳
  public periodEnd: number; // 周期结束时间戳

  constructor(
    id: string,
    type: string,
    categoryId: string,
    amount: number,
    period: string,
    periodStart: number,
    periodEnd: number
  ) {
    this.id = id;
    this.type = type;
    this.categoryId = categoryId;
    this.amount = amount;
    this.period = period;
    this.periodStart = periodStart;
    this.periodEnd = periodEnd;
  }

  /**
   * 从普通对象创建 Budget 实例
   */
  static fromJson(json: BudgetJson): Budget {
    return new Budget(
      json.id as string,
      json.type as string,
      json.categoryId as string,
      json.amount as number,
      json.period as string,
      json.periodStart as number,
      json.periodEnd as number
    );
  }

  /**
   * 转换为普通对象用于存储
   */
  toJson(): BudgetJson {
    return {
      id: this.id,
      type: this.type,
      categoryId: this.categoryId,
      amount: this.amount,
      period: this.period,
      periodStart: this.periodStart,
      periodEnd: this.periodEnd
    };
  }

  /**
   * 判断预算是否已过期（是否需要重置）
   */
  isExpired(): boolean {
    return Date.now() > this.periodEnd;
  }

  /**
   * 根据周期类型计算新的周期起止时间
   */
  static calculatePeriod(period: string, startDate?: Date): PeriodTime {
    const now = startDate ? startDate : new Date();
    let start: Date;
    let end: Date;

    if (period === 'week') {
      // 从周一开始
      start = new Date(now);
      const day = start.getDay();
      const diff = day === 0 ? -6 : 1 - day; // 周日算作上周
      start.setDate(start.getDate() + diff);
      start.setHours(0, 0, 0, 0);

      end = new Date(start);
      end.setDate(end.getDate() + 7);
      end.setHours(0, 0, 0, 0);
    } else if (period === 'month') {
      // 从每月1日开始
      start = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0, 0);
      end = new Date(now.getFullYear(), now.getMonth() + 1, 1, 0, 0, 0, 0);
    } else if (period === 'year') {
      // 从每年1月1日开始
      start = new Date(now.getFullYear(), 0, 1, 0, 0, 0, 0);
      end = new Date(now.getFullYear() + 1, 0, 1, 0, 0, 0, 0);
    } else {
      // 默认为月
      start = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0, 0);
      end = new Date(now.getFullYear(), now.getMonth() + 1, 1, 0, 0, 0, 0);
    }

    const result: PeriodTime = {
      start: start.getTime(),
      end: end.getTime()
    };
    return result;
  }

  /**
   * 创建新预算（自动计算周期）
   */
  static createNew(
    id: string,
    type: string,
    categoryId: string,
    amount: number,
    period: string
  ): Budget {
    const periodTime = Budget.calculatePeriod(period);
    return new Budget(id, type, categoryId, amount, period, periodTime.start, periodTime.end);
  }
}
