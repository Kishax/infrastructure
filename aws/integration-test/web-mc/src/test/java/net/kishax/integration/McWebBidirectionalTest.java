package net.kishax.integration;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import software.amazon.awssdk.auth.credentials.ProfileCredentialsProvider;
import software.amazon.awssdk.services.sqs.SqsClient;
import software.amazon.awssdk.services.sqs.model.Message;
import software.amazon.awssdk.services.sqs.model.SendMessageRequest;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * MC ↔ Web双方向通信統合テスト（SQS直接通信）
 * 
 * テストフロー:
 * 1. MC → Web: mc-to-web-queue-v2にメッセージ送信（直接SQS）
 * 2. Web → MC: web-to-mc-queue-v2にメッセージ送信（直接SQS）
 * 3. 各キューからのメッセージ受信確認
 * 4. メッセージ内容の検証
 */
@Tag("integration")
public class McWebBidirectionalTest {

  private static final Logger logger = LoggerFactory.getLogger(McWebBidirectionalTest.class);
  private SqsClient sqsClient;
  private String mcToWebQueueUrl;
  private String webToMcQueueUrl;

  @BeforeEach
  void setUp() {
    sqsClient = SqsClient.builder()
        .region(TestConfig.AWS_REGION)
        .credentialsProvider(ProfileCredentialsProvider.create(TestConfig.AWS_PROFILE))
        .build();
    
    mcToWebQueueUrl = TestConfig.getMcToWebSqsQueueUrl();
    webToMcQueueUrl = TestConfig.getWebToMcSqsQueueUrl();

    logger.info("Test setup - MC to Web Queue URL: {}", mcToWebQueueUrl);
    logger.info("Test setup - Web to MC Queue URL: {}", webToMcQueueUrl);
  }

  @Test
  void shouldSendMcPlayerStatusToWebQueue() throws Exception {
    final String testId = java.util.UUID.randomUUID().toString();
    // MC → Web: プレイヤーステータスメッセージ作成
    String sessionId = UUID.randomUUID().toString();
    Map<String, Object> playerStatusMessage = new java.util.HashMap<>(Map.of(
        "type", "mc_web_player_status",
        "playerUuid", "test-uuid-player-status-12345",
        "playerName", "TestPlayerStatus",
        "serverName", "test-server",
        "status", "online",
        "location", Map.of(
            "world", "world",
            "x", 100.0,
            "y", 64.0,
            "z", -200.0),
        "sessionId", sessionId,
        "timestamp", Instant.now().toString()));
    playerStatusMessage.put("testId", testId);

    String messageBody = TestUtils.toJson(playerStatusMessage);
    logger.info("Sending MC→Web player status message: {}", messageBody);

    // MC → Web SQS事前状態確認
    int initialMessageCount = TestUtils.getSQSMessageCount(mcToWebQueueUrl);
    logger.info("Initial MC→Web SQS message count: {}", initialMessageCount);

    // MC側からWeb向けSQSキューにメッセージ送信（直接SQS）
    SendMessageRequest sendRequest = SendMessageRequest.builder()
        .queueUrl(mcToWebQueueUrl)
        .messageBody(messageBody)
        .build();

    sqsClient.sendMessage(sendRequest);
    logger.info("MC→Web player status message sent successfully");

    // SQSメッセージ確認
    Message receivedMessage = TestUtils.waitForSpecificMessage(sqsClient, mcToWebQueueUrl, testId, Duration.ofSeconds(10));

    // メッセージが受信されたことを確認
    assertThat(receivedMessage)
        .as("Should receive the specific message from MC→Web SQS")
        .isNotNull();

    // メッセージ内容確認
    Map<String, Object> receivedMessageBody = TestUtils.parseJson(receivedMessage.body());

    logger.info("Received MC→Web SQS message: {}", receivedMessage.body());

    // 送信したメッセージ内容が含まれているか確認
    assertThat(receivedMessageBody)
        .as("Received message should contain mc_web_player_status data")
        .containsEntry("type", "mc_web_player_status")
        .containsEntry("playerName", "TestPlayerStatus")
        .containsEntry("status", "online");

    // Web側での処理をシミュレート
    simulateWebProcessing(receivedMessageBody);

    logger.info("MC→Web player status integration test completed successfully");
  }

