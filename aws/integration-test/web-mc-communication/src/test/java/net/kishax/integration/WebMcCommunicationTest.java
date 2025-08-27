package net.kishax.integration;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.TestInfo;
import org.junit.jupiter.api.TestMethodOrder;
import org.junit.jupiter.api.MethodOrderer;
import org.junit.jupiter.api.Order;
import software.amazon.awssdk.services.apigateway.model.TestInvokeMethodRequest;
import software.amazon.awssdk.services.apigateway.model.TestInvokeMethodResponse;
import software.amazon.awssdk.services.sqs.model.Message;
import software.amazon.awssdk.services.sqs.model.ReceiveMessageRequest;
import software.amazon.awssdk.services.sqs.model.ReceiveMessageResponse;

import java.time.Duration;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.TimeUnit;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Web ↔ MC 双方向通信の統合テスト
 */
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
public class WebMcCommunicationTest extends BaseIntegrationTest {

  private ObjectMapper objectMapper;
  private String webToMcQueueUrl;
  private String mcToWebQueueUrl;

  @BeforeEach
  void setUp(TestInfo testInfo) {
    super.setUp(testInfo);
    this.objectMapper = new ObjectMapper();

    // テスト前にSQSキューをクリーンアップ
    TestUtils.cleanupSqsQueues(sqsClient, webToMcQueueUrl, mcToWebQueueUrl);

    // SQSキューURL取得
    webToMcQueueUrl = TestUtils.getSqsUrlFromSsmWithFallback("/kishax/sqs/web-to-mc-queue-url", TestConfig::getWebToMcSqsQueueUrl);
    mcToWebQueueUrl = TestUtils.getSqsUrlFromSsmWithFallback("/kishax/sqs/mc-to-web-queue-url", TestConfig::getMcToWebSqsQueueUrl);

    logger.info("Web→MC Queue URL: {}", webToMcQueueUrl);
    logger.info("MC→Web Queue URL: {}", mcToWebQueueUrl);
  }

  /**
   * Web→MC認証確認メッセージ送信テスト
   */
  @Test
  @Order(1)
  void testWebToMcAuthConfirmation() throws Exception {
    logger.info("Testing Web→MC Auth Confirmation");
    final String testId = java.util.UUID.randomUUID().toString();

    // テスト用認証確認メッセージ（一意のデータ使用）
    String uniquePlayerName = "authTestPlayer_" + System.currentTimeMillis();
    String uniquePlayerUuid = "550e8400-e29b-41d4-a716-" + String.format("%012d", System.nanoTime() % 1000000000000L);

    Map<String, Object> authMessage = new HashMap<>();
    authMessage.put("type", "web_mc_auth_confirm");
    authMessage.put("playerName", uniquePlayerName);
    authMessage.put("playerUuid", uniquePlayerUuid);
    authMessage.put("timestamp", System.currentTimeMillis());
    authMessage.put("testId", testId);

    // API Gateway経由でメッセージ送信
    String requestBody = objectMapper.writeValueAsString(authMessage);

    TestInvokeMethodRequest apiRequest = TestInvokeMethodRequest.builder()
        .restApiId(TestConfig.API_GATEWAY_ID)
        .resourceId(getResourceId("web-to-mc"))
        .httpMethod("POST")
        .pathWithQueryString("/web-to-mc")
        .body(requestBody)
        .headers(Map.of("Content-Type", "application/json"))
        .build();

    TestInvokeMethodResponse apiResponse = apiGatewayClient.testInvokeMethod(apiRequest);

    // API Gatewayレスポンス検証
    assertEquals(200, apiResponse.status().intValue());
    assertNotNull(apiResponse.body());

    JsonNode responseBody = objectMapper.readTree(apiResponse.body());
    assertTrue(responseBody.path("success").asBoolean());

    // SQSメッセージ受信確認
    Message receivedMessage = TestUtils.waitForSpecificMessage(sqsClient, webToMcQueueUrl, testId, Duration.ofSeconds(30));
    assertNotNull(receivedMessage, "SQSメッセージが受信されませんでした");

    // メッセージ内容検証
    JsonNode messageBody = objectMapper.readTree(receivedMessage.body());
    assertEquals("web_mc_auth_confirm", messageBody.path("type").asText());
    assertEquals(uniquePlayerName, messageBody.path("playerName").asText());
    assertEquals(uniquePlayerUuid, messageBody.path("playerUuid").asText());

    // メッセージ属性検証
    assertEquals("kishax-web", receivedMessage.messageAttributes().get("source").stringValue());

    logger.info("Web→MC Auth Confirmation test passed");
  }

