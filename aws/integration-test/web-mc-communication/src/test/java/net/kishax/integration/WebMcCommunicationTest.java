package net.kishax.integration;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.TestInfo;
import software.amazon.awssdk.core.SdkBytes;
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
public class WebMcCommunicationTest extends BaseIntegrationTest {

    private ObjectMapper objectMapper;
    private String webToMcQueueUrl;
    private String mcToWebQueueUrl;

    @BeforeEach
    void setUp(TestInfo testInfo) {
        super.setUp(testInfo);
        this.objectMapper = new ObjectMapper();
        
        // 新しいSQSキューのURL設定
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
     * Web→MC認証確認メッセージ送信テスト
     */
    @Test
    void testWebToMcAuthConfirmation() throws Exception {
        logger.info("Testing Web→MC Auth Confirmation");

        // テスト用認証確認メッセージ
        Map<String, Object> authMessage = new HashMap<>();
        authMessage.put("type", "web_mc_auth_confirm");
        authMessage.put("playerName", "testPlayer");
        authMessage.put("playerUuid", "550e8400-e29b-41d4-a716-446655440000");
        authMessage.put("timestamp", System.currentTimeMillis());

        // API Gateway経由でメッセージ送信
        String requestBody = objectMapper.writeValueAsString(authMessage);
        
        TestInvokeMethodRequest apiRequest = TestInvokeMethodRequest.builder()
            .restApiId(TestConfig.API_GATEWAY_ID)
            .resourceId(getResourceId("web-to-mc"))
            .httpMethod("POST")
            .pathWithQueryString("/web-to-mc")
            .body(requestBody)
            .headers(Map.of(
                "Content-Type", "application/json",
                "Authorization", generateAuthHeader("POST", "/web-to-mc", requestBody)
            ))
            .build();

        TestInvokeMethodResponse apiResponse = apiGatewayClient.testInvokeMethod(apiRequest);
        
        // API Gatewayレスポンス検証
        assertEquals(200, apiResponse.status().intValue());
        assertNotNull(apiResponse.body());
        
        JsonNode responseBody = objectMapper.readTree(apiResponse.body());
        assertTrue(responseBody.path("success").asBoolean());

        // SQSメッセージ受信確認
        Message receivedMessage = waitForSqsMessage(webToMcQueueUrl, Duration.ofSeconds(30));
        assertNotNull(receivedMessage, "SQSメッセージが受信されませんでした");

        // メッセージ内容検証
        JsonNode messageBody = objectMapper.readTree(receivedMessage.body());
        assertEquals("web_mc_auth_confirm", messageBody.path("type").asText());
        assertEquals("testPlayer", messageBody.path("playerName").asText());
        assertEquals("550e8400-e29b-41d4-a716-446655440000", messageBody.path("playerUuid").asText());

        // メッセージ属性検証
        assertEquals("kishax-web", receivedMessage.messageAttributes().get("source").stringValue());
        
        logger.info("Web→MC Auth Confirmation test passed");
    }

    /**
     * MC→Web認証レスポンステスト
     */
    @Test
    void testMcToWebAuthResponse() throws Exception {
        logger.info("Testing MC→Web Auth Response");

        // テスト用認証レスポンスメッセージ
        Map<String, Object> authResponse = new HashMap<>();
        authResponse.put("type", "mc_web_auth_response");
        authResponse.put("playerName", "testPlayer");
        authResponse.put("playerUuid", "550e8400-e29b-41d4-a716-446655440000");
        authResponse.put("success", true);
        authResponse.put("message", "認証が完了しました");
        authResponse.put("timestamp", System.currentTimeMillis());

        // API Gateway経由でメッセージ送信
        String requestBody = objectMapper.writeValueAsString(authResponse);
        
        TestInvokeMethodRequest apiRequest = TestInvokeMethodRequest.builder()
            .restApiId(TestConfig.API_GATEWAY_ID)
            .resourceId(getResourceId("mc-to-web"))
            .httpMethod("POST")
            .pathWithQueryString("/mc-to-web")
            .body(requestBody)
            .headers(Map.of(
                "Content-Type", "application/json",
                "Authorization", generateAuthHeader("POST", "/mc-to-web", requestBody)
            ))
            .build();

        TestInvokeMethodResponse apiResponse = apiGatewayClient.testInvokeMethod(apiRequest);
        
        // API Gatewayレスポンス検証
        assertEquals(200, apiResponse.status().intValue());
        
        JsonNode responseBody = objectMapper.readTree(apiResponse.body());
        assertTrue(responseBody.path("success").asBoolean());

        // SQSメッセージ受信確認
        Message receivedMessage = waitForSqsMessage(mcToWebQueueUrl, Duration.ofSeconds(30));
        assertNotNull(receivedMessage, "SQSメッセージが受信されませんでした");

        // メッセージ内容検証
        JsonNode messageBody = objectMapper.readTree(receivedMessage.body());
        assertEquals("mc_web_auth_response", messageBody.path("type").asText());
        assertEquals("testPlayer", messageBody.path("playerName").asText());
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
    void testWebToMcCommand() throws Exception {
        logger.info("Testing Web→MC Command");

        // テスト用コマンドメッセージ
        Map<String, Object> commandMessage = new HashMap<>();
        commandMessage.put("type", "web_mc_command");
        commandMessage.put("commandType", "teleport");
        commandMessage.put("playerName", "testPlayer");
        
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
            .headers(Map.of(
                "Content-Type", "application/json",
                "Authorization", generateAuthHeader("POST", "/web-to-mc", requestBody)
            ))
            .build();

        TestInvokeMethodResponse apiResponse = apiGatewayClient.testInvokeMethod(apiRequest);
        assertEquals(200, apiResponse.status().intValue());

        // SQSメッセージ受信確認
        Message receivedMessage = waitForSqsMessage(webToMcQueueUrl, Duration.ofSeconds(30));
        assertNotNull(receivedMessage);

        // メッセージ内容検証
        JsonNode messageBody = objectMapper.readTree(receivedMessage.body());
        assertEquals("web_mc_command", messageBody.path("type").asText());
        assertEquals("teleport", messageBody.path("commandType").asText());
        assertEquals("testPlayer", messageBody.path("playerName").asText());
        assertEquals("100,64,200", messageBody.path("data").path("location").asText());
        
        logger.info("Web→MC Command test passed");
    }

    /**
     * 双方向通信フローテスト
     */
    @Test
    void testBidirectionalCommunicationFlow() throws Exception {
        logger.info("Testing Bidirectional Communication Flow");

        // Step 1: Web→MC認証確認
        Map<String, Object> authRequest = new HashMap<>();
        authRequest.put("type", "web_mc_auth_confirm");
        authRequest.put("playerName", "flowTestPlayer");
        authRequest.put("playerUuid", "660e8400-e29b-41d4-a716-446655440001");
        
        sendWebToMcMessage(authRequest);
        Message authRequestMessage = waitForSqsMessage(webToMcQueueUrl, Duration.ofSeconds(30));
        assertNotNull(authRequestMessage);

        // Step 2: MC→Web認証レスポンス
        Map<String, Object> authResponse = new HashMap<>();
        authResponse.put("type", "mc_web_auth_response");
        authResponse.put("playerName", "flowTestPlayer");
        authResponse.put("playerUuid", "660e8400-e29b-41d4-a716-446655440001");
        authResponse.put("success", true);
        authResponse.put("message", "認証フロー完了");
        
        sendMcToWebMessage(authResponse);
        Message authResponseMessage = waitForSqsMessage(mcToWebQueueUrl, Duration.ofSeconds(30));
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
            .headers(Map.of("Content-Type", "application/json"))
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
            .headers(Map.of(
                "Content-Type", "application/json",
                "Authorization", generateAuthHeader("POST", "/web-to-mc", requestBody)
            ))
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
            .headers(Map.of(
                "Content-Type", "application/json",
                "Authorization", generateAuthHeader("POST", "/mc-to-web", requestBody)
            ))
            .build();

        apiGatewayClient.testInvokeMethod(apiRequest);
    }

    private Message waitForSqsMessage(String queueUrl, Duration timeout) throws InterruptedException {
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
                sqsClient.deleteMessage(builder -> builder
                    .queueUrl(queueUrl)
                    .receiptHandle(message.receiptHandle()));
                
                return message;
            }
            
            TimeUnit.SECONDS.sleep(2);
        }
        
        return null;
    }

    private String getResourceId(String pathPart) {
        // API Gateway のリソースIDを取得（実装は既存のTestUtilsを参照）
        return TestUtils.getApiGatewayResourceId(apiGatewayClient, TestConfig.API_GATEWAY_ID, pathPart);
    }

    private String generateAuthHeader(String method, String path, String body) {
        // AWS Signature V4 認証ヘッダー生成（実装は既存のTestUtilsを参照）
        return TestUtils.generateAwsAuthHeader(method, path, body, TestConfig.AWS_REGION.id());
    }
}