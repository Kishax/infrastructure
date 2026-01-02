# TShock コマンドリファレンス

このドキュメントは、TShock Terrariaサーバで使用できるコマンドのリファレンスです。

## 目次

1. [初回セットアップ](#初回セットアップ)
2. [ログイン・認証](#ログイン認証)
3. [権限管理](#権限管理)
4. [アイテム管理](#アイテム管理)
5. [ボス召喚アイテム](#ボス召喚アイテム)
6. [その他便利なコマンド](#その他便利なコマンド)

---

## 初回セットアップ

### サーバ初期化

サーバ起動時にコンソールに表示されるセットアップトークンを使用します。

```
/setup <トークン>
```

**例:**
```
/setup 9802732
```

### 管理者アカウント作成

セットアップ後、管理者アカウントを作成します。

```
/user add <ユーザー名> <パスワード> owner
```

**例:**
```
/user add sampleuser mypassword owner
```

---

## ログイン・認証

### ログイン

```
/login <ユーザー名> <パスワード>
```

**例:**
```
/login sampleuser mypassword
```

### アカウント登録（初回）

```
/register <パスワード>
```

### パスワード変更

```
/user password <ユーザー名> <新しいパスワード>
```

---

## 権限管理

### ユーザーグループ変更

```
/user group <ユーザー名> <グループ名>
```

**グループ:**
- `superadmin` - 最高権限
- `owner` - 管理者
- `admin` - 管理者
- `default` - デフォルトユーザー

**例:**
```
/user group takaya_maekawa superadmin
```

### グループに権限追加

```
/group addperm <グループ名> <権限>
```

**例（ボス召喚権限を追加）:**
```
/group addperm default tshock.npc.summonboss
```

---

## アイテム管理

### アイテム付与（自分）

```
/item <アイテムID> <個数>
```

または短縮形：

```
/i <アイテムID> <個数>
```

**例:**
```
/item 557 1
/i 557 1
```

### アイテム付与（他プレイヤー）

> **注意:** `/item give` や `/give` コマンドは使用できません。
> 他プレイヤーにアイテムを付与する場合は、サーバコンソールから実行するか、各プレイヤーが自分で `/item` コマンドを実行してください。

---

## ボス召喚アイテム

以下は主要なボス召喚アイテムのIDリストです。

| アイテム名 | アイテムID | 召喚ボス |
|-----------|----------|---------|
| Suspicious Looking Eye | 43 | Eye of Cthulhu |
| Worm Food | 70 | Eater of Worlds |
| Bloody Spine | 1331 | Brain of Cthulhu |
| Abeemination | 1133 | Queen Bee |
| Deer Thing | 5120 | Deerclops |
| Slime Crown | 560 | King Slime |
| Mechanical Eye | 544 | The Twins |
| Mechanical Worm | 556 | The Destroyer |
| Mechanical Skull | 557 | Skeletron Prime |
| Celestial Sigil | 3601 | Moon Lord |

**使用例:**
```
/item 557 1    # Mechanical Skull (Skeletron Prime)
/item 544 1    # Mechanical Eye (The Twins)
/item 556 1    # Mechanical Worm (The Destroyer)
```

---

## その他便利なコマンド

### ヘルプ表示

```
/help
/help <コマンド名>
```

**例:**
```
/help item
```

### サーバ情報

```
/playing
```

### ワールド保存

```
/save
```

### サーバログ確認

サーバログは以下のディレクトリに保存されます：

```
/opt/terraria/tshock/logs/
```

**ログ検索例:**
```bash
grep -i "sampleuser" /opt/terraria/tshock/logs/*.log
```

---

## トラブルシューティング

### ボス召喚権限エラー

**エラー:** `You do not have permission to summon bosses.`

**解決方法:**

1. 管理者アカウントでログイン
2. 自分のグループを `superadmin` に変更:
   ```
   /user group <ユーザー名> superadmin
   ```

または、デフォルトグループに権限を追加:
```
/group addperm default tshock.npc.summonboss
```

### アカウント情報を忘れた場合

サーバログから過去のログイン情報を確認できます：

```bash
grep -i "<ユーザー名>" /opt/terraria/tshock/logs/*.log
```

---

## 参考リンク

- [TShock 公式ドキュメント](https://tshock.readme.io/)
- [Terraria Wiki - アイテムID一覧](https://terraria.fandom.com/wiki/Item_IDs)
