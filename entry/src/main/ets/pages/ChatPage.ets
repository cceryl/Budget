import { ChatMessage } from '../models/ChatMessage';
import { DataService } from '../services/DataService';
import { LLMService, QwenMessage } from '../services/LLMService';

@Entry
@Component
struct ChatPage {
  @State messages: ChatMessage[] = [];
  @State inputText: string = '';
  @State isLoading: boolean = false;
  @State dataRefreshKey: number = 0;
  
  private dataService: DataService = DataService.getInstance();
  private llmService: LLMService = LLMService.getInstance();
  private scroller: Scroller = new Scroller();

  async aboutToAppear(): Promise<void> {
    await this.dataService.waitForInitialization();
    await this.loadChatHistory();
  }

  /**
   * 加载聊天历史
   */
  async loadChatHistory(): Promise<void> {
    this.messages = await this.dataService.getAllChatMessages();
    this.dataRefreshKey++;
    
    // 滚动到底部
    try {
      setTimeout(() => {
        this.scroller.scrollEdge(Edge.Bottom);
      }, 100);
    } catch (err) {
      console.error('Scroll error:', err);
    }
  }

  /**
   * 发送消息
   */
  async sendMessage(): Promise<void> {
    if (this.inputText.trim() === '' || this.isLoading) {
      return;
    }

    const userMessageText = this.inputText.trim();
    this.inputText = '';

    // 创建用户消息
    const userMessage = new ChatMessage(
      ChatMessage.generateId(),
      'user',
      userMessageText,
      Date.now()
    );

    // 添加到界面并保存
    this.messages.push(userMessage);
    this.dataRefreshKey++;
    await this.dataService.addChatMessage(userMessage);

    // 滚动到底部
    try {
      setTimeout(() => {
        this.scroller.scrollEdge(Edge.Bottom);
      }, 100);
    } catch (err) {
      console.error('Scroll error:', err);
    }

    // 显示加载状态
    this.isLoading = true;

    try {
      // 构建对话历史（不包括刚添加的用户消息，因为LLM服务会添加）
      const history: QwenMessage[] = this.messages.slice(0, -1).map(msg => {
        const historyMsg: QwenMessage = {
          role: msg.role,
          content: msg.content
        };
        return historyMsg;
      });

      // 调用LLM服务
      const replyText = await this.llmService.sendMessage(userMessageText, history);

      // 创建助手回复消息
      const assistantMessage = new ChatMessage(
        ChatMessage.generateId(),
        'assistant',
        replyText,
        Date.now()
      );

      // 添加到界面并保存
      this.messages.push(assistantMessage);
      this.dataRefreshKey++;
      await this.dataService.addChatMessage(assistantMessage);

      // 滚动到底部
      try {
        setTimeout(() => {
          this.scroller.scrollEdge(Edge.Bottom);
        }, 100);
      } catch (err) {
        console.error('Scroll error:', err);
      }
    } catch (err) {
      console.error('Send message error:', err);
      // 显示错误提示
      try {
        this.getUIContext().getPromptAction().showToast({
          message: '发送消息失败，请重试',
          duration: 2000
        });
      } catch (toastErr) {
        console.error('Show toast error:', toastErr);
      }
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 清空聊天记录
   */
  async clearHistory(): Promise<void> {
    this.getUIContext().showAlertDialog({
      title: '清空聊天记录',
      message: '确定要清空所有聊天记录吗？此操作不可恢复。',
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '确定',
        action: async () => {
          const success = await this.dataService.clearChatMessages();
          if (success) {
            this.messages = [];
            this.dataRefreshKey++;
            this.getUIContext().getPromptAction().showToast({
              message: '聊天记录已清空',
              duration: 2000
            });
          } else {
            this.getUIContext().getPromptAction().showToast({
              message: '清空失败，请重试',
              duration: 2000
            });
          }
        }
      }
    });
  }

  /**
   * 格式化时间显示
   */
  formatTime(timestamp: number): string {
    const date = new Date(timestamp);
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const messageDate = new Date(date.getFullYear(), date.getMonth(), date.getDate());

    if (messageDate.getTime() === today.getTime()) {
      // 今天：显示时间
      return `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`;
    } else if (messageDate.getTime() === today.getTime() - 24 * 60 * 60 * 1000) {
      // 昨天
      return '昨天';
    } else {
      // 其他日期
      return `${date.getMonth() + 1}/${date.getDate()}`;
    }
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Button({ type: ButtonType.Normal }) {
          Text('←')
            .fontSize(24)
            .fontColor($r('app.color.text_primary'))
        }
        .backgroundColor(Color.Transparent)
        .width(48)
        .height(48)
        .onClick(() => {
          this.getUIContext().getRouter().back();
        })

        Text('财务助手')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Button({ type: ButtonType.Normal }) {
          Text('清空')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
        }
        .backgroundColor(Color.Transparent)
        .width(60)
        .height(48)
        .onClick(() => {
          this.clearHistory();
        })
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 16 })
      .backgroundColor($r('app.color.background_primary'))
      .borderWidth({ bottom: 1 })
      .borderColor($r('app.color.divider'))

