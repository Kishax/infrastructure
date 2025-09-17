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

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Player Event Tests 統合テスト（API Gateway → SQS → Discord Bot）
 * 
 * テストフロー:
 * 1. API Gatewayにメッセージ送信（MinecraftプラグインのようにIAM認証）
 * 2. Lambda → SQS に自動転送
 * 3. SQSからメッセージ受信確認
 * 4. Discord Bot処理をシミュレート
 * 
 * プレイヤーイベント（join/leave）の統合テストに特化
 */
@Tag("integration")
public class DiscordBotSqsTest {

  private static final Logger logger = LoggerFactory.getLogger(DiscordBotSqsTest.class);
  private SdkHttpClient httpClient;
  private String apiGatewayUrl;
  private String sqsQueueUrl;
  private String discordChannelId;

  @BeforeEach
  void setUp() {
    httpClient = ApacheHttpClient.builder().build();
    apiGatewayUrl = TestConfig.getApiGatewayUrl();
    sqsQueueUrl = TestConfig.getSqsQueueUrl();
    discordChannelId = TestConfig.DISCORD_CHANNEL_ID;

    logger.info("Test setup - API Gateway URL: {}", apiGatewayUrl);
    logger.info("Test setup - SQS Queue URL: {}", sqsQueueUrl);
    logger.info("Test setup - Discord Channel ID: {}", discordChannelId);
  }

  @Test
  void shouldSendPlayerJoinEventAndReceiveInSqs() throws Exception {
    final String testId = java.util.UUID.randomUUID().toString();
    // プレイヤー参加イベントメッセージ作成
    Map<String, Object> joinMessage = new java.util.HashMap<>(Map.of(
        "type", "player_event",
        "eventType", "join",
        "playerName", "TestPlayerJoin",
        "playerUuid", "test-uuid-join-12345",
        "serverName", "test-server",
        "timestamp", Instant.now().toString(),
        "channel_id", discordChannelId));
    joinMessage.put("testId", testId);

    String messageBody = TestUtils.toJson(joinMessage);
    logger.info("Sending player join event via API Gateway: {}", messageBody);

    // API Gateway にリクエスト送信
    int statusCode = sendSignedRequest(messageBody);

    // ステータスコード確認
    assertThat(statusCode)
        .as("API Gateway should return 200 OK")
        .isEqualTo(200);

    logger.info("Player join event sent successfully to API Gateway");

    // SQSメッセージ確認
    Message receivedMessage = TestUtils.waitForSpecificMessage(TestConfig.createSqsClient(), sqsQueueUrl, testId, Duration.ofSeconds(10));

    // メッセージが受信されたことを確認
    assertThat(receivedMessage)
        .as("Should receive player join event from SQS")
        .isNotNull();

    // メッセージ内容確認
    Map<String, Object> receivedMessageBody = TestUtils.parseJson(receivedMessage.body());

    logger.info("Received player join SQS message: {}", receivedMessage.body());

    // 送信したメッセージ内容が含まれているか確認
    assertThat(receivedMessageBody)
        .as("Received message should contain player join event data")
        .containsEntry("type", "player_event")
        .containsEntry("eventType", "join")
        .containsEntry("playerName", "TestPlayerJoin");

    // Discord Bot処理シミュレーション
    simulateDiscordBotProcessing(receivedMessageBody);

    logger.info("Player join event integration test completed successfully");
  }

  @Test
  void shouldHandleMultiplePlayerEventsViaApiGateway() throws Exception {
    final String testIdJoin = java.util.UUID.randomUUID().toString();
    final String testIdLeave = java.util.UUID.randomUUID().toString();

    // 複数のプレイヤーイベントをAPI Gateway経由でテスト
    Map<String, Object> joinMessage = new java.util.HashMap<>(Map.of(
        "type", "player_event",
        "eventType", "join",
        "playerName", "MultiTestPlayer1",
        "playerUuid", "test-uuid-multi-join-12345",
        "serverName", "test-server",
        "timestamp", Instant.now().toString(),
        "channel_id", discordChannelId));
    joinMessage.put("testId", testIdJoin);

    Map<String, Object> leaveMessage = new java.util.HashMap<>(Map.of(
        "type", "player_event",
        "eventType", "leave",
        "playerName", "MultiTestPlayer2",
        "playerUuid", "test-uuid-multi-leave-12345",
        "serverName", "test-server",
        "timestamp", Instant.now().toString(),
        "channel_id", discordChannelId));
    leaveMessage.put("testId", testIdLeave);

    Map<String, Map<String, Object>> playerEvents = Map.of(
        "player_join", joinMessage,
        "player_leave", leaveMessage);

    // 各プレイヤーイベントをAPI Gateway経由で送信
    for (Map.Entry<String, Map<String, Object>> entry : playerEvents.entrySet()) {
      String eventType = entry.getKey();
      Map<String, Object> eventData = entry.getValue();

      String messageBody = TestUtils.toJson(eventData);

      // API Gateway にリクエスト送信
      int statusCode = sendSignedRequest(messageBody);

      assertThat(statusCode)
          .as("API Gateway should return 200 OK for " + eventType)
          .isEqualTo(200);

      logger.info("Sent {} event via API Gateway", eventType);

      // 各メッセージ間で少し待機
      TestUtils.waitFor(Duration.ofSeconds(1));
    }

    // 各プレイヤーイベントを受信確認
    Message joinReceived = TestUtils.waitForSpecificMessage(TestConfig.createSqsClient(), sqsQueueUrl, testIdJoin, Duration.ofSeconds(10));
    Message leaveReceived = TestUtils.waitForSpecificMessage(TestConfig.createSqsClient(), sqsQueueUrl, testIdLeave, Duration.ofSeconds(10));

    assertThat(joinReceived).isNotNull();
    assertThat(leaveReceived).isNotNull();

    // 各プレイヤーイベントを処理
    simulateDiscordBotProcessing(TestUtils.parseJson(joinReceived.body()));
    simulateDiscordBotProcessing(TestUtils.parseJson(leaveReceived.body()));

    logger.info("Multiple player events test completed successfully");
  }

