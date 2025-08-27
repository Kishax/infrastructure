package net.kishax.integration;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.TestInfo;
import software.amazon.awssdk.services.sqs.model.Message;
import software.amazon.awssdk.services.sqs.model.ReceiveMessageRequest;

import java.time.Duration;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

import static org.junit.jupiter.api.Assertions.*;

/**
 * MC認証フローのエンドツーエンドテスト
 */
public class McAuthEndToEndTest extends BaseIntegrationTest {

    private ObjectMapper objectMapper;
    private String webToMcQueueUrl;
    private String mcToWebQueueUrl;
    private String testPlayerName;
    private String testPlayerUuid;

    @BeforeEach
    void setUp(TestInfo testInfo) {
        super.setUp(testInfo);
        this.objectMapper = new ObjectMapper();
        
        // テスト用プレイヤー情報生成
        this.testPlayerName = "e2eTestPlayer_" + System.currentTimeMillis();
        this.testPlayerUuid = UUID.randomUUID().toString();
        
        // SQSキューURL取得
        webToMcQueueUrl = TestUtils.getSqsUrlFromSsmWithFallback("/kishax/sqs/web-to-mc-queue-url", TestConfig::getWebToMcSqsQueueUrl);
        mcToWebQueueUrl = TestUtils.getSqsUrlFromSsmWithFallback("/kishax/sqs/mc-to-web-queue-url", TestConfig::getMcToWebSqsQueueUrl);
        
        logger.info("Test Player: {} ({})", testPlayerName, testPlayerUuid);
    }

    /**
     * 完全なMC認証フローテスト
     * 1. Web→MC: 認証確認リクエスト
     * 2. MC→Web: 認証完了レスポンス
     * 3. 双方向でメッセージが正常に処理されることを確認
     */
    @Test
    void testCompleteAuthenticationFlow() throws Exception {
        logger.info("Starting complete MC authentication flow test");
        final String testId = UUID.randomUUID().toString();

        // フェーズ1: Web→MC認証確認
        logger.info("Phase 1: Web→MC authentication confirmation");
        
        Map<String, Object> authRequest = createAuthRequest(testId);
        sendWebToMcMessage(authRequest);
        
        // MC側でメッセージが受信されることを確認
        Message mcReceivedMessage = TestUtils.waitForSpecificMessage(sqsClient, webToMcQueueUrl, testId, Duration.ofSeconds(30));
        assertNotNull(mcReceivedMessage, "MC側で認証リクエストが受信されませんでした");
        
        // メッセージ内容検証
        JsonNode mcMessageBody = objectMapper.readTree(mcReceivedMessage.body());
        assertEquals("web_mc_auth_confirm", mcMessageBody.path("type").asText());
        assertEquals(testPlayerName, mcMessageBody.path("playerName").asText());
        assertEquals(testPlayerUuid, mcMessageBody.path("playerUuid").asText());
        assertEquals("kishax-web", mcReceivedMessage.messageAttributes().get("source").stringValue());
        
        logger.info("✓ MC側で認証リクエストを正常に受信");

        // フェーズ2: MC→Web認証レスポンス（成功）
        logger.info("Phase 2: MC→Web authentication response (success)");
        
        Map<String, Object> authResponse = createAuthResponse(true, "認証が正常に完了しました", testId);
        sendMcToWebMessage(authResponse);
        
        // Web側でレスポンスが受信されることを確認
        Message webReceivedMessage = TestUtils.waitForSpecificMessage(sqsClient, mcToWebQueueUrl, testId, Duration.ofSeconds(30));
        assertNotNull(webReceivedMessage, "Web側で認証レスポンスが受信されませんでした");
        
        // レスポンス内容検証
        JsonNode webMessageBody = objectMapper.readTree(webReceivedMessage.body());
        assertEquals("mc_web_auth_response", webMessageBody.path("type").asText());
        assertEquals(testPlayerName, webMessageBody.path("playerName").asText());
        assertEquals(testPlayerUuid, webMessageBody.path("playerUuid").asText());
        assertTrue(webMessageBody.path("success").asBoolean());
        assertEquals("認証が正常に完了しました", webMessageBody.path("message").asText());
        assertEquals("mc-plugins", webReceivedMessage.messageAttributes().get("source").stringValue());
        
        logger.info("✓ Web側で認証レスポンスを正常に受信");

        // フェーズ3: データ整合性確認
        logger.info("Phase 3: Data consistency verification");
        
        // 同一プレイヤーのリクエストとレスポンスが対応していることを確認
        String requestPlayerUuid = mcMessageBody.path("playerUuid").asText();
        String responsePlayerUuid = webMessageBody.path("playerUuid").asText();
        assertEquals(requestPlayerUuid, responsePlayerUuid, "リクエストとレスポンスのプレイヤーUUIDが一致しません");
        
        // タイムスタンプの妥当性確認
        long requestTimestamp = mcMessageBody.path("timestamp").asLong();
        long responseTimestamp = webMessageBody.path("timestamp").asLong();
        assertTrue(responseTimestamp > requestTimestamp, "レスポンスのタイムスタンプがリクエストより古いです");
        
        long timeDiff = responseTimestamp - requestTimestamp;
        assertTrue(timeDiff < 60000, "認証レスポンスまでの時間が長すぎます: " + timeDiff + "ms");
        
        logger.info("✓ データ整合性確認完了 (応答時間: {}ms)", timeDiff);
        logger.info("Complete MC authentication flow test passed");
    }

