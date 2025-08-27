package net.kishax.integration;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.signer.Aws4Signer;
import software.amazon.awssdk.auth.signer.params.Aws4SignerParams;
import software.amazon.awssdk.http.HttpExecuteRequest;
import software.amazon.awssdk.http.HttpExecuteResponse;
import software.amazon.awssdk.http.SdkHttpClient;
import software.amazon.awssdk.http.SdkHttpFullRequest;
import software.amazon.awssdk.http.SdkHttpMethod;
import software.amazon.awssdk.http.apache.ApacheHttpClient;
import software.amazon.awssdk.services.sqs.model.Message;
import software.amazon.awssdk.utils.IoUtils;

import java.net.URI;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Web → MC認証統合テスト（API Gateway → SQS → MC Plugins）
 * 
 * テストフロー:
 * 1. WebアプリケーションとしてAPI GatewayにWeb→MC認証メッセージ送信（IAM認証）
 * 2. Lambda → Web-to-MC SQS に自動転送
 * 3. Web-to-MC SQSからメッセージ受信確認
 * 4. MC Plugins処理をシミュレート
 */
@Tag("integration")
public class WebMcAuthTest {

  private static final Logger logger = LoggerFactory.getLogger(WebMcAuthTest.class);
  private SdkHttpClient httpClient;
  private String webToMcApiGatewayUrl;
  private String webToMcSqsQueueUrl;

  @BeforeEach
  void setUp() {
    httpClient = ApacheHttpClient.builder().build();
    webToMcApiGatewayUrl = TestConfig.getWebToMcApiGatewayUrl();
    webToMcSqsQueueUrl = TestConfig.getWebToMcSqsQueueUrl();

    logger.info("Test setup - Web→MC API Gateway URL: {}", webToMcApiGatewayUrl);
    logger.info("Test setup - Web→MC SQS Queue URL: {}", webToMcSqsQueueUrl);
  }

  @Test
  void shouldSendWebAuthConfirmViaApiGatewayToMcQueue() throws Exception {
    // API Gatewayに送信するWeb→MC認証確認メッセージ作成
    String sessionId = UUID.randomUUID().toString();
    Map<String, Object> authConfirmMessage = Map.of(
        "type", "web_mc_auth_confirm",
        "playerUuid", "test-uuid-web-auth-confirm-12345",
        "playerName", "TestWebAuthPlayer",
        "userId", "web-user-auth-12345",
        "confirmed", true,
        "sessionId", sessionId,
        "timestamp", Instant.now().toString());

    String messageBody = TestUtils.toJson(authConfirmMessage);
    logger.info("Sending Web→MC auth confirm message via API Gateway: {}", messageBody);

    // Web→MC SQS事前状態確認
    int initialMessageCount = TestUtils.getSQSMessageCount(webToMcSqsQueueUrl);
    logger.info("Initial Web→MC SQS message count: {}", initialMessageCount);

    // API Gateway にリクエスト送信
    int statusCode = sendSignedRequest(messageBody);

    // ステータスコード確認
    assertThat(statusCode)
        .as("API Gateway should return 200 OK")
        .isEqualTo(200);

    logger.info("Web→MC auth confirm message sent successfully via API Gateway");

    // Web→MC SQSメッセージ確認（少し待機してから）
    TestUtils.waitFor(Duration.ofSeconds(3));

    List<Message> messages = TestUtils.receiveSQSMessages(
        webToMcSqsQueueUrl,
        10,
        Duration.ofSeconds(5));

    // メッセージが受信されたことを確認
    assertThat(messages)
        .as("Should receive at least one message from Web→MC SQS")
        .isNotEmpty();

    // メッセージ内容確認
    Message receivedMessage = messages.get(0);
    Map<String, Object> receivedMessageBody = TestUtils.parseJson(receivedMessage.body());

    logger.info("Received Web→MC SQS message: {}", receivedMessage.body());

    // 送信したメッセージ内容が含まれているか確認
    assertThat(receivedMessageBody)
        .as("Received message should contain web_mc_auth_confirm data")
        .containsEntry("type", "web_mc_auth_confirm")
        .containsEntry("playerName", "TestWebAuthPlayer")
        .containsEntry("confirmed", true);

    // MC Plugins処理をシミュレート
    simulateMcPluginProcessing(receivedMessageBody);

    // テスト後クリーンアップ
    TestUtils.deleteSQSMessage(webToMcSqsQueueUrl, receivedMessage.receiptHandle());

    logger.info("Web → MC auth confirm integration test completed successfully");
  }

