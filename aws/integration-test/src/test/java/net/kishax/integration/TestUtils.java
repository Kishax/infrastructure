package net.kishax.integration;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import software.amazon.awssdk.services.apigateway.ApiGatewayClient;
import software.amazon.awssdk.services.apigateway.model.*;
import software.amazon.awssdk.services.ssm.SsmClient;
import software.amazon.awssdk.services.ssm.model.GetParameterRequest;
import software.amazon.awssdk.services.sqs.SqsClient;
import software.amazon.awssdk.services.sqs.model.*;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;

import com.fasterxml.jackson.core.type.TypeReference;

/**
 * 統合テスト用ユーティリティクラス
 */
public class TestUtils {

  private static final Logger logger = LoggerFactory.getLogger(TestUtils.class);
  private static final ObjectMapper objectMapper = new ObjectMapper();

  /**
   * SSMパラメータ値を取得
   */
  public static String getSSMParameter(String parameterName) {
    try (SsmClient ssmClient = TestConfig.createSsmClient()) {
      GetParameterRequest request = GetParameterRequest.builder()
          .name(parameterName)
          .withDecryption(true)
          .build();

      return ssmClient.getParameter(request).parameter().value();
    } catch (Exception e) {
      logger.error("Failed to get SSM parameter: {}", parameterName, e);
      throw new RuntimeException("SSM parameter retrieval failed", e);
    }
  }

  /**
   * SQSキューからメッセージを受信（テスト用）
   */
  public static List<Message> receiveSQSMessages(String queueUrl, int maxMessages, Duration timeout) {
    try (SqsClient sqsClient = TestConfig.createSqsClient()) {
      ReceiveMessageRequest request = ReceiveMessageRequest.builder()
          .queueUrl(queueUrl)
          .maxNumberOfMessages(maxMessages)
          .waitTimeSeconds((int) timeout.getSeconds())
          .build();

      ReceiveMessageResponse response = sqsClient.receiveMessage(request);
      logger.info("Received {} messages from SQS queue", response.messages().size());

      return response.messages();
    } catch (Exception e) {
      logger.error("Failed to receive SQS messages from: {}", queueUrl, e);
      throw new RuntimeException("SQS message receive failed", e);
    }
  }

  /**
   * SQSメッセージを削除
   */
  public static void deleteSQSMessage(String queueUrl, String receiptHandle) {
    try (SqsClient sqsClient = TestConfig.createSqsClient()) {
      DeleteMessageRequest request = DeleteMessageRequest.builder()
          .queueUrl(queueUrl)
          .receiptHandle(receiptHandle)
          .build();

      sqsClient.deleteMessage(request);
      logger.info("Deleted SQS message with receipt handle: {}", receiptHandle);
    } catch (Exception e) {
      logger.error("Failed to delete SQS message", e);
      throw new RuntimeException("SQS message deletion failed", e);
    }
  }

  /**
   * JSONオブジェクトをマップに変換
   */
  public static Map<String, Object> parseJson(String json) {
    try {
      return objectMapper.readValue(json, new TypeReference<Map<String, Object>>() {
      });
    } catch (Exception e) {
      logger.error("Failed to parse JSON: {}", json, e);
      throw new RuntimeException("JSON parsing failed", e);
    }
  }

  /**
   * オブジェクトをJSONに変換
   */
  public static String toJson(Object object) {
    try {
      return objectMapper.writeValueAsString(object);
    } catch (Exception e) {
      logger.error("Failed to convert object to JSON", e);
      throw new RuntimeException("JSON conversion failed", e);
    }
  }

  /**
   * 指定時間待機
   */
  public static void waitFor(Duration duration) {
    try {
      TimeUnit.MILLISECONDS.sleep(duration.toMillis());
    } catch (InterruptedException e) {
      Thread.currentThread().interrupt();
      throw new RuntimeException("Wait interrupted", e);
    }
  }

  /**
   * テストメッセージ生成
   */
  public static Map<String, Object> createTestDiscordMessage() {
    return Map.of(
        "type", "player_join",
        "player", "TestPlayer",
        "message", "Integration test message from " + Instant.now(),
        "timestamp", Instant.now().toString(),
        "server", "test-server");
  }

