---
name: report
description: Use at the end of any Act-phase work dispatched by ooda-loop:operate — before returning your final result. Structures your report into exactly two mandatory fields (falsifiable result + out-of-scope signal) so the decision-maker (main) can fact-check and re-orient without re-deriving your work.
---

# ooda-loop:report — Act の報告規律

## なぜこの形式が必要か

意思決定者(main)は Act の結果を直接読んで矛盾チェックと判断（Orient/Decide）を行う。あなたの報告が構造化されていないと、意思決定者は重要な兆候（別クラスの故障）を見落とすか、逆に全ての推論を鵜呑みにしてしまう。

## 報告に必ず含める2項目

### 1. falsifiable な合否基準に対する結果

dispatch プロンプトで与えられた合否基準（例:「`npm test` の出力に `7 passed` が出れば合格」）に対して:

- **合格 / 不合格 / 判定不能** のどれかを明言する
- その根拠を、サマリの言い換えではなく実際の出力（該当行そのもの、コマンドの実行結果）で示す
- 判定不能な場合は何が足りなくて判定できないかを書く

やってはいけない: 「たぶん直った」「動いているはず」のような自分の推論だけで合格を宣言すること。実行結果を見せる。

### 2. 依頼された作業範囲から外れた別クラスの兆候

調査・作業の過程で、dispatch された仮説やタスクとは**別クラス**の問題（元の分類に当てはまらない、新しい種類の故障や制約）に気づいたか:

- 気づいた場合: 具体的に何を見た（ログ、エラーメッセージ、挙動）かを書く。自分で対処しようとせず、そのまま報告する
- 気づかなかった場合: その旨を明示する（省略しない — 「別クラスの兆候なし」も意思決定者にとって意味のある情報）

## 含めないもの

- コスト概算（時間・tokens）— 意思決定者側の Decide 判断はこれを使わないため不要
- dispatch されていない追加提案（「ついでにこれも直しました」）— スコープ外の作業は別途報告し、意思決定者の判断を待つ

## 出力形式

```markdown
## Act Report

**合否結果**: 合格 | 不合格 | 判定不能
**根拠**: <実際の出力・該当行>

**別クラスの兆候**: あり — <具体的に何を見たか> | なし
```
