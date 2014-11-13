USE [bodb_licensee]
GO
 
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Lrf_SelLeagueBySport] 
	 @LicenseeID INT
	,@CurrencyID INT=0
	,@userID INT
	,@sportId INT
	,@Fromdate SMALLDATETIME
	,@Todate SMALLDATETIME
AS
/*
Created: 20140102@Florent
Task : Get LeagueID from sport type
DB: DBLIC/bodb_Licensee

Revisions:
	- 20140117@Florent: add new sport 154
	- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
Param's Explanation:	
*/
SET NOCOUNT ON

BEGIN
	CREATE TABLE #tblLeagueid (leagueid INT)
	CREATE TABLE #tblBalanceDate (
		BalanceUpDay DATETIME
		,MoveBetsDay DATETIME
		)
	DECLARE @f DATETIME
		,@t DATETIME
		,@TempFromDate DATETIME
		,@TempToDate DATETIME
		,@MoveBetsDay DATETIME

	INSERT INTO #tblBalanceDate
	EXEC bodb02.dbo.Lrf_SelBalanceUpDay

	SELECT @MoveBetsDay = MoveBetsDay
	FROM #tblBalanceDate
	--------
	SELECT  currencyID,LicenseeID into #currency
	FROM  bodb02.dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
	WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))
	-------

	DECLARE @TempAg AS TABLE (custid INT)
	INSERT INTO @TempAg (custid)
	SELECT  DISTINCT lc.CustID  
	FROM    bodb_Licensee.dbo.f_SelLicenseeCust(@licenseeID) lc
			INNER JOIN #currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID
 
	--------
	SET @f = @Fromdate
	SET @t = @Todate

	IF @t > @MoveBetsDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
			SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @f

		INSERT INTO #tblLeagueid
		SELECT m.leagueid
		FROM bodb02.dbo.match AS m WITH (NOLOCK)
		WHERE m.eventdate BETWEEN @TempFromDate AND @t
		GROUP BY leagueid
	END

	IF @f <= @MoveBetsDay
	BEGIN
		IF @t >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @t

		INSERT INTO #tblLeagueid
		SELECT leagueid
		FROM bodb_LicenseeReport.dbo.rptWinlostbyLeague AS rwl WITH (NOLOCK)
		INNER JOIN @TempAg ta on rwl.recommend=ta.custid
		WHERE   rwl.winlostdate BETWEEN @f AND @TempToDate
		GROUP BY leagueid
	END

	SELECT l.leagueid
		,l.sporttype sportid
	FROM #tblLeagueid m
	INNER JOIN bodb02.dbo.League AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
	WHERE (
			(@sportId = 0)
			OR (l.sporttype = @sportId)
			)
		AND (l.sporttype < 100 or l.sporttype=154)
		and l.leagueid>0
	group by l.leagueid	,l.sporttype
	order by l.sporttype
	DROP TABLE #tblLeagueid
	DROP TABLE #tblBalanceDate
	DROP TABLE #currency
END

GO
GRANT EXECUTE
	ON [dbo].[Lrf_SelLeagueBySport]
	TO [bodbLicenseeNet] AS [dbo]
GO

GRANT VIEW DEFINITION
	ON [dbo].[Lrf_SelLeagueBySport]
	TO [vnteam] AS [dbo]
GO


