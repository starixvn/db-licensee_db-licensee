set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

ALTER PROCEDURE [dbo].[Lrf_Rpt_TurnOver]
	@LicenseeID INT,
	@UserID		INT,
	@LicenseeType VARCHAR(100) = NULL,
	@CurrencyID INT = 0,
	@FromDate		SMALLDATETIME,  
	@ToDate			SMALLDATETIME,   
	@username VARCHAR(50) = NULL,
	@excludeTest BIT = 1,
	@showSB		BIT=0,  
	@ShowRB		BIT=0,  
	@ShowNG		BIT=0, 
	@ShowLC		BIT=0,
	@ShowVS		BIT=0,
	@ShowCS 	BIT=0,--- RNG Casino
	@ShowBG		BIT=0 --- Bingo
AS 
/*
Created: 20111017@Henry
Task : Report Turn Over
DB: DBRPT/bodb02


Revisions:
   - 20111110@Henry: remove group by monthly option
   - 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily 
   - 20120614@Jim: optimize code 
   - 20120731@Jim: add player comm value 
   - 20120917@Henry: split column
   - 20121004@Jim: replace @currency input param by @currencyID
   - 20130123@Daniel: Change link server alias   
   - 20130225@Jim: support RNG Casino , Bingo 
   - 20130402@Jim: support base currency USD
   - 20130618@Jim:  Restrict permission of Licensee Users by currency
   - 20130625@Jim: fix bug missing filter currency condition
   - 20130709@Jim: change formula to sum Transfer3rd value
Param's Explanation:
	+ @excludeTest: remove currency UUS
	+ @CurrencyID = 0: get all currency
	
*/
SET NOCOUNT ON
   
DECLARE @tmpAg TABLE( custID INT PRIMARY KEY,currency int)
DECLARE @fdate smalldatetime, @tdate smalldatetime, @tmpdate smalldatetime, @CustID INT
DECLARE @sporttype AS TABLE(sporttype INT)

SELECT @CustID = 0
	,@username = LTRIM(RTRIM(ISNULL(@username,'')))
	,@fdate = @fromdate
	,@tdate = @todate

SELECT CurrencyID,LicenseeID
INTO #Currency
FROM  DBLIC.bodb_licensee.dbo.CurrencyUser WITH (NOLOCK)
WHERE  usrID=@userID 
AND LicenseeID=@LicenseeID 
AND SystemID=1 -- System is default=1 (LRF)
AND isActive=1
AND (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

INSERT INTO @tmpAg
SELECT CustID,currency 
FROM DBLIC.bodb_Licensee.dbo.LicenseeCust lc WITH( NOLOCK )
	INNER JOIN #Currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID 
WHERE 
	[Description] = COALESCE(@LicenseeType,[Description]) 
	AND (@excludeTest = 0 OR (@excludeTest=1 AND Currency<>20))
DROP TABLE #Currency 
	
IF @ShowSB = 1 INSERT INTO @sporttype(sporttype) VALUES(0)
IF @ShowRB = 1 INSERT INTO @sporttype(sporttype) VALUES(151) 
IF @ShowNG = 1 INSERT INTO @sporttype(sporttype) VALUES(161)
IF @ShowLC = 1 INSERT INTO @sporttype(sporttype) VALUES(162)
IF @ShowVS = 1 INSERT INTO @sporttype(sporttype) VALUES(180)
IF @ShowCS = 1 INSERT INTO @sporttype(sporttype) VALUES(251)
IF @ShowBG = 1 INSERT INTO @sporttype(sporttype) VALUES(252)
	
IF @username <> ''
BEGIN
	SELECT @CustID = CustID
	FROM Customer c WITH(NOLOCK)
	WHERE 
		SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, LEN(c.username2)-CHARINDEX('$',c.username2)) = @username
		AND recommend IN (SELECT custid FROM @tmpAg)
		AND roleid = 1
		AND (@CurrencyID=0 OR (@CurrencyID<>0 AND  currency=@CurrencyID))
	
	IF ISNULL(@CustID,0)=0
	BEGIN
		SELECT @CustID = CustID
		FROM Customer WITH(NOLOCK)
		WHERE username = @username
			AND recommend IN (SELECT custid FROM @tmpAg)
			AND roleid = 1
			AND (@CurrencyID=0 OR (@CurrencyID<>0 AND  currency=@CurrencyID))
	END
	
	IF ISNULL(@CustID,0) =0 SET @CustID = -1