      // 消息列表
      if (this.messages.length === 0) {
        // 欢迎界面
        Column() {
          Text('你好！我是你的财务助手')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .margin({ bottom: 8 })

          Text('我可以帮你：')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .margin({ bottom: 12 })

          Column({ space: 8 }) {
            Text('• 分析你的收支情况')
              .fontSize(14)
              .fontColor($r('app.color.text_tertiary'))
            Text('• 提供财务建议')
              .fontSize(14)
              .fontColor($r('app.color.text_tertiary'))
            Text('• 帮助优化预算')
              .fontSize(14)
              .fontColor($r('app.color.text_tertiary'))
            Text('• 回答财务管理问题')
              .fontSize(14)
              .fontColor($r('app.color.text_tertiary'))
          }
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .padding(32)
      } else {
        // 消息列表
        Scroll(this.scroller) {
          Column({ space: 16 }) {
            ForEach(this.messages, (msg: ChatMessage) => {
              this.MessageBubble(msg);
            }, (msg: ChatMessage) => `${this.dataRefreshKey}-${msg.id}`);

            // 加载指示器
            if (this.isLoading) {
              Row() {
                Text('正在思考...')
                  .fontSize(14)
                  .fontColor($r('app.color.text_tertiary'))
                  .padding(12)
              }
              .width('100%')
              .justifyContent(FlexAlign.Start)
              .padding({ left: 16 })
            }
          }
          .width('100%')
          .padding(16)
        }
        .width('100%')
        .layoutWeight(1)
        .backgroundColor($r('app.color.background_secondary'))
        .scrollBar(BarState.Auto)
      }

      // 输入区域
      Row({ space: 12 }) {
        TextInput({ placeholder: '输入消息...', text: this.inputText })
          .layoutWeight(1)
          .fontSize(16)
          .backgroundColor($r('app.color.card_background'))
          .borderRadius(24)
          .padding({ left: 16, right: 16 })
          .height(48)
          .onChange((value: string) => {
            this.inputText = value;
          })
          .onSubmit(() => {
            this.sendMessage();
          })

        Button({ type: ButtonType.Circle }) {
          Text(this.isLoading ? '...' : '发送')
            .fontSize(14)
            .fontColor('#FFFFFF')
        }
        .width(56)
        .height(56)
        .backgroundColor(this.inputText.trim() === '' || this.isLoading ?
          $r('app.color.button_secondary_bg') :
          $r('app.color.primary_color'))
        .enabled(this.inputText.trim() !== '' && !this.isLoading)
        .onClick(() => {
          this.sendMessage();
        })
      }
      .width('100%')
      .padding(16)
      .backgroundColor($r('app.color.background_primary'))
      .borderWidth({ top: 1 })
      .borderColor($r('app.color.divider'))
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background_secondary'))
  }

  /**
   * 消息气泡组件
   */
  @Builder
  MessageBubble(msg: ChatMessage) {
    Column() {
      if (msg.role === 'user') {
        // 用户消息（右侧）
        Column() {
          Row() {
            Text(this.formatTime(msg.timestamp))
              .fontSize(12)
              .fontColor($r('app.color.text_tertiary'))
              .margin({ right: 8 })

            Column() {
              Text(msg.content)
                .fontSize(15)
                .fontColor('#FFFFFF')
                .lineHeight(22)
            }
            .padding(12)
            .backgroundColor($r('app.color.primary_color'))
            .borderRadius(16)
            .constraintSize({ maxWidth: '70%' })
          }
          .width('100%')
          .justifyContent(FlexAlign.End)
        }
        .width('100%')
        .alignItems(HorizontalAlign.End)
      } else {
        // 助手消息（左侧）
        Column() {
          Row() {
            Column() {
              Text(msg.content)
                .fontSize(15)
                .fontColor($r('app.color.text_primary'))
                .lineHeight(22)
            }
            .padding(12)
            .backgroundColor($r('app.color.card_background'))
            .borderRadius(16)
            .constraintSize({ maxWidth: '70%' })
            .shadow({ radius: 2, color: $r('app.color.shadow_light'), offsetY: 1 })

            Text(this.formatTime(msg.timestamp))
              .fontSize(12)
              .fontColor($r('app.color.text_tertiary'))
              .margin({ left: 8 })
          }
          .width('100%')
          .justifyContent(FlexAlign.Start)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
  }
}