  /**
   * SQSキューのメッセージ数を取得
   */
  public static int getSQSMessageCount(String queueUrl) {
    try (SqsClient sqsClient = TestConfig.createSqsClient()) {
      GetQueueAttributesRequest request = GetQueueAttributesRequest.builder()
          .queueUrl(queueUrl)
          .attributeNames(QueueAttributeName.APPROXIMATE_NUMBER_OF_MESSAGES)
          .build();

      GetQueueAttributesResponse response = sqsClient.getQueueAttributes(request);
      String messageCount = response.attributes().get(QueueAttributeName.APPROXIMATE_NUMBER_OF_MESSAGES);

      return Integer.parseInt(messageCount);
    } catch (Exception e) {
      logger.error("Failed to get SQS message count for: {}", queueUrl, e);
      return 0;
    }
  }

  /**
   * API Gateway リソースIDを取得
   */
  public static String getApiGatewayResourceId(ApiGatewayClient apiGatewayClient, String restApiId, String pathPart) {
    try {
      GetResourcesRequest request = GetResourcesRequest.builder()
          .restApiId(restApiId)
          .build();
      
      GetResourcesResponse response = apiGatewayClient.getResources(request);
      
      for (Resource resource : response.items()) {
        if (pathPart.equals(resource.pathPart())) {
          return resource.id();
        }
      }
      
      throw new RuntimeException("API Gateway resource not found: " + pathPart);
    } catch (Exception e) {
      logger.error("Failed to get API Gateway resource ID for: {}", pathPart, e);
      throw new RuntimeException("API Gateway resource lookup failed", e);
    }
  }

  /**
   * API Gateway経由でメッセージ送信
   */
  public static void sendApiGatewayMessage(ApiGatewayClient apiGatewayClient, String restApiId, String pathPart, Map<String, Object> message) throws Exception {
    String resourceId = getApiGatewayResourceId(apiGatewayClient, restApiId, pathPart);
    String requestBody = objectMapper.writeValueAsString(message);
    
    TestInvokeMethodRequest request = TestInvokeMethodRequest.builder()
        .restApiId(restApiId)
        .resourceId(resourceId)
        .httpMethod("POST")
        .pathWithQueryString("/" + pathPart)
        .body(requestBody)
        .headers(Map.of(
            "Content-Type", "application/json",
            "Authorization", generateAwsAuthHeader("POST", "/" + pathPart, requestBody, TestConfig.AWS_REGION.id())
        ))
        .build();

    TestInvokeMethodResponse response = apiGatewayClient.testInvokeMethod(request);
    
    if (response.status() < 200 || response.status() >= 300) {
      throw new RuntimeException("API Gateway request failed: " + response.status() + " " + response.body());
    }
  }

  /**
   * SQSメッセージ待機
   */
  public static Message waitForSqsMessage(SqsClient sqsClient, String queueUrl, Duration timeout) throws InterruptedException {
    long timeoutMs = timeout.toMillis();
    long startTime = System.currentTimeMillis();
    
    while (System.currentTimeMillis() - startTime < timeoutMs) {
      ReceiveMessageResponse response = sqsClient.receiveMessage(
          ReceiveMessageRequest.builder()
              .queueUrl(queueUrl)
              .maxNumberOfMessages(1)
              .waitTimeSeconds(5)
              .messageAttributeNames("All")
              .build()
      );
      
      if (!response.messages().isEmpty()) {
        Message message = response.messages().get(0);
        
        // メッセージを削除（テスト後のクリーンアップ）
        sqsClient.deleteMessage(DeleteMessageRequest.builder()
            .queueUrl(queueUrl)
            .receiptHandle(message.receiptHandle())
            .build());
        
        return message;
      }
      
      TimeUnit.SECONDS.sleep(2);
    }
    
    return null;
  }

  /**
   * AWS Signature V4 認証ヘッダー生成（簡易版）
   */
  public static String generateAwsAuthHeader(String method, String path, String body, String region) {
    // 実際の実装では完全なAWS Signature V4を実装する必要がある
    // テスト環境では簡略化またはIAMロールを使用
    return "AWS4-HMAC-SHA256 Credential=test/20240101/" + region + "/execute-api/aws4_request, SignedHeaders=host;x-amz-date, Signature=test";
  }
}
