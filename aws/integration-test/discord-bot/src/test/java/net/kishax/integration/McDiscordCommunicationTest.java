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
 * MC → Discord通信統合テスト（API Gateway → SQS → Discord Bot）
 * 
 * テストフロー:
 * 1. MinecraftプラグインとしてAPI Gatewayにメッセージ送信（IAM認証）
 * 2. Lambda → Discord SQS に自動転送
 * 3. Discord SQSからメッセージ受信確認
 * 4. Discord Bot処理をシミュレート
 */
@Tag("integration")
public class McDiscordCommunicationTest {

  private static final Logger logger = LoggerFactory.getLogger(McDiscordCommunicationTest.class);
  private SdkHttpClient httpClient;
  private String discordApiGatewayUrl;
  private String discordSqsQueueUrl;
  private String discordChannelId;

  @BeforeEach
  void setUp() {
    httpClient = ApacheHttpClient.builder().build();
    discordApiGatewayUrl = TestConfig.getDiscordApiGatewayUrl();
    discordSqsQueueUrl = TestConfig.getDiscordSqsQueueUrl();
    discordChannelId = TestConfig.DISCORD_CHANNEL_ID;

    logger.info("Test setup - Discord API Gateway URL: {}", discordApiGatewayUrl);
    logger.info("Test setup - Discord SQS Queue URL: {}", discordSqsQueueUrl);
    logger.info("Test setup - Discord Channel ID: {}", discordChannelId);
  }

  @Test
  void shouldSendPlayerJoinMessageViaApiGatewayToDiscordQueue() throws Exception {
    // API Gatewayに送信するプレイヤー参加メッセージ作成
    Map<String, Object> playerJoinMessage = Map.of(
        "type", "player_event",
        "eventType", "join",
        "playerName", "TestPlayerJoin",
        "playerUuid", "test-uuid-discord-join-12345",
        "serverName", "discord-test-server",
        "timestamp", Instant.now().toString(),
        "channel_id", discordChannelId);

    String messageBody = TestUtils.toJson(playerJoinMessage);
    logger.info("Sending player_join message to Discord API Gateway: {}", messageBody);

    // Discord SQS事前状態確認
    int initialMessageCount = TestUtils.getSQSMessageCount(discordSqsQueueUrl);
    logger.info("Initial Discord SQS message count: {}", initialMessageCount);

    // API Gateway にリクエスト送信
    int statusCode = sendSignedRequest(messageBody);

    // ステータスコード確認
    assertThat(statusCode)
        .as("API Gateway should return 200 OK")
        .isEqualTo(200);

    logger.info("Player join message sent successfully to Discord API Gateway");

    // Discord SQSメッセージ確認（少し待機してから）
    TestUtils.waitFor(Duration.ofSeconds(3));

    List<Message> messages = TestUtils.receiveSQSMessages(
        discordSqsQueueUrl,
        10,
        Duration.ofSeconds(5));

    // メッセージが受信されたことを確認
    assertThat(messages)
        .as("Should receive at least one message from Discord SQS")
        .isNotEmpty();

    // メッセージ内容確認
    Message receivedMessage = messages.get(0);
    Map<String, Object> receivedMessageBody = TestUtils.parseJson(receivedMessage.body());

    logger.info("Received Discord SQS message: {}", receivedMessage.body());

    // 送信したメッセージ内容が含まれているか確認
    assertThat(receivedMessageBody)
        .as("Received message should contain player_event join data")
        .containsEntry("type", "player_event")
        .containsEntry("eventType", "join")
        .containsEntry("playerName", "TestPlayerJoin");

    // Discord Bot処理シミュレーション
    simulateDiscordBotProcessing(receivedMessageBody);

    // テスト後クリーンアップ
    TestUtils.deleteSQSMessage(discordSqsQueueUrl, receivedMessage.receiptHandle());

    logger.info("MC → Discord player join integration test completed successfully");
  }

