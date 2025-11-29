import http from '@ohos.net.http';
import { Transaction } from '../models/Transaction';
import { Category } from '../models/Category';
import { Budget } from '../models/Budget';
import { Settings } from '../models/Settings';
import { DataService } from './DataService';

/**
 * API使用量接口
 */
interface WenxinUsage {
  prompt_tokens: number;
  completion_tokens: number;
  total_tokens: number;
}

/**
 * 文心一言API响应接口
 */
interface WenxinResponse {
  id: string;
  object: string;
  created: string;
  result: string;
  is_truncated: boolean;
  need_clear_history: boolean;
  usage: WenxinUsage;
}

/**
 * 文心一言消息格式
 */
export interface WenxinMessage {
  role: string;
  content: string;
}

/**
 * 文心一言请求体
 */
interface WenxinRequestBody {
  messages: WenxinMessage[];
}

/**
 * LLM服务类 - 封装文心一言API调用
 */
export class LLMService {
  private static instance: LLMService;
  private readonly API_URL = 'https://aip.baidubce.com/rpc/2.0/ai_custom/v1/wenxinworkshop/chat/ernie-lite-8k?access_token=24.00784af7d2b66e2d5e73b57d92142631.2592000.1763093694.282335-116017442';
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

    return prompt;
  }

  /**
   * 发送消息到LLM并获取回复
   * @param userMessage 用户消息
   * @param conversationHistory 对话历史（不包含系统提示词）
   * @returns LLM的回复内容
   */
  public async sendMessage(userMessage: string, conversationHistory: WenxinMessage[]): Promise<string> {
    try {
      // 构建系统提示词
      const systemPrompt = await this.buildSystemPrompt();

      // 组合完整的消息列表：系统提示词 + 历史对话 + 新消息
      const messages: WenxinMessage[] = [
        { role: 'user', content: systemPrompt }
      ];

      // 添加对话历史（最多保留最近10轮对话以控制token数量）
      const recentHistory = conversationHistory.slice(-20); // 10轮对话 = 20条消息
      for (const msg of recentHistory) {
        messages.push(msg);
      }

      // 添加当前用户消息
      const userMsg: WenxinMessage = { role: 'user', content: userMessage };
      messages.push(userMsg);

      // 调用API
      const httpRequest = http.createHttp();
      const requestBody: WenxinRequestBody = {
        messages: messages
      };

      const requestOptions: http.HttpRequestOptions = {
        method: http.RequestMethod.POST,
        header: {
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
        const data = JSON.parse(response.result as string) as WenxinResponse;
        return data.result;
      } else {
        console.error('LLM API error:', response.responseCode, response.result);
        return '抱歉，我暂时无法回答您的问题，请稍后再试。';
      }
    } catch (err) {
      console.error('LLM service error:', err);
      return '抱歉，发生了错误，请检查网络连接后重试。';
    }
  }

  /**
   * 将聊天历史转换为API所需的格式
   */
  public convertChatHistoryToMessages(messages: WenxinMessage[]): WenxinMessage[] {
    return messages.map(msg => {
      const result: WenxinMessage = {
        role: msg.role,
        content: msg.content
      };
      return result;
    });
  }
}
