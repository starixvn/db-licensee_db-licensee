USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Lrf_Rpt_TurnOver]
	@FromDate       SMALLDATETIME,  
    @ToDate         SMALLDATETIME,   
    @username		VARCHAR(50) = NULL,
    @showSB			BIT = 0,  
    @ShowRB			BIT = 0,  
    @ShowNG			BIT = 0, 
    @ShowLC			BIT = 0,
    @ShowVS			BIT = 0,
    @ShowCS			BIT = 0, -- RNG Casino
    @ShowBG			BIT = 0, -- Bingo
    @ShowKN			BIT = 0, -- Keno 
	@ShowBT			BIT = 0, -- Bet Trade 
	@ShowAB			BIT = 0, -- Allbet
	@ShowMGCLC 		BIT = 0,
	@ShowMGCRnG 	BIT = 0,
	@ShowAGC		BIT = 0,
	@ShowVB			BIT = 0,
	@ShowCB			BIT = 0,
	@ShowFW 		BIT = 0,
	@ShowCO			BIT = 0,
	@AgentList		VARCHAR(MAX)
AS 
/*
Created: 20111017@Henry
Task : Report Turn Over
DB: DBACC/bodb02

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
   - 20130809@Jim: offer Virtual Horse Racing
   - 20131007@Jim: offer Virtual Tennis
   - 20140305@Florent: support Keno
   - 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
   - 20150127@Jim: support base on GBP Currency
   - 20150210@Jim: fix bug wrong condition when retrieve data from rptDepWinlostByProduct
   - 20150612@Jim: support MicroGaming
   - 20150630@Winnie: support Bet Trade
   - 20150921@Jim: Implement the changes on reports for AG Casino (#43172)
   - 20151108@Jim: Separated MicroGaming into 2 product
   - 20151228@Patrick: Exclude 901 & 902 for turnover
   - 20151228@Bobby: Implement RNG Casino sporttype(208,209,210)
   - 20160127@Bobby: #51625 - HotFix for perf - redundant codes c.recommend in ( .... )
   - 20160401@Percy: Support Voidbridge single wallet [Redmine: #55057]
   - 20160619@Jim: Allbet - Live Casino Integration for Licensees [Redmine: #59624]
   - 20160727@Jim:  LRF - Commercial terms changed for Bet Trade [Redmine: #61342]
   - 20160913@Jim : LRF - Implement Colossus Bets [Redmine: #63785]
   - 20161115@Jim: LRF - Integrate new product Fishing World [RedmineID : #66737]
   - 20170301@Paul: Get @AgentList by web instead of @UserId, @CurrencyID, @LicenseeID, Remove @excludeTest, @LicenseeType [Redmine: #71679]
   - 20170328@Harper: LRF - Integrate new product Cashout [#71727]

Param's Explanation:
    
*/

