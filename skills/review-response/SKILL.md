---
name: review-response
description: Use when a PR or work-item code review has come back and you need to address the feedback — structures the response so the mechanical execution phase (edit/test/commit/push) is delegated to a sonnet subagent, not run on main.
---

## 何をする skill か

レビュー指摘への対応を「判断フェーズ=main / 実行フェーズ=sonnet subagent」に分割する。反復して起きる「最高額モデルで機械作業を直実行」を構造的に防ぐのが目的。

## フェーズと執行者（この分割が本体）

| フェーズ | 内容 | 執行者 |
|---|---|---|
| 調査 | 実レビュースレッドを取得し、各指摘をコードに突合して検証。前セッション/compaction summary の「対応済み・commit済み」主張は git ls-remote/rev-parse/reflog で必ず裏取り（summary は捏造結果をそのまま引き継ぐ） | main |
| 分類 | 各指摘を 修正 / won't-fix（理由付き）/ 別WI化 に判定。Tier（Tier1必須/Tier2推奨/Tier3cleanup）で重大度を確認 | main |
| 実行 | コード変更の適用・テスト実行・commit・push | **sonnet subagent（必ず委譲）** |
| レビュー返信 | 1指摘=1返信、対象ファイル/行を指定、status 更新 | sonnet subagent（定型投稿）または main |
| 検証 | push 実在を git ls-remote/rev-parse で確認、thread status を確認、tracker WI の実在を確認 | main |

## 実行フェーズの委譲プロンプト（テンプレ）

main が「正確な変更 spec（ファイル・該当箇所・変更後の内容）＋検証手順（どのテストを流すか）＋commit メッセージ方針」を書き、それを sonnet subagent に渡す。subagent は実行し、**実際のコミットハッシュと push 結果（`git ls-remote` 出力）を返す**。

```
[変更 spec]
- ファイル: path/to/File.cs
- 該当箇所: ClassName.MethodName（Lxx-Lyy）
- 変更内容: <具体的な差分の説明>

[検証手順]
- dotnet test DentalImageAnotator.Tests --filter <対象>
- （挙動変更を伴う場合）関連 E2E/UIテストも実行

[commit メッセージ方針]
- Conventional Commits（fix: / refactor: 等）、"なぜ" を書く

上記を適用し、テストを実行し、commit と push まで実行し、
実ハッシュと `git ls-remote origin <branch>` の出力を報告せよ。
```

## やってはいけないこと

- main で edit→test→commit→push を直実行しない（この skill の存在理由）
- subagent の「commit した/push した」報告を鵜呑みにしない。main が git ls-remote/rev-parse で裏取りしてから done を報告
- 判断（どの指摘を修正/却下/別WI化するか、auth/security の妥当性）は委譲しない。main が持つ
- スコープ拡大（レビューが Tier2推奨で挙動変更を「明文化で可」としているのに勝手に挙動変更まで踏み込む）をしない

## 完了条件

- 全レビュースレッドに応答済み（修正=resolve / won't-fix=理由付き / 別WI=WI番号明記）
- push が git ls-remote で実在確認済み
- 挙動変更を伴う場合はユニット/E2E 検証済み