END	


CREATE TABLE #tmpRpt (
	Winlostdate SMALLDATETIME,
	Currency INT,
	OpeningBalance MONEY,
	Deposit MONEY,
	Withdrawal MONEY,
	AffiliateTransfer MONEY,
	Bonus MONEY,
	Adjustment MONEY,
	Turnover MONEY,	
	PendingFund MONEY,	
	Winloss MONEY,	
	ClosingBalance MONEY,
	Transfer3rd MONEY,
	DrawGame MONEY,	
	Turnover_BA MONEY,
	Comm_BA MONEY,
	PlayerComm MONEY,	
	AmountDueTo_BA MONEY
	)	

	
IF @fdate > @tdate OR @custid = -1
BEGIN
	SELECT
		'0' AS reporttype,
		b.*,
		NULL OpeningBalanceEUR,
		NULL  AS DepositEUR,
		NULL  AS WithdrawalEUR,
		NULL  AS AffiliateTransferEUR,
		NULL  AS BonusEUR,
		NULL  AS AdjustmentEUR,
		NULL  AS TurnoverEUR,
		NULL  AS PendingFundEUR,
		NULL  AS WinlossEUR,
		NULL  AS ClosingBalanceEUR,
		NULL  AS Transfer3rdEUR,
		NULL  AS DrawGameEUR,
		NULL   AS TurnoverBAEUR,
		NULL  AS CommBAEUR,
		NULL  AS PlayerCommEUR,
		NULL  AS AmountDueToBAEUR,
		--
		NULL OpeningBalanceUSD,
		NULL  AS DepositUSD,
		NULL  AS WithdrawalUSD,
		NULL  AS AffiliateTransferUSD,
		NULL  AS BonusUSD,
		NULL  AS AdjustmentUSD,
		NULL  AS TurnoverUSD,
		NULL  AS PendingFundUSD,
		NULL  AS WinlossUSD,
		NULL  AS ClosingBalanceUSD,
		NULL  AS Transfer3rdUSD,
		NULL  AS DrawGameUSD,
		NULL   AS TurnoverBAUSD,
		NULL  AS CommBAUSD,
		NULL  AS PlayerCommUSD,
		NULL  AS AmountDueToBAUSD
	FROM #tmpRpt b
	RETURN
END

