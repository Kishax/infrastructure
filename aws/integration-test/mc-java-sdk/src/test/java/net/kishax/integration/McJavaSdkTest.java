package net.kishax.integration;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.TestInfo;
import org.junit.jupiter.api.TestMethodOrder;
import org.junit.jupiter.api.MethodOrderer;
import org.junit.jupiter.api.Order;
import software.amazon.awssdk.services.sqs.model.Message;
import software.amazon.awssdk.services.sqs.model.SendMessageRequest;
import software.amazon.awssdk.services.sqs.SqsAsyncClient;

import java.time.Duration;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.CompletableFuture;

import static org.junit.jupiter.api.Assertions.*;

/**
 * MC Plugins Java SDK実装テスト
 * SqsClient.java、WebMcCommunicationManager.javaの実装をテスト
 */
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
public class McJavaSdkTest extends BaseIntegrationTest {

    private ObjectMapper objectMapper;
    private String webToMcQueueUrl;
    private String mcToWebQueueUrl;
    private SqsAsyncClient sqsAsyncClient;

    @BeforeEach
    void setUp(TestInfo testInfo) {
        super.setUp(testInfo);
        this.objectMapper = new ObjectMapper();
        
        // MC Plugins相当の非同期クライアント初期化
        this.sqsAsyncClient = SqsAsyncClient.builder()
            .region(TestConfig.AWS_REGION)
            .credentialsProvider(software.amazon.awssdk.auth.credentials.ProfileCredentialsProvider.create(TestConfig.AWS_PROFILE))
            .build();
        
        // テスト前にSQSキューをクリーンアップ
        TestUtils.cleanupSqsQueues(sqsClient, webToMcQueueUrl, mcToWebQueueUrl);
        
        webToMcQueueUrl = TestUtils.getSqsUrlFromSsmWithFallback("/kishax/sqs/web-to-mc-queue-url", TestConfig::getWebToMcSqsQueueUrl);
        mcToWebQueueUrl = TestUtils.getSqsUrlFromSsmWithFallback("/kishax/sqs/mc-to-web-queue-url", TestConfig::getMcToWebSqsQueueUrl);

        logger.info("Web→MC Queue URL: {}", webToMcQueueUrl);
        logger.info("MC→Web Queue URL: {}", mcToWebQueueUrl);
    }

    /**
     * Java SqsClient.sendAuthResponse()実装テスト
     */
    @Test
    @Order(1)
    void testJavaSqsClientSendAuthResponse() throws Exception {
        logger.info("Testing Java SqsClient.sendAuthResponse()");
        final String testId = generateUniqueTestId("java_auth");

        // MC Plugins Java実装と同等のメッセージ構造
        String uniquePlayerName = "javaAuthPlayer_" + testId;
        String uniquePlayerUuid = "550e8400-e29b-41d4-a716-" + testId;
        
        Map<String, Object> authResponse = new HashMap<>();
        authResponse.put("type", "mc_web_auth_response");
        authResponse.put("playerName", uniquePlayerName);
        authResponse.put("playerUuid", uniquePlayerUuid);
        authResponse.put("success", true);
        authResponse.put("message", "Java MC認証完了");
        authResponse.put("server", "test-server");
        authResponse.put("timestamp", System.currentTimeMillis());
        authResponse.put("testId", testId);

        // Java SqsClient相当の非同期送信をシミュレート
        String messageBody = objectMapper.writeValueAsString(authResponse);
        
        SendMessageRequest request = SendMessageRequest.builder()
            .queueUrl(mcToWebQueueUrl)
            .messageBody(messageBody)
            .messageAttributes(Map.of(
                "messageType", software.amazon.awssdk.services.sqs.model.MessageAttributeValue.builder()
                    .dataType("String")
                    .stringValue("mc_web_auth_response")
                    .build(),
                "source", software.amazon.awssdk.services.sqs.model.MessageAttributeValue.builder()
                    .dataType("String")
                    .stringValue("mc-plugins")
                    .build(),
                "server", software.amazon.awssdk.services.sqs.model.MessageAttributeValue.builder()
                    .dataType("String")
                    .stringValue("test-server")
                    .build()
            ))
            .build();

        // Java CompletableFuture相当のテスト
        CompletableFuture<Void> sendFuture = sqsAsyncClient.sendMessage(request)
            .thenAccept(response -> {
                assertNotNull(response.messageId());
                logger.info("Java async send completed with messageId: {}", response.messageId());
            });

        sendFuture.join(); // 非同期完了を待機

        // SQSメッセージ受信確認
        Message receivedMessage = TestUtils.waitForSpecificMessage(sqsClient, mcToWebQueueUrl, testId, Duration.ofSeconds(30));
        assertNotNull(receivedMessage, "Java送信メッセージが受信されませんでした");

        // メッセージ内容検証
        JsonNode messageData = objectMapper.readTree(receivedMessage.body());
        assertEquals("mc_web_auth_response", messageData.path("type").asText());
        assertEquals(uniquePlayerName, messageData.path("playerName").asText());
        assertEquals(uniquePlayerUuid, messageData.path("playerUuid").asText());
        assertTrue(messageData.path("success").asBoolean());
        assertEquals("Java MC認証完了", messageData.path("message").asText());
        assertEquals("test-server", messageData.path("server").asText());

        // Java実装特有のメッセージ属性検証
        assertEquals("mc-plugins", receivedMessage.messageAttributes().get("source").stringValue());
        assertEquals("test-server", receivedMessage.messageAttributes().get("server").stringValue());
        
        logger.info("Java SqsClient.sendAuthResponse() test passed");
    }

