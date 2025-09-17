package net.kishax.integration;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.TestInfo;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import software.amazon.awssdk.services.apigateway.ApiGatewayClient;
import software.amazon.awssdk.services.sqs.SqsClient;
import software.amazon.awssdk.services.ssm.SsmClient;

/**
 * 統合テスト用ベースクラス
 */
public abstract class BaseIntegrationTest {

    protected Logger logger;
    protected ApiGatewayClient apiGatewayClient;
    protected SqsClient sqsClient;
    protected SsmClient ssmClient;

    @BeforeEach
    void setUp(TestInfo testInfo) {
        this.logger = LoggerFactory.getLogger(testInfo.getTestClass().orElse(this.getClass()));
        
        // AWSクライアント初期化
        this.apiGatewayClient = TestConfig.createApiGatewayClient();
        this.sqsClient = TestConfig.createSqsClient();
        this.ssmClient = TestConfig.createSsmClient();
        
        logger.info("=== Starting test: {} ===", testInfo.getDisplayName());
        logger.info("AWS Region: {}", TestConfig.AWS_REGION);
        logger.info("AWS Profile: {}", TestConfig.AWS_PROFILE);
    }
}