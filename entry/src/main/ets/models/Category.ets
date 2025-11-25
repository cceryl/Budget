/**
 * 分类 JSON 数据接口
 */
export interface CategoryJson {
  id: string;
  name: string;
  type: string;
  icon: string;
  isPreset: boolean;
}

/**
 * 分类数据模型
 */
@Observed
export class Category {
  public id: string;
  public name: string;
  public type: string; // 'income' 或 'expense'
  public icon: string; // 图标名称
  public isPreset: boolean; // 是否为预设分类（不可删除）

  constructor(
    id: string,
    name: string,
    type: string,
    icon: string,
    isPreset: boolean = false
  ) {
    this.id = id;
    this.name = name;
    this.type = type;
    this.icon = icon;
    this.isPreset = isPreset;
  }

  static fromJson(json: CategoryJson): Category {
    return new Category(
      json.id as string,
      json.name as string,
      json.type as string,
      json.icon as string,
      json.isPreset as boolean
    );
  }

  toJson(): CategoryJson {
    return {
      id: this.id,
      name: this.name,
      type: this.type,
      icon: this.icon,
      isPreset: this.isPreset
    };
  }
}

/**
 * 预设分类数据
 */
export const PRESET_CATEGORIES: Category[] = [
  // 支出分类
  new Category('1', '餐饮', 'expense', 'food', true),
  new Category('2', '交通', 'expense', 'transport', true),
  new Category('3', '购物', 'expense', 'shopping', true),
  new Category('4', '娱乐', 'expense', 'entertainment', true),
  new Category('5', '医疗', 'expense', 'medical', true),
  new Category('6', '教育', 'expense', 'education', true),
  new Category('7', '住房', 'expense', 'housing', true),
  new Category('8', '其他支出', 'expense', 'other', true),
  
  // 收入分类
  new Category('101', '工资', 'income', 'salary', true),
  new Category('102', '奖金', 'income', 'bonus', true),
  new Category('103', '投资收益', 'income', 'investment', true),
  new Category('104', '其他收入', 'income', 'other', true),
];
