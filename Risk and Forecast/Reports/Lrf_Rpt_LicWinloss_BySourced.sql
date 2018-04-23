/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_LicWinloss_BySourced]  	
	@LicenseeID		INT,
	@FromDate		SMALLDATETIME,  
	@ToDate			SMALLDATETIME,   
	@showSB			BIT = 0,  
	@ShowRB			BIT = 0,  
	@ShowNG			BIT = 0, 
	@ShowBA			BIT = 0,
	@ShowLC			BIT = 0,
	@ShowVS			BIT = 0,
	@ShowCS   		BIT = 0, -- RNG Casino
	@ShowBG   		BIT = 0, -- Bingo 
	@ShowKN			BIT = 0, -- Keno
	@showMGCLC		BIT = 0, -- MicroGamming
	@showMGCRnG		BIT = 0, -- MicroGamming
	@ShowBT 		BIT = 0, -- licenseeWLBT
	@ShowAGC		BIT = 0, -- AGCasino
	@ShowVB			BIT = 0, -- Voidbridge
	@ShowAB			BIT = 0, -- Allbet
	@ShowFW			BIT = 0, -- Fishing World
	@ShowCO			BIT = 0, -- Cash Out
	@ShowVS2		BIT = 0, -- Bet Radar Virtual Sports
	@ShowLT			BIT = 0, -- Lottery
	@ReportType		TINYINT = 1,  
	@MoveBetsDay	SMALLDATETIME,
	@IsOld			BIT = 0,
	@drawfilter		SMALLINT = 1,
	@AgentList		VARCHAR(MAX)
