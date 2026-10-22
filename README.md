# 線性迴歸分析 Skill 使用說明

本 skill 使用 R 進行簡單線性迴歸（simple linear regression）、複迴歸（multiple regression）與多項式迴歸（polynomial regression），以繁體中文呈現分析結果，並以 Quarto 產生 `.qmd` 與 PDF 報告。

## 檔案結構

| 檔案 | 用途 |
|---|---|
| `SKILL.md` | 分析範圍、執行順序、確認點與中文寫作規則 |
| `references/decision-tree.md` | 分析流程與分支判斷 |
| `references/methods.md` | 模型、檢定、診斷公式、教材來源與勘誤 |
| `references/textbook-methods.md` | 結果解釋與報告撰寫方式 |
| `scripts/regression.R` | 模型估計、配適圖、殘差分析、Box-Cox及影響點分析函數 |
| `assets/report.qmd` | 最終報告模板，依實際資料設定；未完成階段由生成器整段移除 |
| `scripts/finalize_report.R` | 分析結束後，依成功完成階段生成QMD並編譯PDF |
| `agents/openai.yaml` | 支援此格式的介面所使用的 skill 顯示資訊 |

## 如何開始

將整個 `guided-linear-regression` 資料夾放入使用工具支援的 skill 目錄，保持上述相對路徑。資料夾內應直接看得到 `SKILL.md`，不要重複包一層同名資料夾。

在支援指定 skill 的工具中選取本 skill，並提供 CSV。例如：

> 請使用 guided-linear-regression 分析 data.csv。先畫所有變數的散佈圖，再詢問我哪些是解釋變數及反應變數，依序確認後才繼續分析。

不同工具的安裝目錄與載入方式可能不同；僅建立資料夾並不代表已自動安裝完成。

## 分析流程

1. **先畫圖**：檢查資料，對所有可繪圖的數值變數畫兩兩散佈圖。變數很多時分頁，仍涵蓋所有配對；類別或文字欄位另列說明及適合的分組圖，不硬轉數值。
2. **指定變數角色**：展示圖後，詢問哪個是反應變數 Y、哪些是解釋變數 X，並等待回答。不自動從相關係數決定 Y、X。
3. **VIF與模型選擇**：確認X／Y後先計算VIF並給建議；一個數值X為1。一次模型依X數選簡單／複迴歸；圖形彎曲可提議二階或有充分理由的三階，明列哪些X加何次方，詢問各X要幾階。確定中心化及階數後，重算VIF、列公式，再詢問是否配適。
4. **呈現模型結果**：同意後才執行，包含 `summary(fit)`、係數信賴區間、整體配適指標，以及原始資料與配適結果比較圖。
5. **確認殘差分析**：另詢問是否執行。包含殘差圖、Q-Q圖、Shapiro-Wilk與Breusch-Pagan；不論是否確認時間／採樣順序都執行雙尾Durbin-Watson，並註明目前row排序與解讀限制。
6. **確認Box-Cox**：依殘差分析提出是否需要轉換的建議。另獲同意才尋找lambda、轉換、重新配適及診斷；Y必須為正值。
7. **確認離群與影響點分析**：最後另詢問，同意才計算槓桿、內外學生化殘差、Cook、DFFITS與DFBETAS。標記資料不代表自動刪除。

每個確認點都必須等待明確回答。未回答不是同意；拒絕殘差分析時可進入離群分析的詢問，拒絕迴歸則結束。資料或模型公式變更後，後續確認需重新取得。

## 輸入資料

- CSV原則上一個row代表一筆觀測，一個column代表一個變數。
- Y須為一個連續數值變數；X可包含數值或已確認參考組的類別變數。
- 提供欄位意義、測量單位、特殊遺失碼及採樣設計，有助於正確判斷。
- ID不自動當作解釋變數；特殊遺失碼不自行猜測或刪除。
- 二元／計數反應、重複測量、群聚資料需另確認適當模型。