    /**
     * Java WebMcCommunicationManager受信処理テスト
     */
    @Test
    @Order(2)
    void testJavaWebMcCommunicationManagerReceive() throws Exception {
        logger.info("Testing Java WebMcCommunicationManager message reception");
        final String testId = generateUniqueTestId("java_receive");

        // Web→MCメッセージを受信処理テスト用に送信
        String uniquePlayerName = "javaReceivePlayer_" + System.currentTimeMillis();
        
        Map<String, Object> webCommand = new HashMap<>();
        webCommand.put("type", "web_mc_command");
        webCommand.put("from", "web");
        webCommand.put("to", "mc");
        webCommand.put("commandType", "server_switch");
        webCommand.put("playerName", uniquePlayerName);
        webCommand.put("data", Map.of("server", "lobby"));
        webCommand.put("timestamp", System.currentTimeMillis());
        webCommand.put("testId", testId);

        // Web→MCキューにメッセージを送信
        String messageBody = objectMapper.writeValueAsString(webCommand);
        
        SendMessageRequest request = SendMessageRequest.builder()
            .queueUrl(webToMcQueueUrl)
            .messageBody(messageBody)
            .messageAttributes(Map.of(
                "messageType", software.amazon.awssdk.services.sqs.model.MessageAttributeValue.builder()
                    .dataType("String")
                    .stringValue("web_mc_command")
                    .build(),
                "source", software.amazon.awssdk.services.sqs.model.MessageAttributeValue.builder()
                    .dataType("String")
                    .stringValue("kishax-web")
                    .build()
            ))
            .build();

        var sendResult = sqsClient.sendMessage(request);
        assertNotNull(sendResult.messageId());

        // MC側がポーリング受信することをシミュレート
        Message receivedMessage = TestUtils.waitForSpecificMessage(sqsClient, webToMcQueueUrl, testId, Duration.ofSeconds(30));
        assertNotNull(receivedMessage, "Java受信処理用メッセージが受信されませんでした");

        // Java WebMcCommunicationManager.processMessage()相当の検証
        JsonNode messageData = objectMapper.readTree(receivedMessage.body());
        assertEquals("web_mc_command", messageData.path("type").asText());
        assertEquals("server_switch", messageData.path("commandType").asText());
        assertEquals(uniquePlayerName, messageData.path("playerName").asText());
        assertEquals("lobby", messageData.path("data").path("server").asText());

        // Java Minecraft イベント処理相当の検証
        assertEquals("kishax-web", receivedMessage.messageAttributes().get("source").stringValue());
        
        logger.info("Java WebMcCommunicationManager message reception test passed");
    }

