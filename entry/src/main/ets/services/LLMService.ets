import http from '@ohos.net.http';
import { Transaction } from '../models/Transaction';
import { Category } from '../models/Category';
import { Budget } from '../models/Budget';
import { Settings } from '../models/Settings';
import { DataService } from './DataService';

/**
 * API使用量接口
 */
interface QwenUsage {
  prompt_tokens: number;
  completion_tokens: number;
  total_tokens: number;
}

/**
 * 千问消息格式
 */
export interface QwenMessage {
  role: string;
  content: string;
}

/**
 * 千问请求体
 */
interface QwenRequestBody {
  model: string;
  messages: QwenMessage[];
  stream: boolean;
}

/**
 * 千问流式响应中的delta
 */
interface QwenDelta {
  content?: string;
  reasoning_content?: string;
}

/**
 * 千问流式响应中的choice
 */
interface QwenChoice {
  delta: QwenDelta;
  index: number;
  finish_reason?: string;
}

/**
 * 千问流式响应
 */
interface QwenStreamResponse {
  id: string;
  object: string;
  created: number;
  model: string;
  choices: QwenChoice[];
  usage?: QwenUsage;
}

/**
 * 千问非流式响应中的message
 */
interface QwenResponseMessage {
  role: string;
  content: string;
}

/**
 * 千问非流式响应中的choice
 */
interface QwenNonStreamChoice {
  message: QwenResponseMessage;
  index: number;
  finish_reason?: string;
}

/**
 * 千问非流式响应
 */
interface QwenNonStreamResponse {
  id: string;
  object: string;
  created: number;
  model: string;
  choices: QwenNonStreamChoice[];
  usage?: QwenUsage;
}

/**
 * LLM服务类 - 封装千问API调用
 */
export class LLMService {
  private static instance: LLMService;
  private readonly API_URL = 'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions';
  private readonly API_KEY = 'sk-4b8c9539f4a348dc8dd83ee7a02f207d';
  private readonly MODEL = 'qwen-flash';
  private dataService: DataService = DataService.getInstance();

  private constructor() {}

  public static getInstance(): LLMService {
    if (!LLMService.instance) {
      LLMService.instance = new LLMService();
    }
    return LLMService.instance;
  }

  /**
   * 构建系统提示词，注入角色设定和用户数据
   */
  private async buildSystemPrompt(): Promise<string> {
    const settings = await this.dataService.getSettings();
    const transactions = await this.dataService.getAllTransactions();
    const categories = await this.dataService.getAllCategories();
    const budgets = await this.dataService.getAllBudgets();

    // 基础角色设定
    let prompt = `你是一个专业的个人财务助手，帮助用户管理他们的预算和支出。你的职责包括：
1. 分析用户的收支情况，提供财务建议
2. 帮助用户理解支出习惯
3. 提供省钱建议和预算优化方案
4. 回答有关财务管理的问题

用户当前设置：
- 货币符号：${settings.currency}
- 默认页面：${settings.defaultPage}

`;

    // 添加用户交易数据统计
    if (transactions.length > 0) {
      const now = Date.now();
      const monthAgo = now - 30 * 24 * 60 * 60 * 1000;
      const recentTransactions = transactions.filter(t => t.date >= monthAgo);

      let totalIncome = 0;
      let totalExpense = 0;
      const categoryStats = new Map<string, number>();

      for (const t of recentTransactions) {
        if (t.type === 'income') {
          totalIncome += t.amount;
        } else if (t.type === 'expense') {
          totalExpense += t.amount;
          const current = categoryStats.get(t.categoryId);
          if (current !== undefined) {
            categoryStats.set(t.categoryId, current + t.amount);
          } else {
            categoryStats.set(t.categoryId, t.amount);
          }
        }
      }

      prompt += `\n近30天财务概况：
- 总收入：${settings.currency}${(totalIncome / 100).toFixed(2)}
- 总支出：${settings.currency}${(totalExpense / 100).toFixed(2)}
- 结余：${settings.currency}${((totalIncome - totalExpense) / 100).toFixed(2)}
- 交易笔数：${recentTransactions.length}

`;

      // 添加支出分类统计
      if (categoryStats.size > 0) {
        prompt += '支出分类统计：\n';
        const sortedCategories: Array<[string, number]> = [];
        categoryStats.forEach((amount, catId) => {
          sortedCategories.push([catId, amount]);
        });
        sortedCategories.sort((a, b) => b[1] - a[1]);

        for (const entry of sortedCategories) {
          const catId = entry[0];
          const amount = entry[1];
          const category = categories.find(c => c.id === catId);
          const catName = category ? category.name : '未知分类';
          const percentage = totalExpense > 0 ? ((amount / totalExpense) * 100).toFixed(1) : '0';
          prompt += `- ${catName}：${settings.currency}${(amount / 100).toFixed(2)} (${percentage}%)\n`;
        }
      }
    } else {
      prompt += '\n用户暂无交易记录。\n';
    }

    // 添加预算信息
    if (budgets.length > 0) {
      prompt += '\n当前预算设置：\n';
      for (const budget of budgets) {
        if (budget.type === 'global') {
          prompt += `- 全局预算（${budget.period}）：${settings.currency}${(budget.amount / 100).toFixed(2)}\n`;
        } else {
          const category = categories.find(c => c.id === budget.categoryId);
          const catName = category ? category.name : '未知分类';
          prompt += `- ${catName}预算（${budget.period}）：${settings.currency}${(budget.amount / 100).toFixed(2)}\n`;
        }
      }
    }

    prompt += '\n请基于以上信息，为用户提供个性化的财务建议和帮助。回答要简洁、实用、友好。';
    prompt += '\n\n【重要格式要求】由于聊天界面无法渲染Markdown格式，请使用纯文本格式回复，不要使用任何Markdown语法，包括但不限于：';
    prompt += '\n- 不要使用**粗体**或__粗体__';
    prompt += '\n- 不要使用*斜体*或_斜体_';
    prompt += '\n- 不要使用# 标题或其他标题标记';
    prompt += '\n- 不要使用表格（|分隔符）';
    prompt += '\n- 不要使用代码块（```）或行内代码（`）';
    prompt += '\n- 不要使用[链接](url)格式';
    prompt += '\n- 可以使用普通的换行、数字列表和短横线列表';
    prompt += '\n- 用空行分段，用"1. 2. 3."或"- "来列举要点即可';

    return prompt;
  }

