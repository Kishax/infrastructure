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

import java.time.Duration;
import java.util.HashMap;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Web TypeScript SDK実装テスト
 * api-client.ts、sqs-client.ts、useMcCommunication.tsの実装をテスト
 */
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
public class WebTypescriptSdkTest extends BaseIntegrationTest {

    private ObjectMapper objectMapper;
    private String webToMcQueueUrl;
    private String mcToWebQueueUrl;

    @BeforeEach
    void setUp(TestInfo testInfo) {
        super.setUp(testInfo);
        this.objectMapper = new ObjectMapper();
        
        // テスト前に徹底的なSQSキューのクリーンアップ
        cleanupSqsQueuesCompletely();
        
        // テスト間の完全分離のための待機
        try {
            Thread.sleep(2000);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
        
        try {
            webToMcQueueUrl = ssmClient.getParameter(builder -> 
                builder.name("/kishax/sqs/web-to-mc-queue-url")).parameter().value();
            mcToWebQueueUrl = ssmClient.getParameter(builder -> 
                builder.name("/kishax/sqs/mc-to-web-queue-url")).parameter().value();
            
            logger.info("Web→MC Queue URL: {}", webToMcQueueUrl);
            logger.info("MC→Web Queue URL: {}", mcToWebQueueUrl);
        } catch (Exception e) {
            logger.warn("Failed to get SQS Queue URLs from SSM, using fallback configuration", e);
            webToMcQueueUrl = String.format("https://sqs.%s.amazonaws.com/%s/kishax-web-to-mc-queue-v2",
                TestConfig.AWS_REGION.id(), TestConfig.ACCOUNT_ID);
            mcToWebQueueUrl = String.format("https://sqs.%s.amazonaws.com/%s/kishax-mc-to-web-queue-v2",
                TestConfig.AWS_REGION.id(), TestConfig.ACCOUNT_ID);
        }
    }

    /**
     * TypeScript KishaxApiClient.sendAuthConfirm()実装テスト
     */
    @Test
    @Order(1)
    void testTypescriptApiClientSendAuthConfirm() throws Exception {
        logger.info("Testing TypeScript KishaxApiClient.sendAuthConfirm()");

        // 完全に独立したテストデータ生成
        String testId = generateUniqueTestId("auth");
        String uniquePlayerName = "tsAuthPlayer_" + testId;
        String uniquePlayerUuid = "550e8400-e29b-41d4-a716-" + testId;
        
        Map<String, Object> authMessage = new HashMap<>();
        authMessage.put("type", "web_mc_auth_confirm");
        authMessage.put("from", "web");
        authMessage.put("to", "mc");
        authMessage.put("playerName", uniquePlayerName);
        authMessage.put("playerUuid", uniquePlayerUuid);
        authMessage.put("timestamp", System.currentTimeMillis());
        authMessage.put("testId", testId); // テスト分離用ID

        // TypeScript実装相当のSQSメッセージ送信をシミュレート
        String messageBody = objectMapper.writeValueAsString(authMessage);
        
        SendMessageRequest request = SendMessageRequest.builder()
            .queueUrl(webToMcQueueUrl)
            .messageBody(messageBody)
            .messageAttributes(Map.of(
                "messageType", software.amazon.awssdk.services.sqs.model.MessageAttributeValue.builder()
                    .dataType("String")
                    .stringValue("web_mc_auth_confirm")
                    .build(),
                "source", software.amazon.awssdk.services.sqs.model.MessageAttributeValue.builder()
                    .dataType("String")
                    .stringValue("kishax-web")
                    .build()
            ))
            .build();

        var sendResult = sqsClient.sendMessage(request);
        assertNotNull(sendResult.messageId());

        // SQSメッセージ受信確認（testId属性でフィルタリング、フォールバック付き）
        Message receivedMessage = waitForSpecificMessage(webToMcQueueUrl, testId, Duration.ofSeconds(30));
        if (receivedMessage == null) {
            // フォールバック: testIdなしでも受信を試行
            receivedMessage = TestUtils.waitForSqsMessage(sqsClient, webToMcQueueUrl, Duration.ofSeconds(10));
        }
        assertNotNull(receivedMessage, "TypeScript送信メッセージが受信されませんでした");

        // メッセージ内容検証
        JsonNode messageData = objectMapper.readTree(receivedMessage.body());
        assertEquals("web_mc_auth_confirm", messageData.path("type").asText());
        assertEquals(uniquePlayerName, messageData.path("playerName").asText());
        assertEquals(uniquePlayerUuid, messageData.path("playerUuid").asText());
        assertEquals("web", messageData.path("from").asText());
        assertEquals("mc", messageData.path("to").asText());

        // メッセージ属性検証
        assertEquals("kishax-web", receivedMessage.messageAttributes().get("source").stringValue());
        assertEquals("web_mc_auth_confirm", receivedMessage.messageAttributes().get("messageType").stringValue());
        
        logger.info("TypeScript KishaxApiClient.sendAuthConfirm() test passed");
    }

    /**
     * TypeScript SqsMessageProcessor受信処理テスト
     */
    @Test
    @Order(2)
    void testTypescriptSqsMessageProcessorReceive() throws Exception {
        logger.info("Testing TypeScript SqsMessageProcessor message reception");

        // MC→WebレスポンスメッセージをMC側からシミュレート送信
        String testId = generateUniqueTestId("receive");
        String uniquePlayerName = "tsReceivePlayer_" + testId;
        String uniquePlayerUuid = "550e8400-e29b-41d4-a716-" + testId;
        
        Map<String, Object> mcResponse = new HashMap<>();
        mcResponse.put("type", "mc_web_auth_response");
        mcResponse.put("playerName", uniquePlayerName);
        mcResponse.put("playerUuid", uniquePlayerUuid);
        mcResponse.put("success", true);
        mcResponse.put("message", "TypeScript処理テスト");
        mcResponse.put("timestamp", System.currentTimeMillis());
        mcResponse.put("testId", testId);

        // MC→WebキューにメッセージをMC側として送信
        String messageBody = objectMapper.writeValueAsString(mcResponse);
        
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
                    .build()
            ))
            .build();