  /**
   * MC→Web認証レスポンステスト
   */
  @Test
  @Order(2)
  void testMcToWebAuthResponse() throws Exception {
    logger.info("Testing MC→Web Auth Response");
    final String testId = java.util.UUID.randomUUID().toString();

    // テスト用認証レスポンスメッセージ（一意のデータ使用）
    String uniquePlayerName = "responseTestPlayer_" + System.currentTimeMillis();
    String uniquePlayerUuid = "550e8400-e29b-41d4-a716-" + String.format("%012d", System.nanoTime() % 1000000000000L);

    Map<String, Object> authResponse = new HashMap<>();
    authResponse.put("type", "mc_web_auth_response");
    authResponse.put("playerName", uniquePlayerName);
    authResponse.put("playerUuid", uniquePlayerUuid);
    authResponse.put("success", true);
    authResponse.put("message", "認証が完了しました");
    authResponse.put("timestamp", System.currentTimeMillis());
    authResponse.put("testId", testId);

    // API Gateway経由でメッセージ送信
    String requestBody = objectMapper.writeValueAsString(authResponse);

    TestInvokeMethodRequest apiRequest = TestInvokeMethodRequest.builder()
        .restApiId(TestConfig.API_GATEWAY_ID)
        .resourceId(getResourceId("mc-to-web"))
        .httpMethod("POST")
        .pathWithQueryString("/mc-to-web")
        .body(requestBody)
        .headers(Map.of("Content-Type", "application/json"))
        .build();

    TestInvokeMethodResponse apiResponse = apiGatewayClient.testInvokeMethod(apiRequest);

    // API Gatewayレスポンス検証
    assertEquals(200, apiResponse.status().intValue());

    JsonNode responseBody = objectMapper.readTree(apiResponse.body());
    assertTrue(responseBody.path("success").asBoolean());

    // SQSメッセージ受信確認
    Message receivedMessage = TestUtils.waitForSpecificMessage(sqsClient, mcToWebQueueUrl, testId, Duration.ofSeconds(30));
    assertNotNull(receivedMessage, "SQSメッセージが受信されませんでした");

    // メッセージ内容検証
    JsonNode messageBody = objectMapper.readTree(receivedMessage.body());
    assertEquals("mc_web_auth_response", messageBody.path("type").asText());
    assertEquals(uniquePlayerName, messageBody.path("playerName").asText());
    assertTrue(messageBody.path("success").asBoolean());
    assertEquals("認証が完了しました", messageBody.path("message").asText());

    // メッセージ属性検証
    assertEquals("mc-plugins", receivedMessage.messageAttributes().get("source").stringValue());

    logger.info("MC→Web Auth Response test passed");
  }

  /**
   * Web→MCコマンド送信テスト
   */
  @Test
  @Order(3)
  void testWebToMcCommand() throws Exception {
    logger.info("Testing Web→MC Command");
    final String testId = java.util.UUID.randomUUID().toString();

    // テスト用コマンドメッセージ（一意のデータ使用）
    String uniquePlayerName = "commandTestPlayer_" + System.currentTimeMillis();

    Map<String, Object> commandMessage = new HashMap<>();
    commandMessage.put("type", "web_mc_command");
    commandMessage.put("commandType", "teleport");
    commandMessage.put("playerName", uniquePlayerName);
    commandMessage.put("testId", testId);

    Map<String, Object> commandData = new HashMap<>();
    commandData.put("location", "100,64,200");
    commandMessage.put("data", commandData);
    commandMessage.put("timestamp", System.currentTimeMillis());

    // API Gateway経由でメッセージ送信
    String requestBody = objectMapper.writeValueAsString(commandMessage);

    TestInvokeMethodRequest apiRequest = TestInvokeMethodRequest.builder()
        .restApiId(TestConfig.API_GATEWAY_ID)
        .resourceId(getResourceId("web-to-mc"))
        .httpMethod("POST")
        .pathWithQueryString("/web-to-mc")
        .body(requestBody)
        .headers(Map.of("Content-Type", "application/json"))
        .build();

    TestInvokeMethodResponse apiResponse = apiGatewayClient.testInvokeMethod(apiRequest);
    assertEquals(200, apiResponse.status().intValue());

    // SQSメッセージ受信確認
    Message receivedMessage = TestUtils.waitForSpecificMessage(sqsClient, webToMcQueueUrl, testId, Duration.ofSeconds(30));
    assertNotNull(receivedMessage);

    // メッセージ内容検証
    JsonNode messageBody = objectMapper.readTree(receivedMessage.body());
    assertEquals("web_mc_command", messageBody.path("type").asText());
    assertEquals("teleport", messageBody.path("commandType").asText());
    assertEquals(uniquePlayerName, messageBody.path("playerName").asText());
    assertEquals("100,64,200", messageBody.path("data").path("location").asText());

    logger.info("Web→MC Command test passed");
  }