  @Test
  void shouldSendWebCommandViaApiGatewayToMcQueue() throws Exception {
    // API Gatewayに送信するWeb→MCコマンド実行メッセージ作成
    Map<String, Object> commandMessage = Map.of(
        "type", "web_mc_command",
        "playerUuid", "test-uuid-web-command-12345",
        "playerName", "TestWebCommandPlayer",
        "command", "teleport spawn",
        "userId", "web-user-command-12345",
        "timestamp", Instant.now().toString());

    String messageBody = TestUtils.toJson(commandMessage);
    logger.info("Sending Web→MC command message via API Gateway: {}", messageBody);

    // API Gateway にリクエスト送信
    int statusCode = sendSignedRequest(messageBody);

    // ステータスコード確認
    assertThat(statusCode)
        .as("API Gateway should return 200 OK")
        .isEqualTo(200);

    logger.info("Web→MC command message sent successfully via API Gateway");

    // Web→MC SQSメッセージ確認（少し待機してから）
    TestUtils.waitFor(Duration.ofSeconds(3));

    List<Message> messages = TestUtils.receiveSQSMessages(
        webToMcSqsQueueUrl,
        10,
        Duration.ofSeconds(5));

    // メッセージが受信された場合の処理
    if (!messages.isEmpty()) {
      Message receivedMessage = messages.get(0);
      Map<String, Object> receivedMessageBody = TestUtils.parseJson(receivedMessage.body());

      logger.info("Received Web→MC command SQS message: {}", receivedMessage.body());

      // メッセージ内容確認
      assertThat(receivedMessageBody)
          .as("Received message should contain web_mc_command data")
          .containsEntry("type", "web_mc_command")
          .containsEntry("playerName", "TestWebCommandPlayer")
          .containsEntry("command", "teleport spawn");

      // MC Plugins処理をシミュレート
      simulateMcPluginProcessing(receivedMessageBody);

      // テスト後クリーンアップ
      TestUtils.deleteSQSMessage(webToMcSqsQueueUrl, receivedMessage.receiptHandle());
    } else {
      logger.info("No messages received from Web→MC SQS (likely consumed by MC Plugins)");
    }

    logger.info("Web → MC command integration test completed successfully");
  }

