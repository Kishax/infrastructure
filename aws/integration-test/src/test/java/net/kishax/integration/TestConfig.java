package net.kishax.integration;

import io.github.cdimascio.dotenv.Dotenv;
import software.amazon.awssdk.auth.credentials.ProfileCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.apigateway.ApiGatewayClient;
import software.amazon.awssdk.services.sqs.SqsClient;
import software.amazon.awssdk.services.ssm.SsmClient;

/**
 * 統合テスト用の共通設定クラス
 * .env ファイルから環境変数を読み取り
 */
public class TestConfig {

  private static final Dotenv dotenv = Dotenv.configure()
      .directory(".")
      .ignoreIfMissing()
      .load();

  // AWS Settings
  public static final String AWS_PROFILE = getEnvValue("AWS_PROFILE");
  public static final Region AWS_REGION = Region.of(getEnvValue("AWS_REGION"));
  public static final String ACCOUNT_ID = getEnvValue("AWS_ACCOUNT_ID");

  // API Gateway
  public static final String API_GATEWAY_ID = getEnvValue("AWS_API_GATEWAY_ID");
  public static final String API_GATEWAY_STAGE = getEnvValue("AWS_API_GATEWAY_STAGE");

  // 各通信パターン用SQSキュー名
  public static final String SQS_DISCORD_QUEUE_NAME = getEnvValue("AWS_SQS_DISCORD_QUEUE_NAME");
  public static final String SQS_MC_TO_WEB_QUEUE_NAME = getEnvValue("AWS_SQS_MC_TO_WEB_QUEUE_NAME");
  public static final String SQS_WEB_TO_MC_QUEUE_NAME = getEnvValue("AWS_SQS_WEB_TO_MC_QUEUE_NAME");

  // DLQ名
  public static final String SQS_DISCORD_DLQ_NAME = getEnvValue("AWS_SQS_DISCORD_DLQ_NAME");
  public static final String SQS_MC_TO_WEB_DLQ_NAME = getEnvValue("AWS_SQS_MC_TO_WEB_DLQ_NAME");
  public static final String SQS_WEB_TO_MC_DLQ_NAME = getEnvValue("AWS_SQS_WEB_TO_MC_DLQ_NAME");

  // 各通信パターン用API Gatewayリソースパス
  public static final String API_GATEWAY_DISCORD_RESOURCE_PATH = getEnvValue("AWS_API_GATEWAY_DISCORD_RESOURCE_PATH");
  public static final String API_GATEWAY_WEB_TO_MC_RESOURCE_PATH = getEnvValue("AWS_API_GATEWAY_WEB_TO_MC_RESOURCE_PATH");
  public static final String API_GATEWAY_MC_TO_WEB_RESOURCE_PATH = getEnvValue("AWS_API_GATEWAY_MC_TO_WEB_RESOURCE_PATH");

  // Discord設定
  public static final String DISCORD_CHANNEL_ID = getEnvValue("DISCORD_CHANNEL_ID");


  // AWS Credentials for integration testing
  // Note: これらはDiscordBotSqsTestでSystem.getenvから直接取得されます

  /**
   * 環境変数または.envファイルから値を取得
   */
  private static String getEnvValue(String key) {
    // システム環境変数を優先、なければ.envファイルから取得
    String value = System.getenv(key);
    if (value == null) {
      value = dotenv.get(key);
    }
    if (value == null) {
      throw new IllegalStateException("Required environment variable not found: " + key);
    }
    return value;
  }

  /**
   * AWS API Gateway クライアント作成
   */
  public static ApiGatewayClient createApiGatewayClient() {
    return ApiGatewayClient.builder()
        .region(AWS_REGION)
        .credentialsProvider(ProfileCredentialsProvider.create(AWS_PROFILE))
        .build();
  }

  /**
   * AWS SQS クライアント作成
   */
  public static SqsClient createSqsClient() {
    return SqsClient.builder()
        .region(AWS_REGION)
        .credentialsProvider(ProfileCredentialsProvider.create(AWS_PROFILE))
        .build();
  }

  /**
   * AWS SSM クライアント作成
   */
  public static SsmClient createSsmClient() {
    return SsmClient.builder()
        .region(AWS_REGION)
        .credentialsProvider(ProfileCredentialsProvider.create(AWS_PROFILE))
        .build();
  }

  /**
   * 通信パターン別API Gateway エンドポイントURL生成
   */
  public static String getDiscordApiGatewayUrl() {
    return String.format("https://%s.execute-api.%s.amazonaws.com/%s%s",
        API_GATEWAY_ID, AWS_REGION.id(), API_GATEWAY_STAGE, API_GATEWAY_DISCORD_RESOURCE_PATH);
  }

  public static String getWebToMcApiGatewayUrl() {
    return String.format("https://%s.execute-api.%s.amazonaws.com/%s%s",
        API_GATEWAY_ID, AWS_REGION.id(), API_GATEWAY_STAGE, API_GATEWAY_WEB_TO_MC_RESOURCE_PATH);
  }

  public static String getMcToWebApiGatewayUrl() {
    return String.format("https://%s.execute-api.%s.amazonaws.com/%s%s",
        API_GATEWAY_ID, AWS_REGION.id(), API_GATEWAY_STAGE, API_GATEWAY_MC_TO_WEB_RESOURCE_PATH);
  }

  /**
   * 後方互換性のためのメソッド（Discord通信用）
   */
  public static String getApiGatewayUrl() {
    return getDiscordApiGatewayUrl();
  }

  /**
   * 通信パターン別SQS Queue URL生成
   */
  public static String getDiscordSqsQueueUrl() {
    return String.format("https://sqs.%s.amazonaws.com/%s/%s",
        AWS_REGION.id(), ACCOUNT_ID, SQS_DISCORD_QUEUE_NAME);
  }

  public static String getMcToWebSqsQueueUrl() {
    return String.format("https://sqs.%s.amazonaws.com/%s/%s",
        AWS_REGION.id(), ACCOUNT_ID, SQS_MC_TO_WEB_QUEUE_NAME);
  }

  public static String getWebToMcSqsQueueUrl() {
    return String.format("https://sqs.%s.amazonaws.com/%s/%s",
        AWS_REGION.id(), ACCOUNT_ID, SQS_WEB_TO_MC_QUEUE_NAME);
  }

  /**
   * 後方互換性のためのメソッド（MC→Web通信用）
   */
  public static String getSqsQueueUrl() {
    return getMcToWebSqsQueueUrl();
  }
}
