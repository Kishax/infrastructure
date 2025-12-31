p.
ec2で起動毎に、mc.kishax.net にpublic ipを向けるようにするには、mc.kishax.net のインスタンス起動時にsystemd などで1回きりmc.kishax.net のAレコードを変更する権限を持ったポリシーで動いている特定のアクセスキーでスクリプトを実行すればいいかな？他の方法ってある？

## 💡 EC2起動時にRoute 53のAレコードを更新するベストプラクティス

ご質問の「EC2起動毎に $mc.kishax.net$ にPublic IPを向ける」という要件に対して、ご提案の方法（特定のアクセスキーとスクリプトを使う方法）は技術的には可能ですが、**よりセキュアでAWSのベストプラクティスに沿った別の方法**があります。

Terraformで管理されている環境でも、EC2インスタンスが自身のIPアドレスをDNSに登録・更新する仕組みを構築することはよくあります。

-----

### 1\. 推奨されるベストプラクティス（IAMロールとAWS CLI/SDK）

アクセスキーをEC2インスタンス内に直接埋め込むのは、キー漏洩のリスクがあるため**非推奨**です。AWSでは、EC2インスタンスに権限を与えるために **IAMロール** を使用することがベストプラクティスです。

#### 🔹 必要な手順

1.  **IAMポリシーの作成:**
    `mc.kishax.net` のホストゾーンIDに対してのみ、`route53:ChangeResourceRecordSets`アクションを許可する最小権限のIAMポリシーを作成します。

    ```json
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": "route53:ChangeResourceRecordSets",
                "Resource": "arn:aws:route53:::hostedzone/YOUR_HOSTED_ZONE_ID"
            }
        ]
    }
    ```

2.  **IAMロールへのアタッチ:**
    上記ポリシーをEC2インスタンスにアタッチするIAMロールに紐付けます。

3.  **EC2インスタンスの起動と設定:**

      * EC2インスタンスを起動する際に、作成したIAMロールを割り当てます。
      * \*\*ユーザーデータ（User Data）\*\*として、以下の処理を行うスクリプトを設定します。

#### 🔹 ユーザーデータに設定するスクリプトの例（Bash）

ユーザーデータは、インスタンスが最初に起動するときに一度だけ実行されます。

```bash
#!/bin/bash
# ホストゾーンIDとドメイン名を設定
HOSTED_ZONE_ID="YOUR_HOSTED_ZONE_ID"
DOMAIN_NAME="mc.kishax.net"

# EC2インスタンスのPublic IPアドレスを取得
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

# 変更セットのJSONを作成
CHANGE_BATCH=$(cat <<EOF
{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${DOMAIN_NAME}",
        "Type": "A",
        "TTL": 60,
        "ResourceRecords": [
          {
            "Value": "${PUBLIC_IP}"
          }
        ]
      }
    }
  ]
}
EOF
)

# AWS CLIを使ってRoute 53のレコードを更新
aws route53 change-resource-record-sets \
    --hosted-zone-id ${HOSTED_ZONE_ID} \
    --change-batch "${CHANGE_BATCH}"
```

この方法であれば、**アクセスキーをインスタンスに保存する必要がなく**、権限も最小限に抑えられるため、非常に安全です。

-----

### 2\. その他の方法（Elastic IP / ロードバランサー）

もし、このEC2インスタンスが停止・起動を繰り返す重要なサーバー（例：ゲームサーバーなど）である場合、そもそもIPアドレスが変わらないようにする方が、DNSの伝播遅延を避ける上で根本的な解決になります。

#### A. Elastic IP (EIP) の利用

  * **方法:** EIPをインスタンスに割り当てます。インスタンスが停止・起動しても、EIPは変わりません。
  * **DNS:** $mc.kishax.net$ のAレコードをEIPに向けて固定します。
  * **利点:** DNSの更新が不要になるため、最もシンプルで確実です。
  * **注意点:** EIPはアタッチされていない状態が続くと課金対象になります。

#### B. AWS Global Accelerator (推奨) または Application Load Balancer (ALB) の利用

  * **方法:** EC2インスタンスの前にALBやGlobal Acceleratorを配置します。
  * **DNS:** $mc.kishax.net$ のAレコードをALBまたはGlobal AcceleratorのDNS名に向けます（エイリアスレコードを使用）。
  * **利点:** EC2のIPアドレスが変動しても、ALB/Global Acceleratorのアドレスは変わらないため、DNSの更新が不要です。高可用性やパフォーマンス向上にもつながります。

-----

### 3\. systemdとアクセスキー（ご提案の方法の評価）

ご提案の「特定のアクセスキーでスクリプトを **systemd** などで1回きり実行する」方法は、以下のような評価になります。

  * **技術的な実現性:** **可能**です。`systemd`の`oneshot`タイプや`User Data`内のスクリプトとして実行できます。
  * **セキュリティ:** アクセスキーとシークレットキーをインスタンス内に何らかの形で（ファイル、環境変数など）保存する必要があるため、**推奨されません**。キーが漏洩した場合、意図しないAWSリソースへのアクセスを許してしまうリスクがあります。

-----

最も推奨されるのは、**IAMロールとUser Dataを使う方法**（セクション1）です。

もし、この $mc.kishax.net$ のDNSレコードを**Terraform自体が管理している**場合、User Dataでレコードを更新すると、TerraformのStateファイルとAWS上の実際のレコードに\*\*差分（Drift）\*\*が発生することになります。この点も考慮が必要です。

ご使用のTerraformの構成に応じて、最適な方法をご検討ください。

どの方法で進めるか、または、EC2起動時のIAMロール設定についてさらに詳しく知りたい点があればお気軽にご質問ください。

p.
これ、ec2の内部から動かすんだよね？

はい、その通りです。

セクション1で提案した **「IAMロールとユーザーデータ（User Data）を使う方法」** は、EC2インスタンスが起動した際に、**EC2インスタンスの内部**でスクリプトを実行する仕組みです。

### 仕組みの再確認 

1.  **IAMロール（権限の付与）:**
    * 外部のアクセスキーを使わず、EC2インスタンス自体に Route 53 のレコード更新権限が付与されます。
2.  **ユーザーデータ（スクリプトの実行）:**
    * EC2インスタンスの起動時（初回のみ）に、OSが自動的に `User Data` に書かれたBashスクリプトを実行します。
3.  **スクリプトの処理:**
    * スクリプトはまず **EC2インスタンス自身のPublic IPアドレスを取得します**（`curl -s http://169.254.169.254/latest/meta-data/public-ipv4`）。
    * 次に、割り当てられた **IAMロールの権限** を利用して **AWS CLI** を実行し、Route 53のAレコードをそのPublic IPアドレスで更新します。

これにより、インスタンスが外部と通信することなく、自身の情報を使ってDNSレコードを最新の状態に保つことができます。

---

もし、この仕組みを **Terraformで構築** したい場合は、どのリソースに設定を組み込むべきか、具体的なコード例をご提示できます。いかがでしょうか？