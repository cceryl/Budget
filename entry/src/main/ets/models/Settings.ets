/**
 * 设置 JSON 数据接口
 */
export interface SettingsJson {
  themeMode: string;
  currency: string;
  defaultPage: string;
  language: string;
  apiKey?: string; // API密钥，仅用于内部存储，不导出
}

/**
 * 设置数据模型
 */
@Observed
export class Settings {
  public themeMode: string; // 'system' | 'light' | 'dark'
  public currency: string; // '¥' | '$' | '€' | '£'
  public defaultPage: string; // 'details' | 'budget' | 'stats'
  public language: string; // 'zh-CN'
  public apiKey: string; // 千问API密钥

  constructor(
    themeMode: string = 'system',
    currency: string = '¥',
    defaultPage: string = 'details',
    language: string = 'zh-CN',
    apiKey: string = ''
  ) {
    this.themeMode = themeMode;
    this.currency = currency;
    this.defaultPage = defaultPage;
    this.language = language;
    this.apiKey = apiKey;
  }

  static fromJson(json: SettingsJson): Settings {
    return new Settings(
      json.themeMode as string,
      json.currency as string,
      json.defaultPage as string,
      json.language as string,
      json.apiKey as string || ''
    );
  }

  toJson(): SettingsJson {
    // 注意：导出时不包含apiKey，保护用户隐私
    return {
      themeMode: this.themeMode,
      currency: this.currency,
      defaultPage: this.defaultPage,
      language: this.language
    };
  }

  /**
   * 转换为JSON（包含apiKey，仅用于本地存储）
   */
  toJsonWithApiKey(): SettingsJson {
    return {
      themeMode: this.themeMode,
      currency: this.currency,
      defaultPage: this.defaultPage,
      language: this.language,
      apiKey: this.apiKey
    };
  }

  /**
   * 获取默认设置
   */
  static getDefault(): Settings {
    return new Settings();
  }

  /**
   * 获取主题模式显示名称
   */
  getThemeModeDisplayName(): string {
    if (this.themeMode === 'system') {
      return '跟随系统';
    } else if (this.themeMode === 'light') {
      return '明亮模式';
    } else if (this.themeMode === 'dark') {
      return '深色模式';
    }
    return '未知';
  }

  /**
   * 获取货币显示名称
   */
  getCurrencyDisplayName(): string {
    if (this.currency === '¥') {
      return '人民币 (¥)';
    } else if (this.currency === '$') {
      return '美元 ($)';
    } else if (this.currency === '€') {
      return '欧元 (€)';
    } else if (this.currency === '£') {
      return '英镑 (£)';
    }
    return '未知';
  }

  /**
   * 获取默认页面显示名称
   */
  getDefaultPageDisplayName(): string {
    if (this.defaultPage === 'details') {
      return '明细';
    } else if (this.defaultPage === 'budget') {
      return '预算';
    } else if (this.defaultPage === 'stats') {
      return '统计';
    }
    return '未知';
  }
}
