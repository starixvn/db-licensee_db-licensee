/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_LicWinloss_BySourced]  	
	@LicenseeID		INT,
	@FromDate		SMALLDATETIME,  
	@ToDate			SMALLDATETIME,   
	@showSB			BIT = 0,  
	@ShowNG			BIT = 0, 
	@ShowBA			BIT = 0,
	@ShowVS			BIT = 0,
	@ShowCS   		BIT = 0, -- RNG Casino
	@ShowKN			BIT = 0, -- Keno
	@showMGCLC		BIT = 0, -- MicroGamming
	@showMGCRnG		BIT = 0, -- MicroGamming
	@ShowBT 		BIT = 0, -- licenseeWLBT
	@ShowAGC		BIT = 0, -- AGCasino
	@ShowVB			BIT = 0, -- Voidbridge
	@ShowAB			BIT = 0, -- Allbet
	@ShowCO			BIT = 0, -- Cash Out
	@ShowVS2		BIT = 0, -- Bet Radar Virtual Sports
	@ShowLT			BIT = 0, -- Lottery
	@ShowPP			BIT = 0, -- PP
	@ReportType		TINYINT = 1,  
	@MoveBetsDay	SMALLDATETIME,
	@drawfilter		SMALLINT = 1,
	@AgentList		VARCHAR(MAX)
