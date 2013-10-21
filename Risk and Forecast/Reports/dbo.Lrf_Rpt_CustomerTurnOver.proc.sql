set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go


ALTER   PROCEDURE  [dbo].[Lrf_Rpt_CustomerTurnOver]
	 @LicenseeID INT,
	 @UserID  INT,
	 @Username VARCHAR(50)='', 
	 @Product  VARCHAR(50), 
	 @Bettype  VARCHAR(200), 
	 @CurrencyID INT,
	 @FromDate SMALLDATETIME,
	 @ToDate SMALLDATETIME,
	 @Odds FLOAT,
	 @ReportBy  TINYINT   = 1, 
	 @MoveBetsDay SMALLDATETIME,
	 @BalanceUpDay SMALLDATETIME,
	 @Langkey NVARCHAR(10)='en-US' ,
	 @PageSize INT=1000,
	 @PageIndex INT=1,
	 @IsExportExcel bit =0,
	 @ShowWin bit=1,
	 @ShowLoss bit=1,
	 @ShowDraw bit=1
AS

/*	
	Created	: Henry
	Task: Customer Performance Report
	Date: 2011-12-28
	DB: DBRPT/BODB02
	Original: Lrf_Rpt_CustomerPerformance
	Revision:
	- 20120214@Henry: Seperate 3 options: Win/Loss/Draw (and all)
	- 20120801@Jim: add PlayerComm value 
    - 20130124@Daniel: Change link server alias
	- 20130618@Jim:  Restrict permission of Licensee Users by currency
	- 20131021@Jim: Add more products to Customer Turnover Report
	Parameter's Explanation:
		- @ReportBy:  1: daily, 2: monthly
		- @FilterBy:  1: Win, 2: Loss, 3: Draw
		- @SportID   : Sport type ID  
		- @bettype   : Bet type ID  
		- @MoveBetsDay: The day we move tickets to bettrans14
		- @BalanceUpDay: The day we move tickets to bettrans_bk
		
			
*/ 
SET NOCOUNT ON

DECLARE @TempFromDate SMALLDATETIME
DECLARE @TempToDate SMALLDATETIME
DECLARE @CustID INT
DECLARE @checkSB BIT 

CREATE TABLE #Data
(
	CustID INT,
	winlostdate DATETIME,
	sporttype INT, 
	bettype INT,
	currency SMALLINT,
	Turnover	MONEY,   
	Winlost		MONEY,
	PlayerComm  MONEY,
	Odds SMALLMONEY,
	OddsType SMALLINT
)

DECLARE @Status AS TABLE
(
	StatusID INT
)

CREATE TABLE #DataSum
(
	totaltransaction			 INT,
	SumTurnover				 MONEY,
	SumWinlost 				 MONEY,
	SumComm					MONEY,
	Total							MONEY
)

DECLARE @RowStart INT ,
        @RowEnd INT 
		
SELECT VAL sportID INTO #ProductID FROM strSplit(@Product,',')
SELECT VAL bettypeID INTO #BettypeID FROM strSplit(@Bettype,',')

SELECT  @PageIndex = @PageIndex - 1 ,
            @RowStart = @PageSize * @PageIndex + 1 ,
            @RowEnd = @RowStart + @PageSize - 1 
			