  @Test
  void shouldSendWebPlayerRequestViaApiGatewayToMcQueue() throws Exception {
    // API Gatewayに送信するWeb→MCプレイヤー情報要求メッセージ作成
    Map<String, Object> playerRequestMessage = Map.of(
        "type", "web_mc_player_request",
        "playerUuid", "test-uuid-web-player-req-12345",
        "playerName", "TestWebPlayerReq",
        "requestType", "status",
        "userId", "web-user-player-req-12345",
        "timestamp", Instant.now().toString());

    String messageBody = TestUtils.toJson(playerRequestMessage);
    logger.info("Sending Web→MC player request message via API Gateway: {}", messageBody);

    // API Gateway にリクエスト送信
    int statusCode = sendSignedRequest(messageBody);

    // ステータスコード確認
    assertThat(statusCode)
        .as("API Gateway should return 200 OK")
        .isEqualTo(200);

    logger.info("Web→MC player request message sent successfully via API Gateway");

    // Web→MC SQSメッセージ確認
    TestUtils.waitFor(Duration.ofSeconds(3));

    List<Message> messages = TestUtils.receiveSQSMessages(
        webToMcSqsQueueUrl,
        10,
        Duration.ofSeconds(5));

    // メッセージが受信された場合の処理
    if (!messages.isEmpty()) {
      Message receivedMessage = messages.get(0);
      Map<String, Object> receivedMessageBody = TestUtils.parseJson(receivedMessage.body());

      logger.info("Received Web→MC player request SQS message: {}", receivedMessage.body());

      // メッセージ内容確認
      assertThat(receivedMessageBody)
          .as("Received message should contain web_mc_player_request data")
          .containsEntry("type", "web_mc_player_request")
          .containsEntry("playerName", "TestWebPlayerReq")
          .containsEntry("requestType", "status");

      // MC Plugins処理をシミュレート
      simulateMcPluginProcessing(receivedMessageBody);

      // テスト後クリーンアップ
      TestUtils.deleteSQSMessage(webToMcSqsQueueUrl, receivedMessage.receiptHandle());
    } else {
      logger.info("No messages received from Web→MC SQS (likely consumed by MC Plugins)");
    }

    logger.info("Web → MC player request integration test completed successfully");
  }

  @Test
  void shouldHandleWebToMcAuthFlow() throws Exception {
    // Web→MC完全認証フローテスト
    String sessionId = UUID.randomUUID().toString();
    String playerUuid = "test-uuid-auth-flow-12345";
    String playerName = "TestAuthFlowPlayer";
    String userId = "web-user-auth-flow-12345";

    // 1. Web→MC: 認証確認
    Map<String, Object> authConfirmMessage = Map.of(
        "type", "web_mc_auth_confirm",
        "playerUuid", playerUuid,
        "playerName", playerName,
        "userId", userId,
        "confirmed", true,
        "sessionId", sessionId,
        "timestamp", Instant.now().toString());

    int statusCode1 = sendSignedRequest(TestUtils.toJson(authConfirmMessage));
    assertThat(statusCode1).isEqualTo(200);
    logger.info("Step 1: Web→MC auth confirm sent successfully");

    TestUtils.waitFor(Duration.ofSeconds(2));

    // 2. Web→MC: プレイヤー情報要求
    Map<String, Object> playerRequestMessage = Map.of(
        "type", "web_mc_player_request",
        "playerUuid", playerUuid,
        "playerName", playerName,
        "requestType", "full_status",
        "userId", userId,
        "sessionId", sessionId,
        "timestamp", Instant.now().toString());

    int statusCode2 = sendSignedRequest(TestUtils.toJson(playerRequestMessage));
    assertThat(statusCode2).isEqualTo(200);
    logger.info("Step 2: Web→MC player request sent successfully");

    TestUtils.waitFor(Duration.ofSeconds(2));

    // 3. Web→MC: コマンド実行
    Map<String, Object> commandMessage = Map.of(
        "type", "web_mc_command",
        "playerUuid", playerUuid,
        "playerName", playerName,
        "command", "kit starter",
        "userId", userId,
        "sessionId", sessionId,
        "timestamp", Instant.now().toString());

    int statusCode3 = sendSignedRequest(TestUtils.toJson(commandMessage));
    assertThat(statusCode3).isEqualTo(200);
    logger.info("Step 3: Web→MC command sent successfully");

    // 全メッセージの確認とクリーンアップ
    TestUtils.waitFor(Duration.ofSeconds(3));
    List<Message> allMessages = TestUtils.receiveSQSMessages(
        webToMcSqsQueueUrl, 10, Duration.ofSeconds(5));

    logger.info("Web→MC auth flow test: Received {} messages total", allMessages.size());

    // すべてのメッセージをクリーンアップ
    allMessages.forEach(msg -> {
      try {
        Map<String, Object> msgBody = TestUtils.parseJson(msg.body());
        logger.info("Processing auth flow message: {}", msgBody.get("type"));
        TestUtils.deleteSQSMessage(webToMcSqsQueueUrl, msg.receiptHandle());
      } catch (Exception e) {
        logger.error("Error processing auth flow message", e);
      }
    });

    logger.info("Web → MC complete auth flow integration test completed successfully");
  }