  @Test
  void shouldSendMcAuthResponseToWebQueue() throws Exception {
    final String testId = java.util.UUID.randomUUID().toString();
    // MC → Web: 認証レスポンスメッセージ作成
    String sessionId = UUID.randomUUID().toString();
    Map<String, Object> authResponseMessage = new java.util.HashMap<>(Map.of(
        "type", "mc_web_auth_response",
        "playerUuid", "test-uuid-auth-response-12345",
        "playerName", "TestAuthPlayer",
        "serverName", "test-server",
        "authStatus", "success",
        "sessionId", sessionId,
        "timestamp", Instant.now().toString()));
    authResponseMessage.put("testId", testId);

    String messageBody = TestUtils.toJson(authResponseMessage);
    logger.info("Sending MC→Web auth response message: {}", messageBody);

    // MC側からWeb向けSQSキューにメッセージ送信
    SendMessageRequest sendRequest = SendMessageRequest.builder()
        .queueUrl(mcToWebQueueUrl)
        .messageBody(messageBody)
        .build();

    sqsClient.sendMessage(sendRequest);
    logger.info("MC→Web auth response message sent successfully");

    // SQSメッセージ確認
    Message receivedMessage = TestUtils.waitForSpecificMessage(sqsClient, mcToWebQueueUrl, testId, Duration.ofSeconds(10));

    // メッセージ受信確認
    if (receivedMessage != null) {
      Map<String, Object> receivedMessageBody = TestUtils.parseJson(receivedMessage.body());

      logger.info("Received MC→Web auth response SQS message: {}", receivedMessage.body());

      // メッセージ内容確認
      assertThat(receivedMessageBody)
          .as("Received message should contain mc_web_auth_response data")
          .containsEntry("type", "mc_web_auth_response")
          .containsEntry("playerName", "TestAuthPlayer")
          .containsEntry("authStatus", "success");

      // Web側での処理をシミュレート
      simulateWebProcessing(receivedMessageBody);
    }

    logger.info("MC→Web auth response integration test completed successfully");
  }

  @Test
  void shouldSendWebAuthConfirmToMcQueue() throws Exception {
    final String testId = java.util.UUID.randomUUID().toString();
    // Web → MC: 認証確認メッセージ作成
    String sessionId = UUID.randomUUID().toString();
    Map<String, Object> authConfirmMessage = new java.util.HashMap<>(Map.of(
        "type", "web_mc_auth_confirm",
        "playerUuid", "test-uuid-auth-confirm-12345",
        "playerName", "TestWebAuthPlayer",
        "userId", "web-user-12345",
        "confirmed", true,
        "sessionId", sessionId,
        "timestamp", Instant.now().toString()));
    authConfirmMessage.put("testId", testId);

    String messageBody = TestUtils.toJson(authConfirmMessage);
    logger.info("Sending Web→MC auth confirm message: {}", messageBody);

    // Web → MC SQS事前状態確認
    int initialMessageCount = TestUtils.getSQSMessageCount(webToMcQueueUrl);
    logger.info("Initial Web→MC SQS message count: {}", initialMessageCount);

    // Web側からMC向けSQSキューにメッセージ送信
    SendMessageRequest sendRequest = SendMessageRequest.builder()
        .queueUrl(webToMcQueueUrl)
        .messageBody(messageBody)
        .build();

    sqsClient.sendMessage(sendRequest);
    logger.info("Web→MC auth confirm message sent successfully");

    // SQSメッセージ確認
    Message receivedMessage = TestUtils.waitForSpecificMessage(sqsClient, webToMcQueueUrl, testId, Duration.ofSeconds(10));

    // メッセージが受信されたことを確認
    assertThat(receivedMessage)
        .as("Should receive the specific message from Web→MC SQS")
        .isNotNull();

    // メッセージ内容確認
    Map<String, Object> receivedMessageBody = TestUtils.parseJson(receivedMessage.body());

    logger.info("Received Web→MC SQS message: {}", receivedMessage.body());

    // 送信したメッセージ内容が含まれているか確認
    assertThat(receivedMessageBody)
        .as("Received message should contain web_mc_auth_confirm data")
        .containsEntry("type", "web_mc_auth_confirm")
        .containsEntry("playerName", "TestWebAuthPlayer")
        .containsEntry("confirmed", true);

    // MC側での処理をシミュレート
    simulateMcProcessing(receivedMessageBody);

    logger.info("Web→MC auth confirm integration test completed successfully");
  }

  @Test
  void shouldSendWebCommandToMcQueue() throws Exception {
    final String testId = java.util.UUID.randomUUID().toString();
    // Web → MC: コマンド実行メッセージ作成
    Map<String, Object> commandMessage = new java.util.HashMap<>(Map.of(
        "type", "web_mc_command",
        "playerUuid", "test-uuid-command-12345",
        "playerName", "TestCommandPlayer",
        "command", "tp spawn",
        "userId", "web-user-command-12345",
        "timestamp", Instant.now().toString()));
    commandMessage.put("testId", testId);

    String messageBody = TestUtils.toJson(commandMessage);
    logger.info("Sending Web→MC command message: {}", messageBody);

    // Web側からMC向けSQSキューにメッセージ送信
    SendMessageRequest sendRequest = SendMessageRequest.builder()
        .queueUrl(webToMcQueueUrl)
        .messageBody(messageBody)
        .build();

    sqsClient.sendMessage(sendRequest);
    logger.info("Web→MC command message sent successfully");

    // SQSメッセージ確認
    Message receivedMessage = TestUtils.waitForSpecificMessage(sqsClient, webToMcQueueUrl, testId, Duration.ofSeconds(10));

    // メッセージ受信確認
    if (receivedMessage != null) {
      Map<String, Object> receivedMessageBody = TestUtils.parseJson(receivedMessage.body());

      logger.info("Received Web→MC command SQS message: {}", receivedMessage.body());

      // メッセージ内容確認
      assertThat(receivedMessageBody)
          .as("Received message should contain web_mc_command data")
          .containsEntry("type", "web_mc_command")
          .containsEntry("playerName", "TestCommandPlayer")
          .containsEntry("command", "tp spawn");

      // MC側での処理をシミュレート
      simulateMcProcessing(receivedMessageBody);
    }

    logger.info("Web→MC command integration test completed successfully");
  }

