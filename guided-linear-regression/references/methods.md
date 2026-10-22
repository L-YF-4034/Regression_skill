# 方法與來源

以 k 為斜率數，p=rank(X) 為含截距參數數，n 為分析筆數。

## 簡單與多元迴歸

簡單模型 Y_i=beta_0+beta_1 X_i+epsilon_i；多元模型 Y=X beta+epsilon。條件平均線性、誤差平均零、同方差；常態與獨立誤差支持有限樣本 t/F 推論。滿秩時 beta_hat=(X'X)^(-1)X'Y，實作用 lm 的 QR 分解。s²=SSE/(n-p)，Cov(beta_hat)=s²(X'X)^(-1)。秩不足須停止指出共線性。

係數 H0:beta_j=0，t=beta_hat_j/SE，參考 t(n-p)，雙尾。整體 H0:所有斜率為零，F=(SSR/k)/(SSE/(n-p))，參考 F(k,n-p)。summary(fit) 提供估計、SE、t、p、R²、調整R²、殘差標準差與整體 F；confint 提供95%CI。anova(fit) 為順序平方和，不能冒充各變數調整所有其他 X 的檢定。多元係數須解釋為控制其他 X 後的關聯。

簡單模型原始點加排序後配適線；多元模型畫 observed vs fitted 及 y=x，再將其他 X 固定中位數／參考組畫條件線，說明固定值。平均反應CI與個體PI不可混淆；R²不是外部預測準確率。類別 X 設 factor 並記錄參考組，不把 ID 當 X。

## 殘差

e=y-yhat。畫殘差對配適值、各 X、常態 Q-Q、sqrt(abs(rstandard))。SW：H0常態，shapiro.test，3≤n≤5000；殘差本身相關，p值僅輔助。BP：H0同方差，lmtest::bptest(studentize=TRUE) 採 Koenker 版本，漸近卡方。DW=sum(diff(e)^2)/sum(e²)，lmtest::dwtest(alternative="two.sided")，H0為一階誤差相關零，不代表所有形式獨立；一律按目前分析資料row順序執行；無已確認時間／採樣次序時說明排序依賴，不能證明誤差獨立。不要呼叫 plot(fit) 的 Cook/leverage 面板以免提前離群診斷。

## Box-Cox

Y>0，T_lambda(Y)=(Y^lambda-1)/lambda，lambda=0為log(Y)。MASS::boxcox 含Jacobian的profile likelihood，固定網格[-2,2]步長.01；端點最大需擴展。95% profile CI：2(ell_max-ell_lambda)≤qchisq(.95,1)。CI含1通常不足以支持轉換；簡化為0等值須記錄並重新診斷。講義p.50使用幾何平均標準化，與此轉換尺度不同，不能混比較SSE。Box-Cox不保證修復自相關，不比較跨Y尺度的未校正AIC/R²；直接反轉換不是無偏平均。一般lm推論未計入lambda估計不確定性。

## 離群與影響

H=X(X'X)^(-1)X'；hatvalues>2p/n 為高槓桿（門檻≥1時無實用性）。內學生化 r=e/[s sqrt(1-h)]，|rstandard|>3為粗略標記。外學生化 t=e/[s_(i)sqrt(1-h)]，rstudent，參考t(n-p-1)，同時n筆採Bonferroni門檻qt(1-alpha/(2n),n-p-1)。Cook D=e²h/[p s²(1-h)²]，cooks.distance>1為講義門檻，4/n為補充敏感篩檢。|dffits|>2sqrt(p/n)，各|dfbetas|>2/sqrt(n)。高槓桿、Y離群、影響不同；列原始row ID和所有指標，不自動刪除。另獲同意才作刪點敏感度，保留原模型。

## 來源對照與勘誤

* Program_1.pdf：18–29頁簡單迴歸；30–37殘差、SW/BP/DW；38–49多元與預測；50–55 Box-Cox。
* Program_2.pdf：2–8頁槓桿、內外學生化、Cook、DFBETAS/DFFITS；10–15指標變數。
* Montgomery, Peck & Vining (2012), Introduction to Linear Regression Analysis, 5th ed.：第2–3章估計推論、第4章模型診斷（上傳PDF130–133頁）、第5章轉換、第6章槓桿影響（211–213頁）。
* 修正Program_1 p.29：整體F的H0是斜率全零，不是截距零；p.37/50不應解讀成轉換保證解決相依。Program_2門檻統一p含截距、取絕對值及正確平方根；外學生化逐筆.05改用Bonferroni，並明示為補充保守校正。


## 最新執行與報告規格

1. 殘差分析獲同意後，原模型與轉換模型都執行雙尾Durbin-Watson。沿用目前分析row順序；若無已確認的時間／採樣順序，明示結果依賴排序，不能據此證明獨立。`ordered`只標記排序是否確認。
2. Box-Cox先呼叫`boxcox_profile()`，展示估計lambda、95% profile CI與Box-Cox plot，再讓使用者指定lambda。沒有另指定且同意轉換時使用估計值。`transform_model(lambda=NULL)`採估計值，指定有限數值則使用指定值；記錄估計值與實際值，不混為一談。CI由網格及門檻交點內插近似。
3. QMD依「Code 1→實際結果／圖→Code 1中文解釋→Code 2→實際結果／圖→Code 2中文解釋」排列；所有推論文字取自該段R物件，圖形文字需實際檢視後撰寫。
4. 模板新增`approve_boxcox_profile: false`與`boxcox_lambda: null`。前者控制是否取得profile結果，`approve_boxcox`控制是否實際轉換；兩步分開確認。`boxcox_lambda: null`為估計值，數值為使用者指定值。


## VIF：角色確認後、配適Y之前

`vif_design()`建立含截距的X設計矩陣，對第j個非截距column作其餘columns的輔助迴歸，VIF_j=1/(1−R_j²)，tolerance=1/VIF。這不使用Y的反應值，不提供Y的係數或檢定。角色確認本身授權此設計診斷；Y模型仍待確認。

單一非截距數值column時定義VIF=1；不能稱為共線性檢定通過，更不代表誤差獨立。VIF<5、5至10、≥10分別作較低、需留意、高共線性經驗提示，不是普遍有效的顯著性門檻。完全或近完全依賴會標Inf並核查設計秩，停止不合適配適，不以無限值參與一般推論。不依VIF自動刪X。

本腳本輸出為**設計column層級VIF**：factor dummy及每個多項式冪次分開列示，並非term層級GVIF。不能把dummy結果當成整個factor的GVIF；若要補充GVIF需另實作並清楚報df及GVIF^(1/(2df))，不得直接套用普通VIF的5／10門檻。

## 多項式迴歸的建議與實作

選定Y／X後依圖形提出候選：平滑單一彎曲優先建議二階；明顯S形或兩次轉折且觀測充分時才考慮三階。寫出變數與具體次方項，先詢問幾階、等待後才配適；不以肉眼宣稱最佳階數，不因單一高槓桿點盲目升階。若要擬合候選來比較，需先取得候選比較授權。

模型Y=beta0+sum_j sum_(k=1)^d_j beta_jk (X_j−c_j)^k+epsilon。預設建議c_j=分析資料的X_j平均數，需使用者確認並保存，後續predict及Box-Cox固定沿用；若不中心化則c_j=0。保留1至d_j所有低階項。中心化完整多項式通常改善非本質共線性，保持相同階數模型的預測空間，但不保證VIF一定低；不要為降低VIF刪除必要低階項。不能對factor升冪。

`model_spec()`固定公式、各X階數及中心值；`fit_model(degrees=c(X=2), center=TRUE)`只在已同意後配適。不同X值數需大於階數、矩陣滿秩、殘差自由度足夠。單一X多項式仍對beta線性，但不稱簡單直線模型；多個原始X也可含部分多項式項，無自動交互作用。使用I()明列原始／中心化冪次，不默用poly()的正交基底，避免係數及VIF解讀混淆。配適圖畫predict得到的曲線；不以abline代替。多項式不可靠外推，R²上升本身不能證明高階更佳。

補充方法來源：NIST VIF公式（https://www.itl.nist.gov/div898/software/dataplot/refman2/auxillar/vif.htm）；R stats::poly文件（https://www.stat.math.ethz.ch/R-manual/R-devel/library/stats/html/poly.html）；car::vif文件（https://www.stat.ethz.ch/CRAN/web/packages/car/refman/car.html）。新增內容為方法補充，不宣稱所有細節均出自原上傳講義。


## 最終輸出規則（取代任何較早的分階段報告指示）

1. 離群與影響分析仍對全部分析樣本計算，但只print至少一項門檻為true的樣本。合併列原始row ID、數值及flag_reason，DFBETAS也只列這些樣本；不print完整無問題樣本表。若沒有任何標記，只說「沒有被所用門檻標記的離群值或影響樣本」。不自動刪點。
2. 互動期間只展示當階段結果與圖、保存狀態，不逐階段生成最終QMD或編譯PDF。走完流程，或使用者明確拒絕後續而結束時，先在對話告知「此次分析結束」，接著直接產生報告，不再為生成報告多問一次。
3. 以實際成功完成的completed_stages清單選章節，不把approval=true當作已完成。尚未回答時仍等待，不能自行宣告結束；失敗／中止／拒絕／未執行部分不放入PDF，亦不保留其標題、程式碼或待確認提示。內部確認紀錄可保留，不作空白章節。
4. `scripts/finalize_report.R`提供`write_final_report()`：傳入模板、輸出qmd路徑、當次參數、completed_stages及analysis_finished=TRUE；預設直接呼叫Quarto編譯PDF。analysis_finished未確認時拒絕生成。`render=FALSE`僅供開發／檢查；正常交付需編譯且檢視PDF，失敗據實回報。
5. 最終QMD及PDF仍為每段「程式碼→實際結果／圖→該段中文解釋」。生成器實體移除未完成階段，並重新編排Code編號；不能只以eval=false隱藏執行而留下空章節。
