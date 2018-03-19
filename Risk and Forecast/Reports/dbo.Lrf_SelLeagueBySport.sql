USE [bodb_licensee]
GO
 
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Lrf_SelLeagueBySport] 
	@sportId INT
	,@Fromdate SMALLDATETIME
	,@Todate SMALLDATETIME
	,@AgentList	VARCHAR(MAX)
AS
/*
Created: 20140102@Florent
Task : Get LeagueID from sport type
DB: DBLIC/bodb_Licensee

Revisions:
	- 20140117@Florent: add new sport 154
	- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
	- 20170228@Paul: Get @AgentList by web instead of @UserId, @CurrencyID, @LicenseeID [Redmine: #71679]
	- 20180319: Enhance SP because of timeout issue [Redmine: #92292] 
Param's Explanation:	
*/
SET NOCOUNT ON

BEGIN
	CREATE TABLE #tblLeagueid (leagueid INT)
	CREATE TABLE #tblBalanceDate (
		BalanceUpDay SMALLDATETIME
		,MoveBetsDay SMALLDATETIME
		)
	DECLARE @f SMALLDATETIME
		,@t SMALLDATETIME
		,@TempFromDate SMALLDATETIME
		,@TempToDate SMALLDATETIME
		,@MoveBetsDay SMALLDATETIME

	INSERT INTO #tblBalanceDate
	EXEC bodb02.dbo.Lrf_SelBalanceUpDay

	SELECT @MoveBetsDay = MoveBetsDay
	FROM #tblBalanceDate
	--------
	DECLARE @TempAg AS TABLE (CustId INT,Currency int)

	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	
		INSERT INTO @TempAg(CustId, Currency)
		SELECT AgentId, Currency 
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;
 
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
		INNER JOIN @TempAg ta on rwl.recommend=ta.custid AND rwl.currency = ta.currency
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


