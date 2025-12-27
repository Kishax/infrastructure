次に、apps/mc/ をより保守・運用しやすいように、機能を追加していくことを考える。

MC追加要件
SPIGOT側のサーバ（総称：SPIGOTs）を増やせるようにする。
つまり、配列にする。
現在は、apps/mc/docker/data/urls.json によりプラグインやサーババージョンが選択できるが、これを拡張する。
まず、urls.json というのは相応しくない。

servers.json にする。
server.json要件
配列にできるのはサーバだけではなく、プラグインプリセット（PP）を定義できる。
PPにより、SPIGOTsにおいて、一括でプラグインを適用することができるようになる。

メモリ要件
PROXYs(Velocity)のメモリをV-M-Y（YはPROXYsの総数である。Y=1に限定する）とするとき、各SPIGOTsのSPIGOT-X（XはSPIGOTsの総数である）は、メモリ（S-M-X, 0 < ΣS-M-X + V-M-Y < 10.0）を変更できる。
server.json では、それらを歩合で表現する。
（以下のMC全体メモリに占める歩合とする）

以下定義
全体メモリ（O-Mと呼ぶ）を.env より受け取る。（今回は8.0(GB)）
バッファメモリ（B-M, 0 < B-M < O-M）を0.1

このとき
O-MC-WANTAGE(0 < O-MC-WANTAGE < 1.0)によって、サーバ全体の何割をMCサーバに割り当てるかを定義すると、スカラーとしてMC全体メモリ（O-MCと呼ぶ）は以下を満たす。
（今回はMC専用サーバを想定し、O-MC-WANTAGEは1.0とする。）
O-MC = (O-M - B-M) × O-WANTAGE
ΣS-M-X + V-M-Y < O-MC <= O-M - B-M(0.1) < O-M

つまり
0 < B-M(0.1) < ΣS-M-X + V-M-Y <= O-MC + B-M(0.1) < O-M <= 8.0

S-M-Xが0の場合、起動しない。
ΣS-M-XがO-MCを超える場合はエラーを出す。
O-MC < 0.9 の場合
残りの 0.9 - 0-MC > 0 を X + Y で割り、全てのサーバに足すようにする。

現在は、.env よりそれらが一つのSPIGOTにのみ展開されているが、これらSPIGOTsの多層化により、不要になると考えている。

---

これさ、もっと大規模になると思うんだ。
apps/mc/docker/data/velocity-kishax-config.yml
apps/mc/docker/data/spigot-kishax-config.yml
には修正が必ず入るはず。
また、プラグインの配置とか
apps/mc/docker/mc/velocity に至っても修正が入るはず。
また、apps/mc/docker/mc/velocity/plugins/luckperms/config.yml 
apps/mc/docker/mc/spigot/plugins/LuckPerms/config.yml
apps/mc/docker/mc/spigot/config/paper-global.yml
にあるようなものもservers.jsonによって、動的生成が必要になると思っている。
現在、urls.jsonは使用されていますか？
servers.json に統一するのはいかがでしょう？
データベースに至っては、確か、アプリケーションレベルで、velocityがapps/mc/docker/mc/velocity/velocity.toml とapps/mc/docker/data/velocity-kishax-config.yml に応じて、statusテーブルにサーバを配置する。

---

Kishaxプラグインは、バージョンによって配置が自動化されますか？今って確かビルドしてた思う。
ビルドして配置して、みたいなのを元々やってて、対応バージョンは限られるけど、一回ビルドしたら、jarは出てくる。
そのSPIGOTのバージョンによって、Kishaxプラグインを配置すればいいだけなのかなって思ってる。

---

そうですね。おそらく、
apps/mc/docker/mc/template/ に
spigot/ と velocity/ を移動させ、Dockerfileかスクリプトで、実際に、動的にディレクトリを生成するのがよいかもしれませんね！