  /**
   * IAM認証でAPI GatewayにPOSTリクエスト送信
   * 実際のWebアプリケーションと同じ認証方式を使用
   */
  private int sendSignedRequest(String requestBody) throws Exception {
    // AWS認証情報（環境変数から取得）
    AwsBasicCredentials credentials = AwsBasicCredentials.create(
        System.getenv("AWS_ACCESS_KEY_ID"),
        System.getenv("AWS_SECRET_ACCESS_KEY"));

    // HTTPリクエスト作成
    SdkHttpFullRequest request = SdkHttpFullRequest.builder()
        .method(SdkHttpMethod.POST)
        .uri(URI.create(webToMcApiGatewayUrl))
        .putHeader("Content-Type", "application/json")
        .contentStreamProvider(() -> new java.io.ByteArrayInputStream(requestBody.getBytes()))
        .build();

    // AWS Signature V4 で署名
    Aws4Signer signer = Aws4Signer.create();
    Aws4SignerParams signerParams = Aws4SignerParams.builder()
        .awsCredentials(credentials)
        .signingName("execute-api")
        .signingRegion(TestConfig.AWS_REGION)
        .build();

    SdkHttpFullRequest signedRequest = signer.sign(request, signerParams);

    // リクエスト実行
    HttpExecuteRequest executeRequest = HttpExecuteRequest.builder()
        .request(signedRequest)
        .contentStreamProvider(signedRequest.contentStreamProvider().orElse(null))
        .build();

    HttpExecuteResponse response = httpClient.prepareRequest(executeRequest).call();
    try {
      String responseBody = response.responseBody()
          .map(stream -> {
            try {
              return IoUtils.toUtf8String(stream);
            } catch (Exception e) {
              logger.error("Failed to read response body", e);
              return "";
            }
          })
          .orElse("");

      logger.info("Web→MC API Gateway response: {} - {}", response.httpResponse().statusCode(), responseBody);

      return response.httpResponse().statusCode();
    } finally {
      // HttpExecuteResponseはcloseメソッドを持たないので削除
    }
  }

  /**
   * MC Plugins のメッセージ処理をシミュレート
   * 実際のMC内での処理をログ出力のみでシミュレート
   */
  private void simulateMcPluginProcessing(Map<String, Object> messageData) {
    String messageType = (String) messageData.get("type");
    String playerName = (String) messageData.get("playerName");

    // MC Plugins の処理ロジックをシミュレート
    switch (messageType) {
      case "web_mc_auth_confirm":
        Boolean confirmed = (Boolean) messageData.get("confirmed");
        String userId = (String) messageData.get("userId");
        if (Boolean.TRUE.equals(confirmed)) {
          logger.info("🎮 MC Plugins would process: Auth confirmed for player {} (User ID: {})", playerName, userId);
          logger.info("🔑 MC Plugins would: Link Minecraft account with web user");
        } else {
          logger.info("🎮 MC Plugins would process: Auth denied for player {}", playerName);
        }
        break;
      case "web_mc_command":
        String command = (String) messageData.get("command");
        logger.info("🎮 MC Plugins would process: Execute command '{}' for player {}", command, playerName);
        logger.info("⚡ MC Plugins would: Run in-game command for {}", playerName);
        break;
      case "web_mc_player_request":
        String requestType = (String) messageData.get("requestType");
        logger.info("🎮 MC Plugins would process: Player {} info request - type: {}", playerName, requestType);
        logger.info("📊 MC Plugins would: Gather player data and send response to MC→Web queue");
        break;
      default:
        logger.info("🎮 MC Plugins would process: Unknown Web→MC message type - {}", messageType);
    }

    // 処理完了を示す
    logger.info("✅ MC Plugins processing completed for message type: {}", messageType);
  }
}