## 報告輸出與編譯

分析資料夾應包含以下檔案：

| 檔案 | 說明 |
|---|---|
| `analysis_<資料名稱>.qmd` | 包含R程式、圖表、中文解釋與執行狀態的來源檔 |
| `analysis_<資料名稱>.pdf` | 編譯成功並檢查後的報告 |
| 原始CSV | 固定分析輸入 |
| `regression.R` | 從skill複製的分析函數，以相對路徑載入 |

依實際資料修改模板的檔名、欄位、樣本數檢查與資料說明；不能把模板的trees設定直接套到其他資料。確認紀錄應另外區分「尚未回答」與「拒絕」。

分析授權參數預設為 `false`，lambda參數預設為 `null`：

```yaml
params:
  approve_fit: false
  approve_diagnostics: false
  approve_boxcox_profile: false
  approve_boxcox: false
  boxcox_lambda: null
  approve_influence: false
```

只有取得該步同意後，才更新對應參數。重新編譯不代表授權新分析，不能一次全部改為 `true`。

在報告所在資料夾執行：

```sh
quarto render analysis_<資料名稱>.qmd --to pdf
```

需要R、Quarto、可用的PDF引擎及中文字型。模板目前指定XeLaTeX與Microsoft JhengHei；不同作業系統需改為已安裝且支援中文的字型。模板亦含Windows語系設定，其他平台需調整為當地可用的UTF-8語系。

所需R套件包括 `MASS`、`lmtest`、`knitr`、`rmarkdown`、`yaml`。編譯失敗時保留qmd及已執行R結果，回報錯誤，不將未產生的PDF宣稱為完成。

## 可重現性

- `configure()`固定種子20261020、亂數產生方式、數字顯示與contrasts。
- 固定CSV、row次序、缺失處理、factor levels、參考組、公式、顯著水準與lambda搜尋設定。
- 記錄資料MD5、`sessionInfo()`、Quarto版本與各階段確認。
- 相同環境及選項下數值可重現；OLS本身沒有隨機性，單靠設定種子不足以保證跨版本一致。
- 跨機重現時應另鎖定R與套件環境，例如使用renv。PDF的時間與字型資訊可能不同，不保證檔案位元組相同。

## 方法依據

方法參考使用者提供的 `Program_1.pdf`、`Program_2.pdf`，以及Montgomery、Peck與Vining（2012）的 *Introduction to Linear Regression Analysis* 第5版。
章節對照、公式與教材勘誤詳見 `references/methods.md`。原始PDF不包含在本skill資料夾內。

## 目前狀態

已建立skill與報告模板；後續函數曾以固定模擬資料測試。這不代表每種資料型態或環境均已驗證。trees資料分析目前依使用者要求暫停；其範例模板不表示已執行完整迴歸、殘差或離群分析。本機建立與Git提交不代表已同步或安裝至其他工具。


## 最新執行與報告規格

1. 殘差分析獲同意後，原模型與轉換模型都執行雙尾Durbin-Watson。沿用目前分析row順序；若無已確認的時間／採樣順序，明示結果依賴排序，不能據此證明獨立。`ordered`只標記排序是否確認。
2. Box-Cox先呼叫`boxcox_profile()`，展示估計lambda、95% profile CI與Box-Cox plot，再讓使用者指定lambda。沒有另指定且同意轉換時使用估計值。`transform_model(lambda=NULL)`採估計值，指定有限數值則使用指定值；記錄估計值與實際值，不混為一談。CI由網格及門檻交點內插近似。
3. QMD依「Code 1→實際結果／圖→Code 1中文解釋→Code 2→實際結果／圖→Code 2中文解釋」排列；所有推論文字取自該段R物件，圖形文字需實際檢視後撰寫。
4. 模板新增`approve_boxcox_profile: false`與`boxcox_lambda: null`。前者控制是否取得profile結果，`approve_boxcox`控制是否實際轉換；兩步分開確認。`boxcox_lambda: null`為估計值，數值為使用者指定值。