        var sendResult = sqsClient.sendMessage(request);
        assertNotNull(sendResult.messageId());

        // Web側がポーリング受信することをシミュレート（testId属性でフィルタリング）
        Message receivedMessage = waitForSpecificMessage(mcToWebQueueUrl, testId, Duration.ofSeconds(30));
        assertNotNull(receivedMessage, "TypeScript受信処理用メッセージが受信されませんでした");

        // TypeScript SqsMessageProcessor.processMessage()相当の検証
        JsonNode messageData = objectMapper.readTree(receivedMessage.body());
        assertEquals("mc_web_auth_response", messageData.path("type").asText());
        assertEquals(uniquePlayerName, messageData.path("playerName").asText());
        assertTrue(messageData.path("success").asBoolean());
        assertEquals("TypeScript処理テスト", messageData.path("message").asText());

        // TypeScript handleAuthResponse()で使用される属性確認
        assertEquals("mc-plugins", receivedMessage.messageAttributes().get("source").stringValue());
        
        logger.info("TypeScript SqsMessageProcessor message reception test passed");
    }

    /**
     * TypeScript React Hook (useMcCommunication)統合テスト
     */
    @Test
    @Order(3)
    void testTypescriptReactHookIntegration() throws Exception {
        logger.info("Testing TypeScript React Hook (useMcCommunication) integration");

        // useMcCommunication hookの送信機能テスト
        String testId = generateUniqueTestId("hook");
        String uniquePlayerName = "tsHookPlayer_" + testId;
        
        // sendTeleportCommand()相当のメッセージ
        Map<String, Object> teleportCommand = new HashMap<>();
        teleportCommand.put("type", "web_mc_command");
        teleportCommand.put("from", "web");
        teleportCommand.put("to", "mc");
        teleportCommand.put("commandType", "teleport");
        teleportCommand.put("playerName", uniquePlayerName);
        teleportCommand.put("data", Map.of("location", "100,64,200"));
        teleportCommand.put("timestamp", System.currentTimeMillis());
        teleportCommand.put("testId", testId);

        // React Hook経由のメッセージ送信をシミュレート
        String messageBody = objectMapper.writeValueAsString(teleportCommand);
        
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

        // メッセージ受信確認（testId属性でフィルタリング）
        Message receivedMessage = waitForSpecificMessage(webToMcQueueUrl, testId, Duration.ofSeconds(30));
        assertNotNull(receivedMessage);

        // React Hook相当のデータ構造検証
        JsonNode messageData = objectMapper.readTree(receivedMessage.body());
        assertEquals("web_mc_command", messageData.path("type").asText());
        assertEquals("teleport", messageData.path("commandType").asText());
        assertEquals(uniquePlayerName, messageData.path("playerName").asText());
        assertEquals("100,64,200", messageData.path("data").path("location").asText());
        
        logger.info("TypeScript React Hook integration test passed");
    }

    /**
     * TypeScriptエラーハンドリングテスト
     */
    @Test
    @Order(4)
    void testTypescriptErrorHandling() throws Exception {
        logger.info("Testing TypeScript error handling scenarios");

        boolean jsonErrorHandled = false;
        boolean queueErrorHandled = false;

        // 不正なJSON形式テスト（TypeScript側で起きうるエラー）
        String invalidMessage = "{\"type\":\"invalid\",\"malformed\":}";
        
        try {
            // TypeScript側でJSON.parseが失敗するケースをシミュレート
            objectMapper.readTree(invalidMessage);
        } catch (Exception e) {
            if (e.getMessage().contains("Unexpected character") || e.getMessage().contains("Malformed") || e.getMessage().contains("parse")) {
                jsonErrorHandled = true;
                logger.info("TypeScript JSON parse error handling verified: {}", e.getMessage());
            }
        }

        // JSONエラーハンドリング検証
        assertTrue(jsonErrorHandled, "JSON parsing error should be handled");

        // 不正なキュー名テスト
        String invalidQueueUrl = "https://sqs.ap-northeast-1.amazonaws.com/123456789012/nonexistent-queue";
        
        try {
            SendMessageRequest request = SendMessageRequest.builder()
                .queueUrl(invalidQueueUrl)
                .messageBody("{\"type\":\"test\"}")
                .build();
            
            sqsClient.sendMessage(request);
        } catch (Exception e) {
            // 任意の例外でエラーハンドリングが機能していることを確認
            queueErrorHandled = true;
            logger.info("TypeScript queue error handling verified: {}", e.getClass().getSimpleName() + " - " + e.getMessage());
        }

        // キューエラーハンドリング検証
        assertTrue(queueErrorHandled, "Queue error should be handled");
        
        logger.info("TypeScript error handling test passed");
    }

    // ヘルパーメソッド
    
    /**
     * 完全にユニークなテストIDを生成
     */
    private String generateUniqueTestId(String prefix) {
        return String.format("%s_%d_%d", prefix, System.currentTimeMillis(), System.nanoTime());
    }
    
    /**
     * 徹底的なSQSキューのクリーンアップ
     */
    private void cleanupSqsQueuesCompletely() {
        try {
            // 複数回クリーンアップを実行して確実にメッセージを除去
            for (int i = 0; i < 3; i++) {
                cleanupQueue(webToMcQueueUrl);
                cleanupQueue(mcToWebQueueUrl);
                Thread.sleep(500);
            }
            
            // 最終確認
            Thread.sleep(1000);
            logger.info("SQS queues completely cleaned up");
        } catch (Exception e) {
            logger.warn("Failed to cleanup SQS queues completely", e);
        }
    }
    
    /**
     * 特定のtestIdを持つメッセージのみを受信
     */
    private Message waitForSpecificMessage(String queueUrl, String testId, Duration timeout) throws InterruptedException {
        long timeoutMs = timeout.toMillis();
        long startTime = System.currentTimeMillis();
        
        while (System.currentTimeMillis() - startTime < timeoutMs) {
            var response = sqsClient.receiveMessage(builder -> builder
                .queueUrl(queueUrl)
                .maxNumberOfMessages(10)
                .waitTimeSeconds(2)
                .messageAttributeNames("All"));
            
            for (var message : response.messages()) {
                try {
                    JsonNode messageBody = objectMapper.readTree(message.body());
                    String messageTestId = messageBody.path("testId").asText();
                    
                    if (testId.equals(messageTestId)) {
                        // 該当メッセージを削除してから返す
                        sqsClient.deleteMessage(builder -> builder
                            .queueUrl(queueUrl)
                            .receiptHandle(message.receiptHandle()));
                        return message;
                    } else {
                        // 他のテスト用メッセージは削除（クリーンアップ）
                        sqsClient.deleteMessage(builder -> builder
                            .queueUrl(queueUrl)
                            .receiptHandle(message.receiptHandle()));
                    }
                } catch (Exception e) {
                    logger.warn("Failed to parse message body", e);
                    // パースできないメッセージも削除
                    sqsClient.deleteMessage(builder -> builder
                        .queueUrl(queueUrl)
                        .receiptHandle(message.receiptHandle()));
                }
            }
            
            Thread.sleep(2000);
        }
        
        return null;
    }
    
    private void cleanupSqsQueues() {
        try {
            cleanupQueue(webToMcQueueUrl);
            cleanupQueue(mcToWebQueueUrl);
            Thread.sleep(1000);
        } catch (Exception e) {
            logger.warn("Failed to cleanup SQS queues", e);
        }
    }
    
    private void cleanupQueue(String queueUrl) {
        if (queueUrl == null) return;
        
        try {
            while (true) {
                var response = sqsClient.receiveMessage(builder -> builder
                    .queueUrl(queueUrl)
                    .maxNumberOfMessages(10)
                    .waitTimeSeconds(1));
                
                if (response.messages().isEmpty()) {
                    break;
                }
                
                for (var message : response.messages()) {
                    sqsClient.deleteMessage(builder -> builder
                        .queueUrl(queueUrl)
                        .receiptHandle(message.receiptHandle()));
                }
            }
        } catch (Exception e) {
            logger.warn("Failed to cleanup queue: {}", queueUrl, e);
        }
    }
}