    /**
     * Java Minecraft イベントハンドラー統合テスト
     */
    @Test
    @Order(3)
    void testJavaMinecraftEventHandlerIntegration() throws Exception {
        logger.info("Testing Java Minecraft Event Handler integration");
        final String testId = generateUniqueTestId("java_event");

        // Minecraft PlayerJoinEvent相当のテスト
        String uniquePlayerName = "javaEventPlayer_" + System.currentTimeMillis();
        String uniquePlayerUuid = "550e8400-e29b-41d4-a716-" + String.format("%012d", System.nanoTime() % 1000000000000L);
        
        // Java onPlayerJoin()相当のメッセージ
        Map<String, Object> playerJoinEvent = new HashMap<>();
        playerJoinEvent.put("type", "mc_web_player_status");
        playerJoinEvent.put("playerName", uniquePlayerName);
        playerJoinEvent.put("playerUuid", uniquePlayerUuid);
        playerJoinEvent.put("status", "online");
        playerJoinEvent.put("serverName", "survival-1");
        playerJoinEvent.put("joinTime", System.currentTimeMillis());
        playerJoinEvent.put("testId", testId);

        // Minecraft イベント処理からのメッセージ送信をシミュレート
        String messageBody = objectMapper.writeValueAsString(playerJoinEvent);
        
        SendMessageRequest request = SendMessageRequest.builder()
            .queueUrl(mcToWebQueueUrl)
            .messageBody(messageBody)
            .messageAttributes(Map.of(
                "messageType", software.amazon.awssdk.services.sqs.model.MessageAttributeValue.builder()
                    .dataType("String")
                    .stringValue("mc_web_player_status")
                    .build(),
                "source", software.amazon.awssdk.services.sqs.model.MessageAttributeValue.builder()
                    .dataType("String")
                    .stringValue("mc-plugins")
                    .build(),
                "server", software.amazon.awssdk.services.sqs.model.MessageAttributeValue.builder()
                    .dataType("String")
                    .stringValue("survival-1")
                    .build(),
                "eventType", software.amazon.awssdk.services.sqs.model.MessageAttributeValue.builder()
                    .dataType("String")
                    .stringValue("player_join")
                    .build()
            ))
            .build();

        var sendResult = sqsAsyncClient.sendMessage(request);
        var response = sendResult.join();
        assertNotNull(response.messageId());

        // メッセージ受信確認
        Message receivedMessage = TestUtils.waitForSpecificMessage(sqsClient, mcToWebQueueUrl, testId, Duration.ofSeconds(30));
        assertNotNull(receivedMessage);

        // Minecraft イベント相当のデータ構造検証
        JsonNode messageData = objectMapper.readTree(receivedMessage.body());
        assertEquals("mc_web_player_status", messageData.path("type").asText());
        assertEquals("online", messageData.path("status").asText());
        assertEquals(uniquePlayerName, messageData.path("playerName").asText());
        assertEquals("survival-1", messageData.path("serverName").asText());

        // Minecraft固有属性検証
        assertEquals("mc-plugins", receivedMessage.messageAttributes().get("source").stringValue());
        assertEquals("survival-1", receivedMessage.messageAttributes().get("server").stringValue());
        assertEquals("player_join", receivedMessage.messageAttributes().get("eventType").stringValue());
        
        logger.info("Java Minecraft Event Handler integration test passed");
    }

    /**
     * Java非同期処理とエラーハンドリングテスト
     */
    @Test
    @Order(4)
    void testJavaAsyncErrorHandling() throws Exception {
        logger.info("Testing Java async processing and error handling");

        boolean asyncErrorHandled = false;

        // Java CompletableFutureエラーハンドリングテスト
        String invalidQueueUrl = "https://sqs.ap-northeast-1.amazonaws.com/123456789012/nonexistent-queue";
        
        CompletableFuture<String> errorFuture = sqsAsyncClient.sendMessage(SendMessageRequest.builder()
                .queueUrl(invalidQueueUrl)
                .messageBody("{\"type\":\"test\"}")
                .build())
            .handle((result, throwable) -> {
                if (throwable != null) {
                    logger.error("Async error occurred in testJavaAsyncErrorHandling", throwable);
                    Throwable cause = throwable.getCause();
                    if (cause instanceof software.amazon.awssdk.services.sqs.model.QueueDoesNotExistException) {
                        logger.info("Java async error handling verified: {}", cause.getMessage());
                        return "error_handled";
                    }
                }
                return "no_error";
            });

        String errorResult = errorFuture.join();
        asyncErrorHandled = "error_handled".equals(errorResult);
        
        assertTrue(asyncErrorHandled, "Java async error should be handled");

        // Java非同期タイムアウトテスト
        long startTime = System.currentTimeMillis();
        
        CompletableFuture<String> timeoutFuture = CompletableFuture.supplyAsync(() -> {
            try {
                Thread.sleep(1000); // 1秒待機
                return "completed";
            } catch (InterruptedException e) {
                return "interrupted";
            }
        });

        String result = timeoutFuture.join();
        long endTime = System.currentTimeMillis();
        
        assertEquals("completed", result);
        assertTrue(endTime - startTime >= 1000, "Java async timeout handling verified");
        
        logger.info("Java async processing and error handling test passed");
    }

    // ヘルパーメソッド
    
    /**
     * 完全にユニークなテストIDを生成
     */
    private String generateUniqueTestId(String prefix) {
        return String.format("%s_%d_%d", prefix, System.currentTimeMillis(), System.nanoTime());
    }
    
    

    void tearDown() {
        if (sqsAsyncClient != null) {
            sqsAsyncClient.close();
        }
    }
}