IF EXISTS (SELECT 1 FROM #ProductID WHERE SportID=0)
	BEGIN 
		SET @checkSB=1
	END 
ELSE 
	BEGIN 
		SET @checkSB=0
	END	
IF  NOT EXISTS (SELECT TOP 1 1  FROM #ProductID )
	BEGIN 
		RETURN
	END 
ELSE 
	BEGIN 

		SELECT lc.CustID INTO #Currency
		FROM DBLIC.bodb_licensee.dbo.LicenseeCust lc WITH (NOLOCK) 
			INNER JOIN DBLIC.bodb_licensee.dbo.CurrencyUser c WITH (NOLOCK)
			ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID	
		WHERE lc.LicenseeID=@LicenseeID 
		AND lc.RoleID=2
		AND lc.Currency=@CurrencyID
		AND c.usrID=@userID 
		AND c.SystemID=1 -- System is default=1 (LRF)	
		AND c.isActive=1

		SELECT @Username = ltrim(rtrim(@Username))
		IF ISNULL(@Username,'')<>''
		BEGIN 

			SELECT @CustID = cr.CustID 
			FROM Customer cr (NOLOCK)
				INNER JOIN #Currency c ON cr.recommend=c.CustID
			WHERE username2 LIKE '%$' + @Username

			IF ISNULL(@CustID,0) = 0
			BEGIN
				SELECT @CustID = cr.CustID 
				FROM Customer cr(NOLOCK)
					INNER JOIN #Currency c ON cr.recommend=c.CustID
				WHERE username = @Username
			END
		END

		DROP TABLE #Currency 

		IF @ShowWin =1
		BEGIN
			INSERT INTO @Status
			SELECT 112
		END

		IF @ShowLoss=1
		BEGIN
			INSERT INTO @Status
			SELECT 113
		END

		IF  @ShowDraw=1
		BEGIN
			INSERT INTO @Status
			SELECT 111
		END

		IF @Todate > @MoveBetsDay
		BEGIN
			IF @FromDate <= @MoveBetsDay 
				SET @TempFromDate =  DATEADD(DAY,1,@MoveBetsDay)
			ELSE
				SET @TempFromDate = @FromDate
			
			INSERT INTO #DataSum
			SELECT 
					COUNT(currency) totaltransaction,
					SUM(stake)	sumTurnover,
					SUM(b.winlost-b.actual_stake) SumWinlost,
					Sum(b.PlayerComm)  SumComm,
					sum(b.winlost-b.actual_stake+b.PlayerComm) Total
			FROM bettrans b WITH (NOLOCK)
			INNER JOIN #BettypeID bet  ON b.bettype=bet.bettypeID
			LEFT JOIN match m WITH (NOLOCK) ON b.matchid = m.matchid
			LEFT JOIN outright o with(nolock) ON b.matchid = o.orid 
			LEFT JOIN league l with(nolock) ON o.leagueid = l.leagueid
			WHERE 
					b.winlostdate BETWEEN @TempFromDate AND @todate
					AND (b.CustID = @CustID OR ISNULL(@CustID,'')='')
					AND ((m.sporttype<100 AND @checkSB=1) OR (m.sporttype IN (SELECT sportID FROM #ProductID)))
					AND b.statusID IN (SELECT StatusID FROM @Status)
			
					
			INSERT INTO #Data
			SELECT 
				b.CustID,
				winlostdate,
				m.sporttype,
				b.bettype,
				currency,
				stake as turnover,
				b.winlost - b.actual_stake as winlost,
				b.PlayerComm ,
				b.Odds,
				b.Oddstype
			FROM bettrans b WITH (NOLOCK)
			INNER JOIN #BettypeID bet  ON b.bettype=bet.bettypeID
			LEFT JOIN match m WITH (NOLOCK) ON b.matchid = m.matchid
			LEFT JOIN outright o with(nolock) ON b.matchid = o.orid 
			LEFT JOIN league l with(nolock) ON o.leagueid = l.leagueid
			WHERE 
				b.winlostdate BETWEEN @TempFromDate AND @todate
				AND (b.CustID = @CustID OR ISNULL(@CustID,'')='')
				AND ((m.sporttype<100 AND @checkSB=1) OR (m.sporttype IN (SELECT sportID FROM #ProductID)))
				AND b.statusID IN (SELECT StatusID FROM @Status)
		END
		IF @Fromdate <= @MoveBetsDay
		BEGIN
			IF @ToDate >= @MoveBetsDay
				SET @TempToDate = @MoveBetsDay
			ELSE
				SET  @TempToDate = @ToDate
				
			IF @BalanceUpDay < @FromDate 
				SELECT @BalanceUpDay=@FromDate
			
			INSERT INTO #DataSum
			SELECT 
					COUNT(currency) totaltransaction,
					SUM(stake)	sumTurnover,
					SUM(b.winlost-b.actual_stake) SumWinlost,
					Sum(b.PlayerComm)  SumComm,
					sum(b.winlost-b.actual_stake+b.PlayerComm) Total
			FROM bettrans14 b WITH (NOLOCK)
			INNER JOIN #BettypeID bet  ON b.bettype=bet.bettypeID
			LEFT JOIN match14 m WITH (NOLOCK) ON b.matchid = m.matchid
			LEFT JOIN outright14 o with(nolock) ON b.matchid = o.orid 
			LEFT JOIN league l with(nolock) ON o.leagueid = l.leagueid
			WHERE 
					b.winlostdate BETWEEN @TempFromDate AND @todate
					AND (b.CustID = @CustID OR ISNULL(@CustID,'')='')
					AND ((m.sporttype<100 AND @checkSB=1) OR (m.sporttype IN (SELECT sportID FROM #ProductID)))
					AND b.statusID IN (SELECT StatusID FROM @Status)	
			
			INSERT INTO #Data
			SELECT 
				b.CustID,
				winlostdate,
				m.sporttype,
				b.bettype,
				currency,
				stake as turnover,
				b.winlost - b.actual_stake as winlost,
				b.PlayerComm,
				b.Odds,
				b.Oddstype
			FROM bettrans14 b WITH (NOLOCK)
			INNER JOIN #BettypeID bet  ON b.bettype=bet.bettypeID
			LEFT JOIN match14 m WITH (NOLOCK) ON b.matchid = m.matchid
			LEFT JOIN outright14 o with(nolock) ON b.matchid = o.orid 
			LEFT JOIN league l with(nolock) ON o.leagueid = l.leagueid
			WHERE 
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
				AND (b.CustID = @CustID OR ISNULL(@CustID,'')='')
				AND ((m.sporttype<100 AND @checkSB=1) OR (m.sporttype IN (SELECT sportID FROM #ProductID)))
				AND b.statusID IN (SELECT StatusID FROM @Status)
		END

		IF @FromDate < @BalanceUpDay
		BEGIN
			IF @todate >= DATEADD(dd, -1, @BalanceUpDay)
				SET @TempToDate = DATEADD(dd, -1, @BalanceUpDay)
			ELSE
				SET @TempToDate = @todate
			
			
			SELECT 
					bk.winlostdate,
					bk.CustID,
					bk.bettype,
					bk.matchid,
					bk.currency,
					bk.stake as turnover,
					bk.winlost - bk.actual_stake as winlost,
					bk.PlayerComm,
					bk.Odds,
					bk.oddstype,
					bk.statusID
			INTO #temp_bk
			FROM 
					bodb_archive.dbo.bettrans_bk bk WITH (NOLOCK,INDEX=IX_custid)
					INNER JOIN #BettypeID bet  ON bk.bettype=bet.bettypeID
					LEFT JOIN bodb_archive.dbo.Outright_BK o with(nolock) ON bk.matchid = o.orid 
					--LEFT JOIN league l with(nolock) ON o.leagueid = l.leagueid	
					WHERE
							bk.winlostdate BETWEEN @fromdate AND @TempToDate
							AND (bk.CustID = @CustID OR ISNULL(@CustID,'')='')
							AND bk.statusID IN (SELECT StatusID FROM @Status)
							
			INSERT INTO #DataSum
			SELECT 
					COUNT(b.currency) totaltransaction,
					SUM(b.turnover)	sumTurnover,
					SUM(b.winlost) SumWinlost,
					Sum(b.PlayerComm)  SumComm,
					sum(b.winlost+b.PlayerComm) Total
			FROM #temp_bk  b
			LEFT JOIN bodb_archive.dbo.MATCH_BK m WITH (NOLOCK) ON b.matchid = m.matchid
			WHERE 
					((m.sporttype<100 AND @checkSB=1) OR (m.sporttype IN (SELECT sportID FROM #ProductID)))
					
	
			INSERT INTO #Data
			SELECT 
				b.CustID,
				b.winlostdate,
				m.sporttype,
				b.bettype,
				currency,
				b.turnover,
				b.winlost,
				b.PlayerComm,
				b.Odds,
				b.Oddstype
			FROM #temp_bk  b
			LEFT JOIN bodb_archive.dbo.MATCH_BK m WITH (NOLOCK) ON b.matchid = m.matchid
			WHERE 
				 ((m.sporttype<100 AND @checkSB=1) OR (m.sporttype IN (SELECT sportID FROM #ProductID)))
			DROP TABLE #temp_bk
				
		END


		UPDATE #Data
		SET odds = CASE WHEN OddsType = 1 THEN odds + 1 --decimal
						WHEN OddsType = 2 THEN Odds + 1 --hongkong to decimal
						WHEN OddsType IN (3,4) THEN --malay and indo to decimal
												CASE 
													WHEN odds < 0 THEN (1 -  cast(1 as float) / cast(odds AS float))
													WHEN odds >=0 THEN (1 + odds) END
						WHEN OddsType = 5 THEN --american odds to decimal
											CASE
											WHEN (odds * 100) < 0 THEN (1- cast (1 AS float)/ cast (odds AS float))
											WHEN (odds * 100) % 2 = 0 THEN 2
											WHEN (odds * 100) > 0 THEN (1 + odds) END 
						ELSE odds END		
		WHERE 
			bettype IN (1,2,3,7,12,8,20)	
			OR bettype BETWEEN 81 AND 88
			OR bettype BETWEEN 90 AND 120
			
		SELECT 
			CASE WHEN @ReportBy = 1 THEN CONVERT(VARCHAR(8),winlostdate,112)  
				WHEN @ReportBy = 2 THEN CONVERT(VARCHAR(6),winlostdate,112)  
				ELSE '0' END ReportBy,  
				A.*
		FROM 
		(	
		SELECT   
			ROW_NUMBER() over(order by username, sporttype) AS RowNum,
			b.winlostdate,
			ISNULL(right(charindex ('$',c.username2),len(c.username2)),username) as 	username,
			CASE 
				WHEN e.exchangeid = 20 THEN 'UUS'
				WHEN e.exchangeid = 51 THEN e.currency
				ELSE e.Code END AS Currency,
			b.sporttype,	
			CASE WHEN  b.bettype BETWEEN 81 AND 120 THEN N'NG - ' + bt.typenamee 
				 WHEN (b.bettype BETWEEN 1201 AND 1299 AND typeid NOT IN (1220,1235,1236,1231,1232,1233,1237,1238)) THEN N'V.'+bt.typenamee 
				 ELSE bt.typenamee END AS bettype,
			count(b.currency) AS Betcount,
			sum(b.turnover) AS Turnover,
			sum(b.winlost) AS Winlost,
			SUM(PlayerComm) AS PlayerComm
			
		FROM #Data b
			INNER JOIN dbo.Customer c WITH (NOLOCK) ON b.CustID=c.CustID 
			INNER JOIN bettype bt WITH (NOLOCK) ON b.bettype = bt.typeid
			INNER JOIN exchange e WITH (NOLOCK) ON b.currency = e.exchangeid
		WHERE b.Odds >= @Odds
			 AND c.RoleID=1
		GROUP BY 
			b.winlostdate,	
			ISNULL(right(charindex ('$',c.username2),len(c.username2)),username) ,
			CASE 
				WHEN e.exchangeid = 20 THEN 'UUS'
				WHEN e.exchangeid = 51 THEN e.currency
				ELSE e.Code END,
			b.sporttype,	
			CASE WHEN  b.bettype BETWEEN 81 AND 120 THEN N'NG - ' + bt.typenamee 
				 WHEN (b.bettype BETWEEN 1201 AND 1299 AND typeid NOT IN (1220,1235,1236,1231,1232,1233,1237,1238)) THEN N'V.'+bt.typenamee 
				 ELSE bt.typenamee END
		
			)A
		WHERE ( A.RowNum between @RowStart AND @RowEnd	AND  @IsExportExcel=0) OR @IsExportExcel=1
		ORDER BY
			CASE WHEN @ReportBy = 1 THEN CONVERT(VARCHAR(8),winlostdate,112)  
				WHEN @ReportBy = 2 THEN CONVERT(VARCHAR(6),winlostdate,112)  
				ELSE '0' END
		SELECT SUM(totaltransaction) totaltransaction,
				   sum(SumTurnover) SumTurnover,
				  sum(SumWinlost) SumWinlost ,
				  sum(SumComm) SumComm,
				  sum(Total) Total			 	
		FROM #DataSum
				
		DROP TABLE #Data	
		DROP TABLE #DataSum	
	END
		
DROP TABLE #ProductID
DROP TABLE #BettypeID

GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_CustomerTurnOver] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_CustomerTurnOver] TO [vnteam] 