IF @custid <> 0
BEGIN
	DECLARE @CutDate SMALLDATETIME
	SELECT @CutDate =  min(winlostdate) from bodb_report.dbo.rptdepwinlost with(nolock) 

	IF @fdate < @CutDate
	BEGIN 
		select @tmpdate = case when @tdate >= @CutDate then DATEADD(dd,-1,@CutDate) else @tdate end
		INSERT INTO #tmpRpt (
			Winlostdate, Currency, OpeningBalance, Deposit, Withdrawal, AffiliateTransfer, Bonus, 
			Adjustment, Turnover, PendingFund, Winloss,	ClosingBalance, Transfer3rd, DrawGame, 
			Turnover_BA, Comm_BA, PlayerComm, AmountDueTo_BA
		)
		SELECT 
			b.winlostdate
			,b.currency
			,SUM(isnull(b.openingbalance,0))
			,SUM(isnull(b.deposit,0))
			,SUM(isnull(b.withdrawal,0))
			,SUM(isnull(b.Aff2MemTransfer,0)) --AffiliateTransfer
			,SUM(isnull(b.Bonus,0))
			,SUM(isnull(b.Adjustment,0))
			,0 as Turnover
			,0 as PendingFund
			,0 as Winloss 
			,SUM(isnull(b.ClosingBalance,0))
			,SUM(isnull(b.Transfer3rd+b.Transfer3rdOthers,0))
			,0 as DrawGame
			,SUM(isnull(b.Turnover_BA,0))
			,SUM(isnull(b.Comm_BA,0))
			,0 as PlayerComm
			,SUM(isnull(b.AmountDueTo_BA,0))
		FROM bodb_report.dbo.rptdepwinlost_bk b with(nolock)			
		WHERE b.winlostdate between @fdate AND @tmpdate
			AND b.custid = @custid
		GROUP BY b.winlostdate, currency
		
		;WITH sourceDATA as (
			SELECT p.winlostdate
				,c.currency
				,SUM(isnull(p.turnover,0)) as Turnover
				,SUM(isnull(p.outstanding,0)) as PendingFund
				,SUM(isnull(p.winlost,0)) as Winloss 
				,SUM(isnull(p.drawTO,0)) as DrawGame
				,SUM(isnull(p.playercomm,0)) as PlayerComm
			FROM bodb_Report.dbo.rptDepWinlostByProduct_bk p WITH(NOLOCK)	
				INNER JOIN dbo.Customer c WITH(NOLOCK) on p.custid = c.custid
			WHERE p.winlostdate between @fdate AND @tmpdate
				AND p.custid = @custid
				AND p.sporttype in (SELECT sporttype FROM @sporttype)				    
			GROUP BY p.winlostdate,c.currency
		)
		UPDATE #tmpRpt
		SET turnover = isnull(s.turnover,0)
			,pendingfund = isnull(s.pendingfund,0)
			,winloss = isnull(s.winloss,0)
			,drawgame = isnull(s.drawgame,0)
			,playercomm = isnull(s.playercomm, 0)
		FROM sourceDATA s
		WHERE #tmpRpt.winlostdate = s.winlostdate
	END
	IF @tdate >= @CutDate
	BEGIN 
		select @tmpdate = case when @fdate < @CutDate then @CutDate else @fdate end
		INSERT INTO #tmpRpt (
			Winlostdate, Currency, OpeningBalance, Deposit, Withdrawal, AffiliateTransfer, Bonus, 
			Adjustment, Turnover, PendingFund, Winloss,	ClosingBalance, Transfer3rd, DrawGame, 
			Turnover_BA, Comm_BA, PlayerComm, AmountDueTo_BA
		)
		SELECT 
			b.winlostdate
			,b.currency
			,SUM(isnull(b.openingbalance,0))
			,SUM(isnull(b.deposit,0))
			,SUM(isnull(b.withdrawal,0))
			,SUM(isnull(b.Aff2MemTransfer,0)) --AffiliateTransfer
			,SUM(isnull(b.Bonus,0))
			,SUM(isnull(b.Adjustment,0))
			,0 as Turnover
			,0 as PendingFund
			,0 as Winloss 
			,SUM(isnull(b.ClosingBalance,0))
			,SUM(isnull(b.Transfer3rd+b.Transfer3rdOthers,0))
			,0 as DrawGame
			,SUM(isnull(b.Turnover_BA,0))
			,SUM(isnull(b.Comm_BA,0))
			,0 as PlayerComm
			,SUM(isnull(b.AmountDueTo_BA,0))
		FROM bodb_report.dbo.rptdepwinlost b with(nolock)			
		WHERE b.winlostdate between @tmpdate AND @tdate
			AND b.custid = @custid
		GROUP BY b.winlostdate, currency
		
		;WITH sourceDATA as (
			SELECT p.winlostdate
				,c.currency
				,SUM(isnull(p.turnover,0)) as Turnover
				,SUM(isnull(p.outstanding,0)) as PendingFund
				,SUM(isnull(p.winlost,0)) as Winloss 
				,SUM(isnull(p.drawTO,0)) as DrawGame
				,SUM(isnull(p.playercomm,0)) as PlayerComm
			FROM bodb_Report.dbo.rptDepWinlostByProduct p WITH(NOLOCK)	
				INNER JOIN dbo.Customer c WITH(NOLOCK) on p.custid = c.custid
			WHERE p.winlostdate between @tmpdate AND @tdate
				AND p.custid = @custid
				AND p.sporttype in (SELECT sporttype FROM @sporttype)				    
			GROUP BY p.winlostdate,c.currency
		)
		UPDATE #tmpRpt
		SET turnover = isnull(s.turnover,0)
			,pendingfund = isnull(s.pendingfund,0)
			,winloss = isnull(s.winloss,0)
			,drawgame = isnull(s.drawgame,0)
			,playercomm = isnull(s.playercomm, 0)
		FROM sourceDATA s
		WHERE #tmpRpt.winlostdate = s.winlostdate
	END
