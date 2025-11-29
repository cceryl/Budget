/**
 * 聊天消息 JSON 数据接口
 */
export interface ChatMessageJson {
  id: string;
  role: string;
  content: string;
  timestamp: number;
}

/**
 * 聊天消息数据模型
 */
@Observed
export class ChatMessage {
  public id: string;
  public role: string; // 'user' 或 'assistant'
  public content: string;
  public timestamp: number; // 时间戳

  constructor(
    id: string,
    role: string,
    content: string,
    timestamp: number
  ) {
    this.id = id;
    this.role = role;
    this.content = content;
    this.timestamp = timestamp;
  }

  /**
   * 从普通对象创建 ChatMessage 实例
   */
  static fromJson(json: ChatMessageJson): ChatMessage {
    return new ChatMessage(
      json.id as string,
      json.role as string,
      json.content as string,
      json.timestamp as number
    );
  }

  /**
   * 转换为普通对象用于序列化
   */
  toJson(): ChatMessageJson {
    return {
      id: this.id,
      role: this.role,
      content: this.content,
      timestamp: this.timestamp
    };
  }

  /**
   * 生成新的聊天消息ID
   */
  static generateId(): string {
    return `msg_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
  }
}
