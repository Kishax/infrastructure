ブランチは
infra/delete-cloudformation-and-standardize
を使うこと。
Cloudformation関連のファイルを削除すること。
私が目視で確認している予想される削除ファイル分。
- cloudformation-parameters.json
- cloudformation-template.yaml
- ssm-parameters.json.example

.gitignoreの更新も忘れずに。
また、.gitignoreで省かれていて、実際にそのファイルが残っている場合には、.bak/に移動させること。

.env.ec2.example などは.env.example に名前変更すること。
compose-ec2.yml も一緒。

また、それにあたり、テスト環境も整備したい。
ここがメインの部分になると思う。
できればそれがローカルでも動くことを保証したい。
簡単な.envの書き換えでね。

他
ルートディレクトリ直下の.env.example は必要なくなるはず。

Makefile にあたっては、だいぶCloudformationの時のものが残っているので、削除してリニューアルしてもよい。make login は入れてほしいな。（よく使うので）

scripts/ も必要なくなるか。
EC2環境リファクタリングにあたり、scripts/ に何も追加していないのなら、ディレクトリごと削除してもよい。

ドキュメントファイルの更新も忘れずに。