END
ELSE
BEGIN
	DECLARE @maxdate_SUM SMALLDATETIME
	SELECT @maxdate_SUM =  MAX(winlostdate) from bodb_report.dbo.rptdepwinlost_SUM with(nolock) 
	
	IF @fdate <= @maxdate_SUM
	BEGIN		
		select @tmpdate = case when @tdate > @maxdate_SUM then @maxdate_SUM else @tdate end
		INSERT INTO #tmpRpt (
			Winlostdate, Currency, OpeningBalance, Deposit, Withdrawal, AffiliateTransfer, Bonus, 
			Adjustment, Turnover, PendingFund, Winloss,	ClosingBalance, Transfer3rd, DrawGame, 
			Turnover_BA, Comm_BA, PlayerComm, AmountDueTo_BA
		)
		SELECT 
			b.winlostdate
			,b.currency
			,SUM(isnull(b.openingbalance,0))
			,SUM(isnull(b.deposit,0))
			,SUM(isnull(b.withdrawal,0))
			,SUM(isnull(b.Aff2MemTransfer,0)) --AffiliateTransfer
			,SUM(isnull(b.Bonus,0))
			,SUM(isnull(b.Adjustment,0))
			,0 as Turnover
			,0 as PendingFund
			,0 as Winloss 
			,SUM(isnull(b.ClosingBalance,0))
			,SUM(isnull(b.Transfer3rd+b.Transfer3rdOthers,0))
			,0 as DrawGame
			,SUM(isnull(b.Turnover_BA,0))
			,SUM(isnull(b.Comm_BA,0))
			,0 as PlayerComm
			,SUM(isnull(b.AmountDueTo_BA,0))
		FROM bodb_report.dbo.rptdepwinlost_SUM b with(nolock)			
		WHERE b.winlostdate between @fdate and @tmpdate	
			AND b.custid in (SELECT custid from @tmpAg)
		GROUP BY b.winlostdate, currency
		
		;WITH sourceDATA as (
			SELECT p.winlostdate
				,c.currency
				,SUM(isnull(p.turnover,0)) as Turnover
				,SUM(isnull(p.outstanding,0)) as PendingFund
				,SUM(isnull(p.winlost,0)) as Winloss 
				,SUM(isnull(p.drawTO,0)) as DrawGame
				,SUM(isnull(p.playercomm,0)) as PlayerComm
			FROM bodb_Report.dbo.rptdepwinlostbyproduct_SUM p WITH(NOLOCK)	
				INNER JOIN @tmpAg c on p.custid = c.custid
			WHERE p.winlostdate BETWEEN @fdate and @tmpdate					
				AND p.sporttype in (SELECT sporttype FROM @sporttype)				    
			GROUP BY p.winlostdate,c.currency
		)
		UPDATE #tmpRpt
		SET turnover = isnull(s.turnover,0)
			,pendingfund = isnull(s.pendingfund,0)
			,winloss = isnull(s.winloss,0)
			,drawgame = isnull(s.drawgame,0)
			,playercomm = isnull(s.playercomm, 0)
		FROM sourceDATA s
		WHERE #tmpRpt.winlostdate = s.winlostdate and #tmpRpt.currency = s.currency
	END

	IF @tdate > @maxdate_SUM
	BEGIN
		select @tmpdate = case when @fdate <= @maxdate_SUM then DATEADD(dd,1,@maxdate_SUM) else @fdate end		
		INSERT INTO #tmpRpt (
			Winlostdate, Currency, OpeningBalance, Deposit, Withdrawal, AffiliateTransfer, Bonus, 
			Adjustment, Turnover, PendingFund, Winloss,	ClosingBalance, Transfer3rd, DrawGame, 
			Turnover_BA, Comm_BA, PlayerComm, AmountDueTo_BA
		)
		SELECT 
			b.winlostdate
			,b.currency
			,SUM(isnull(b.openingbalance,0))
			,SUM(isnull(b.deposit,0))
			,SUM(isnull(b.withdrawal,0))
			,SUM(isnull(b.Aff2MemTransfer,0)) --AffiliateTransfer
			,SUM(isnull(b.Bonus,0))
			,SUM(isnull(b.Adjustment,0))
			,0 as Turnover
			,0 as PendingFund
			,0 as Winloss 
			,SUM(isnull(b.ClosingBalance,0))
			,SUM(isnull(b.Transfer3rd+b.Transfer3rdOthers,0))
			,0 as DrawGame
			,SUM(isnull(b.Turnover_BA,0))
			,SUM(isnull(b.Comm_BA,0))
			,0 as PlayerComm
			,SUM(isnull(b.AmountDueTo_BA,0))
		FROM bodb_report.dbo.rptdepwinlost b with(nolock)			
		WHERE b.winlostdate between @tmpdate and @tdate	
			AND b.recommend in (SELECT custid from @tmpAg)
		GROUP BY b.winlostdate, currency
		
		;WITH sourceDATA as (
			SELECT p.winlostdate
				,c.currency
				,SUM(isnull(p.turnover,0)) as Turnover
				,SUM(isnull(p.outstanding,0)) as PendingFund
				,SUM(isnull(p.winlost,0)) as Winloss 
				,SUM(isnull(p.drawTO,0)) as DrawGame
				,SUM(isnull(p.playercomm,0)) as PlayerComm
			FROM bodb_Report.dbo.rptDepWinlostByProduct p WITH(NOLOCK)	
				INNER JOIN dbo.Customer c WITH(NOLOCK) on p.custid = c.custid
			WHERE p.winlostdate BETWEEN @tmpdate and @tdate	
				AND c.roleid = 1
				AND c.recommend in (SELECT custid from @tmpAg)
				AND p.sporttype in (SELECT sporttype FROM @sporttype)				    
			GROUP BY p.winlostdate,c.currency
		)
		UPDATE #tmpRpt
		SET turnover = isnull(s.turnover,0)
			,pendingfund = isnull(s.pendingfund,0)
			,winloss = isnull(s.winloss,0)
			,drawgame = isnull(s.drawgame,0)
			,playercomm = isnull(s.playercomm, 0)
		FROM sourceDATA s
		WHERE #tmpRpt.winlostdate = s.winlostdate and #tmpRpt.currency = s.currency
	END
