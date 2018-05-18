/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[LRF_Rpt_MicroGamingWinloss]
	@LicenseeID INT,
	@FromDate	SMALLDATETIME,  
	@ToDate		SMALLDATETIME,  
	@ReportType	TINYINT=1,  
	@AgentList	VARCHAR(MAX)
AS  
/*  Created: Jim
	Date: 2015-07-28
    Task : MicroGaming Win Loss report 
    DB: DBEXT.bodb02  
    Revisions:  
		  - 20150921@Jim: support RNG bettype
		  - 20160413@Victor: support MKK currency code [Redmine: #55745]
		  - 20160506@Francis: support MGC RNG progressive contribution [Redmine: #56248]
		  - 20170302@Paul: Get @AgentList by web instead of @UserId, @CurrencyID, @LicenseeID, Remove @excludeTest [Redmine: #71679]
		  - 20180509@Joseph: Remove cheat currency name for special currencies [RedmineID: #94845]
	Param's Explanation:  
	  + @excludeTest: remove currency UUS
	  + @ReportType: 1-Daily; 2-Monthly;  
*/ 
BEGIN
	CREATE TABLE #tmpResult (WinlostDate	  DATETIME  	
							 ,Currency 		  INT
							 ,TypeID		  TINYINT 
							 ,TypeName		  VARCHAR(200)								 
							 ,TurnOver 		  MONEY
							 ,TotalTrans	  INT	
							 ,Winlost  		  MONEY
							 ,LicenseeWinlost MONEY
							 ,ProgressiveContribution MONEY
							 ,ProgressivePayout MONEY
							 ,AmtDueToMGC MONEY
							)
	CREATE TABLE #Bettype (Bettype INT,TypeID TINYINT,TypeName VARCHAR(200)) 
	CREATE TABLE #TempAg  (CustId INT, Currency INT)
	DECLARE @MoveBetsDay DATETIME
			,@TempFromDate DATETIME
			,@TempToDate DATETIME	
	SELECT    
        @MoveBetsDay = MAX(eventdate)  
    FROM dbo.match14 WITH(NOLOCK)  
    		
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	
		INSERT INTO #TempAg(CustId, Currency)
		SELECT AgentId, Currency 
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;

	CREATE TABLE #currency(Currency INT)

	INSERT INTO #currency(Currency)
	SELECT DISTINCT Currency
	FROM #TempAg

	INSERT INTO #Bettype (Bettype,TypeID,TypeName)	
	EXEC LRF_MicroGamingWinloss_Bettype  @TypeID = 0
	
	--Get PayoutTrans data
	CREATE TABLE #PayoutTrans (Refno BIGINT, WinAmount MONEY)
	INSERT INTO #PayoutTrans(Refno, WinAmount)
	SELECT Refno, WinAmount FROM DBTXN.bodb02.dbo.PayoutTrans WITH (NOLOCK)
	
	-------------LA's part
	--Get PartyID from LicenseeID
	DECLARE @PartyID SMALLINT
	SELECT @PartyID = PartyID FROM bodb_licensee.dbo.OAS_Party WITH (NOLOCK) WHERE OldRefID = @LicenseeID AND PartyType = 1
	
	--Get ProductID and BettypeRef from Bettype
	CREATE TABLE #ProductBettypeRef (Bettype SMALLINT, BettypeRef SMALLINT, ProductID SMALLINT)
	INSERT INTO #ProductBettypeRef (Bettype, BettypeRef, ProductID)
	SELECT b.Bettype, sbr.BettypeRef,
		    CASE WHEN sbr.Sporttype = 203 THEN 14
				WHEN sbr.Sporttype = 205 THEN 17 ELSE 0 END AS ProductID 
	FROM #Bettype b
		INNER JOIN bodb_licensee.dbo.Sport_Bettype_Reference sbr WITH (NOLOCK) ON b.Bettype = sbr.Bettype
		
	--Get charge rate
	CREATE TABLE #ChargeRate (ProductID INT, Bettype INT, DI_Rate MONEY, FromDate SMALLDATETIME, ToDate SMALLDATETIME)
	INSERT INTO #ChargeRate (ProductID, Bettype, DI_Rate, FromDate, ToDate)
	SELECT ProductID, Bettype, DI_Rate, Fromdate, Todate
	FROM bodb_licensee.dbo.LA_f_ChargeInfo(@PartyID, @FromDate, @ToDate, 'MGCLC,MGCRNG', 'OA', 1)
	-------------
		
	IF @ToDate > @MoveBetsDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
			SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FromDate
				INSERT INTO #tmpResult ( Winlostdate
							 ,Currency 
							 ,TypeID	
							 ,TypeName
							 ,TurnOver 	
							 ,TotalTrans
							 ,Winlost  	
							 ,LicenseeWinlost
							 ,ProgressiveContribution
							 ,ProgressivePayout
							 ,AmtDueToMGC 
							)
				SELECT  b.winlostdate
						, t.currency
						, bet.TypeID
						, bet.TypeName
						, SUM(stake) AS turnover
						, COUNT(b.transid) AS TotalTrans
						, SUM(b.winlost - b.actual_stake) AS Winlost
						, SUM(- 1 * (b.winlost - b.actual_stake)) AS LicenseeWinlost
						, 0 AS ProgressiveContribution
						, 0 AS ProgressivePayout
						, SUM((b.actual_stake - b.winlost) * ISNULL(cr.DI_Rate,0)) AS AmtDueToMGC
				FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN #TempAg t ON b.recommend = t.custid AND t.Currency = b.Currency
				INNER JOIN #Bettype bet ON b.bettype = bet.bettype
				INNER JOIN #ProductBettypeRef pbr ON bet.bettype = pbr.Bettype
				LEFT JOIN #ChargeRate cr ON pbr.BettypeRef = cr.Bettype AND pbr.ProductID = cr.ProductID AND b.winlostdate BETWEEN cr.FromDate AND cr.ToDate
				WHERE b.winlostdate BETWEEN @TempFromDate AND @ToDate
							AND b.statusID IN (111, 112, 113)
							AND b.bettype NOT IN (2008,2009)
				GROUP BY b.winlostdate
						, t.currency
						, bet.TypeID
						, bet.TypeName
					
				--For MGC RNG		
				INSERT INTO #tmpResult ( Winlostdate
							 ,Currency 
							 ,TypeID	
							 ,TypeName
							 ,TurnOver 	
							 ,TotalTrans
							 ,Winlost  	
							 ,LicenseeWinlost 
							 ,ProgressiveContribution
							 ,ProgressivePayout
							 ,AmtDueToMGC 
							)		
				SELECT 	b.winlostdate
						, t.currency
						, bet.TypeID
						, bet.TypeName
						, SUM(stake) turnover
						, COUNT(b.transid) TotalTrans
						, SUM(b.winlost - b.actual_stake) AS Winlost
						, SUM(- 1 * (b.winlost - b.actual_stake)) AS LicenseeWinlost
						, SUM(ISNULL(ABS(b.stake) * r.Contribution,0)) AS ProgressiveContribution
						, SUM(ISNULL(p.WinAmount,0)) AS ProgressivePayout
						, SUM((b.actual_stake - b.winlost - ISNULL(ABS(b.stake) * r.Contribution,0)) * ISNULL(cr.DI_Rate,0)) AS AmtDueToMGC
				FROM dbo.bettransRnG b WITH (NOLOCK)
				INNER JOIN #TempAg t ON b.recommend = t.custid AND t.Currency = b.Currency
				INNER HASH JOIN #Bettype bet ON b.gameID  = bet.bettype
				INNER HASH JOIN #ProductBettypeRef pbr ON bet.bettype = pbr.Bettype
				LEFT HASH JOIN #ChargeRate cr ON pbr.BettypeRef = cr.Bettype AND pbr.ProductID = cr.ProductID AND b.winlostdate BETWEEN cr.FromDate AND cr.ToDate
				LEFT HASH JOIN bodb_LicenseeReport.dbo.view_MGCRNG_ProgressiveContribution_Rate r ON b.transdesc = r.ResourceID
				LEFT HASH JOIN #PayoutTrans p ON b.transid = p.RefNo
				WHERE b.winlostdate BETWEEN @TempFromDate AND @ToDate
							AND b.statusID IN (111, 112, 113)
							AND bet.bettype IN (2009,2008)
				GROUP BY b.winlostdate
						, t.currency
						, bet.TypeID
						, bet.TypeName									
	END	
	IF @FromDate <= @MoveBetsDay 
	BEGIN
		IF @ToDate >= @MoveBetsDay
				SET @TempToDate = @MoveBetsDay
			ELSE
				SET  @TempToDate = @ToDate
				
		INSERT INTO #tmpResult ( Winlostdate
								 ,Currency 
								 ,TypeID	
								 ,TypeName
								 ,TurnOver 	
								 ,TotalTrans
								 ,Winlost  	
								 ,LicenseeWinlost
     							 ,ProgressiveContribution
								 ,ProgressivePayout
								 ,AmtDueToMGC
								)
		SELECT 
		     b.rptDate AS Winlostdate		
		   , b.CurrencyID AS Currency
		   , bet.TypeID AS TypeID
		   , bet.TypeName AS TypeName
		   , SUM(b.TurnOver) AS TurnOver
		   , SUM(b.BetCount) AS TotalTrans
		   , SUM(b.Winloss)  AS Winlost
		   , -SUM(b.Winloss) AS LicenseeWinlost
		   , SUM(b.ProgressiveContribution) AS ProgressiveContribution
		   , SUM(b.ProgressivePayout) AS ProgressivePayout
		   , SUM((-b.Winloss - b.ProgressiveContribution) * ISNULL(cr.DI_Rate,0)) AS AmtDueToMGC
	FROM  bodb_LicenseeReport.dbo.rpt_ThirdPartyWL_ExtraGMT b  WITH (NOLOCK)
		  INNER JOIN #currency c ON b.CurrencyID = c.Currency
		  INNER JOIN #Bettype bet ON b.bettypeID  = bet.bettype
		  INNER JOIN #ProductBettypeRef pbr ON bet.bettype = pbr.Bettype
		  LEFT JOIN #ChargeRate cr ON pbr.BettypeRef = cr.Bettype AND pbr.ProductID = cr.ProductID AND b.RptDate BETWEEN cr.FromDate AND cr.ToDate
	WHERE b.rptDate BETWEEN @FromDate AND @TempToDate
		  AND b.StatusId NOT IN (-1,103)
		  AND b.SiteID = @LicenseeID
	GROUP BY 	b.rptDate  		
				,b.CurrencyID  
				,bet.TypeID
				 ,bet.TypeName
	
	END				 
	SELECT ExchangeDate
		   ,ExchangeId
		   ,Code
		   ,USD
		   ,EUR
		   ,GBP
	INTO #TempExchange 
	FROM Lrf_f_GetExchangeDaily(@FromDate, @ToDate)
	WHERE exchangeid IN (SELECT DISTINCT Currency FROM #tmpResult)
	
	
	SELECT  CASE WHEN @ReportType = 1 THEN CONVERT(VARCHAR(8),r.winlostdate,112)  
				 WHEN @ReportType = 2 THEN CONVERT(VARCHAR(6),r.winlostdate,112)  
				 ELSE '0' END winlostdate 
		   ,r.TypeID
		   ,r.TypeName
		   ,r.Currency	
		   ,SUM(r.TurnOver)   	 AS TurnOver
		   ,SUM(r.TotalTrans) 	 AS TotalTrans
		   ,SUM(r.Winlost)		 AS Winlost
		   ,SUM(r.LicenseeWinlost) AS LicenseeWinlost
		   ,SUM(r.ProgressiveContribution) AS ProgressiveContribution
		   ,SUM(r.ProgressivePayout) AS ProgressivePayout
		   ,SUM(r.LicenseeWinlost - r.ProgressiveContribution) AS LicenseeNetWin
		   ,SUM(r.AmtDueToMGC) AS AmtDueToMGC
		   ,SUM(r.ProgressiveContribution - r.ProgressivePayout) AS ProgressiveFee
		---USD
			,SUM(r.TurnOver*e.USD)   	 	AS TurnOverUSD
			,SUM(r.Winlost*e.USD)		 	AS WinlostUSD
			,SUM(r.LicenseeWinlost*e.USD)   AS LicenseeWinlostUSD
			,SUM(r.ProgressiveContribution*e.USD) AS ProgressiveContributionUSD
		    ,SUM(r.ProgressivePayout*e.USD) AS ProgressivePayoutUSD
		    ,SUM((r.LicenseeWinlost - r.ProgressiveContribution)*e.USD) AS LicenseeNetWinUSD
		    ,SUM(r.AmtDueToMGC*e.USD) AS AmtDueToMGCUSD
		    ,SUM((r.ProgressiveContribution - r.ProgressivePayout)*e.USD) AS ProgressiveFeeUSD
		---EUR
			,SUM(r.TurnOver*e.EUR)   	 	AS TurnOverEUR
			,SUM(r.Winlost*e.EUR)		 	AS WinlostEUR
			,SUM(r.LicenseeWinlost*e.EUR)   AS LicenseeWinlostEUR
			,SUM(r.ProgressiveContribution*e.EUR) AS ProgressiveContributionEUR
		    ,SUM(r.ProgressivePayout*e.EUR) AS ProgressivePayoutEUR
		    ,SUM((r.LicenseeWinlost - r.ProgressiveContribution)*e.EUR) AS LicenseeNetWinEUR
		    ,SUM(r.AmtDueToMGC*e.EUR) AS AmtDueToMGCEUR
		    ,SUM((r.ProgressiveContribution - r.ProgressivePayout)*e.EUR) AS ProgressiveFeeEUR
		---GBP
			,SUM(r.TurnOver*e.GBP)   	 	AS TurnOverGBP
			,SUM(r.Winlost*e.GBP)		 	AS WinlostGBP
			,SUM(r.LicenseeWinlost*e.GBP)   AS LicenseeWinlostGBP
			,SUM(r.ProgressiveContribution*e.GBP) AS ProgressiveContributionGBP
		    ,SUM(r.ProgressivePayout*e.GBP) AS ProgressivePayoutGBP
		    ,SUM((r.LicenseeWinlost - r.ProgressiveContribution)*e.GBP) AS LicenseeNetWinGBP
		    ,SUM(r.AmtDueToMGC*e.GBP) AS AmtDueToMGCGBP
		    ,SUM((r.ProgressiveContribution - r.ProgressivePayout)*e.GBP) AS ProgressiveFeeGBP
	FROM #tmpResult r
		INNER JOIN #TempExchange e ON r.Winlostdate = e.ExchangeDate AND r.currency = e.ExchangeId
	GROUP BY  CASE WHEN @ReportType = 1 THEN CONVERT(VARCHAR(8),r.winlostdate,112)  
				 WHEN @ReportType = 2 THEN CONVERT(VARCHAR(6),r.winlostdate,112)  
				 ELSE '0' END
			   ,r.TypeID
			   ,r.TypeName
		      ,r.Currency
	ORDER BY r.TypeID
			
	
	---------
	DROP TABLE #tmpResult
	DROP TABLE #TempAg
	DROP TABLE #TempExchange 
	DROP TABLE #Bettype 
	DROP TABLE #ProductBettypeRef
	DROP TABLE #ChargeRate
	DROP TABLE #PayoutTrans
	DROP TABLE #currency
END
GO