import { SQSClient, SendMessageCommand } from "@aws-sdk/client-sqs";
import { SSMClient, GetParameterCommand } from "@aws-sdk/client-ssm";

// AWSクライアントを初期化
const sqsClient = new SQSClient({
  region: process.env.AWS_REGION || "ap-northeast-1",
});

const ssmClient = new SSMClient({
  region: process.env.AWS_REGION || "ap-northeast-1",
});

// SSMからSQS Queue URLを取得する関数
async function getQueueUrl(parameterName) {
  try {
    const command = new GetParameterCommand({
      Name: parameterName,
      WithDecryption: true
    });
    const result = await ssmClient.send(command);
    return result.Parameter.Value;
  } catch (error) {
    console.error(`Failed to get SQS Queue URL from SSM (${parameterName}):`, error);
    throw error;
  }
}

// 各キューのURL取得関数
async function getDiscordQueueUrl() {
  return await getQueueUrl("/kishax/sqs/queue-url");
}

async function getWebToMcQueueUrl() {
  return await getQueueUrl("/kishax/sqs/web-to-mc-queue-url");
}

async function getMcToWebQueueUrl() {
  return await getQueueUrl("/kishax/sqs/mc-to-web-queue-url");
}

/**
 * Lambda関数のメインハンドラー
 * API Gateway からのリクエストを受け取り、SQS にメッセージを送信
 */
export const handler = async (event) => {
  console.log("Received event:", JSON.stringify(event, null, 2));

  try {
    // リクエストパスからルーティング先を決定
    const requestPath = event.pathParameters?.proxy || event.requestContext?.resourcePath || '';
    console.log("Request path:", requestPath);
    
    let QUEUE_URL;
    let messageSource = "unknown";
    
    if (requestPath.includes('discord') || requestPath.includes('server-status') || 
        requestPath.includes('player-request') || requestPath.includes('broadcast')) {
      // 既存のDiscord Bot向けメッセージ
      QUEUE_URL = await getDiscordQueueUrl();
      messageSource = "velocity-plugin";
    } else if (requestPath.includes('web-to-mc')) {
      // Web → MC 向けメッセージ
      QUEUE_URL = await getWebToMcQueueUrl();
      messageSource = "kishax-web";
    } else if (requestPath.includes('mc-to-web')) {
      // MC → Web 向けメッセージ
      QUEUE_URL = await getMcToWebQueueUrl();
      messageSource = "mc-plugins";
    } else {
      // デフォルトはDiscordキュー
      QUEUE_URL = await getDiscordQueueUrl();
      messageSource = "velocity-plugin";
    }
    
    console.log("Selected SQS Queue URL:", QUEUE_URL, "Source:", messageSource);
    
    // リクエストボディを解析
    let requestBody;
    if (event.body) {
      if (typeof event.body === "string") {
        try {
          requestBody = JSON.parse(event.body);
        } catch (e) {
          console.log("Failed to parse body as JSON, using as is:", event.body);
          requestBody = { message: event.body };
        }
      } else {
        requestBody = event.body;
      }
    } else {
      requestBody = event;
    }

    // リクエストタイプを判定
    const messageType = requestBody.type || "unknown";

    // SQS メッセージを構築
    const sqsMessage = {
      QueueUrl: QUEUE_URL,
      MessageBody: JSON.stringify(requestBody),
      MessageAttributes: {
        messageType: {
          DataType: "String",
          StringValue: messageType,
        },
        source: {
          DataType: "String",
          StringValue: messageSource,
        },
        timestamp: {
          DataType: "String",
          StringValue: new Date().toISOString(),
        },
      },
    };

    // SQS にメッセージを送信
    const command = new SendMessageCommand(sqsMessage);
    const result = await sqsClient.send(command);

    console.log("Message sent to SQS:", result.MessageId);

    // 成功レスポンスを返す
    return {
      statusCode: 200,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization",
      },
      body: JSON.stringify({
        success: true,
        messageId: result.MessageId,
        "message": "Message queued successfully",
      }),
    };
  } catch (error) {
    console.error("Error processing request:", error);

    // エラーレスポンスを返す
    return {
      statusCode: 500,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
      body: JSON.stringify({
        success: false,
        error: error.message,
        message: "Failed to process request",
      }),
    };
  }
};