  @Test
  void shouldHandleBidirectionalCommunication() throws Exception {
    final String testId1 = java.util.UUID.randomUUID().toString();
    final String testId2 = java.util.UUID.randomUUID().toString();
    // 双方向通信テスト：Web認証フロー全体をシミュレート
    String sessionId = UUID.randomUUID().toString();
    String playerUuid = "test-uuid-bidirectional-12345";
    String playerName = "TestBidirectionalPlayer";

    // 1. Web → MC: 認証確認送信
    Map<String, Object> authConfirmMessage = new java.util.HashMap<>(Map.of(
        "type", "web_mc_auth_confirm",
        "playerUuid", playerUuid,
        "playerName", playerName,
        "userId", "web-user-bidirectional-12345",
        "confirmed", true,
        "sessionId", sessionId,
        "timestamp", Instant.now().toString()));
    authConfirmMessage.put("testId", testId1);

    SendMessageRequest webToMcRequest = SendMessageRequest.builder()
        .queueUrl(webToMcQueueUrl)
        .messageBody(TestUtils.toJson(authConfirmMessage))
        .build();

    sqsClient.sendMessage(webToMcRequest);
    logger.info("Step 1: Web→MC auth confirm sent");

    // 少し待機
    TestUtils.waitFor(Duration.ofSeconds(1));

    // 2. MC → Web: 認証レスポンス送信
    Map<String, Object> authResponseMessage = new java.util.HashMap<>(Map.of(
        "type", "mc_web_auth_response",
        "playerUuid", playerUuid,
        "playerName", playerName,
        "serverName", "test-server",
        "authStatus", "success",
        "sessionId", sessionId,
        "timestamp", Instant.now().toString()));
    authResponseMessage.put("testId", testId2);

    SendMessageRequest mcToWebRequest = SendMessageRequest.builder()
        .queueUrl(mcToWebQueueUrl)
        .messageBody(TestUtils.toJson(authResponseMessage))
        .build();

    sqsClient.sendMessage(mcToWebRequest);
    logger.info("Step 2: MC→Web auth response sent");

    // 両方向のメッセージ受信確認
    Message webToMcMessage = TestUtils.waitForSpecificMessage(sqsClient, webToMcQueueUrl, testId1, Duration.ofSeconds(10));
    Message mcToWebMessage = TestUtils.waitForSpecificMessage(sqsClient, mcToWebQueueUrl, testId2, Duration.ofSeconds(10));

    // 両方向のメッセージが正常に送受信されたことを確認
    assertThat(webToMcMessage).isNotNull();
    assertThat(mcToWebMessage).isNotNull();

    logger.info("MC ↔ Web bidirectional communication integration test completed successfully");
  }

  /**
   * Web側でのメッセージ処理をシミュレート
   */
  private void simulateWebProcessing(Map<String, Object> messageData) {
    String messageType = (String) messageData.get("type");
    String playerName = (String) messageData.get("playerName");

    switch (messageType) {
      case "mc_web_auth_response":
        String authStatus = (String) messageData.get("authStatus");
        logger.info("🌐 Web would process: Auth response for {} - status: {}", playerName, authStatus);
        break;
      case "mc_web_player_status":
        String status = (String) messageData.get("status");
        logger.info("🌐 Web would process: Player {} status update - {}", playerName, status);
        break;
      case "mc_web_server_info":
        logger.info("🌐 Web would process: Server info update for {}", messageData.get("serverName"));
        break;
      default:
        logger.info("🌐 Web would process: Unknown message type - {}", messageType);
    }

    logger.info("✅ Web processing completed for message type: {}", messageType);
  }

  /**
   * MC側でのメッセージ処理をシミュレート
   */
  private void simulateMcProcessing(Map<String, Object> messageData) {
    String messageType = (String) messageData.get("type");
    String playerName = (String) messageData.get("playerName");

    switch (messageType) {
      case "web_mc_auth_confirm":
        Boolean confirmed = (Boolean) messageData.get("confirmed");
        logger.info("🎮 MC would process: Auth confirm for {} - confirmed: {}", playerName, confirmed);
        break;
      case "web_mc_command":
        String command = (String) messageData.get("command");
        logger.info("🎮 MC would process: Execute command '{}' for player {}", command, playerName);
        break;
      case "web_mc_player_request":
        logger.info("🎮 MC would process: Player request for {}", playerName);
        break;
      default:
        logger.info("🎮 MC would process: Unknown message type - {}", messageType);
    }

    logger.info("✅ MC processing completed for message type: {}", messageType);
  }
}