END	

SELECT * INTO #TempExchange
FROM Lrf_f_GetExchangeDaily(@FromDate,@ToDate)
WHERE exchangeid IN (SELECT DISTINCT Currency FROM #tmpRpt)

SELECT	
	b.winlostdate,	
    SUM(b.OpeningBalance) AS OpeningBalance,
	SUM(b.Deposit) AS Deposit,
	SUM(b.Withdrawal) AS Withdrawal,
	SUM(b.AffiliateTransfer) AS AffiliateTransfer,
	SUM(b.Bonus) AS Bonus,
	SUM(b.Adjustment) AS Adjustment,
	SUM(b.Turnover) AS Turnover,
	SUM(b.PendingFund) AS PendingFund,
	SUM(b.Winloss) AS Winloss,	
	SUM(b.ClosingBalance) AS ClosingBalance,
	SUM(b.Transfer3rd) AS Transfer3rd,
	SUM(b.DrawGame) AS DrawGame,
	CASE WHEN @showSB=1 THEN SUM(b.Turnover_BA) ELSE 0 END AS TurnoverBA,
	CASE WHEN @showSB=1 THEN SUM(b.Comm_BA) ELSE 0 END AS CommBA,
	SUM(b.PlayerComm) AS PlayerComm,
	CASE WHEN @showSB=1 THEN SUM(b.AmountDueTo_BA) ELSE 0 END AS AmountDueToBA,
	--- EUR
	CAST(SUM(b.OpeningBalance * e.EUR) AS MONEY) AS OpeningBalanceEUR,
	CAST(SUM(b.Deposit * e.EUR) AS MONEY) AS DepositEUR,
	CAST(SUM(b.Withdrawal * e.EUR) AS MONEY) AS WithdrawalEUR,
	CAST(SUM(b.AffiliateTransfer * e.EUR) AS MONEY) AS AffiliateTransferEUR,
	CAST(SUM(b.Bonus * e.EUR) AS MONEY) AS BonusEUR,
	CAST(SUM(b.Adjustment * e.EUR) AS MONEY) AS AdjustmentEUR,
	CAST(SUM(b.Turnover * e.EUR )AS MONEY) AS TurnoverEUR,
	CAST(SUM(b.PendingFund * e.EUR) AS MONEY) AS PendingFundEUR,
	CAST(SUM(b.Winloss * e.EUR) AS MONEY) AS WinlossEUR,
	CAST(SUM(b.ClosingBalance * e.EUR) AS MONEY) AS ClosingBalanceEUR,
	CAST(SUM(b.Transfer3rd * e.EUR) AS MONEY) AS Transfer3rdEUR,
	CAST(SUM(b.DrawGame * e.EUR) AS MONEY) AS DrawGameEUR,
	CAST(SUM(b.PlayerComm * e.EUR) AS MONEY) AS PlayerCommEUR,
	CASE WHEN @showSB=1 THEN CAST(SUM(b.Turnover_BA * e.EUR) AS MONEY) ELSE 0 END  AS TurnoverBAEUR,
	CASE WHEN @showSB=1 THEN CAST(SUM(b.Comm_BA * e.EUR) AS MONEY) ELSE 0 END AS CommBAEUR,
	CASE WHEN @showSB=1 THEN CAST(SUM(b.AmountDueTo_BA * e.EUR) AS MONEY) ELSE 0 END AS AmountDueToBAEUR,
	--- USD
	CAST(SUM(b.OpeningBalance * e.USD) AS MONEY) AS OpeningBalanceUSD,
	CAST(SUM(b.Deposit * e.USD) AS MONEY) AS DepositUSD,
	CAST(SUM(b.Withdrawal * e.USD) AS MONEY) AS WithdrawalUSD,
	CAST(SUM(b.AffiliateTransfer * e.USD) AS MONEY) AS AffiliateTransferUSD,
	CAST(SUM(b.Bonus * e.USD) AS MONEY) AS BonusUSD,
	CAST(SUM(b.Adjustment * e.USD) AS MONEY) AS AdjustmentUSD,
	CAST(SUM(b.Turnover * e.USD )AS MONEY) AS TurnoverUSD,
	CAST(SUM(b.PendingFund * e.USD) AS MONEY) AS PendingFundUSD,
	CAST(SUM(b.Winloss * e.USD) AS MONEY) AS WinlossUSD,
	CAST(SUM(b.ClosingBalance * e.USD) AS MONEY) AS ClosingBalanceUSD,
	CAST(SUM(b.Transfer3rd * e.USD) AS MONEY) AS Transfer3rdUSD,
	CAST(SUM(b.DrawGame * e.USD) AS MONEY) AS DrawGameUSD,
	CAST(SUM(b.PlayerComm * e.USD) AS MONEY) AS PlayerCommUSD,
	CASE WHEN @showSB=1 THEN CAST(SUM(b.Turnover_BA * e.USD) AS MONEY) ELSE 0 END  AS TurnoverBAUSD,
	CASE WHEN @showSB=1 THEN CAST(SUM(b.Comm_BA * e.USD) AS MONEY) ELSE 0 END AS CommBAUSD,
	CASE WHEN @showSB=1 THEN CAST(SUM(b.AmountDueTo_BA * e.USD) AS MONEY) ELSE 0 END AS AmountDueToBAUSD
	
FROM #tmpRpt b
	INNER JOIN #TempExchange e
	ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
GROUP BY b.winlostdate
		
DROP TABLE 	#tmpRpt
DROP TABLE 	#TempExchange
Go
GRANT EXECUTE ON [dbo].[Lrf_Rpt_TurnOver] TO [bodbLicenseeNet] 
GO
GRANT ALTER ON [dbo].[Lrf_Rpt_TurnOver] TO [vnteam] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_TurnOver] TO [vnteam] 