AS 
/*  Created: 20180312@Harper  
    Description: LAP - Customise backend for Ivorybet and Opal88
	Source: Lrf_Rpt_LicWinloss
    DB: DB052.bodb02  
   
    Revisions:  
		- 20180312@Harper: Created new Licensee Winloss SP for Ivorybet and Opal88 [RedmineID: #91738]
		- 20180420@Amanda: Include more cash out tickets [RedmineID: #93919]

	Param's Explanation:  
	  + @ReportType: 1-Daily; 2-Monthly;  
	  +	@drawfilter: 'No Draw' filter is supportted (1:Normal 2:No Draw 3:No Draw for Turnover only)
	  + @IsOld: 0 - query in table rptLicWinloss, 1 - query in table rptLicWinloss_old. 	  
	  + @MoveBetsDay: The day we move tickets to bettrans14
	  + @AgentList: xml structure
					  <ROOT>
					   <Agent AgentId="12345" Currency="3"/>  
					   <Agent AgentId="12345" Currency="5"/>  
					  </ROOT>
	exec Lrf_Rpt_LicWinloss_BySourced @reporttype=1,@licenseeid=185,@AgentList=N'<ROOT><Agent AgentId="24942757" Currency="9"/><Agent AgentId="0" Currency="13"/><Agent AgentId="24942816" Currency="41"/><Agent AgentId="0" Currency="15"/><Agent AgentId="24942841" Currency="51"/><Agent AgentId="0" Currency="51"/><Agent AgentId="24942791" Currency="2"/><Agent AgentId="0" Currency="2"/><Agent AgentId="24942774" Currency="4"/><Agent AgentId="0" Currency="4"/></ROOT>',@fromdate='2018-01-01 00:00:00',@todate='2018-03-01 00:00:00',@isold=0,@drawfilter=1,@movebetsday='2018-03-03 00:00:00',@showSB=1,@showNG=1
*/  
BEGIN  

	SET NOCOUNT ON  

	CREATE TABLE #SAgWinLoss
	(  
		winlostdate			DATETIME,  
		Currency			INT,
		ProductCode			VARCHAR(10),
		Turnover			MONEY,
		BTActualStake		MONEY,
		Winlost				MONEY,
		LicenseeWL			MONEY,
		AmtDueToBA			MONEY,   
		AmtDueToRB			MONEY,
		CommBA				MONEY,   
		CommRB				MONEY,  
		PlayerComm			MONEY,
		Betcount			BIGINT,
		licenseeWLBT		MONEY,   
		BetTradeComm		MONEY,  
		WLBetTicket			MONEY, 	
		WLBoughtTicket		MONEY,
		BuyBackAmtSB		MONEY,
		BuyBackAmtBA		MONEY,
		CashOutComm			MONEY
	) 
 

	DECLARE @TempCurrency		TABLE(ID INT IDENTITY, currency INT)  
	DECLARE @SourceIDs			TABLE (LicenseeID INT, CustID INT, CurrencyID INT, RoleID TINYINT, EffectiveDate SMALLDATETIME)
	CREATE TABLE #tmpCust		(CustID INT, AgentID INT, currency INT, EffectiveDate SMALLDATETIME)

	DECLARE @VNDCurrencyName	VARCHAR(20)
	DECLARE @bettype			TABLE (bettype INT PRIMARY KEY, ProductCode VARCHAR(10))
	DECLARE @sporttype			TABLE (sporttype INT, ProductCode VARCHAR(10))
	DECLARE @LicenseeName		VARCHAR(50)
	DECLARE @WLBetTicket		TABLE (winlostdate DATETIME, currency INT, WLBetTicket MONEY)
	DECLARE @ProductList		VARCHAR (500)

	DECLARE @_FromDate SMALLDATETIME, @_ToDate SMALLDATETIME
	SELECT @_FromDate = @FromDate, @_ToDate = @ToDate

	SELECT @VNDCurrencyName = currency FROM exchange (NOLOCK) WHERE ExchangeId = 51

	DECLARE @IsTest BIT = 0
	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)
	
	-- Get SourceID: Agent for Ivory, Member for Opal88
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
				,@AgentList
		INSERT INTO @TempCurrency (currency)
		SELECT DISTINCT Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
				,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;
	
	INSERT INTO @SourceIDs (LicenseeID, CustID, RoleID, CurrencyID, EffectiveDate)	
	EXEC bodb_Licensee.dbo.LRF_LicenseeSourcedSel @LicenseeID = @LicenseeID, @ToDate = @_ToDate

	DELETE s
	FROM @SourceIDs s
	WHERE NOT EXISTS (SELECT 1 FROM @TempCurrency c WHERE s.CurrencyID = c.currency)

	INSERT INTO #tmpCust (CustID, AgentID, Currency, EffectiveDate)	
	SELECT NULL, lc.CustID, lc.CurrencyID, lc.EffectiveDate
	FROM @SourceIDs lc
	WHERE lc.RoleID = 2 -- Agent
	UNION ALL
	SELECT a.CustID, c.recommend, a.CurrencyID, EffectiveDate
	FROM @SourceIDs a
		INNER JOIN dbo.custInfo c WITH (NOLOCK) ON a.CustID = c.custid
	WHERE a.RoleID = 1 -- Member
	
	SELECT @LicenseeName = LicenseeName FROM bodb_Licensee.dbo.Licensees (NOLOCK) WHERE LicenseeID = @LicenseeID 

	IF @ShowSB = 1  
	BEGIN  
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'SB', 'SB')		
	END  

	IF @ShowRB = 1  
	BEGIN  
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'RB', 'RB')		
	END  

	IF @ShowNG = 1
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'NG', 'NG')		
	END 

	IF @ShowLC = 1
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'LC', 'LC')		
	END

	IF @ShowVS = 1
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'VS', 'VS')
	END

	IF @ShowCS = 1 -- RNG Casino
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'CS', 'CS')
	END

	IF @ShowBG = 1 -- Bingo
	BEGIN 
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'BG', 'BG')
	END 

	IF @ShowKN = 1 -- Keno
	BEGIN 
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'KN', 'KN')
	END

	IF @showMGCLC = 1 -- MicroGamming
	BEGIN 
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'MGCLC', 'MGCLC')
	END 

	IF @showMGCRnG = 1 -- MicroGamming
	BEGIN 
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'MGCRNG', 'MGCRNG')
	END

	IF @ShowAGC = 1 -- AGCasino
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'AGC', 'AGC')
	END

	IF @ShowVB = 1
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'VB', 'VB')
	END
	IF @ShowAB = 1
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'AB', 'AB')
	END

	IF @ShowFW = 1
	BEGIN 
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'FW', 'FW')
	END

	IF @ShowVS2 = 1 -- Betradar Virtual Sports
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'VS2', 'VS2')
	END
	
	IF @ShowLT = 1 -- Lottery
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'LT', 'LT')
	END

	IF LEN(ISNULL(@ProductList, '')) > 0 
	BEGIN
		-- Insert Bettype
		INSERT INTO @bettype ( bettype, ProductCode )
		SELECT DISTINCT BetType, ProductPrefix
		FROM f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', @ProductList, @IsTest)

		IF CHARINDEX('CS', @ProductList) > 0
			DELETE @bettype
			WHERE bettype = 72 AND ProductCode = 'CS'

		IF CHARINDEX('SB', @ProductList) > 0 OR CHARINDEX('RB', @ProductList) > 0
			DELETE @bettype
			WHERE ProductCode IN ('SB', 'RB')
		
		-- Insert Sport Type
		INSERT INTO @sporttype ( sporttype, ProductCode )
		SELECT DISTINCT sporttype, ProductCode
		FROM f_LicWinLoss_ProductSportType_Sel(@ProductList)

	END	

	DECLARE @TempFromDate	DATETIME,
			@TempToDate		DATETIME,
			@MaxOldDate		DATETIME

	IF @_ToDate > @MoveBetsDay
	BEGIN
		IF @_FromDate <= @MoveBetsDay 
			SET @TempFromDate = DATEADD(DAY,1,@MoveBetsDay)
		ELSE
			SET @TempFromDate = @_FromDate
	
		DECLARE @transid BIGINT
		SELECT TOP 1 @transid = transid FROM dbo.bettrans WITH(NOLOCK) WHERE matchid > 0 ORDER BY transid

		IF @ShowBA = 1 
		BEGIN
			;WITH CTE AS
			(
				SELECT DISTINCT transid
				FROM
					bodb_licensee.dbo.LicenseeBATransaction_active BA WITH(NOLOCK)
					INNER JOIN #tmpCust r ON BA.recommend = r.AgentID
				UNION
				SELECT NULL
			)
			INSERT INTO #SAgWinLoss
			(  
				winlostdate, Currency, ProductCode, Turnover, BTActualStake,
				Winlost, LicenseeWL, AmtDueToBA, AmtDueToRB, CommBA,
				CommRB, PlayerComm, Betcount, licenseeWLBT, BetTradeComm,  
				WLBetTicket, WLBoughtTicket, BuyBackAmtSB, BuyBackAmtBA, CashOutComm
			)
			SELECT   
				b.winlostdate,  
				tma.currency,
				'BA',
				SUM(CASE WHEN RAND() + 1 > 0 THEN stake ELSE 0 END
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN (b.statusID = 112 OR b.statusID = 113) AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
							ELSE 1 END
					ELSE 1 END
				) AS turnover, 
				0 AS BTActualStake,
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.winlost-b.actual_stake ELSE 0 END) AS Winlost,
				0 AS LicenseeWL,
				-SUM(CASE WHEN RAND() + 1 > 0 THEN b.winlost-b.actual_stake+awinlost+comm ELSE 0 END) AS AmountDueToBA,
				0 AS AmountDueToRB,
				SUM(CASE WHEN RAND() + 1 > 0 THEN comm ELSE 0 END) AS CommBA,
				0 AS CommRB,
				SUM(ISNULL(CASE WHEN RAND() + 1 > 0 THEN b.playercomm ELSE 0 END,0)) AS PlayerComm,
				COUNT(CASE WHEN RAND() + 1 > 0 AND @drawfilter = 2 AND b.statusID = 111 THEN NULL ELSE b.transid END)AS BetCount,
				0 AS licenseeWLBT,
				0 AS BetTradeComm,			
				SUM(CASE WHEN RAND() + 1 > 0 AND b.betdaqid = 0 THEN (b.winlost-b.actual_stake) ELSE 0 END) AS WLBetTicket,
				0 AS WLBoughtTicket,
				0 AS BuyBackAmtSB,
				0 AS BuyBackAmtBA,
				0 AS CashOutComm
			FROM
				CTE
				INNER JOIN dbo.bettrans b WITH (NOLOCK) ON CTE.transid = b.transid
				INNER JOIN #tmpCust tma ON tma.AgentID = b.recommend AND b.currency = tma.currency AND b.winlostdate >= tma.EffectiveDate
			WHERE (tma.CustID IS NULL OR b.custid = tma.CustID)
				AND b.winlostdate BETWEEN @TempFromDate AND @_ToDate				
				AND b.statusID  IN (111, 112, 113)
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
			GROUP BY b.winlostdate, tma.currency 
		END
	
		IF @ShowSB = 1
		BEGIN
			INSERT INTO #SAgWinLoss
			(  
				winlostdate, Currency, ProductCode, Turnover, BTActualStake,
				Winlost, LicenseeWL, AmtDueToBA, AmtDueToRB, CommBA,
				CommRB, PlayerComm, Betcount, licenseeWLBT, BetTradeComm,  
				WLBetTicket, WLBoughtTicket, BuyBackAmtSB, BuyBackAmtBA, CashOutComm
			)
			SELECT   
				b.winlostdate,  
				a.currency,
				'SB',
				SUM(CASE WHEN RAND() + 1 > 0 THEN stake ELSE 0 END
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN (b.statusID = 112 OR b.statusID = 113) AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
							ELSE 1 END
					ELSE 1 END
				) AS turnover,
				0 AS BTActualStake,
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.winlost-b.actual_stake ELSE 0 END) AS Winlost,
				-SUM(CASE WHEN RAND() + 1 > 0 THEN b.winlost-b.actual_stake ELSE 0 END) AS LicenseeWL,
				0 AS AmountDueToBA,
				0 AS AmountDueToRB,
				0 AS CommBA,
				0 AS CommRB,
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.playerComm ELSE 0 END) AS PlayerComm,
				COUNT(CASE WHEN RAND() + 1 > 0 AND @drawfilter = 2 AND b.statusID = 111 THEN NULL ELSE b.transid END)AS BetCount,
				0 AS licenseeWLBT,
				0 AS BetTradeComm,	
				SUM(CASE WHEN RAND() + 1 > 0 AND b.betdaqid = 0 THEN b.winlost-b.actual_stake ELSE 0 END) AS WLBetTicket,
				0 AS WLBoughtTicket,
				0 AS BuyBackAmtSB,
				0 AS BuyBackAmtBA,
				0 AS CashOutComm
			FROM 
				Bettrans b WITH (NOLOCK)
				INNER JOIN #tmpCust a ON b.recommend = a.AgentID AND b.currency = a.currency AND b.winlostdate >= a.EffectiveDate
			WHERE (a.CustID IS NULL OR b.custid = a.CustID)
				AND b.winlostdate BETWEEN @TempFromDate AND @_ToDate
				AND  
				(
					b.bettype < 31
					OR b.bettype BETWEEN 121 AND 999
					OR b.Bettype BETWEEN 1301 and 1399 --new tennis's bettypes
				)
				AND b.statusID IN (111, 112, 113)
				AND b.tpositiontaking <> 0
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND b.transid >= @transid
			GROUP BY b.winlostdate, a.currency --, statusID, b.bettype
		END

		IF @ShowBT = 1
		BEGIN
			INSERT INTO #SAgWinLoss
			(  
				winlostdate, Currency, ProductCode, Turnover, BTActualStake,
				Winlost, LicenseeWL, AmtDueToBA, AmtDueToRB, CommBA,
				CommRB, PlayerComm, Betcount, licenseeWLBT, BetTradeComm,  
				WLBetTicket, WLBoughtTicket, BuyBackAmtSB, BuyBackAmtBA, CashOutComm
			)
			SELECT   
				b.winlostdate,  
				a.currency,
				'BT',
				0 turnover,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 902 THEN b.winlost ELSE 0 END) AS BTActualStake,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 903 THEN 0 ELSE b.winlost-b.actual_stake END) AS Winlost,
				0 AS LicenseeWL,
				0 AS AmountDueToBA,
				0 AS AmountDueToRB,
				0 AS CommBA,
				0 AS CommRB,
				0 AS PlayerComm,
				COUNT(CASE WHEN RAND() + 1 > 0 AND ((b.bettype = 903) OR (@drawfilter = 2 AND b.statusID = 111)) THEN NULL ELSE b.transid END) AS BetCount,
				-SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype IN (901, 902) THEN b.winlost-b.actual_stake ELSE 0 END) AS licenseeWLBT,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 903 THEN b.awinlost ELSE 0 END) AS BetTradeComm,
				0 WLBetTicket,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 902 THEN b.winlost-b.actual_stake ELSE 0 END) AS WLBoughtTicket,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 902 AND transid2 = 0 THEN b.actual_stake ELSE 0 END) AS BuyBackAmtSB,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 902 AND transid2 = 1 THEN b.actual_stake ELSE 0 END) AS BuyBackAmtBA,
				0 AS CashOutComm
			FROM 
				Bettrans b WITH (NOLOCK)
				INNER JOIN #tmpCust a ON b.recommend = a.AgentID AND b.currency = a.currency AND b.winlostdate >= a.EffectiveDate
			WHERE (a.CustID IS NULL OR b.custid = a.CustID)
				AND b.winlostdate BETWEEN @TempFromDate AND @_ToDate
				AND b.bettype IN (901, 902, 903)
				AND b.statusID IN (111, 112, 113)
				AND b.transid >= @transid
			GROUP BY b.winlostdate, a.currency  
		END

		IF @ShowCO = 1
		BEGIN
			INSERT INTO #SAgWinLoss
			(  
				winlostdate, Currency, ProductCode, Turnover, BTActualStake,
				Winlost, LicenseeWL, AmtDueToBA, AmtDueToRB, CommBA,
				CommRB, PlayerComm, Betcount, licenseeWLBT, BetTradeComm,  
				WLBetTicket, WLBoughtTicket, BuyBackAmtSB, BuyBackAmtBA, CashOutComm
			)
			SELECT   
				b.winlostdate,  
				a.currency,
				'CO',
				0 AS turnover,
				0 AS BTActualStake,
				SUM(CASE WHEN b.bettype = 913 THEN 0 ELSE b.winlost - b.actual_stake END) AS Winlost,
				- SUM(CASE WHEN b.bettype = 913 THEN 0 ELSE b.winlost - b.actual_stake END) AS LicenseeWL,
				0 AS AmountDueToBA,
				0 AS AmountDueToRB,
				0 AS CommBA,
				0 AS CommRB,
				0 AS PlayerComm,
				SUM(CASE WHEN b.bettype = 913 THEN 0 ELSE 1 END) AS BetCount,
				0 AS licenseeWLBT,
				0 AS BetTradeComm,
				0 WLBetTicket,
				0 AS WLBoughtTicket,
				0 AS BuyBackAmtSB,
				0 AS BuyBackAmtBA,
				SUM(CASE WHEN b.bettype = 913 THEN b.awinlost ELSE 0 END) AS CashOutComm
			FROM 
				Bettrans b WITH (NOLOCK)
				INNER JOIN #tmpCust a ON b.recommend = a.AgentID AND b.currency = a.currency AND b.winlostdate >= a.EffectiveDate
			WHERE (a.CustID IS NULL OR b.custid = a.CustID)
				AND b.winlostdate BETWEEN @TempFromDate AND @_ToDate
				AND b.bettype IN (911, 912, 913)
				AND b.statusID IN (111, 112, 113)
				AND b.transid >= @transid
			GROUP BY b.winlostdate, a.currency  
		END

		IF 1 IN (@ShowNG, @ShowLC, @ShowVS, @ShowCS, @ShowBG, @ShowKN, @showMGCLC, @showMGCRnG, @ShowAGC, @ShowVB, @ShowAB, @ShowFW, @ShowVS2, @ShowLT)
		BEGIN
			INSERT INTO #SAgWinLoss
			(  
				winlostdate, Currency, ProductCode, Turnover, BTActualStake,
				Winlost, LicenseeWL, AmtDueToBA, AmtDueToRB, CommBA,
				CommRB, PlayerComm, Betcount, licenseeWLBT, BetTradeComm,  
				WLBetTicket, WLBoughtTicket, BuyBackAmtSB, BuyBackAmtBA, CashOutComm
			)
			SELECT   
				b.winlostdate,  
				a.currency,
				bt.ProductCode,
				SUM(CASE WHEN RAND() + 1 > 0 AND @drawfilter IN (2,3) AND b.statusID = 111 THEN 0 ELSE stake END) AS turnover,
				0 AS BTActualStake,
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.winlost-b.actual_stake ELSE 0 END) AS Winlost,
				-SUM(CASE WHEN RAND() + 1 > 0 THEN b.winlost - b.actual_stake ELSE 0 END) AS LicenseeWL,
				0 AS AmountDueToBA,
				0 AS AmountDueToRB,
				0 AS CommBA,
				0 AS CommRB,
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.playerComm ELSE 0 END) AS PlayerComm,
				COUNT(CASE WHEN RAND() + 1 > 0 AND @drawfilter = 2 AND b.statusID = 111 THEN NULL ELSE b.transid END) AS BetCount,
				0 AS licenseeWLBT,
				0 AS BetTradeComm,	
				0 AS WLBetTicket,
				0 AS WLBoughtTicket,
				0 AS BuyBackAmtSB,
				0 AS BuyBackAmtBA,
				0 AS CashOutComm
			FROM 
				Bettrans b WITH (NOLOCK)
				INNER JOIN #tmpCust a   ON b.recommend = a.AgentID AND b.Currency = a.Currency AND b.winlostdate >= a.EffectiveDate
				INNER JOIN @bettype bt ON b.bettype = bt.bettype
			WHERE (a.CustID IS NULL OR b.custid = a.CustID)
				AND b.winlostdate BETWEEN @TempFromDate AND @_ToDate
				AND b.statusID IN (111, 112, 113)
				AND b.transid >= @transid
			GROUP BY   
				b.winlostdate, a.currency,  
				bt.ProductCode
		END
	
		IF @ShowRB = 1
		BEGIN
			INSERT INTO #SAgWinLoss
			(  
				winlostdate, Currency, ProductCode, Turnover, BTActualStake,
				Winlost, LicenseeWL, AmtDueToBA, AmtDueToRB, CommBA,
				CommRB, PlayerComm, Betcount, licenseeWLBT, BetTradeComm,  
				WLBetTicket, WLBoughtTicket, BuyBackAmtSB, BuyBackAmtBA, CashOutComm
			)
			SELECT   
				b.winlostdate,  
				a.currency,
				'RB',
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype IN (33, 43) AND liveawayscore = 0 THEN stake/2 ELSE stake END 
					* CASE WHEN RAND() + 1 > 0 AND @drawfilter IN (2,3) AND b.statusID = 111 THEN 0 ELSE 1 END
				) AS turnover,
				0 AS BTActualStake,
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.winlost-b.actual_stake ELSE 0 END) AS Winlost,
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.awinlost ELSE 0 END) AS LicenseeWL,
				0 AS AmountDueToBA,
				-SUM((CASE WHEN RAND() + 1 > 0 THEN b.winlost-b.actual_stake+awinlost+comm ELSE 0 END)) AS AmountDueToRB,
				0 AS CommBA,
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.comm ELSE 0 END) AS CommRB,
				SUM(ISNULL(CASE WHEN RAND() + 1 > 0 THEN b.PlayerComm ELSE 0 END,0)) AS PlayerComm,
				COUNT(CASE WHEN RAND() + 1 > 0 AND @drawfilter = 2 AND b.statusID = 111 THEN NULL ELSE b.transid END) AS BetCount,
				0 AS licenseeWLBT,
				0 AS BetTradeComm,	
				0 AS WLBetTicket,
				0 AS WLBoughtTicket,
				0 AS BuyBackAmtSB,
				0 AS BuyBackAmtBA,
				0 AS CashOutComm
			FROM 
				dbo.Bettrans b WITH (NOLOCK)
			INNER JOIN #tmpCust a ON b.recommend = a.AgentID AND b.currency = a.currency AND b.winlostdate >= a.EffectiveDate
			WHERE (a.CustID IS NULL OR b.custid = a.CustID)
				AND b.winlostdate BETWEEN @TempFromDate AND @_ToDate
				AND bettype BETWEEN 31 AND 33
				AND b.statusID IN (111, 112, 113)
				AND b.transid >= @transid
			GROUP BY b.winlostdate, a.currency
		END
	END  

	IF @_FromDate <= @MoveBetsDay 
	BEGIN
		IF @_ToDate >= @MoveBetsDay
				SET @TempToDate = @MoveBetsDay
			ELSE
				SET @TempToDate = @_ToDate
	
		DECLARE @CustBettrade TABLE (recommend INT, custid INT, currency INT)
		INSERT INTO @CustBettrade
		SELECT c.recommend, bt.custID, bt.currency 
		FROM f_GetBetTradeCustList(@LicenseeName) bt
		INNER JOIN dbo.Customer c WITH(NOLOCK) ON bt.custID = c.custid AND c.roleid = 1

		IF @ShowBA = 1 
		BEGIN
			INSERT INTO #SAgWinLoss  
			(  
				winlostdate, Currency, ProductCode, Turnover, BTActualStake,
				Winlost, LicenseeWL, AmtDueToBA, AmtDueToRB, CommBA,
				CommRB, PlayerComm, Betcount, licenseeWLBT, BetTradeComm,  
				WLBetTicket, WLBoughtTicket, BuyBackAmtSB, BuyBackAmtBA, CashOutComm
			)
			SELECT 
				b.winlostdate,  
				b.currency,
				'BA',
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.turnover ELSE 0 END
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
					ELSE 1 END
				) AS turnover,
				0 AS BTActualStake,
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.winlost ELSE 0 END),
				0 AS LicenseeWL,
				-SUM(CASE WHEN RAND() + 1 > 0 THEN b.winlost+b.awinlost+b.comm ELSE 0 END) AS AmountDueToBA,
				0 AS AmountDueToRB,
				SUM (CASE WHEN RAND() + 1 > 0 THEN b.comm ELSE 0 END) AS CommBA,
				0 AS CommRB,
				SUM(ISNULL(CASE WHEN RAND() + 1 > 0 THEN b.playercomm ELSE 0 END,0)) AS PlayerComm,
				SUM(CASE WHEN RAND() + 1 > 0 AND @drawfilter = 2 AND b.statusID = 111 THEN 0 ELSE b.betcount END) AS BetCount,
				0 AS licenseeWLBT,
				0 AS BetTradeComm,	
				0 AS WLBetTicket,
				0 AS WLBoughtTicket,
				0 AS BuyBackAmtSB,
				0 AS BuyBackAmtBA,
				0 AS CashOutComm
			FROM 
				  bodb_licenseereport.dbo.rptLicWinloss2 b WITH ( NOLOCK )  
				  INNER JOIN #tmpCust ag ON b.recommend = ag.AgentID AND b.Currency = ag.currency AND b.winlostdate >= ag.EffectiveDate
			WHERE (ag.CustID IS NULL OR b.custid = ag.CustID)
				AND b.Winlostdate BETWEEN @_FromDate AND @TempToDate  
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND b.roleid = 1   
				AND b.statusID <> 101 --exclude REJECT bets
				AND b.isBA = 1 
			GROUP BY b.winlostdate, b.currency

			INSERT INTO @WLBetTicket(winlostdate, currency, WLBetTicket)
			SELECT 
				b.winlostdate,  
				b.currency,
				SUM(b.winlost)
			FROM 
				  bodb_licenseereport.dbo.rptLicWinloss2 b WITH ( NOLOCK )  
				  INNER JOIN @CustBettrade ag ON b.recommend = ag.recommend AND b.custid = ag.custid AND b.Currency = ag.currency
			WHERE  
				 b.Winlostdate BETWEEN @_FromDate AND @TempToDate  
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND b.roleid = 1   
				AND b.statusID <> 101 --exclude REJECT bets
				AND b.isBA = 1
			GROUP BY b.winlostdate, b.currency
		END
	
		--exclude BA tickets
		IF 1 IN (@showSB, @ShowRB, @ShowNG, @ShowLC, @ShowVS, @ShowCS, @ShowBG, @ShowKN, @ShowMGCLC, @ShowMGCRnG, @ShowAGC, @ShowVB, @ShowAB, @ShowFW, @ShowVS2, @ShowLT)
		BEGIN
			INSERT INTO #SAgWinLoss 
			(  
				winlostdate, Currency, ProductCode, Turnover, BTActualStake,
				Winlost, LicenseeWL, AmtDueToBA, AmtDueToRB, CommBA,
				CommRB, PlayerComm, Betcount, licenseeWLBT, BetTradeComm,  
				WLBetTicket, WLBoughtTicket, BuyBackAmtSB, BuyBackAmtBA, CashOutComm
			) 
			SELECT 
				b.winlostdate,  
				b.currency,
				t.ProductCode,
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.turnover ELSE 0 END
					*
					CASE WHEN RAND() + 1 > 0 AND @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
				) AS turnover,
				0 AS BTActualStake,
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.winlost ELSE 0 END),
				-SUM(CASE WHEN RAND() + 1 > 0 THEN CASE WHEN b.sporttype = 151 THEN -b.awinlost ELSE b.winlost END ELSE 0 END) AS LicenseeWL,
				0 AS AmountDueToBA,
				-SUM(CASE WHEN RAND() + 1 > 0 AND b.sporttype = 151 THEN b.winlost+b.awinlost+b.comm ELSE 0 END) AS AmountDueToRB,
				0 AS CommBA,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.sporttype = 151 THEN comm ELSE 0 END) AS CommRB,
				SUM(ISNULL(CASE WHEN RAND() + 1 > 0 THEN playercomm ELSE 0 END, 0)) AS PlayerComm,
				SUM(CASE WHEN RAND() + 1 > 0 AND @drawfilter = 2 AND b.statusID = 111 THEN 0 ELSE b.betcount END) AS BetCount,
				0 AS licenseeWLBT,
				0 AS BetTradeComm,	
				0 AS WLBetTicket,
				0 AS WLBoughtTicket,
				0 AS BuyBackAmtSB,
				0 AS BuyBackAmtBA,
				0 AS CashOutComm
			FROM
				bodb_licenseereport.dbo.rptLicWinloss2 b WITH ( NOLOCK )  
				INNER JOIN #tmpCust ag   ON b.recommend = ag.AgentID AND ag.currency = b.Currency AND b.winlostdate >= ag.EffectiveDate
				INNER JOIN @sporttype t ON b.sporttype = t.sporttype
			WHERE (ag.CustID IS NULL OR b.custid = ag.CustID)
				AND b.Winlostdate BETWEEN @_FromDate AND @TempToDate
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND b.roleid = 1   
				AND b.statusID <> 101 --exclude REJECT bets
				AND b.isBA = 0 
			GROUP BY b.winlostdate, b.currency, 
				t.ProductCode

			INSERT INTO @WLBetTicket(winlostdate, currency, WLBetTicket)
			SELECT 
				b.winlostdate,  
				b.currency,
				SUM(b.winlost)
			FROM 
				bodb_licenseereport.dbo.rptLicWinloss2 b WITH ( NOLOCK )  
				INNER JOIN @CustBettrade ag ON b.recommend = ag.recommend AND b.custid = ag.custid AND b.Currency = ag.currency
			WHERE  
				b.Winlostdate BETWEEN @_FromDate AND @TempToDate
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914) 
				AND b.roleid = 1   
				AND b.statusID <> 101 --exclude REJECT bets
				AND b.isBA = 0 
				AND b.sporttype = 0
			GROUP BY b.winlostdate, b.currency
		END

		IF @ShowBT = 1
		BEGIN
			INSERT INTO #SAgWinLoss
			(  
				winlostdate, Currency, ProductCode, Turnover, BTActualStake,
				Winlost, LicenseeWL, AmtDueToBA, AmtDueToRB, CommBA,
				CommRB, PlayerComm, Betcount, licenseeWLBT, BetTradeComm,  
				WLBetTicket, WLBoughtTicket, BuyBackAmtSB, BuyBackAmtBA, CashOutComm
			)
			SELECT   
				b.winlostdate,  
				ag.currency,
				'BT',
				0 AS turnover,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 902 THEN b.winlost + BuyBackAmt + BABuyBackAmt ELSE 0 END) AS BTActualStake,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 903 THEN 0 ELSE b.winlost END) AS Winlost,    
				0 AS LicenseeWL,
				0 as AmountDueToBA,
				0 as AmountDueToRB,
				0 as CommBA,
				0 as CommRB,
				0 as PlayerComm,
				SUM(CASE WHEN RAND() + 1 > 0 AND ((b.bettype = 903) OR (@drawfilter = 2 AND b.statusID = 111)) THEN 0 ELSE b.BetCount END) AS BetCount,
				-SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype IN (901, 902) THEN b.winlost ELSE 0 END) AS licenseeWLBT,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 903 THEN b.awinlost ELSE 0 END) AS BetTradeComm,
				0 WLBetTicket,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 902 THEN b.winlost ELSE 0 END) AS WLBoughtTicket,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 902 THEN BuyBackAmt ELSE 0 END) AS BuyBackAmtSB,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 902 THEN BABuyBackAmt ELSE 0 END) AS BuyBackAmtBA,
				0 AS CashOutComm
			FROM 
				bodb_licenseereport.dbo.rptLicWinloss2 b WITH ( NOLOCK )  
				INNER JOIN #tmpCust ag ON b.recommend = ag.AgentID AND ag.currency = b.Currency AND b.winlostdate >= ag.EffectiveDate
			WHERE (ag.CustID IS NULL OR b.custid = ag.CustID)
				AND b.Winlostdate BETWEEN @_FromDate AND @TempToDate
				AND b.bettype IN (901, 902, 903)
				AND b.statusID  IN (111, 112, 113)
				AND b.roleid = 1 
			GROUP BY b.winlostdate, ag.currency, b.bettype
		END

		IF @ShowCO = 1
		BEGIN
			INSERT INTO #SAgWinLoss
			(  
				winlostdate, Currency, ProductCode, Turnover, BTActualStake,
				Winlost, LicenseeWL, AmtDueToBA, AmtDueToRB, CommBA,
				CommRB, PlayerComm, Betcount, licenseeWLBT, BetTradeComm,  
				WLBetTicket, WLBoughtTicket, BuyBackAmtSB, BuyBackAmtBA, CashOutComm
			)
			SELECT   
				b.winlostdate,  
				ag.currency,
				'CO',
				0 AS turnover,
				0 AS BTActualStake,
				SUM(CASE WHEN b.bettype = 913 THEN 0 ELSE b.winlost END) AS Winlost,    
				- SUM(CASE WHEN b.bettype = 913 THEN 0 ELSE b.winlost END) AS LicenseeWL,
				0 as AmountDueToBA,
				0 as AmountDueToRB,
				0 as CommBA,
				0 as CommRB,
				0 as PlayerComm,
				SUM(CASE WHEN b.bettype = 913 THEN 0 ELSE b.BetCount END) AS BetCount,
				0 AS licenseeWLBT,
				0 AS BetTradeComm,
				0 WLBetTicket,
				0 AS WLBoughtTicket,
				0 AS BuyBackAmtSB,
				0 AS BuyBackAmtBA,
				SUM(CASE WHEN b.bettype = 913 THEN b.awinlost ELSE 0 END) AS CashOutComm
			FROM 
				bodb_licenseereport.dbo.rptLicWinloss2 b WITH ( NOLOCK )  
				INNER JOIN #tmpCust ag ON b.recommend = ag.AgentID AND ag.currency = b.Currency AND b.winlostdate >= ag.EffectiveDate
			WHERE (ag.CustID IS NULL OR b.custid = ag.CustID)
				AND b.Winlostdate BETWEEN @_FromDate AND @TempToDate
				AND b.bettype IN (911, 912, 913)
				AND b.statusID  IN (111, 112, 113)
				AND b.roleid = 1 
			GROUP BY b.winlostdate, ag.currency
		END
	END

	IF @IsOld = 1 
	BEGIN
		SELECT @MaxOldDate = MAX(winlostdate) FROM bodb_licenseereport.dbo.rptLicWinloss_old (NOLOCK)
		IF @_ToDate >= @MaxOldDate
			SET @TempToDate = @MaxOldDate
		ELSE
			SET  @TempToDate = @_ToDate

		IF @ShowBA = 1 
		BEGIN
			INSERT INTO #SAgWinLoss  
			(  
				winlostdate, Currency, ProductCode, Turnover, BTActualStake,
				Winlost, LicenseeWL, AmtDueToBA, AmtDueToRB, CommBA,
				CommRB, PlayerComm, Betcount, licenseeWLBT, BetTradeComm,  
				WLBetTicket, WLBoughtTicket, BuyBackAmtSB, BuyBackAmtBA, CashOutComm
			)
			SELECT 
				b.winlostdate,  
				b.currency,
				'BA',
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.turnover ELSE 0 END
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
					ELSE 1 END
				) AS turnover,
				0 AS BTActualStake,
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.winlost ELSE 0 END),
				0 AS LicenseeWL,
				-SUM(CASE WHEN RAND() + 1 > 0 THEN b.winlost+b.awinlost+b.comm ELSE 0 END) AS AmountDueToBA,
				0 AS AmountDueToRB,
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.comm ELSE 0 END) AS CommBA,
				0 AS CommRB,
				SUM(ISNULL(CASE WHEN RAND() + 1 > 0 THEN b.playercomm ELSE 0 END,0)) AS PlayerComm,
				SUM(CASE WHEN RAND() + 1 > 0 AND @drawfilter = 2 AND b.statusID = 111 THEN 0 ELSE b.betcount END) AS BetCount,
				0 AS licenseeWLBT,
				0 AS BetTradeComm,	
				0 AS WLBetTicket,
				0 AS WLBoughtTicket,
				0 AS BuyBackAmtSB,
				0 AS BuyBackAmtBA,
				0 AS CashOutComm
			FROM  
				bodb_licenseereport.dbo.rptLicWinloss_old b WITH ( NOLOCK )  
				INNER JOIN #tmpCust ag ON b.recommend = ag.AgentID AND b.Currency = ag.currency AND b.winlostdate >= ag.EffectiveDate
			WHERE  (ag.CustID IS NULL OR b.custid = ag.CustID)
				AND b.Winlostdate BETWEEN @_FromDate AND @TempToDate  
				AND b.bettype NOT IN (901, 902, 903,904) 
				AND b.roleid = 1   
				AND b.statusID <> 101 --exclude REJECT bets
				AND ISNULL(b.isBA, 0) = 1
			GROUP BY b.winlostdate, b.currency

			INSERT INTO @WLBetTicket(winlostdate, currency, WLBetTicket)
			SELECT 
				b.winlostdate,  
				b.currency,
				SUM(b.winlost)
			FROM  
				bodb_licenseereport.dbo.rptLicWinloss_old b WITH ( NOLOCK )  
				INNER JOIN @CustBettrade ag ON b.recommend = ag.recommend AND b.custid = ag.custid AND b.Currency = ag.currency
			WHERE  
				b.Winlostdate BETWEEN @_FromDate AND @TempToDate  
				AND b.bettype NOT IN (901, 902, 903,904) 
				AND b.roleid = 1   
				AND b.statusID <> 101 --exclude REJECT bets
				AND ISNULL(b.isBA, 0) = 1
			GROUP BY b.winlostdate, b.currency
		END

		--exclude BA tickets
		IF 1 IN (@showSB, @ShowRB, @ShowNG, @ShowLC, @ShowVS, @ShowCS, @ShowBG, @ShowKN, @ShowMGCLC, @ShowMGCRnG, @ShowAGC, @ShowVB, @ShowAB, @ShowFW, @ShowVS2)
		BEGIN
			INSERT INTO #SAgWinLoss  
			(  
				winlostdate, Currency, ProductCode, Turnover, BTActualStake,
				Winlost, LicenseeWL, AmtDueToBA, AmtDueToRB, CommBA,
				CommRB, PlayerComm, Betcount, licenseeWLBT, BetTradeComm,  
				WLBetTicket, WLBoughtTicket, BuyBackAmtSB, BuyBackAmtBA, CashOutComm
			)
			SELECT 
				b.winlostdate,  
				b.currency,
				t.ProductCode,
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.turnover ELSE 0 END
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.statusID IN (114,115) THEN 0.5
							ELSE 1 END
						ELSE 1 END
				) AS turnover,
				0 AS BTActualStake,
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.winlost ELSE 0 END),  
				-SUM(CASE WHEN RAND() + 1 > 0 THEN CASE WHEN b.sporttype = 151 THEN -b.awinlost ELSE b.winlost END ELSE 0 END) AS LicenseeWL,
				0 AS AmountDueToBA,
				- SUM ( CASE WHEN RAND() + 1 > 0 AND b.sporttype = 151 THEN (b.winlost+b.awinlost+b.comm) ELSE 0 END) AS AmountDueToRB,
				0 AS CommBA,
				SUM ( CASE WHEN RAND() + 1 > 0 AND b.sporttype = 151 THEN (comm) ELSE 0 END) AS CommRB,
				SUM (ISNULL(CASE WHEN RAND() + 1 > 0 THEN playercomm ELSE 0 END,0)) AS PlayerComm,
				SUM(CASE WHEN RAND() + 1 > 0 AND @drawfilter = 2 AND b.statusID = 111 THEN 0 ELSE b.betcount END) AS BetCount,
				0 AS licenseeWLBT,
				0 AS BetTradeComm,	
				0 AS WLBetTicket,
				0 AS WLBoughtTicket,
				0 AS BuyBackAmtSB,
				0 AS BuyBackAmtBA,
				0 AS CashOutComm
			FROM 
				bodb_licenseereport.dbo.rptLicWinloss_old b WITH (NOLOCK)  
				INNER JOIN #tmpCust ag ON b.recommend = ag.AgentID AND b.Currency = ag.currency AND b.winlostdate >= ag.EffectiveDate
				INNER JOIN @sporttype t ON b.sporttype = t.sporttype
			WHERE  (ag.CustID IS NULL OR b.custid = ag.CustID)
				AND b.Winlostdate BETWEEN @_FromDate AND @TempToDate  
				AND b.bettype NOT IN (901, 902, 903,904) 
				AND b.roleid = 1   
				AND b.statusID <> 101 --exclude REJECT bets
				AND ISNULL(b.isBA, 0) = 0
			GROUP BY b.winlostdate, b.currency, 
				t.ProductCode

			INSERT INTO @WLBetTicket(winlostdate, currency, WLBetTicket)
			SELECT 
				b.winlostdate,  
				b.currency,
				SUM(b.winlost)
			FROM  
				bodb_licenseereport.dbo.rptLicWinloss_old b WITH ( NOLOCK )  
				INNER JOIN @CustBettrade ag ON b.recommend = ag.recommend AND b.custid = ag.custid AND b.Currency = ag.currency
			WHERE  
				b.Winlostdate BETWEEN @_FromDate AND @TempToDate  
				AND b.bettype NOT IN (901, 902, 903,904) 
				AND b.roleid = 1   
				AND b.statusID <> 101 --exclude REJECT bets
				AND ISNULL(b.isBA, 0) = 0
				AND b.sporttype = 0
			GROUP BY b.winlostdate, b.currency
		END

		IF @ShowBT = 1
		BEGIN
			INSERT INTO #SAgWinLoss
			(  
				winlostdate, Currency, ProductCode, Turnover, BTActualStake,
				Winlost, LicenseeWL, AmtDueToBA, AmtDueToRB, CommBA,
				CommRB, PlayerComm, Betcount, licenseeWLBT, BetTradeComm,  
				WLBetTicket, WLBoughtTicket, BuyBackAmtSB, BuyBackAmtBA, CashOutComm
			)
			SELECT   
				b.winlostdate,  
				ag.currency,
				'BT',
				0 AS turnover,
				0 BTActualStake,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 903 THEN 0 ELSE b.winlost END) AS Winlost,    
				0 AS LicenseeWL,
				0 AS AmountDueToBA,
				0 AS AmountDueToRB,
				0 AS CommBA,
				0 AS CommRB,
				0 AS PlayerComm,
				SUM(CASE WHEN RAND() + 1 > 0 AND ((b.bettype = 903) OR (@drawfilter = 2 AND b.statusID = 111)) THEN 0 ELSE b.BetCount END) AS BetCount,
				-SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype IN (901, 902) THEN (b.winlost) ELSE 0 END) AS licenseeWLBT,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 903 THEN b.awinlost ELSE 0 END) AS BetTradeComm,
				0 WLBetTicket,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 902 THEN b.winlost ELSE 0 END) AS WLBoughtTicket,
				0 AS BuyBackAmtSB,
				0 AS BuyBackAmtBA,
				0 AS CashOutComm
			FROM 
				bodb_licenseereport.dbo.rptLicWinloss_old b WITH (NOLOCK)  
				INNER JOIN #tmpCust ag ON b.recommend = ag.AgentID AND ag.currency = b.Currency AND b.winlostdate >= ag.EffectiveDate
			WHERE (ag.CustID IS NULL OR b.custid = ag.CustID)
				AND b.Winlostdate BETWEEN @_FromDate AND @TempToDate
				AND b.bettype IN (901, 902, 903)
				AND b.statusID IN (111, 112, 113)
				AND b.roleid = 1 
			GROUP BY b.winlostdate, ag.currency
		END
	END

	DECLARE @SAgWL TABLE
	(  
		winlostdate			DATETIME,  
		Currency			INT,
		TurnoverSB			MONEY,
		TurnoverBA			MONEY,
		TurnoverNG			MONEY,
		TurnoverRB			MONEY,
		TurnoverLC			MONEY,
		TurnoverVS			MONEY,
		TurnoverCS 			MONEY,
		TurnoverBG			MONEY,
		TurnoverKN			MONEY,
		turnoverMGCLC		MONEY, 
		turnoverMGCRnG		MONEY, 
		turnoverAGC			MONEY,
		turnoverVB			MONEY, 
		turnoverAB			MONEY,
		turnoverFW			MONEY, 
		turnoverCO			MONEY,
		TurnoverVS2		MONEY,
		TurnoverLT			MONEY,
		BTActualStake		MONEY,
		Winlost				MONEY,
		LicenseeWLSB 		MONEY,
		LicenseeWLBA		MONEY,
		LicenseeWLNG		MONEY,
		LicenseeWLRB		MONEY,
		LicenseeWLLC		MONEY,
		LicenseeWLVS		MONEY,
		LicenseeWLCS		MONEY,
		LicenseeWLBG		MONEY,
		LicenseeWLKN		MONEY,
		LicenseeWLMGCLC	    MONEY,
		LicenseeWLMGCRnG	MONEY,
		LicenseeWLAGC		MONEY,
		LicenseeWLVB		MONEY,
		LicenseeWLAB		MONEY,
		LicenseeWLFW		MONEY,
		LicenseeWLCO		MONEY,
		LicenseeWLVS2		MONEY,
		LicenseeWLLT		MONEY,
		AmtDueToBA			MONEY,   
		AmtDueToRB			MONEY,
		CommBA				MONEY,   
		CommRB				MONEY,  
		PlayerComm			MONEY,
		Betcount			BIGINT,
		licenseeWLBT		MONEY,   
		BetTradeComm		MONEY,  
		WLBetTicket			MONEY, 	
		WLBoughtTicket		MONEY,
		BuyBackAmtSB		MONEY,
		BuyBackAmtBA		MONEY,
		CashOutComm			MONEY,
		UNIQUE CLUSTERED (winlostdate, currency)
	)  

	INSERT INTO @SAgWL
	(  
		winlostdate, Currency,
		TurnoverSB, TurnoverBA, TurnoverNG, TurnoverRB, TurnoverLC, TurnoverVS, TurnoverCS, TurnoverBG,
		TurnoverKN, turnoverMGCLC, turnoverMGCRnG, turnoverAGC, turnoverVB, turnoverAB, turnoverFW, turnoverCO, TurnoverVS2, TurnoverLT,
		BTActualStake, Winlost,
		LicenseeWLSB, LicenseeWLBA, LicenseeWLNG, LicenseeWLRB, LicenseeWLLC, LicenseeWLVS, LicenseeWLCS, LicenseeWLBG,
		LicenseeWLKN, LicenseeWLMGCLC, LicenseeWLMGCRnG, LicenseeWLAGC, LicenseeWLVB, LicenseeWLAB, LicenseeWLFW, LicenseeWLCO, LicenseeWLVS2, LicenseeWLLT,
		AmtDueToBA, AmtDueToRB,
		CommBA, CommRB,  
		PlayerComm,
		Betcount,
		licenseeWLBT,   
		BetTradeComm,  
		WLBetTicket, WLBoughtTicket,
		BuyBackAmtSB, BuyBackAmtBA,
		CashOutComm
	)
	SELECT
		winlostdate,
		Currency,
		SUM(CASE ProductCode WHEN 'SB'		THEN Turnover ELSE 0 END)	AS TurnoverSB,   
		SUM(CASE ProductCode WHEN 'BA'		THEN Turnover ELSE 0 END)	AS TurnoverBA,   
		SUM(CASE ProductCode WHEN 'NG'		THEN Turnover ELSE 0 END)	AS TurnoverNG,   
		SUM(CASE ProductCode WHEN 'RB'		THEN Turnover ELSE 0 END)	AS TurnoverRB,   
		SUM(CASE ProductCode WHEN 'LC'		THEN Turnover ELSE 0 END)	AS TurnoverLC,   
		SUM(CASE ProductCode WHEN 'VS'		THEN Turnover ELSE 0 END)	AS TurnoverVS,   
		SUM(CASE ProductCode WHEN 'CS'		THEN Turnover ELSE 0 END)	AS TurnoverCS,
		SUM(CASE ProductCode WHEN 'BG'		THEN Turnover ELSE 0 END)	AS TurnoverBG,
		SUM(CASE ProductCode WHEN 'KN'		THEN Turnover ELSE 0 END)	AS TurnoverKN,
		SUM(CASE ProductCode WHEN 'MGCLC'	THEN Turnover ELSE 0 END)   AS TurnoverMGCLC,
		SUM(CASE ProductCode WHEN 'MGCRnG'	THEN Turnover ELSE 0 END)   AS TurnoverMGCRnG,
		SUM(CASE ProductCode WHEN 'AGC'		THEN Turnover ELSE 0 END)	AS TurnoverAGC,
		SUM(CASE ProductCode WHEN 'VB'		THEN Turnover ELSE 0 END)	AS TurnoverVB,
		SUM(CASE ProductCode WHEN 'AB'		THEN Turnover ELSE 0 END)	AS TurnoverAB,
		SUM(CASE ProductCode WHEN 'FW'		THEN Turnover ELSE 0 END)	AS TurnoverFW,
		SUM(CASE ProductCode WHEN 'CO'		THEN Turnover ELSE 0 END)	AS TurnoverCO,
		SUM(CASE ProductCode WHEN 'VS2'	THEN Turnover ELSE 0 END)	AS TurnoverVS2,
		SUM(CASE ProductCode WHEN 'LT'		THEN Turnover ELSE 0 END)	AS TurnoverLT,
		SUM(BTActualStake)		AS BTActualStake,
		SUM(Winlost)			AS Winlost,
		SUM(CASE ProductCode WHEN 'SB'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLSB,   
		SUM(CASE ProductCode WHEN 'BA'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLBA,   
		SUM(CASE ProductCode WHEN 'NG'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLNG,   
		SUM(CASE ProductCode WHEN 'RB'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLRB,   
		SUM(CASE ProductCode WHEN 'LC'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLLC,   
		SUM(CASE ProductCode WHEN 'VS'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLVS,   
		SUM(CASE ProductCode WHEN 'CS'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLCS,
		SUM(CASE ProductCode WHEN 'BG'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLBG,
		SUM(CASE ProductCode WHEN 'KN'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLKN,
		SUM(CASE ProductCode WHEN 'MGCLC'	THEN LicenseeWL ELSE 0 END) AS LicenseeWLMGCLC,
		SUM(CASE ProductCode WHEN 'MGCRnG'	THEN LicenseeWL ELSE 0 END) AS LicenseeWLMGCRnG,
		SUM(CASE ProductCode WHEN 'AGC'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLAGC,
		SUM(CASE ProductCode WHEN 'VB'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLVB,
		SUM(CASE ProductCode WHEN 'AB'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLAB,
		SUM(CASE ProductCode WHEN 'FW'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLFW,
		SUM(CASE ProductCode WHEN 'CO'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLCO,
		SUM(CASE ProductCode WHEN 'VS2'	THEN LicenseeWL ELSE 0 END)	AS LicenseeWLVS2,
		SUM(CASE ProductCode WHEN 'LT'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLLT,
		SUM(AmtDuetoBA)			AS AmtDuetoBA,
		SUM(AmtDuetoRB)			AS AmtDuetoRB,
		SUM(CommBA)				AS CommBA,
		SUM(CommRB)				AS CommRB,
		SUM(playerComm)			AS PlayerComm,
		SUM(Betcount)			AS Betcount,
		SUM(licenseeWLBT)		AS licenseeWLBT,
		SUM(BetTradeComm)		AS BetTradeComm,
		SUM(WLBetTicket)		AS WLBetTicket,
		SUM(WLBoughtTicket)		AS WLBoughtTicket,
		SUM(BuyBackAmtSB)		AS BuyBackAmtSB,
		SUM(BuyBackAmtBA)		AS BuyBackAmtBA,
		SUM(CashOutComm)		AS CashOutComm
	FROM #SAgWinLoss
	GROUP BY winlostdate, Currency

	UPDATE s
	SET s.WLBetTicket = s.WLBetTicket + w.WLBetTicket
	FROM
		@SAgWL s
		INNER JOIN (SELECT SUM(WLBetTicket) WLBetTicket, winlostdate, currency FROM @WLBetTicket GROUP BY winlostdate, currency ) w
			ON s.winlostdate = w.winlostdate AND s.currency = w.currency-- AND s.statusID = w.statusID

	SELECT * INTO #TempExchange 
	FROM Lrf_f_GetExchangeDaily(@_FromDate,@_ToDate)
	
	SELECT   
		CASE WHEN @ReportType = 1 THEN CONVERT(VARCHAR(8),w.winlostdate,112)  
			WHEN @ReportType = 2 THEN CONVERT(VARCHAR(6),w.winlostdate,112)  
			ELSE '0' END ReportType,  
		Currency,   
		CASE	WHEN Currency = 51 THEN @VNDCurrencyName 
				WHEN Currency = 70 THEN 'MKK'
		  ELSE e.Code END AS currencyName,
		SUM(TurnoverSB)			AS TurnoverSB,   
		SUM(TurnoverBA)			AS TurnoverBA,   
		SUM(TurnoverNG)			AS TurnoverNG,   
		SUM(TurnoverRB)			AS TurnoverRB,   
		SUM(TurnoverLC)			AS TurnoverLC,   
		SUM(TurnoverVS)			AS TurnoverVS,   
		SUM(TurnoverCS)			AS TurnoverCS,
		SUM(TurnoverBG)			AS TurnoverBG,
		SUM(TurnoverKN)			AS TurnoverKN,
		SUM(TurnoverMGCLC)      AS TurnoverMGCLC,
		SUM(TurnoverMGCRnG)     AS TurnoverMGCRnG,
		SUM(TurnoverAGC)		AS TurnoverAGC,
		SUM(TurnoverVB)			AS TurnoverVB,
		SUM(TurnoverAB)			AS TurnoverAB,
		SUM(TurnoverFW)			AS TurnoverFW,
		SUM(TurnoverCO)			AS TurnoverCO,
		SUM(TurnoverVS2)		AS TurnoverVS2,
		SUM(TurnoverLT)			AS TurnoverLT,
		SUM(BTActualStake)		AS BTActualStake,
		SUM(Winlost)			AS Winlost,
		SUM(LicenseeWLSB)		AS LicenseeWLSB,
		SUM(LicenseeWLBA)		AS LicenseeWLBA,
		SUM(LicenseeWLNG)		AS LicenseeWLNG,
		SUM(LicenseeWLRB)		AS LicenseeWLRB,
		SUM(LicenseeWLLC)		AS LicenseeWLLC,
		SUM(LicenseeWLVS)		AS LicenseeWLVS,   
		SUM(LicenseeWLCS)		AS LicenseeWLCS,
		SUM(LicenseeWLBG)		AS LicenseeWLBG,
		SUM(LicenseeWLKN)		AS LicenseeWLKN,
		SUM(LicenseeWLMGCLC)	AS LicenseeWLMGCLC,
		SUM(LicenseeWLMGCRnG)	AS LicenseeWLMGCRnG,
		SUM(LicenseeWLAGC)		AS LicenseeWLAGC,
		SUM(LicenseeWLVB)		AS LicenseeWLVB,
		SUM(LicenseeWLAB)		AS LicenseeWLAB,
		SUM(LicenseeWLFW)		AS LicenseeWLFW,
		SUM(LicenseeWLCO)		AS LicenseeWLCO,
		SUM(LicenseeWLVS2)		AS LicenseeWLVS2,
		SUM(LicenseeWLLT)		AS LicenseeWLLT,
		SUM(CommBA)				AS CommBA,
		SUM(CommRB)				AS CommRB,
		SUM(playerComm)			AS PlayerComm,
		SUM(AmtDuetoBA)			AS AmtDuetoBA,
		SUM(AmtDuetoRB)			AS AmtDuetoRB,
		SUM(Betcount)			AS Betcount,
		SUM(licenseeWLBT)		AS licenseeWLBT,
		SUM(BetTradeComm)		AS BetTradeComm,
		SUM(WLBetTicket+WLBoughtTicket-BetTradeComm)	AS AmtDueToBT,
		SUM(BuyBackAmtSB)		AS BuyBackAmtSB,
		SUM(BuyBackAmtBA)		AS BuyBackAmtBA,
		SUM(CashOutComm)		AS CashOutComm,
		CAST(SUM(TurnoverSB*e.USD)			AS MONEY)   AS TurnoverSBUSD,   
		CAST(SUM(TurnoverBA*e.USD)			AS MONEY)   AS TurnoverBAUSD,   
		CAST(SUM(TurnoverNG*e.USD)			AS MONEY)   AS TurnoverNGUSD,   
		CAST(SUM(TurnoverRB*e.USD)			AS MONEY)   AS TurnoverRBUSD,
		CAST(SUM(TurnoverLC*e.USD)			AS MONEY)	AS TurnoverLCUSD,
		CAST(SUM(TurnoverVS*e.USD)			AS MONEY)	AS TurnoverVSUSD,
		CAST(SUM(TurnoverCS*e.USD)			AS MONEY)   AS TurnoverCSUSD,
		CAST(SUM(TurnoverBG*e.USD)			AS MONEY)   AS TurnoverBGUSD,
		CAST(SUM(TurnoverKN*e.USD)			AS MONEY)   AS TurnoverKNUSD,
		CAST(SUM(TurnoverMGCLC*e.USD)		AS MONEY)   AS TurnoverMGCLCUSD,
		CAST(SUM(TurnoverMGCRnG*e.USD)		AS MONEY)   AS TurnoverMGCRnGUSD,
		CAST(SUM(TurnoverAGC*e.USD)			AS MONEY)   AS TurnoverAGCUSD,
		CAST(SUM(TurnoverVB*e.USD)			AS MONEY)   AS TurnoverVBUSD,
		CAST(SUM(TurnoverAB*e.USD)			AS MONEY)   AS TurnoverABUSD,
		CAST(SUM(TurnoverFW*e.USD)			AS MONEY)   AS TurnoverFWUSD,
		CAST(SUM(TurnoverCO*e.USD)			AS MONEY)   AS TurnoverCOUSD,
		CAST(SUM(TurnoverVS2*e.USD)		AS MONEY)   AS TurnoverVS2USD,
		CAST(SUM(TurnoverLT*e.USD)			AS MONEY)   AS TurnoverLTUSD,
		CAST(SUM(BTActualStake*e.USD)		AS MONEY)   AS BTActualStakeUSD,
		CAST(SUM(Winlost*e.USD)				AS MONEY)	AS WinlostUSD,
		CAST(SUM(LicenseeWLSB*e.USD)		AS MONEY)	AS LicenseeWLSBUSD,
		CAST(SUM(LicenseeWLBA*e.USD)		AS MONEY)	AS LicenseeWLBAUSD,
		CAST(SUM(LicenseeWLNG*e.USD)		AS MONEY) 	AS LicenseeWLNGUSD,
		CAST(SUM(LicenseeWLRB*e.USD)		AS MONEY)	AS LicenseeWLRBUSD,
		CAST(SUM(LicenseeWLLC*e.USD)		AS MONEY)	AS LicenseeWLLCUSD,
		CAST(SUM(LicenseeWLVS*e.USD)		AS MONEY)	AS LicenseeWLVSUSD,
		CAST(SUM(LicenseeWLCS*e.USD)		AS MONEY)	AS LicenseeWLCSUSD,
		CAST(SUM(LicenseeWLBG*e.USD)		AS MONEY)	AS LicenseeWLBGUSD,
		CAST(SUM(LicenseeWLKN*e.USD)		AS MONEY)	AS LicenseeWLKNUSD,
		CAST(SUM(LicenseeWLMGCLC*e.USD)		AS MONEY)	AS LicenseeWLMGCLCUSD,
		CAST(SUM(LicenseeWLMGCRnG*e.USD)	AS MONEY)	AS LicenseeWLMGCRnGUSD,
		CAST(SUM(LicenseeWLAGC*e.USD)		AS MONEY)	AS LicenseeWLAGCUSD,
		CAST(SUM(LicenseeWLVB*e.USD)		AS MONEY)	AS LicenseeWLVBUSD,
		CAST(SUM(LicenseeWLAB*e.USD)		AS MONEY)	AS LicenseeWLABUSD,
		CAST(SUM(LicenseeWLFW*e.USD)		AS MONEY)	AS LicenseeWLFWUSD,
		CAST(SUM(LicenseeWLCO*e.USD)		AS MONEY)	AS LicenseeWLCOUSD,
		CAST(SUM(LicenseeWLVS2*e.USD)		AS MONEY)	AS LicenseeWLVS2USD,
		CAST(SUM(LicenseeWLLT*e.USD)		AS MONEY)	AS LicenseeWLLTUSD,
		CAST(SUM(CommBA * e.USD)			AS MONEY)	AS CommBAUSD,
		CAST(SUM(CommRB * e.USD)			AS MONEY)	AS CommRBUSD,
		CAST(SUM(PlayerComm*e.USD)			AS MONEY)	AS PlayerCommUSD,
		CAST(SUM(AmtDuetoBA*e.USD)			AS MONEY)	AS AmtDuetoBAUSD,
		CAST(SUM(AmtDuetoRB*e.USD)			AS MONEY)	AS AmtDuetoRBUSD,
		CAST(SUM(licenseeWLBT* e.USD)		AS MONEY)   AS licenseeWLBTUSD,
		CAST(SUM(BetTradeComm* e.USD)		AS MONEY)	AS BetTradeCommUSD,
		CAST(SUM((WLBetTicket+WLBoughtTicket-BetTradeComm)* e.USD) AS MONEY)	AS AmtDueToBTUSD,
		CAST(SUM(BuyBackAmtSB * e.USD)		AS MONEY)	AS BuyBackAmtSBUSD,
		CAST(SUM(BuyBackAmtBA * e.USD)		AS MONEY)	AS BuyBackAmtBAUSD,
		CAST(SUM(CashOutComm * e.USD)		AS MONEY)	AS CashOutCommUSD		
	FROM	
		@SAgWL w   
		INNER JOIN #TempExchange e ON w.winlostdate = e.ExchangeDate AND w.currency = e.ExchangeId
	GROUP BY   
		Currency,
		CASE	WHEN @ReportType = 1 THEN CONVERT(VARCHAR(8),w.winlostdate,112)  
				WHEN @ReportType = 2 THEN CONVERT(VARCHAR(6),w.winlostdate,112)  
				ELSE '0' END,  
		CASE	WHEN Currency = 51 THEN @VNDCurrencyName 
				WHEN Currency = 70 THEN 'MKK'
		  ELSE e.Code END
	ORDER BY ReportType

	DROP TABLE #SAgWinLoss

	DROP TABLE #TempExchange

END
GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_LicWinloss_BySourced] TO [bodbLicenseeNet]
GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_LicWinloss_BySourced] TO [dot_member]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_LicWinloss_BySourced] TO [vnteam]
GO