BEGIN
	SET NOCOUNT ON
   
	DECLARE @tmpAg   TABLE (custID INT, currency INT)
	DECLARE @fdate   SMALLDATETIME,
			@tdate   SMALLDATETIME,
			@tmpdate SMALLDATETIME,
			@CustID  INT
	DECLARE @sporttype TABLE (sporttype INT)
 
	SELECT	@CustID = 0,
			@username = LTRIM(RTRIM(ISNULL(@username,''))),
			@fdate = @fromdate,
			@tdate = @todate

	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	
		INSERT INTO @tmpAg(CustId, Currency)
		SELECT AgentId, Currency 
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;
    
	IF @ShowSB		= 1 INSERT INTO @sporttype(sporttype) VALUES(0)
	IF @ShowRB		= 1 INSERT INTO @sporttype(sporttype) VALUES(151) 
	IF @ShowNG		= 1 INSERT INTO @sporttype(sporttype) VALUES(161)
	IF @ShowLC		= 1 INSERT INTO @sporttype(sporttype) VALUES(162)
	IF @ShowVS		= 1 INSERT INTO @sporttype(sporttype) VALUES(180)
	IF @ShowCS		= 1 INSERT INTO @sporttype(sporttype) VALUES(251),(208),(209),(210)
	IF @ShowBG		= 1 INSERT INTO @sporttype(sporttype) VALUES(252)
	IF @ShowKN		= 1 INSERT INTO @sporttype(sporttype) VALUES(202)
	IF @ShowMGCLC	= 1 INSERT INTO @sporttype(sporttype) VALUES(203)
	IF @ShowMGCRnG	= 1 INSERT INTO @sporttype(sporttype) VALUES(205)
	IF @ShowAGC		= 1 INSERT INTO @sporttype(sporttype) VALUES(250)
	IF @ShowVB		= 1 INSERT INTO @sporttype(sporttype) VALUES(212)
	IF @ShowAB		= 1 INSERT INTO @sporttype(sporttype) VALUES(211)
	IF @ShowCB		= 1 INSERT INTO @sporttype(sporttype) VALUES(204)	
	IF @ShowBT		= 1 
	BEGIN
		INSERT INTO @sporttype(sporttype) VALUES(-2)
		INSERT INTO @sporttype(sporttype) VALUES(-3)
	END
	IF @ShowFW		= 1 INSERT INTO @sporttype(sporttype) VALUES(219)
	IF @ShowCO		= 1 INSERT INTO @sporttype(sporttype) VALUES(-6), (-7)

	IF @username <> ''
	BEGIN
		SELECT @CustID = CustID
		FROM Customer c WITH(NOLOCK)
		WHERE 
			SUBSTRING(c.username2,  CHARINDEX('$',c.username2) + 1, LEN(c.username2)-CHARINDEX('$',c.username2)) = @username
			AND recommend IN (SELECT custid FROM @tmpAg)
			AND roleid = 1
			AND currency IN (SELECT currency FROM @tmpAg)
    
		IF ISNULL(@CustID, 0) = 0
		BEGIN
			SELECT @CustID = CustID
			FROM Customer WITH(NOLOCK)
			WHERE username = @username
				AND recommend IN (SELECT DISTINCT custid FROM @tmpAg)
				AND roleid = 1
				AND currency IN (SELECT currency FROM @tmpAg)
		END
    
		IF ISNULL(@CustID, 0) = 0 SET @CustID = -1
	END    

	CREATE TABLE #tmpRpt
	(
		Winlostdate			SMALLDATETIME,
		Currency			INT,
		OpeningBalance		MONEY,
		Deposit				MONEY,
		Withdrawal			MONEY,
		AffiliateTransfer	MONEY,
		Bonus				MONEY,
		Adjustment			MONEY,
		Turnover			MONEY,    
		PendingFund			MONEY,    
		Winloss				MONEY,    
		ClosingBalance		MONEY,
		Transfer3rd			MONEY,
		DrawGame			MONEY,    
		Turnover_BA			MONEY,
		Comm_BA				MONEY,
		PlayerComm			MONEY,    
		AmountDueTo_BA		MONEY
	)    

	IF @fdate > @tdate OR @custid = -1
	BEGIN
		SELECT
			'0'  AS reporttype,
			b.*,
			NULL AS OpeningBalanceEUR,
			NULL AS DepositEUR,
			NULL AS WithdrawalEUR,
			NULL AS AffiliateTransferEUR,
			NULL AS BonusEUR,
			NULL AS AdjustmentEUR,
			NULL AS TurnoverEUR,
			NULL AS PendingFundEUR,
			NULL AS WinlossEUR,
			NULL AS ClosingBalanceEUR,
			NULL AS Transfer3rdEUR,
			NULL AS DrawGameEUR,
			NULL AS TurnoverBAEUR,
			NULL AS CommBAEUR,
			NULL AS PlayerCommEUR,
			NULL AS AmountDueToBAEUR,
			--
			NULL AS OpeningBalanceUSD,
			NULL AS DepositUSD,
			NULL AS WithdrawalUSD,
			NULL AS AffiliateTransferUSD,
			NULL AS BonusUSD,
			NULL AS AdjustmentUSD,
			NULL AS TurnoverUSD,
			NULL AS PendingFundUSD,
			NULL AS WinlossUSD,
			NULL AS ClosingBalanceUSD,
			NULL AS Transfer3rdUSD,
			NULL AS DrawGameUSD,
			NULL AS TurnoverBAUSD,
			NULL AS CommBAUSD,
			NULL AS PlayerCommUSD,
			NULL AS AmountDueToBAUSD,
			--
			NULL AS OpeningBalanceGBP,
			NULL AS DepositGBP,
			NULL AS WithdrawalGBP,
			NULL AS AffiliateTransferGBP,
			NULL AS BonusGBP,
			NULL AS AdjustmentGBP,
			NULL AS TurnoverGBP,
			NULL AS PendingFundGBP,
			NULL AS WinlossGBP,
			NULL AS ClosingBalanceGBP,
			NULL AS Transfer3rdGBP,
			NULL AS DrawGameGBP,
			NULL AS TurnoverBAGBP,
			NULL AS CommBAGBP,
			NULL AS PlayerCommGBP,
			NULL AS AmountDueToBAGBP
		FROM #tmpRpt b
	END
	ELSE
	BEGIN
		IF @custid <> 0
		BEGIN
			DECLARE @CutDate SMALLDATETIME
			SELECT  @CutDate =  MIN(winlostdate) FROM bodb_report.dbo.rptdepwinlost WITH (NOLOCK) 

			IF @fdate < @CutDate
			BEGIN 
				SELECT @tmpdate = CASE WHEN @tdate >= @CutDate THEN DATEADD(dd, -1, @CutDate) ELSE @tdate END
				INSERT INTO #tmpRpt
				(
					Winlostdate, Currency, OpeningBalance, Deposit, Withdrawal, AffiliateTransfer, Bonus, 
					Adjustment, Turnover, PendingFund, Winloss, ClosingBalance, Transfer3rd, DrawGame, 
					Turnover_BA, Comm_BA, PlayerComm, AmountDueTo_BA
				)
				SELECT 
					b.winlostdate,
					b.currency,
					SUM(ISNULL(b.openingbalance, 0)),
					SUM(ISNULL(b.deposit, 0)),
					SUM(ISNULL(b.withdrawal, 0)),
					SUM(ISNULL(b.Aff2MemTransfer, 0)), --AffiliateTransfer
					SUM(ISNULL(b.Bonus, 0)),
					SUM(ISNULL(b.Adjustment, 0)),
					0 AS Turnover,
					0 AS PendingFund,
					0 AS Winloss,
					SUM(ISNULL(b.ClosingBalance, 0)),
					SUM(ISNULL(b.Transfer3rd+b.Transfer3rdOthers, 0)),
					0 AS DrawGame,
					SUM(ISNULL(b.Turnover_BA, 0)),
					SUM(ISNULL(b.Comm_BA, 0)),
					0 AS PlayerComm,
					SUM(ISNULL(b.AmountDueTo_BA, 0))
				FROM
					bodb_report.dbo.rptdepwinlost_bk b WITH (NOLOCK) 
					INNER JOIN @tmpAg a ON b.recommend = a.CustId AND b.Currency = a.Currency
				WHERE b.winlostdate BETWEEN @fdate AND @tmpdate
					AND b.custid = @custid
				GROUP BY b.winlostdate, b.currency
        
				;WITH sourceDATA AS
				(
					SELECT
						p.winlostdate,
						c.currency,
						SUM(ISNULL(CASE WHEN p.sporttype IN (-2,-3,-5,-6,-7) THEN 0 ELSE p.turnover END, 0)) AS Turnover,
						SUM(ISNULL(p.outstanding, 0)) AS PendingFund,
						SUM(ISNULL(p.winlost, 0)) AS Winloss, 
						SUM(ISNULL(p.drawTO, 0)) AS DrawGame,
						SUM(ISNULL(p.playercomm, 0)) AS PlayerComm
					FROM
						bodb_Report.dbo.rptDepWinlostByProduct_bk p WITH (NOLOCK)    
						INNER JOIN dbo.Customer c WITH(NOLOCK) ON p.custid = c.custid
					WHERE
						p.winlostdate BETWEEN @fdate AND @tmpdate
						AND p.custid = @custid
						AND p.sporttype IN (SELECT sporttype FROM @sporttype)                    
					GROUP BY p.winlostdate, c.currency
				)
				UPDATE #tmpRpt
				SET turnover	= ISNULL(s.turnover,0),
					pendingfund = ISNULL(s.pendingfund,0),
					winloss		= ISNULL(s.winloss,0),
					drawgame	= ISNULL(s.drawgame,0),
					playercomm	= ISNULL(s.playercomm, 0)
				FROM sourceDATA s
				WHERE #tmpRpt.winlostdate = s.winlostdate
			END

			IF @tdate >= @CutDate
			BEGIN 
				SELECT @tmpdate = CASE WHEN @fdate < @CutDate THEN @CutDate ELSE @fdate END
				INSERT INTO #tmpRpt
				(
					Winlostdate, Currency, OpeningBalance, Deposit, Withdrawal, AffiliateTransfer, Bonus, 
					Adjustment, Turnover, PendingFund, Winloss, ClosingBalance, Transfer3rd, DrawGame, 
					Turnover_BA, Comm_BA, PlayerComm, AmountDueTo_BA
				)
				SELECT 
					b.winlostdate,
					b.currency,
					SUM(ISNULL(b.openingbalance, 0)),
					SUM(ISNULL(b.deposit, 0)),
					SUM(ISNULL(b.withdrawal, 0)),
					SUM(ISNULL(b.Aff2MemTransfer, 0)), --AffiliateTransfer
					SUM(ISNULL(b.Bonus, 0)),
					SUM(ISNULL(b.Adjustment, 0)),
					0 AS Turnover,
					0 AS PendingFund,
					0 AS Winloss,
					SUM(ISNULL(b.ClosingBalance, 0)),
					SUM(ISNULL(b.Transfer3rd+b.Transfer3rdOthers, 0)),
					0 AS DrawGame,
					SUM(ISNULL(b.Turnover_BA, 0)),
					SUM(ISNULL(b.Comm_BA, 0)),
					0 AS PlayerComm,
					SUM(ISNULL(b.AmountDueTo_BA, 0))
				FROM
					bodb_report.dbo.rptdepwinlost b WITH(NOLOCK)
					INNER JOIN @tmpAg a ON b.recommend = a.CustId AND b.Currency = a.Currency
				WHERE
					b.winlostdate BETWEEN @tmpdate AND @tdate
					AND b.custid = @custid
				GROUP BY b.winlostdate, b.currency
        
				;WITH sourceDATA AS
				(
					SELECT
						p.winlostdate,
						c.currency,
						SUM(ISNULL(CASE WHEN p.sporttype IN (-2,-3,-5,-6,-7) THEN 0 ELSE p.turnover END, 0)) AS Turnover,
						SUM(ISNULL(p.outstanding, 0)) AS PendingFund,
						SUM(ISNULL(p.winlost, 0)) AS Winloss,
						SUM(ISNULL(p.drawTO, 0)) AS DrawGame,
						SUM(ISNULL(p.playercomm, 0)) AS PlayerComm
					FROM
						bodb_Report.dbo.rptDepWinlostByProduct p WITH(NOLOCK)
						INNER JOIN dbo.Customer c WITH(NOLOCK) on p.custid = c.custid
					WHERE p.winlostdate between @tmpdate AND @tdate
						AND p.custid = @custid
						AND p.sporttype IN (SELECT sporttype FROM @sporttype)                    
					GROUP BY p.winlostdate,c.currency
				)
				UPDATE #tmpRpt
				SET turnover	= ISNULL(s.turnover,0),
					pendingfund = ISNULL(s.pendingfund,0),
					winloss		= ISNULL(s.winloss,0),
					drawgame	= ISNULL(s.drawgame,0),
					playercomm	= ISNULL(s.playercomm, 0)
				FROM sourceDATA s
				WHERE #tmpRpt.winlostdate = s.winlostdate
			END
		END
		ELSE
		BEGIN
			DECLARE @maxdate_SUM SMALLDATETIME
			SELECT @maxdate_SUM =  MAX(winlostdate) FROM bodb_report.dbo.rptdepwinlost_SUM WITH(NOLOCK)
    
			IF @fdate <= @maxdate_SUM
			BEGIN        
				SELECT @tmpdate = CASE WHEN @tdate > @maxdate_SUM THEN @maxdate_SUM ELSE @tdate END
				INSERT INTO #tmpRpt
				(
					Winlostdate, Currency, OpeningBalance, Deposit, Withdrawal, AffiliateTransfer, Bonus, 
					Adjustment, Turnover, PendingFund, Winloss, ClosingBalance, Transfer3rd, DrawGame, 
					Turnover_BA, Comm_BA, PlayerComm, AmountDueTo_BA
				)
				SELECT 
					b.winlostdate,
					b.currency,
					SUM(ISNULL(b.openingbalance,0)),
					SUM(ISNULL(b.deposit,0)),
					SUM(ISNULL(b.withdrawal,0)),
					SUM(ISNULL(b.Aff2MemTransfer,0)), --AffiliateTransfer
					SUM(ISNULL(b.Bonus,0)),
					SUM(ISNULL(b.Adjustment,0)),
					0 AS Turnover,
					0 AS PendingFund,
					0 AS Winloss,
					SUM(ISNULL(b.ClosingBalance,0)),
					SUM(ISNULL(b.Transfer3rd+b.Transfer3rdOthers,0)),
					0 AS DrawGame,
					SUM(ISNULL(b.Turnover_BA,0)),
					SUM(ISNULL(b.Comm_BA,0)),
					0 AS PlayerComm,
					SUM(ISNULL(b.AmountDueTo_BA,0))
				FROM
					bodb_report.dbo.rptdepwinlost_SUM b WITH(NOLOCK)
					INNER JOIN @tmpAg ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency	
				WHERE b.winlostdate BETWEEN @fdate AND @tmpdate    
				GROUP BY b.winlostdate, b.currency
        
				;WITH sourceDATA AS
				(
					SELECT
						p.winlostdate,
						c.currency,
						SUM(ISNULL(p.turnover,0)) AS Turnover,
						SUM(ISNULL(p.outstanding,0)) AS PendingFund,
						SUM(ISNULL(p.winlost,0)) AS Winloss,
						SUM(ISNULL(p.drawTO,0)) AS DrawGame,
						SUM(ISNULL(p.playercomm,0)) AS PlayerComm
					FROM
						bodb_Report.dbo.rptdepwinlostbyproduct_SUM p WITH(NOLOCK)    
						INNER JOIN @tmpAg c ON p.custid = c.custid AND p.Currency = c.Currency
					WHERE
						p.winlostdate BETWEEN @fdate AND @tmpdate                    
						AND p.sporttype IN (SELECT sporttype FROM @sporttype)                    
					GROUP BY p.winlostdate, c.currency
				)
				UPDATE #tmpRpt
				SET turnover	= ISNULL(s.turnover,0),
					pendingfund = ISNULL(s.pendingfund,0),
					winloss		= ISNULL(s.winloss,0),
					drawgame	= ISNULL(s.drawgame,0),
					playercomm	= ISNULL(s.playercomm,0)
				FROM sourceDATA s
				WHERE #tmpRpt.winlostdate = s.winlostdate AND #tmpRpt.currency = s.currency
			END

			IF @tdate > @maxdate_SUM
			BEGIN
				SELECT @tmpdate = CASE WHEN @fdate <= @maxdate_SUM THEN DATEADD(dd,1,@maxdate_SUM) ELSE @fdate END        
				INSERT INTO #tmpRpt
				(
					Winlostdate, Currency, OpeningBalance, Deposit, Withdrawal, AffiliateTransfer, Bonus, 
					Adjustment, Turnover, PendingFund, Winloss, ClosingBalance, Transfer3rd, DrawGame, 
					Turnover_BA, Comm_BA, PlayerComm, AmountDueTo_BA
				)
				SELECT 
					b.winlostdate,
					b.currency,
					SUM(ISNULL(b.openingbalance,0)),
					SUM(ISNULL(b.deposit,0)),
					SUM(ISNULL(b.withdrawal,0)),
					SUM(ISNULL(b.Aff2MemTransfer,0)), --AffiliateTransfer
					SUM(ISNULL(b.Bonus,0)),
					SUM(ISNULL(b.Adjustment,0)),
					0 AS Turnover,
					0 AS PendingFund,
					0 AS Winloss,
					SUM(ISNULL(b.ClosingBalance,0)),
					SUM(ISNULL(b.Transfer3rd+b.Transfer3rdOthers,0)),
					0 AS DrawGame,
					SUM(ISNULL(b.Turnover_BA,0)),
					SUM(ISNULL(b.Comm_BA,0)),
					0 AS PlayerComm,
					SUM(ISNULL(b.AmountDueTo_BA,0))
				FROM
					bodb_report.dbo.rptdepwinlost b WITH(NOLOCK)
					INNER JOIN @tmpAg a ON b.recommend = a.CustId AND b.Currency = a.Currency	
				WHERE b.winlostdate BETWEEN @tmpdate AND @tdate
				GROUP BY b.winlostdate, b.currency
        
				;WITH sourceDATA AS
				(
					SELECT
						p.winlostdate,
						c.currency,
						SUM(ISNULL(p.turnover,0)) AS Turnover,
						SUM(ISNULL(p.outstanding,0)) AS PendingFund,
						SUM(ISNULL(p.winlost,0)) AS Winloss ,
						SUM(ISNULL(p.drawTO,0)) AS DrawGame,
						SUM(ISNULL(p.playercomm,0)) AS PlayerComm
					FROM
						bodb_Report.dbo.rptDepWinlostByProduct p WITH(NOLOCK)    
						INNER JOIN dbo.Customer c WITH(NOLOCK) ON p.custid = c.custid
						INNER JOIN @tmpAg a ON p.Currency = a.Currency AND a.CustID = c.Recommend
					WHERE p.winlostdate BETWEEN @tmpdate and @tdate    
						AND c.roleid = 1
						AND p.sporttype IN (SELECT sporttype FROM @sporttype)                    
					GROUP BY p.winlostdate, c.currency
				)
				UPDATE #tmpRpt
				SET turnover	= ISNULL(s.turnover,0),
					pendingfund = ISNULL(s.pendingfund,0),
					winloss		= ISNULL(s.winloss,0),
					drawgame	= ISNULL(s.drawgame,0),
					playercomm	= ISNULL(s.playercomm, 0)
				FROM sourceDATA s
				WHERE #tmpRpt.winlostdate = s.winlostdate AND #tmpRpt.currency = s.currency
			END
		END    

		SELECT * INTO #TempExchange
		FROM Lrf_f_GetExchangeDaily(@FromDate, @ToDate)
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
			CASE WHEN @showSB=1 THEN CAST(SUM(b.AmountDueTo_BA * e.USD) AS MONEY) ELSE 0 END AS AmountDueToBAUSD,
			--- GBP
			CAST(SUM(b.OpeningBalance * e.GBP) AS MONEY) AS OpeningBalanceGBP,
			CAST(SUM(b.Deposit * e.GBP) AS MONEY) AS DepositGBP,
			CAST(SUM(b.Withdrawal * e.GBP) AS MONEY) AS WithdrawalGBP,
			CAST(SUM(b.AffiliateTransfer * e.GBP) AS MONEY) AS AffiliateTransferGBP,
			CAST(SUM(b.Bonus * e.GBP) AS MONEY) AS BonusGBP,
			CAST(SUM(b.Adjustment * e.GBP) AS MONEY) AS AdjustmentGBP,
			CAST(SUM(b.Turnover * e.GBP )AS MONEY) AS TurnoverGBP,
			CAST(SUM(b.PendingFund * e.GBP) AS MONEY) AS PendingFundGBP,
			CAST(SUM(b.Winloss * e.GBP) AS MONEY) AS WinlossGBP,
			CAST(SUM(b.ClosingBalance * e.GBP) AS MONEY) AS ClosingBalanceGBP,
			CAST(SUM(b.Transfer3rd * e.GBP) AS MONEY) AS Transfer3rdGBP,
			CAST(SUM(b.DrawGame * e.GBP) AS MONEY) AS DrawGameGBP,
			CAST(SUM(b.PlayerComm * e.GBP) AS MONEY) AS PlayerCommGBP,
			CASE WHEN @showSB=1 THEN CAST(SUM(b.Turnover_BA * e.GBP) AS MONEY) ELSE 0 END  AS TurnoverBAGBP,
			CASE WHEN @showSB=1 THEN CAST(SUM(b.Comm_BA * e.GBP) AS MONEY) ELSE 0 END AS CommBAGBP,
			CASE WHEN @showSB=1 THEN CAST(SUM(b.AmountDueTo_BA * e.GBP) AS MONEY) ELSE 0 END AS AmountDueToBAGBP
    
		FROM #tmpRpt b
			INNER JOIN #TempExchange e
			ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
		GROUP BY b.winlostdate
		DROP TABLE #TempExchange
	END
    
	DROP TABLE #tmpRpt

END
GO

GRANT EXECUTE ON [dbo].[Lrf_Rpt_TurnOver] TO [bodbLicenseeNet] 
GO
GRANT ALTER ON [dbo].[Lrf_Rpt_TurnOver] TO [vnteam] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_TurnOver] TO [vnteam]
GO 