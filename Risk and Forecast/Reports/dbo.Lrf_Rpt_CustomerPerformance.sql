ALTER PROC [dbo].[Lrf_Rpt_CustomerPerformance]
	@LicenseeID INT,
	@Username VARCHAR(50),
	@FromDate SMALLDATETIME,
	@ToDate SMALLDATETIME,
	@SportID  INT    = 0,  
	@bettype  INT    = 0,  
	@Odds FLOAT,
	@ReportBy  TINYINT   = 1, 
	@FilterBy VARCHAR(100) = '', 
	@MoveBetsDay SMALLDATETIME,
	@BalanceUpDay SMALLDATETIME
AS

BEGIN
/*	
	Created	: Henry
	Task: Customer Performance Report
	Date: 2011-12-28
	DB: DBRPT/BODB02
	Original: 
	Revision:
	- 20120214@Henry: Seperate 3 options: Win/Loss/Draw (and all)
	- 20120801@Jim: add PlayerComm value 
    - 20130124@Daniel: Change link server alias

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

CREATE TABLE #Data
(
	winlostdate DATETIME,
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
 

SELECT @Username = ltrim(rtrim(@Username))

SELECT @CustID = CustID FROM Customer (NOLOCK)
WHERE
	recommend IN (SELECT CustID FROM DBLIC.bodb_licensee.dbo.LicenseeCust WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND RoleID=2)
	AND 
	username2 LIKE '%$' + @Username

IF ISNULL(@CustID,0) = 0
BEGIN
	SELECT @CustID = CustID FROM Customer (NOLOCK)
	WHERE
		recommend IN (SELECT CustID FROM DBLIC.bodb_licensee.dbo.LicenseeCust WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND RoleID=2)
		AND 
		username = @Username
END


IF ISNULL(@CustID,0) = 0
BEGIN
	SELECT '' AS ReportBy, '' AS Currency,0 AS BetCount,'' AS Bettype,Turnover,Winlost,PlayerComm
	FROM #Data
	RETURN
END

IF LTRIM(RTRIM(@FilterBy))=''
	SET @FilterBy = '1,2,3'

IF 1 IN (SELECT VAL FROM strSplit(@FilterBy,','))
BEGIN
	INSERT INTO @Status
	SELECT 112
END

IF 2 IN (SELECT VAL FROM strSplit(@FilterBy,','))
BEGIN
	INSERT INTO @Status
	SELECT 113
END

IF 3 IN (SELECT VAL FROM strSplit(@FilterBy,','))
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

	INSERT INTO #Data
	SELECT 
		winlostdate,
		bettype,
		currency,
		stake as turnover,
		b.winlost - b.actual_stake as winlost,
		b.PlayerComm ,
		b.Odds,
		b.Oddstype
	FROM bettrans b WITH (NOLOCK)
	LEFT JOIN match m WITH (NOLOCK) ON b.matchid = m.matchid
	LEFT JOIN outright o with(nolock) ON b.matchid = o.orid 
	LEFT JOIN league l with(nolock) ON o.leagueid = l.leagueid
	WHERE 
		b.winlostdate BETWEEN @TempFromDate AND @todate
		AND b.CustID = @CustID
		AND b.bettype<=999
		AND b.bettype NOT BETWEEN 31 AND 120
		AND b.statusID IN (SELECT StatusID FROM @Status)
		AND (@bettype=0 OR (@bettype<>0 AND b.bettype = @bettype  ))
		AND (@SportID=0 OR (@SportID<>0 AND b.bettype=10 AND l.sporttype = @SportID) OR (@SportID<>0 AND b.bettype NOT IN (9,29,10) AND m.sporttype = @SportID) )	
	
			
END
IF @Fromdate <= @MoveBetsDay
BEGIN
	IF @ToDate >= @MoveBetsDay
		SET @TempToDate = @MoveBetsDay
	ELSE
		SET  @TempToDate = @ToDate
		
	IF @BalanceUpDay < @FromDate 
		SELECT @BalanceUpDay=@FromDate
		
	INSERT INTO #Data
	SELECT 
		winlostdate,
		bettype,
		currency,
		stake as turnover,
		b.winlost - b.actual_stake as winlost,
		b.PlayerComm,
		b.Odds,
		b.Oddstype
	FROM bettrans14 b WITH (NOLOCK)
	LEFT JOIN match14 m WITH (NOLOCK) ON b.matchid = m.matchid
	LEFT JOIN outright14 o with(nolock) ON b.matchid = o.orid 
	LEFT JOIN league l with(nolock) ON o.leagueid = l.leagueid
	WHERE 
		b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
		AND b.CustID = @CustID
		AND b.bettype<=999
		AND b.bettype NOT BETWEEN 31 AND 120
		AND b.statusID IN (SELECT StatusID FROM @Status)
		AND (@bettype=0 OR (@bettype<>0 AND b.bettype = @bettype  ))
		AND (@SportID=0 OR (@SportID<>0 AND b.bettype=10 AND l.sporttype = @SportID) OR (@SportID<>0 AND b.bettype NOT IN (9,29,10) AND m.sporttype = @SportID) )			
	
END

IF @FromDate < @BalanceUpDay
BEGIN
	IF @todate >= DATEADD(dd, -1, @BalanceUpDay)
		SET @TempToDate = DATEADD(dd, -1, @BalanceUpDay)
	ELSE
		SET @TempToDate = @todate
		
	INSERT INTO #Data
	SELECT 
		winlostdate,
		bettype,
		currency,
		stake as turnover,
		b.winlost - b.actual_stake as winlost,
		b.PlayerComm,
		b.Odds,
		b.Oddstype
	FROM bodb_archive.dbo.bettrans_bk b WITH (NOLOCK,INDEX=IX_custid)
	LEFT JOIN bodb_archive.dbo.MATCH_BK m WITH (NOLOCK) ON b.matchid = m.matchid
	LEFT JOIN bodb_archive.dbo.Outright_BK o with(nolock) ON b.matchid = o.orid 
	LEFT JOIN league l with(nolock) ON o.leagueid = l.leagueid
	WHERE 
		b.winlostdate BETWEEN @fromdate AND @TempToDate
		AND b.CustID = @CustID
		AND b.bettype<=999
		AND b.bettype NOT BETWEEN 31 AND 120
		AND b.statusID IN (SELECT StatusID FROM @Status)
		AND (@bettype=0 OR (@bettype<>0 AND b.bettype = @bettype  ))
		AND (@SportID=0 OR (@SportID<>0 AND b.bettype=10 AND l.sporttype = @SportID) OR (@SportID<>0 AND b.bettype NOT IN (9,29,10) AND m.sporttype = @SportID) )			
		
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
	--OR bettype BETWEEN 1101 AND 1199 -- add live casino

SELECT   
	CASE WHEN @ReportBy = 1 THEN CONVERT(VARCHAR(8),b.winlostdate,112)  
		WHEN @ReportBy = 2 THEN CONVERT(VARCHAR(6),b.winlostdate,112)  
		ELSE '0' END ReportBy,  
	CASE 
		WHEN e.exchangeid = 20 THEN 'UUS'
		WHEN e.exchangeid = 51 THEN e.currency
		ELSE e.Code END AS Currency,
	count(b.currency) AS Betcount,
	bt.typenamee AS bettype,
	sum(b.turnover) AS Turnover,
	sum(b.winlost) AS Winlost,
	SUM(PlayerComm) AS PlayerComm
	
FROM #Data b
	INNER JOIN bettype bt WITH (NOLOCK) ON b.bettype = bt.typeid
	INNER JOIN exchange e WITH (NOLOCK) ON b.currency = e.exchangeid
WHERE b.Odds >= @Odds
GROUP BY 	
	CASE WHEN @ReportBy = 1 THEN CONVERT(VARCHAR(8),b.winlostdate,112)  
		WHEN @ReportBy = 2 THEN CONVERT(VARCHAR(6),b.winlostdate,112)  
		ELSE '0' END,  
	CASE 
		WHEN e.exchangeid = 20 THEN 'UUS'
		WHEN e.exchangeid = 51 THEN e.currency
		ELSE e.Code END,
	bt.typenamee
ORDER BY
	CASE WHEN @ReportBy = 1 THEN CONVERT(VARCHAR(8),b.winlostdate,112)  
		WHEN @ReportBy = 2 THEN CONVERT(VARCHAR(6),b.winlostdate,112)  
		ELSE '0' END
	
DROP TABLE #Data	

	
END
GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_CustomerPerformance] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_CustomerPerformance] TO [vnteam] AS [dbo]