  /**
   * 发送消息到LLM并获取回复（非流式）
   * @param userMessage 用户消息
   * @param conversationHistory 对话历史（不包含系统提示词）
   * @returns LLM的回复内容
   */
  public async sendMessage(userMessage: string, conversationHistory: QwenMessage[]): Promise<string> {
    try {
      // 构建系统提示词
      const systemPrompt = await this.buildSystemPrompt();

      // 组合完整的消息列表：系统提示词 + 历史对话 + 新消息
      const messages: QwenMessage[] = [
        { role: 'system', content: systemPrompt }
      ];

      // 添加对话历史（最多保留最近10轮对话以控制token数量）
      const recentHistory = conversationHistory.slice(-20); // 10轮对话 = 20条消息
      for (const msg of recentHistory) {
        messages.push(msg);
      }

      // 添加当前用户消息
      const userMsg: QwenMessage = { role: 'user', content: userMessage };
      messages.push(userMsg);

      // 调用API
      const httpRequest = http.createHttp();
      const requestBody: QwenRequestBody = {
        model: this.MODEL,
        messages: messages,
        stream: false
      };

      const requestOptions: http.HttpRequestOptions = {
        method: http.RequestMethod.POST,
        header: {
          'Authorization': `Bearer ${this.API_KEY}`,
          'Content-Type': 'application/json'
        },
        extraData: JSON.stringify(requestBody),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 30000,
        readTimeout: 30000
      };

      const response = await httpRequest.request(this.API_URL, requestOptions);

      httpRequest.destroy();

      if (response.responseCode === 200) {
        const data = JSON.parse(response.result as string) as QwenNonStreamResponse;
        if (data.choices && data.choices.length > 0) {
          const content = data.choices[0].message.content;
          if (content !== undefined && content !== null) {
            return content;
          } else {
            return `收到了空回复，完整响应: ${response.result}`;
          }
        } else {
          return `API返回了异常数据结构: ${response.result}`;
        }
      } else {
        const errorMsg = `API请求失败 - HTTP ${response.responseCode}: ${response.result}`;
        return errorMsg;
      }
    } catch (err) {
      const errorMsg = `LLM服务异常: ${JSON.stringify(err)}`;
      return errorMsg;
    }
  }

  /**
   * 将聊天历史转换为API所需的格式
   */
  public convertChatHistoryToMessages(messages: QwenMessage[]): QwenMessage[] {
    return messages.map(msg => {
      const result: QwenMessage = {
        role: msg.role,
        content: msg.content
      };
      return result;
    });
  }
}