AS 
/*  Created: 20180312@Harper  
    Description: LAP - Customise backend for Ivorybet and Opal88
	Source: Lrf_Rpt_LicWinloss
    DB: DB052.bodb02  
   
    Revisions:  
		- 20180312@Harper: Created new Licensee Winloss SP for Ivorybet and Opal88 [RedmineID: #91738]
		- 20180419@Amanda: LAP - Integrate PP [RedmineID: #92318]
		- 20180420@Amanda: Include more cash out tickets [RedmineID: #93919]
		- 20180509@Joseph: Remove cheat currency name for special currencies [RedmineID: #94845]
		- 20180515@Joseph: Remove LC product [RedmineID: #85965]
		- 20180323@Sophia: Add more column SourcedLicenseeSitename [Redmine: #92574]
		- 20180706@Joseph: Add EndDate column to SourcedLicensee [Redmine: #97913]
		- 20180807@Amanda: Remove Racing, Bingo and Old(@IsOld) data [RedmineID: #99378]
		- 20201001@Louis: Licensee Spread Setting [RedmineID: #142532]
		- 20210119@Hogan: Integrate Four Guardians [RedmineID: #148100]
	    - 20230303@Evan: Remove inactive products CB, FW, GD, GDG [Redmine: 181424]  

	Param's Explanation:  
	  + @ReportType: 1-Daily; 2-Monthly;  
	  +	@drawfilter: 'No Draw' filter is supportted (1:Normal 2:No Draw 3:No Draw for Turnover only)
	  + @MoveBetsDay: The day we move tickets to bettrans14
	  + @AgentList: xml structure
					  <ROOT>
					   <Agent AgentId="12345" Currency="3"/>  
					   <Agent AgentId="12345" Currency="5"/>  
					  </ROOT>
	exec Lrf_Rpt_LicWinloss_BySourced @reporttype=1,@licenseeid=185,@AgentList=N'<ROOT><Agent AgentId="24942757" Currency="9"/><Agent AgentId="0" Currency="13"/><Agent AgentId="24942816" Currency="41"/><Agent AgentId="0" Currency="15"/><Agent AgentId="24942841" Currency="51"/><Agent AgentId="0" Currency="51"/><Agent AgentId="24942791" Currency="2"/><Agent AgentId="0" Currency="2"/><Agent AgentId="24942774" Currency="4"/><Agent AgentId="0" Currency="4"/></ROOT>',@fromdate='2018-01-01 00:00:00',@todate='2018-03-01 00:00:00',@isold=0,@drawfilter=1,@movebetsday='2018-03-03 00:00:00',@showSB=1,@showNG=1
	
	Developer' Note:
		- This SP use for urgent request. DO NOT DELETE THIS SP.
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
		CommBA				MONEY,   
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
	DECLARE @SourceIDs			TABLE (LicenseeID INT, LicenseeeName NVARCHAR(50), CustID INT, CurrencyID INT, RoleID TINYINT, EffectiveDate SMALLDATETIME, EndDate SMALLDATETIME)
	CREATE TABLE #tmpCust		(CustID INT, AgentID INT, currency INT, EffectiveDate SMALLDATETIME, EndDate SMALLDATETIME)

	DECLARE @bettype			TABLE (bettype INT PRIMARY KEY, ProductCode VARCHAR(10))
	DECLARE @sporttype			TABLE (sporttype INT, ProductCode VARCHAR(10))
	DECLARE @LicenseeName		VARCHAR(50)
	DECLARE @WLBetTicket		TABLE (winlostdate DATETIME, currency INT, WLBetTicket MONEY)
	DECLARE @ProductList		VARCHAR (500)

	DECLARE @_FromDate SMALLDATETIME, @_ToDate SMALLDATETIME
	SELECT @_FromDate = @FromDate, @_ToDate = @ToDate

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
	
	INSERT INTO @SourceIDs (LicenseeID, LicenseeeName, CustID, RoleID, CurrencyID, EffectiveDate, EndDate)	
	EXEC bodb_Licensee.dbo.LRF_LicenseeSourcedSel @LicenseeID = @LicenseeID, @FromDate = @_FromDate, @ToDate = @_ToDate

	DELETE s
	FROM @SourceIDs s
	WHERE NOT EXISTS (SELECT 1 FROM @TempCurrency c WHERE s.CurrencyID = c.currency)

	INSERT INTO #tmpCust (CustID, AgentID, Currency, EffectiveDate, EndDate)	
	SELECT NULL, lc.CustID, lc.CurrencyID, lc.EffectiveDate, lc.EndDate
	FROM @SourceIDs lc
	WHERE lc.RoleID = 2 -- Agent
	UNION ALL
	SELECT a.CustID, c.recommend, a.CurrencyID, EffectiveDate, EndDate
	FROM @SourceIDs a
		INNER JOIN dbo.custInfo c WITH (NOLOCK) ON a.CustID = c.custid
	WHERE a.RoleID = 1 -- Member
	
	SELECT @LicenseeName = LicenseeName FROM bodb_Licensee.dbo.Licensees (NOLOCK) WHERE LicenseeID = @LicenseeID 
	
	DECLARE @ExcludedBetType TABLE (ProductCode VARCHAR (10), BetType INT)
	-- Insert Excluded BetType
	INSERT INTO @ExcludedBetType (ProductCode, BetType)
	SELECT ProductCode, BetType FROM Lrf_f_SelExcludedBetType()
	

	IF @ShowSB = 1  
	BEGIN  
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'SB', 'SB')		
	END  

	IF @ShowNG = 1
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'NG', 'NG')		
	END 

	IF @ShowVS = 1
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'VS', 'VS')
	END

	IF @ShowCS = 1 -- RNG Casino
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'CS', 'CS')
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

	IF @ShowVS2 = 1 -- Betradar Virtual Sports
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'VS2', 'VS2')
	END
	
	IF @ShowLT = 1 -- Lottery
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'LT', 'LT')
	END
	
	IF @ShowPP = 1 -- PP
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'PP', 'PP')
	END

	IF LEN(ISNULL(@ProductList, '')) > 0 
	BEGIN
		-- Insert Bettype
		INSERT INTO @bettype ( bettype, ProductCode )
		SELECT DISTINCT BetType, ProductPrefix
		FROM f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', @ProductList, @IsTest)
		WHERE BetType NOT IN (SELECT BetType FROM @ExcludedBetType e WHERE e.ProductCode = ProductPrefix)

		IF CHARINDEX('CS', @ProductList) > 0
			DELETE @bettype
			WHERE bettype = 72 AND ProductCode = 'CS'

		IF CHARINDEX('SB', @ProductList) > 0
			DELETE @bettype
			WHERE ProductCode = 'SB'
		
		-- Insert Sport Type
		INSERT INTO @sporttype ( sporttype, ProductCode )
		SELECT DISTINCT sporttype, ProductCode
		FROM f_LicWinLoss_ProductSportType_Sel(@ProductList)

	END	

	DECLARE @TempFromDate	DATETIME,
			@TempToDate		DATETIME

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
				Winlost, LicenseeWL, AmtDueToBA, CommBA,
				PlayerComm, Betcount, licenseeWLBT, BetTradeComm,  
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
				SUM(CASE WHEN RAND() + 1 > 0 THEN comm ELSE 0 END) AS CommBA,
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
				INNER JOIN #tmpCust tma ON tma.AgentID = b.recommend AND b.currency = tma.currency AND b.winlostdate >= tma.EffectiveDate AND b.winlostdate <= tma.EndDate
			WHERE (tma.CustID IS NULL OR b.custid = tma.CustID)
				AND b.winlostdate BETWEEN @TempFromDate AND @_ToDate				
				AND b.statusID  IN (111, 112, 113)
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
			GROUP BY b.winlostdate, tma.currency 
		END
	
		IF @ShowSB = 1
		BEGIN
			INSERT INTO #SAgWinLoss
			(  
				winlostdate, Currency, ProductCode, Turnover, BTActualStake,
				Winlost, LicenseeWL, AmtDueToBA, CommBA,
				PlayerComm, Betcount, licenseeWLBT, BetTradeComm,  
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
				0 AS CommBA,
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
				INNER JOIN #tmpCust a ON b.recommend = a.AgentID AND b.currency = a.currency AND b.winlostdate >= a.EffectiveDate AND b.winlostdate <= a.EndDate
			WHERE (a.CustID IS NULL OR b.custid = a.CustID)
				AND b.winlostdate BETWEEN @TempFromDate AND @_ToDate
				AND  
				(
					b.bettype <= 30
					OR b.bettype BETWEEN 121 AND 999
					OR b.Bettype BETWEEN 1301 and 1399 --new tennis's bettypes
				)
				AND b.statusID IN (111, 112, 113)
				AND b.tpositiontaking <> 0
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.ProductCode = 'SB' AND e.BetType = b.BetType)
				AND b.transid >= @transid
			GROUP BY b.winlostdate, a.currency --, statusID, b.bettype
		END

		IF @ShowBT = 1
		BEGIN
			INSERT INTO #SAgWinLoss
			(  
				winlostdate, Currency, ProductCode, Turnover, BTActualStake,
				Winlost, LicenseeWL, AmtDueToBA, CommBA,
				PlayerComm, Betcount, licenseeWLBT, BetTradeComm,  
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
				0 AS CommBA,
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
				INNER JOIN #tmpCust a ON b.recommend = a.AgentID AND b.currency = a.currency AND b.winlostdate >= a.EffectiveDate AND b.winlostdate <= a.EndDate
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
				Winlost, LicenseeWL, AmtDueToBA, CommBA,
				PlayerComm, Betcount, licenseeWLBT, BetTradeComm,  
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
				0 AS CommBA,
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
				INNER JOIN #tmpCust a ON b.recommend = a.AgentID AND b.currency = a.currency AND b.winlostdate >= a.EffectiveDate AND b.winlostdate <= a.EndDate
			WHERE (a.CustID IS NULL OR b.custid = a.CustID)
				AND b.winlostdate BETWEEN @TempFromDate AND @_ToDate
				AND b.bettype IN (911, 912, 913)
				AND b.statusID IN (111, 112, 113)
				AND b.transid >= @transid
			GROUP BY b.winlostdate, a.currency  
		END

		IF 1 IN (@ShowNG, @ShowVS, @ShowCS, @ShowKN, @showMGCLC, @showMGCRnG, @ShowAGC, @ShowVB, @ShowAB, @ShowVS2, @ShowLT, @ShowPP)
		BEGIN
			INSERT INTO #SAgWinLoss
			(  
				winlostdate, Currency, ProductCode, Turnover, BTActualStake,
				Winlost, LicenseeWL, AmtDueToBA, CommBA,
				PlayerComm, Betcount, licenseeWLBT, BetTradeComm,  
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
				0 AS CommBA,
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
				INNER JOIN #tmpCust a   ON b.recommend = a.AgentID AND b.Currency = a.Currency AND b.winlostdate >= a.EffectiveDate AND b.winlostdate <= a.EndDate
				INNER JOIN @bettype bt ON b.bettype = bt.bettype
			WHERE (a.CustID IS NULL OR b.custid = a.CustID)
				AND b.winlostdate BETWEEN @TempFromDate AND @_ToDate
				AND b.statusID IN (111, 112, 113)
				AND b.transid >= @transid
			GROUP BY   
				b.winlostdate, a.currency,  
				bt.ProductCode
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
				Winlost, LicenseeWL, AmtDueToBA, CommBA,
				PlayerComm, Betcount, licenseeWLBT, BetTradeComm,  
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
				SUM (CASE WHEN RAND() + 1 > 0 THEN b.comm ELSE 0 END) AS CommBA,
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
				  INNER JOIN #tmpCust ag ON b.recommend = ag.AgentID AND b.Currency = ag.currency AND b.winlostdate >= ag.EffectiveDate AND b.winlostdate <= ag.EndDate
			WHERE (ag.CustID IS NULL OR b.custid = ag.CustID)
				AND b.Winlostdate BETWEEN @_FromDate AND @TempToDate  
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
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
				AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
				AND b.roleid = 1   
				AND b.statusID <> 101 --exclude REJECT bets
				AND b.isBA = 1
			GROUP BY b.winlostdate, b.currency
		END
	
		--exclude BA tickets
		IF 1 IN (@showSB, @ShowNG, @ShowVS, @ShowCS, @ShowKN, @ShowMGCLC, @ShowMGCRnG, @ShowAGC, @ShowVB, @ShowAB, @ShowVS2, @ShowLT, @ShowPP)
		BEGIN
			INSERT INTO #SAgWinLoss 
			(  
				winlostdate, Currency, ProductCode, Turnover, BTActualStake,
				Winlost, LicenseeWL, AmtDueToBA, CommBA,
				PlayerComm, Betcount, licenseeWLBT, BetTradeComm,  
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
				-SUM(CASE WHEN RAND() + 1 > 0 THEN b.winlost ELSE 0 END) AS LicenseeWL,
				0 AS AmountDueToBA,
				0 AS CommBA,
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
				INNER JOIN #tmpCust ag   ON b.recommend = ag.AgentID AND ag.currency = b.Currency AND b.winlostdate >= ag.EffectiveDate AND b.winlostdate <= ag.EndDate
				INNER JOIN @sporttype t ON b.sporttype = t.sporttype
			WHERE (ag.CustID IS NULL OR b.custid = ag.CustID)
				AND b.Winlostdate BETWEEN @_FromDate AND @TempToDate
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
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
				AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
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
				Winlost, LicenseeWL, AmtDueToBA, CommBA,
				PlayerComm, Betcount, licenseeWLBT, BetTradeComm,  
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
				0 as CommBA,
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
				INNER JOIN #tmpCust ag ON b.recommend = ag.AgentID AND ag.currency = b.Currency AND b.winlostdate >= ag.EffectiveDate AND b.winlostdate <= ag.EndDate
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
				Winlost, LicenseeWL, AmtDueToBA, CommBA,
				PlayerComm, Betcount, licenseeWLBT, BetTradeComm,  
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
				0 as CommBA,
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
				INNER JOIN #tmpCust ag ON b.recommend = ag.AgentID AND ag.currency = b.Currency AND b.winlostdate >= ag.EffectiveDate AND b.winlostdate <= ag.EndDate
			WHERE (ag.CustID IS NULL OR b.custid = ag.CustID)
				AND b.Winlostdate BETWEEN @_FromDate AND @TempToDate
				AND b.bettype IN (911, 912, 913)
				AND b.statusID  IN (111, 112, 113)
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
		TurnoverVS			MONEY,
		TurnoverCS 			MONEY,
		TurnoverKN			MONEY,
		turnoverMGCLC		MONEY, 
		turnoverMGCRnG		MONEY, 
		turnoverAGC			MONEY,
		turnoverVB			MONEY, 
		turnoverAB			MONEY,
		turnoverCO			MONEY,
		TurnoverVS2		MONEY,
		TurnoverLT			MONEY,
		TurnoverPP			MONEY,
		BTActualStake		MONEY,
		Winlost				MONEY,
		LicenseeWLSB 		MONEY,
		LicenseeWLBA		MONEY,
		LicenseeWLNG		MONEY,
		LicenseeWLVS		MONEY,
		LicenseeWLCS		MONEY,
		LicenseeWLKN		MONEY,
		LicenseeWLMGCLC	    MONEY,
		LicenseeWLMGCRnG	MONEY,
		LicenseeWLAGC		MONEY,
		LicenseeWLVB		MONEY,
		LicenseeWLAB		MONEY,
		LicenseeWLCO		MONEY,
		LicenseeWLVS2		MONEY,
		LicenseeWLLT		MONEY,
		LicenseeWLPP		MONEY,
		AmtDueToBA			MONEY,   
		CommBA				MONEY,   
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
		TurnoverSB, TurnoverBA, TurnoverNG, TurnoverVS, TurnoverCS,
		TurnoverKN, turnoverMGCLC, turnoverMGCRnG, turnoverAGC, turnoverVB, turnoverAB, turnoverCO, TurnoverVS2, TurnoverLT, TurnoverPP,
		BTActualStake, Winlost,
		LicenseeWLSB, LicenseeWLBA, LicenseeWLNG, LicenseeWLVS, LicenseeWLCS,
		LicenseeWLKN, LicenseeWLMGCLC, LicenseeWLMGCRnG, LicenseeWLAGC, LicenseeWLVB, LicenseeWLAB, LicenseeWLCO, LicenseeWLVS2, LicenseeWLLT, LicenseeWLPP,
		AmtDueToBA,
		CommBA, 
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
		SUM(CASE ProductCode WHEN 'VS'		THEN Turnover ELSE 0 END)	AS TurnoverVS,   
		SUM(CASE ProductCode WHEN 'CS'		THEN Turnover ELSE 0 END)	AS TurnoverCS,
		SUM(CASE ProductCode WHEN 'KN'		THEN Turnover ELSE 0 END)	AS TurnoverKN,
		SUM(CASE ProductCode WHEN 'MGCLC'	THEN Turnover ELSE 0 END)   AS TurnoverMGCLC,
		SUM(CASE ProductCode WHEN 'MGCRnG'	THEN Turnover ELSE 0 END)   AS TurnoverMGCRnG,
		SUM(CASE ProductCode WHEN 'AGC'		THEN Turnover ELSE 0 END)	AS TurnoverAGC,
		SUM(CASE ProductCode WHEN 'VB'		THEN Turnover ELSE 0 END)	AS TurnoverVB,
		SUM(CASE ProductCode WHEN 'AB'		THEN Turnover ELSE 0 END)	AS TurnoverAB,
		SUM(CASE ProductCode WHEN 'CO'		THEN Turnover ELSE 0 END)	AS TurnoverCO,
		SUM(CASE ProductCode WHEN 'VS2'		THEN Turnover ELSE 0 END)	AS TurnoverVS2,
		SUM(CASE ProductCode WHEN 'LT'		THEN Turnover ELSE 0 END)	AS TurnoverLT,
		SUM(CASE ProductCode WHEN 'PP'		THEN Turnover ELSE 0 END)	AS TurnoverPP,
		SUM(BTActualStake)		AS BTActualStake,
		SUM(Winlost)			AS Winlost,
		SUM(CASE ProductCode WHEN 'SB'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLSB,   
		SUM(CASE ProductCode WHEN 'BA'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLBA,   
		SUM(CASE ProductCode WHEN 'NG'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLNG,   
		SUM(CASE ProductCode WHEN 'VS'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLVS,   
		SUM(CASE ProductCode WHEN 'CS'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLCS,
		SUM(CASE ProductCode WHEN 'KN'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLKN,
		SUM(CASE ProductCode WHEN 'MGCLC'	THEN LicenseeWL ELSE 0 END) AS LicenseeWLMGCLC,
		SUM(CASE ProductCode WHEN 'MGCRnG'	THEN LicenseeWL ELSE 0 END) AS LicenseeWLMGCRnG,
		SUM(CASE ProductCode WHEN 'AGC'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLAGC,
		SUM(CASE ProductCode WHEN 'VB'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLVB,
		SUM(CASE ProductCode WHEN 'AB'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLAB,
		SUM(CASE ProductCode WHEN 'CO'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLCO,
		SUM(CASE ProductCode WHEN 'VS2'	THEN LicenseeWL ELSE 0 END)	AS LicenseeWLVS2,
		SUM(CASE ProductCode WHEN 'LT'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLLT,
		SUM(CASE ProductCode WHEN 'PP'		THEN LicenseeWL ELSE 0 END)	AS LicenseeWLPP,
		SUM(AmtDuetoBA)			AS AmtDuetoBA,
		SUM(CommBA)				AS CommBA,
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
		SUM(TurnoverSB)			AS TurnoverSB,   
		SUM(TurnoverBA)			AS TurnoverBA,   
		SUM(TurnoverNG)			AS TurnoverNG,   
		SUM(TurnoverVS)			AS TurnoverVS,   
		SUM(TurnoverCS)			AS TurnoverCS,
		SUM(TurnoverKN)			AS TurnoverKN,
		SUM(TurnoverMGCLC)      AS TurnoverMGCLC,
		SUM(TurnoverMGCRnG)     AS TurnoverMGCRnG,
		SUM(TurnoverAGC)		AS TurnoverAGC,
		SUM(TurnoverVB)			AS TurnoverVB,
		SUM(TurnoverAB)			AS TurnoverAB,
		SUM(TurnoverCO)			AS TurnoverCO,
		SUM(TurnoverVS2)		AS TurnoverVS2,
		SUM(TurnoverLT)			AS TurnoverLT,
		SUM(TurnoverPP)			AS TurnoverPP,
		SUM(BTActualStake)		AS BTActualStake,
		SUM(Winlost)			AS Winlost,
		SUM(LicenseeWLSB)		AS LicenseeWLSB,
		SUM(LicenseeWLBA)		AS LicenseeWLBA,
		SUM(LicenseeWLNG)		AS LicenseeWLNG,
		SUM(LicenseeWLVS)		AS LicenseeWLVS,   
		SUM(LicenseeWLCS)		AS LicenseeWLCS,
		SUM(LicenseeWLKN)		AS LicenseeWLKN,
		SUM(LicenseeWLMGCLC)	AS LicenseeWLMGCLC,
		SUM(LicenseeWLMGCRnG)	AS LicenseeWLMGCRnG,
		SUM(LicenseeWLAGC)		AS LicenseeWLAGC,
		SUM(LicenseeWLVB)		AS LicenseeWLVB,
		SUM(LicenseeWLAB)		AS LicenseeWLAB,
		SUM(LicenseeWLCO)		AS LicenseeWLCO,
		SUM(LicenseeWLVS2)		AS LicenseeWLVS2,
		SUM(LicenseeWLLT)		AS LicenseeWLLT,
		SUM(LicenseeWLPP)		AS LicenseeWLPP,
		SUM(CommBA)				AS CommBA,
		SUM(playerComm)			AS PlayerComm,
		SUM(AmtDuetoBA)			AS AmtDuetoBA,
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
		CAST(SUM(TurnoverVS*e.USD)			AS MONEY)	AS TurnoverVSUSD,
		CAST(SUM(TurnoverCS*e.USD)			AS MONEY)   AS TurnoverCSUSD,
		CAST(SUM(TurnoverKN*e.USD)			AS MONEY)   AS TurnoverKNUSD,
		CAST(SUM(TurnoverMGCLC*e.USD)		AS MONEY)   AS TurnoverMGCLCUSD,
		CAST(SUM(TurnoverMGCRnG*e.USD)		AS MONEY)   AS TurnoverMGCRnGUSD,
		CAST(SUM(TurnoverAGC*e.USD)			AS MONEY)   AS TurnoverAGCUSD,
		CAST(SUM(TurnoverVB*e.USD)			AS MONEY)   AS TurnoverVBUSD,
		CAST(SUM(TurnoverAB*e.USD)			AS MONEY)   AS TurnoverABUSD,
		CAST(SUM(TurnoverCO*e.USD)			AS MONEY)   AS TurnoverCOUSD,
		CAST(SUM(TurnoverVS2*e.USD)			AS MONEY)   AS TurnoverVS2USD,
		CAST(SUM(TurnoverLT*e.USD)			AS MONEY)   AS TurnoverLTUSD,
		CAST(SUM(TurnoverPP*e.USD)			AS MONEY)   AS TurnoverPPUSD,
		CAST(SUM(BTActualStake*e.USD)		AS MONEY)   AS BTActualStakeUSD,
		CAST(SUM(Winlost*e.USD)				AS MONEY)	AS WinlostUSD,
		CAST(SUM(LicenseeWLSB*e.USD)		AS MONEY)	AS LicenseeWLSBUSD,
		CAST(SUM(LicenseeWLBA*e.USD)		AS MONEY)	AS LicenseeWLBAUSD,
		CAST(SUM(LicenseeWLNG*e.USD)		AS MONEY) 	AS LicenseeWLNGUSD,
		CAST(SUM(LicenseeWLVS*e.USD)		AS MONEY)	AS LicenseeWLVSUSD,
		CAST(SUM(LicenseeWLCS*e.USD)		AS MONEY)	AS LicenseeWLCSUSD,
		CAST(SUM(LicenseeWLKN*e.USD)		AS MONEY)	AS LicenseeWLKNUSD,
		CAST(SUM(LicenseeWLMGCLC*e.USD)		AS MONEY)	AS LicenseeWLMGCLCUSD,
		CAST(SUM(LicenseeWLMGCRnG*e.USD)	AS MONEY)	AS LicenseeWLMGCRnGUSD,
		CAST(SUM(LicenseeWLAGC*e.USD)		AS MONEY)	AS LicenseeWLAGCUSD,
		CAST(SUM(LicenseeWLVB*e.USD)		AS MONEY)	AS LicenseeWLVBUSD,
		CAST(SUM(LicenseeWLAB*e.USD)		AS MONEY)	AS LicenseeWLABUSD,
		CAST(SUM(LicenseeWLCO*e.USD)		AS MONEY)	AS LicenseeWLCOUSD,
		CAST(SUM(LicenseeWLVS2*e.USD)		AS MONEY)	AS LicenseeWLVS2USD,
		CAST(SUM(LicenseeWLLT*e.USD)		AS MONEY)	AS LicenseeWLLTUSD,
		CAST(SUM(LicenseeWLPP*e.USD)		AS MONEY)	AS LicenseeWLPPUSD,
		CAST(SUM(CommBA * e.USD)			AS MONEY)	AS CommBAUSD,
		CAST(SUM(PlayerComm*e.USD)			AS MONEY)	AS PlayerCommUSD,
		CAST(SUM(AmtDuetoBA*e.USD)			AS MONEY)	AS AmtDuetoBAUSD,
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
				ELSE '0' END
	ORDER BY ReportType

	DROP TABLE #SAgWinLoss

	DROP TABLE #TempExchange

END
GO