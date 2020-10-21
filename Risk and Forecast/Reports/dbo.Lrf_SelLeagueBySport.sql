/*<info serverAlias="DBLIC-bodb_Licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_SelLeagueBySport]
	@AgentList				VARCHAR(MAX),
	@SportId				INT,
	@FromDate				SMALLDATETIME,
	@ToDate					SMALLDATETIME,
	@MoveBetsDay			SMALLDATETIME,
	@IsIncludeTestLeague	BIT				= 0
AS

/*
	Created: 20140102@Florent
	Task: Get LeagueID from sport type
	DB: DBLIC.bodb_Licensee

	Revisions:
		- 20140117@Florent: add new sport 154
		- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
		- 20170228@Paul: Get @AgentList by web instead of @UserId, @CurrencyID, @LicenseeID [Redmine: #71679]
		- 20180319: Enhance SP because of timeout issue [Redmine: #92292] 
		- 20190104@Joseph: Add param @IsIncludeTestLeague to exclude test leagues [Redmine: #107473]
		- 20200929@Kos: Return addtional column LeagueGroupId [Redmine: #141454]
					- Add new param @MoveBetsDay SMALLDATETIME
		- 20201019@Kos: Change to use new table to check performance [RedmineID: #143310]
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #TempAg (CustId INT, Currency INT, PRIMARY KEY (CustId, Currency))

	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	
		INSERT INTO #TempAg (CustId, Currency)
		SELECT AgentId, Currency 
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'ParamEter invalid.'

		RETURN
	END CATCH;

	CREATE TABLE #tblLeagueid (LeagueId INT)

	DECLARE @f SMALLDATETIME
		,@t SMALLDATETIME
		,@TempFromDate SMALLDATETIME
		,@TempToDate SMALLDATETIME
 
	--------
	SET @f = @FromDate
	SET @t = @ToDate

	IF @t > @MoveBetsDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
			SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @f

		INSERT INTO #tblLeagueid
		SELECT leagueid
		FROM bodb02.dbo.match WITH (NOLOCK)
		WHERE eventdate BETWEEN @TempFromDate AND @t
		GROUP BY leagueid
	END

	IF @f <= @MoveBetsDay
	BEGIN
		IF @t >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @t

		CREATE TABLE #Date (Date SMALLDATETIME, PRIMARY KEY(Date))

		INSERT INTO #Date
		SELECT [Date]
		FROM bodb02.dbo.f_GetDateBetweenTwoDates (@f, @TempToDate)

		INSERT INTO #tblLeagueid
		SELECT DISTINCT rwl.leagueid
		FROM #Date AS d
			CROSS APPLY (
				SELECT rwl.leagueid
				FROM bodb_LicenseeReport.dbo.rptWinlostbyLeague AS rwl WITH (NOLOCK)
					INNER JOIN #TempAg ta on rwl.recommend = ta.custid AND rwl.currency = ta.currency
				WHERE rwl.winlostdate = d.Date
				GROUP BY rwl.leagueid
			) AS rwl

		DROP TABLE #Date
	END

	SELECT
		l.leagueid,
		l.sporttype sportid,
		ISNULL(l.LeagueGroupID, 0) AS LeagueGroupID
	FROM #tblLeagueid AS m
		INNER JOIN bodb02.dbo.League AS l WITH (NOLOCK) ON m.LeagueId = l.leagueid
	WHERE (@IsIncludeTestLeague = 1 OR l.isTest = 0)
		AND (@SportId = 0 OR l.sporttype = @SportId)
		AND l.sporttype < 100
		AND l.leagueid > 0
	GROUP BY l.leagueid,
		l.sporttype,
		l.LeagueGroupID
	ORDER BY l.sporttype

	DROP TABLE #tblLeagueid
	DROP TABLE #TempAg
END
GO