  /**
   * 双方向通信フローテスト
   */
  @Test
  @Order(4)
  void testBidirectionalCommunicationFlow() throws Exception {
    logger.info("Testing Bidirectional Communication Flow");
    final String testId1 = java.util.UUID.randomUUID().toString();
    final String testId2 = java.util.UUID.randomUUID().toString();

    // Step 1: Web→MC認証確認（一意のデータ使用）
    String uniqueFlowPlayerName = "flowTestPlayer_" + System.currentTimeMillis();
    String uniqueFlowPlayerUuid = "660e8400-e29b-41d4-a716-"
        + String.format("%012d", System.nanoTime() % 1000000000000L);

    Map<String, Object> authRequest = new HashMap<>();
    authRequest.put("type", "web_mc_auth_confirm");
    authRequest.put("playerName", uniqueFlowPlayerName);
    authRequest.put("playerUuid", uniqueFlowPlayerUuid);
    authRequest.put("testId", testId1);

    sendWebToMcMessage(authRequest);
    Message authRequestMessage = TestUtils.waitForSpecificMessage(sqsClient, webToMcQueueUrl, testId1, Duration.ofSeconds(30));
    assertNotNull(authRequestMessage);

    // Step 2: MC→Web認証レスポンス
    Map<String, Object> authResponse = new HashMap<>();
    authResponse.put("type", "mc_web_auth_response");
    authResponse.put("playerName", uniqueFlowPlayerName);
    authResponse.put("playerUuid", uniqueFlowPlayerUuid);
    authResponse.put("success", true);
    authResponse.put("message", "認証フロー完了");
    authResponse.put("testId", testId2);

    sendMcToWebMessage(authResponse);
    Message authResponseMessage = TestUtils.waitForSpecificMessage(sqsClient, mcToWebQueueUrl, testId2, Duration.ofSeconds(30));
    assertNotNull(authResponseMessage);

    // 両方のメッセージが正常に処理されたことを確認
    JsonNode requestBody = objectMapper.readTree(authRequestMessage.body());
    JsonNode responseBody = objectMapper.readTree(authResponseMessage.body());

    assertEquals(requestBody.path("playerUuid").asText(), responseBody.path("playerUuid").asText());
    assertTrue(responseBody.path("success").asBoolean());

    logger.info("Bidirectional Communication Flow test passed");
  }

  /**
   * エラーハンドリングテスト
   */
  @Test
  @Order(5)
  void testErrorHandling() throws Exception {
    logger.info("Testing Error Handling");

    // 不正なメッセージ形式
    String invalidMessage = "{ invalid json";

    TestInvokeMethodRequest apiRequest = TestInvokeMethodRequest.builder()
        .restApiId(TestConfig.API_GATEWAY_ID)
        .resourceId(getResourceId("web-to-mc"))
        .httpMethod("POST")
        .pathWithQueryString("/web-to-mc")
        .body(invalidMessage)
        .headers(Map.of(
            "Content-Type", "application/json",
            "Authorization", generateAuthHeader("POST", "/web-to-mc", invalidMessage)))
        .build();

    TestInvokeMethodResponse apiResponse = apiGatewayClient.testInvokeMethod(apiRequest);

    // エラーレスポンスの確認
    assertTrue(apiResponse.status() >= 400);

    logger.info("Error Handling test passed");
  }

  // ヘルパーメソッド

  private void sendWebToMcMessage(Map<String, Object> message) throws JsonProcessingException {
    String requestBody = objectMapper.writeValueAsString(message);

    TestInvokeMethodRequest apiRequest = TestInvokeMethodRequest.builder()
        .restApiId(TestConfig.API_GATEWAY_ID)
        .resourceId(getResourceId("web-to-mc"))
        .httpMethod("POST")
        .pathWithQueryString("/web-to-mc")
        .body(requestBody)
        .headers(Map.of("Content-Type", "application/json"))
        .build();

    apiGatewayClient.testInvokeMethod(apiRequest);
  }

  private void sendMcToWebMessage(Map<String, Object> message) throws JsonProcessingException {
    String requestBody = objectMapper.writeValueAsString(message);

    TestInvokeMethodRequest apiRequest = TestInvokeMethodRequest.builder()
        .restApiId(TestConfig.API_GATEWAY_ID)
        .resourceId(getResourceId("mc-to-web"))
        .httpMethod("POST")
        .pathWithQueryString("/mc-to-web")
        .body(requestBody)
        .headers(Map.of("Content-Type", "application/json"))
        .build();

    apiGatewayClient.testInvokeMethod(apiRequest);
  }

  

  private String getResourceId(String pathPart) {
    // 環境変数から直接Resource IDを取得（動的検索を避けてテストを安定化）
    switch (pathPart) {
      case "web-to-mc":
        return System.getenv("AWS_API_GATEWAY_WEB_TO_MC_RESOURCE_ID");
      case "mc-to-web":
        return System.getenv("AWS_API_GATEWAY_MC_TO_WEB_RESOURCE_ID");
      case "discord":
        return System.getenv("AWS_API_GATEWAY_DISCORD_RESOURCE_ID");
      default:
        throw new RuntimeException("Unknown path part: " + pathPart);
    }
  }

  

  
}