## 新增：VIF與多項式設定

角色確認後可執行`vif_design(df, y="Volume", xs="Girth", selection_confirmed=TRUE)`；它只診斷X，不提前配適Y。單一數值X的VIF為1；多個設計columns按<5、5至10、≥10作經驗提示，不自動刪除。factor輸出為dummy-column VIF，非GVIF。

若圖形顯示彎曲，說明建議加入的次方項，再詢問「要用幾階？」。使用者確認二階時可設定`polynomial_degrees: {Girth: 2}`；一次模型維持`polynomial_degrees: null`。`center_polynomial: true`代表已確認採中心化；`center_values`保存分析資料中心值，後續預測及Box-Cox沿用。階數d會納入1到d所有低階項。變更階數須重新確認配適。

QMD新增`selection_confirmed: false`。指定角色後才設true以執行VIF，`approve_fit`仍維持false直到配適獲同意。報告按code→結果→解釋記錄兩者；不能為呈現VIF而先執行Y的lm模型。更多方法見references/methods.md，流程圖見references/workflow.mmd及HTML設計報告。


模型設定確認紀錄：QMD另以`model_confirmed: false`記錄模型類型、各X階數及中心化是否已確認，只有確認後才設true；`approve_fit`須同時滿足selection_confirmed與model_confirmed。`research_goal`保存使用者的研究目的。角色確認後改階數時不沿用一次模型的虛構中心值；僅保存真正多項式項的中心值。最終設計須保留至少2個殘差自由度。


## 最終輸出規則（取代任何較早的分階段報告指示）

1. 離群與影響分析仍對全部分析樣本計算，但只print至少一項門檻為true的樣本。合併列原始row ID、數值及flag_reason，DFBETAS也只列這些樣本；不print完整無問題樣本表。若沒有任何標記，只說「沒有被所用門檻標記的離群值或影響樣本」。不自動刪點。
2. 互動期間只展示當階段結果與圖、保存狀態，不逐階段生成最終QMD或編譯PDF。走完流程，或使用者明確拒絕後續而結束時，先在對話告知「此次分析結束」，接著直接產生報告，不再為生成報告多問一次。
3. 以實際成功完成的completed_stages清單選章節，不把approval=true當作已完成。尚未回答時仍等待，不能自行宣告結束；失敗／中止／拒絕／未執行部分不放入PDF，亦不保留其標題、程式碼或待確認提示。內部確認紀錄可保留，不作空白章節。
4. `scripts/finalize_report.R`提供`write_final_report()`：傳入模板、輸出qmd路徑、當次參數、completed_stages及analysis_finished=TRUE；預設直接呼叫Quarto編譯PDF。analysis_finished未確認時拒絕生成。`render=FALSE`僅供開發／檢查；正常交付需編譯且檢視PDF，失敗據實回報。
5. 最終QMD及PDF仍為每段「程式碼→實際結果／圖→該段中文解釋」。生成器實體移除未完成階段，並重新編排Code編號；不能只以eval=false隱藏執行而留下空章節。


### 流程結束後的報告呼叫範例

先在對話告知「此次分析結束」，使用已保存的當次設定及成功完成清單，再執行：

```r
source("<skill路徑>/scripts/finalize_report.R", encoding="UTF-8")
write_final_report(
  template="<skill路徑>/assets/report.qmd",
  output="report/analysis.qmd",
  params=analysis_params,
  completed_stages=completed_stages,
  analysis_finished=TRUE,
  render=TRUE
)
```

`analysis_params`為本次已確認的資料路徑、Y、X、公式階數、中心值、lambda及授權設定；`completed_stages`只填成功執行的階段，可用exploration、vif、fit、diagnostics、boxcox_profile、boxcox、influence。若只完成配適，清單可為`c("exploration","vif","fit")`，不納入殘差、Box-Cox或離群章節。正常交付只在流程結束時生成一次，不在每次詢問後編譯。