    /**
     * 認証失敗ケースのテスト
     */
    @Test
    void testAuthenticationFailureFlow() throws Exception {
        logger.info("Starting authentication failure flow test");
        final String testId = UUID.randomUUID().toString();

        // 認証リクエスト送信
        Map<String, Object> authRequest = createAuthRequest(testId);
        sendWebToMcMessage(authRequest);
        
        Message mcReceivedMessage = TestUtils.waitForSpecificMessage(sqsClient, webToMcQueueUrl, testId, Duration.ofSeconds(30));
        assertNotNull(mcReceivedMessage);
        
        // 認証失敗レスポンス送信
        Map<String, Object> authResponse = createAuthResponse(false, "認証に失敗しました: パスワードが一致しません", testId);
        sendMcToWebMessage(authResponse);
        
        Message webReceivedMessage = TestUtils.waitForSpecificMessage(sqsClient, mcToWebQueueUrl, testId, Duration.ofSeconds(30));
        assertNotNull(webReceivedMessage);
        
        // 失敗レスポンス内容検証
        JsonNode responseBody = objectMapper.readTree(webReceivedMessage.body());
        assertFalse(responseBody.path("success").asBoolean());
        assertTrue(responseBody.path("message").asText().contains("認証に失敗"));
        
        logger.info("Authentication failure flow test passed");
    }

    /**
     * タイムアウトケースのテスト
     */
    @Test
    void testAuthenticationTimeoutHandling() throws Exception {
        logger.info("Starting authentication timeout handling test");
        final String testId = UUID.randomUUID().toString();

        // 認証リクエスト送信
        Map<String, Object> authRequest = createAuthRequest(testId);
        sendWebToMcMessage(authRequest);
        
        Message mcReceivedMessage = TestUtils.waitForSpecificMessage(sqsClient, webToMcQueueUrl, testId, Duration.ofSeconds(30));
        assertNotNull(mcReceivedMessage);
        
        // タイムアウトシミュレーション（レスポンス無し状態を維持）
        logger.info("Simulating timeout scenario (no response)");
        
        // 一定時間待機してタイムアウトレスポンスが送信されるかテスト
        // 実際の実装では、MC側でタイムアウトを検知してレスポンスを送信すべき
        Thread.sleep(5000); // 5秒待機
        
        // タイムアウトレスポンス送信（MC側のタイムアウトハンドラーをシミュレート）
        Map<String, Object> timeoutResponse = createAuthResponse(false, "認証がタイムアウトしました", testId);
        sendMcToWebMessage(timeoutResponse);
        
        Message timeoutMessage = TestUtils.waitForSpecificMessage(sqsClient, mcToWebQueueUrl, testId, Duration.ofSeconds(30));
        assertNotNull(timeoutMessage);
        
        JsonNode timeoutBody = objectMapper.readTree(timeoutMessage.body());
        assertFalse(timeoutBody.path("success").asBoolean());
        assertTrue(timeoutBody.path("message").asText().contains("タイムアウト"));
        
        logger.info("Authentication timeout handling test passed");
    }