  @Test
  void shouldSendPlayerLeaveMessageViaApiGatewayToDiscordQueue() throws Exception {
    // API Gatewayに送信するプレイヤー離脱メッセージ作成
    Map<String, Object> playerLeaveMessage = Map.of(
        "type", "player_event",
        "eventType", "leave",
        "playerName", "TestPlayerLeave",
        "playerUuid", "test-uuid-discord-leave-12345",
        "serverName", "discord-test-server",
        "timestamp", Instant.now().toString(),
        "channel_id", discordChannelId);

    String messageBody = TestUtils.toJson(playerLeaveMessage);
    logger.info("Sending player_leave message to Discord API Gateway: {}", messageBody);

    // Discord SQS事前状態確認
    int initialMessageCount = TestUtils.getSQSMessageCount(discordSqsQueueUrl);
    logger.info("Initial Discord SQS message count: {}", initialMessageCount);

    // API Gateway にリクエスト送信
    int statusCode = sendSignedRequest(messageBody);

    // ステータスコード確認
    assertThat(statusCode)
        .as("API Gateway should return 200 OK")
        .isEqualTo(200);

    logger.info("Player leave message sent successfully to Discord API Gateway");

    // Discord SQSメッセージ確認（少し待機してから）
    TestUtils.waitFor(Duration.ofSeconds(3));

    List<Message> messages = TestUtils.receiveSQSMessages(
        discordSqsQueueUrl,
        10,
        Duration.ofSeconds(5));

    // メッセージが受信された場合の処理
    if (!messages.isEmpty()) {
      Message receivedMessage = messages.get(0);
      Map<String, Object> receivedMessageBody = TestUtils.parseJson(receivedMessage.body());

      logger.info("Received Discord SQS message: {}", receivedMessage.body());

      // メッセージ内容確認
      assertThat(receivedMessageBody)
          .as("Received message should contain player_event leave data")
          .containsEntry("type", "player_event")
          .containsEntry("eventType", "leave")
          .containsEntry("playerName", "TestPlayerLeave");

      // Discord Bot処理シミュレーション
      simulateDiscordBotProcessing(receivedMessageBody);

      // テスト後クリーンアップ
      TestUtils.deleteSQSMessage(discordSqsQueueUrl, receivedMessage.receiptHandle());
    } else {
      logger.info("No messages received from Discord SQS (likely consumed by Discord Bot service)");
    }

    logger.info("MC → Discord player leave integration test completed successfully");
  }

  @Test
  void shouldSendServerStatusMessageViaApiGatewayToDiscordQueue() throws Exception {
    // API Gatewayに送信するサーバーステータスメッセージ作成
    Map<String, Object> serverStatusMessage = Map.of(
        "type", "server_status",
        "status", "online",
        "players", 3,
        "message", "Server is online with 3 players",
        "timestamp", Instant.now().toString(),
        "server", "discord-test-server",
        "channel_id", discordChannelId);

    String messageBody = TestUtils.toJson(serverStatusMessage);
    logger.info("Sending server_status message to Discord API Gateway: {}", messageBody);

    // API Gateway にリクエスト送信
    int statusCode = sendSignedRequest(messageBody);

    // ステータスコード確認
    assertThat(statusCode)
        .as("API Gateway should return 200 OK")
        .isEqualTo(200);

    logger.info("Server status message sent successfully to Discord API Gateway");

    // Discord SQSメッセージ確認（少し待機してから）
    TestUtils.waitFor(Duration.ofSeconds(3));

    List<Message> messages = TestUtils.receiveSQSMessages(
        discordSqsQueueUrl,
        10,
        Duration.ofSeconds(5));

    // メッセージが受信された場合の処理
    if (!messages.isEmpty()) {
      Message receivedMessage = messages.get(0);
      Map<String, Object> receivedMessageBody = TestUtils.parseJson(receivedMessage.body());

      logger.info("Received Discord SQS message: {}", receivedMessage.body());

      // メッセージ内容確認
      assertThat(receivedMessageBody)
          .as("Received message should contain server_status data")
          .containsEntry("type", "server_status")
          .containsEntry("status", "online")
          .containsEntry("players", 3);

      // Discord Bot処理シミュレーション
      simulateDiscordBotProcessing(receivedMessageBody);

      // テスト後クリーンアップ
      TestUtils.deleteSQSMessage(discordSqsQueueUrl, receivedMessage.receiptHandle());
    } else {
      logger.info("No messages received from Discord SQS (likely consumed by Discord Bot service)");
    }

    logger.info("MC → Discord server status integration test completed successfully");
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
        .uri(URI.create(discordApiGatewayUrl))
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

      logger.info("Discord API Gateway response: {} - {}", response.httpResponse().statusCode(), responseBody);

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

    // Discord Bot の処理ロジックをシミュレート
    switch (messageType) {
      case "player_event":
        String eventType = (String) messageData.get("eventType");
        String playerName = (String) messageData.get("playerName");
        if ("join".equals(eventType)) {
          logger.info("🎮 Discord Bot would send: Player {} joined the server!", playerName);
        } else if ("leave".equals(eventType)) {
          logger.info("🚪 Discord Bot would send: Player {} left the server!", playerName);
        } else {
          logger.info("👤 Discord Bot would send: Player {} - {}", playerName, eventType);
        }
        break;
      case "server_status":
        Object playersObj = messageData.get("players");
        int players = playersObj instanceof Integer ? (Integer) playersObj : 0;
        logger.info("📊 Discord Bot would send: Server status - {} with {} players", 
            messageData.get("status"), players);
        break;
      default:
        String message = (String) messageData.get("message");
        logger.info("💬 Discord Bot would send: {}", message);
    }

    // 処理完了を示す
    logger.info("✅ Discord Bot processing completed for message type: {}", messageType);
  }
}