  @Test
  void shouldSendPlayerLeaveEventAndReceiveInSqs() throws Exception {
    final String testId = java.util.UUID.randomUUID().toString();
    // プレイヤー離脱イベントメッセージ作成
    Map<String, Object> leaveMessage = new java.util.HashMap<>(Map.of(
        "type", "player_event",
        "eventType", "leave",
        "playerName", "TestPlayerLeave",
        "playerUuid", "test-uuid-leave-12345",
        "serverName", "test-server",
        "timestamp", Instant.now().toString(),
        "channel_id", discordChannelId));
    leaveMessage.put("testId", testId);

    String messageBody = TestUtils.toJson(leaveMessage);
    logger.info("Sending player leave event via API Gateway: {}", messageBody);

    // API Gateway にリクエスト送信
    int statusCode = sendSignedRequest(messageBody);

    // ステータスコード確認
    assertThat(statusCode)
        .as("API Gateway should return 200 OK")
        .isEqualTo(200);

    logger.info("Player leave event sent successfully to API Gateway");

    // SQSメッセージ確認
    Message receivedMessage = TestUtils.waitForSpecificMessage(TestConfig.createSqsClient(), sqsQueueUrl, testId, Duration.ofSeconds(10));

    // メッセージが受信されたことを確認
    assertThat(receivedMessage)
        .as("Should receive player leave event from SQS")
        .isNotNull();

    // メッセージ内容確認
    Map<String, Object> receivedMessageBody = TestUtils.parseJson(receivedMessage.body());

    logger.info("Received player leave SQS message: {}", receivedMessage.body());

    // 送信したメッセージ内容が含まれているか確認
    assertThat(receivedMessageBody)
        .as("Received message should contain player leave event data")
        .containsEntry("type", "player_event")
        .containsEntry("eventType", "leave")
        .containsEntry("playerName", "TestPlayerLeave");

    // Discord Bot処理シミュレーション
    simulateDiscordBotProcessing(receivedMessageBody);

    logger.info("Player leave event integration test completed successfully");
  }

  /**
   * IAM認証でAPI GatewayにPOSTリクエスト送信
   * 実際のMinecraftプラグインと同じ認証方式を使用
   */
  private int sendSignedRequest(String requestBody) throws Exception {
    // AWS認証情報（環境変数から取得）
    AwsBasicCredentials credentials = AwsBasicCredentials.create(
        System.getenv("AWS_ACCESS_KEY_ID"),
        System.getenv("AWS_SECRET_ACCESS_KEY"));

    // HTTPリクエスト作成
    SdkHttpFullRequest request = SdkHttpFullRequest.builder()
        .method(SdkHttpMethod.POST)
        .uri(URI.create(apiGatewayUrl))
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

      logger.info("API Gateway response: {} - {}", response.httpResponse().statusCode(), responseBody);

      return response.httpResponse().statusCode();
    } finally {
      // HttpExecuteResponseはcloseメソッドを持たないので削除
    }
  }

  /**
   * Discord Bot のメッセージ処理をシミュレート
   * 実際のDiscord APIには送信せず、ログ出力のみ
   */
  private void simulateDiscordBotProcessing(Map<String, Object> messageData) {
    String messageType = (String) messageData.get("type");
    String message = (String) messageData.get("message");

    // Discord Bot の処理ロジックをシミュレート
    switch (messageType) {
      case "player_event":
        String eventType = (String) messageData.get("eventType");
        String playerName = (String) messageData.get("playerName");
        if ("join".equals(eventType)) {
          logger.info("🎮 Discord Bot would send: Player {} joined!", playerName);
        } else if ("leave".equals(eventType)) {
          logger.info("🚪 Discord Bot would send: Player {} left!", playerName);
        } else {
          logger.info("👤 Discord Bot would send: Player {} - {}", playerName, eventType);
        }
        break;
      case "server_status":
        logger.info("📊 Discord Bot would send: Server status - {}", messageData.get("status"));
        break;
      default:
        logger.info("💬 Discord Bot would send: {}", message);
    }

    // 処理完了を示す
    logger.info("✅ Discord Bot processing completed for message type: {}", messageType);
  }
}
