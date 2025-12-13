7fbb0f1e8ae9 以前がCloudformationを用いた企業レベルのインフラでした。それ以降はTerraformによるコスト最適化を目的としてEC2環境のインフラにリファクタリングされています。

PRでいうと
https://github.com/Kishax/infrastructure/pull/9
です。
ブランチでいうと
infra/migrate-to-ec2
です。
apps/ にある各アプリでも同じようにブランチを用意し、各々でPRを出しています。

ですので、もし、戻したいときは
このPR以前に戻すかそれ以前のコミットを参照すること。

それらドキュメントも用意しているので、EC2環境を作成し、Cloudformation環境に移行するにあたっては、[./ec2/](./ec2) を参照すること。

特に[./ec2/requirements.md](./ec2/requirements.md) が要件であり、AIに投げる前に私の頭で考えたことが反映されているので、これがわかりやすいかもしれない。

---

## CloudFormation関連ファイルの削除と統合

infra/delete-cloudformation-and-standardize ブランチ以降、CloudFormation関連ファイルを削除し、EC2/Terraform環境に統合しました。

PRでいうと
https://github.com/Kishax/infrastructure/pull/10
です。
ブランチでいうと
infra/delete-cloudformation-and-standardize
です。
同様にこれもapps/ 以下の各アプリでも同じようにブランチを用意しています。

### 主な変更内容

- **削除ファイル**:
  - `cloudformation-parameters.json`
  - `cloudformation-template.yaml`
  - `ssm-parameters.json.example`
  - `scripts/` ディレクトリ（EC2環境で未使用）
  - ルート直下の `.env.example`

- **ファイル統合**:
  - `apps/*/compose-ec2.yaml` → `apps/*/compose.yaml`
  - `apps/*/.env.ec2.example` → `apps/*/.env.example`

- **リニューアル**:
  - `Makefile`: Terraform/EC2環境用にリニューアル
  - `.gitignore`: CloudFormation関連の除外設定を削除

特に、[./ec2/requirements-delete-cloudformation-and-standardize.md](./ec2/requirements-delete-cloudformation-and-standardize.md) にはCloudformation関連ファイルを削除するにあたっての要件と意図が書かれてある。