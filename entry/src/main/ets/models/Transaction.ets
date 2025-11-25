/**
 * 交易 JSON 数据接口
 */
export interface TransactionJson {
  id: string;
  type: string;
  amount: number;
  categoryId: string;
  description: string;
  date: number;
}

/**
 * 交易数据模型
 */
@Observed
export class Transaction {
  public id: string;
  public type: string; // 'income' 或 'expense'
  public amount: number; // 以分为单位存储，避免浮点数问题
  public categoryId: string;
  public description: string;
  public date: number; // 时间戳

  constructor(
    id: string,
    type: string,
    amount: number,
    categoryId: string,
    description: string,
    date: number
  ) {
    this.id = id;
    this.type = type;
    this.amount = amount;
    this.categoryId = categoryId;
    this.description = description;
    this.date = date;
  }

  /**
   * 从普通对象创建 Transaction 实例
   */
  static fromJson(json: TransactionJson): Transaction {
    return new Transaction(
      json.id as string,
      json.type as string,
      json.amount as number,
      json.categoryId as string,
      json.description as string,
      json.date as number
    );
  }

  /**
   * 转换为普通对象用于存储
   */
  toJson(): TransactionJson {
    return {
      id: this.id,
      type: this.type,
      amount: this.amount,
      categoryId: this.categoryId,
      description: this.description,
      date: this.date
    };
  }
}