    /**
     * 並行認証リクエストテスト
     */
    @Test
    void testConcurrentAuthenticationRequests() throws Exception {
        logger.info("Starting concurrent authentication requests test");

        int concurrentRequests = 3;
        CountDownLatch latch = new CountDownLatch(concurrentRequests);
        java.util.List<String> testIds = new java.util.concurrent.CopyOnWriteArrayList<>();
        
        // 複数の認証リクエストを並行送信
        for (int i = 0; i < concurrentRequests; i++) {
            String playerName = "concurrentPlayer" + i;
            String playerUuid = UUID.randomUUID().toString();
            String testId = UUID.randomUUID().toString();
            testIds.add(testId);
            
            new Thread(() -> {
                try {
                    Map<String, Object> request = createAuthRequest(playerName, playerUuid, testId);
                    sendWebToMcMessage(request);
                    
                    // 対応するレスポンス送信
                    Thread.sleep(1000); // 少し待機
                    Map<String, Object> response = createAuthResponse(playerName, playerUuid, true, "並行認証完了", testId);
                    sendMcToWebMessage(response);
                    
                } catch (Exception e) {
                    logger.error("Concurrent test error", e);
                } finally {
                    latch.countDown();
                }
            }).start();
        }
        
        // すべてのスレッドが完了するまで待機
        assertTrue(latch.await(60, TimeUnit.SECONDS), "並行認証リクエストがタイムアウトしました");
        
        // 少し待ってからすべてのメッセージを一括受信
        Thread.sleep(2000);
        java.util.List<Message> allMessages = TestUtils.receiveAllMessages(sqsClient, mcToWebQueueUrl, Duration.ofSeconds(10));
        java.util.Set<String> receivedTestIds = new java.util.HashSet<>();
        for (Message message : allMessages) {
            try {
                JsonNode body = objectMapper.readTree(message.body());
                if (body.has("testId")) {
                    receivedTestIds.add(body.get("testId").asText());
                }
            } catch (Exception e) {
                logger.warn("Error parsing message in concurrent test", e);
            }
        }

        // すべてのtestIdが受信されたか確認
        for (String sentTestId : testIds) {
            assertTrue(receivedTestIds.contains(sentTestId), "並行認証レスポンス " + sentTestId + " が受信されませんでした");
        }
        
        logger.info("Concurrent authentication requests test passed");
    }

    // ヘルパーメソッド

    private Map<String, Object> createAuthRequest() {
        return createAuthRequest(testPlayerName, testPlayerUuid);
    }

    private Map<String, Object> createAuthRequest(String playerName, String playerUuid, String testId) {
        Map<String, Object> request = new HashMap<>();
        request.put("type", "web_mc_auth_confirm");
        request.put("playerName", playerName);
        request.put("playerUuid", playerUuid);
        request.put("timestamp", System.currentTimeMillis());
        if (testId != null) {
            request.put("testId", testId);
        }
        return request;
    }

    private Map<String, Object> createAuthRequest(String playerName, String playerUuid) {
        return createAuthRequest(playerName, playerUuid, null);
    }

    private Map<String, Object> createAuthResponse(boolean success, String message) {
        return createAuthResponse(testPlayerName, testPlayerUuid, success, message);
    }

    private Map<String, Object> createAuthResponse(String playerName, String playerUuid, boolean success, String message, String testId) {
        Map<String, Object> response = new HashMap<>();
        response.put("type", "mc_web_auth_response");
        response.put("playerName", playerName);
        response.put("playerUuid", playerUuid);
        response.put("success", success);
        response.put("message", message);
        response.put("timestamp", System.currentTimeMillis());
        if (testId != null) {
            response.put("testId", testId);
        }
        return response;
    }

    private Map<String, Object> createAuthResponse(String playerName, String playerUuid, boolean success, String message) {
        return createAuthResponse(playerName, playerUuid, success, message, null);
    }

    private void sendWebToMcMessage(Map<String, Object> message) throws Exception {
        TestUtils.sendApiGatewayMessage(apiGatewayClient, TestConfig.API_GATEWAY_ID, "web-to-mc", message);
    }

    private void sendMcToWebMessage(Map<String, Object> message) throws Exception {
        TestUtils.sendApiGatewayMessage(apiGatewayClient, TestConfig.API_GATEWAY_ID, "mc-to-web", message);
    }

    private Message waitForSqsMessage(String queueUrl, Duration timeout) throws InterruptedException {
        return TestUtils.waitForSqsMessage(sqsClient, queueUrl, timeout);
    }

    private Map<String, Object> createAuthRequest(String testId) {
        Map<String, Object> request = createAuthRequest(testPlayerName, testPlayerUuid);
        request.put("testId", testId);
        return request;
    }

    private Map<String, Object> createAuthResponse(boolean success, String message, String testId) {
        Map<String, Object> response = createAuthResponse(testPlayerName, testPlayerUuid, success, message);
        response.put("testId", testId);
        return response;
    }
}