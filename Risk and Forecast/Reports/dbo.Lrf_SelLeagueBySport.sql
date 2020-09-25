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
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @TempAg AS TABLE (CustId INT,Currency int)

	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	
		INSERT INTO @TempAg(CustId, Currency)
		SELECT AgentId, Currency 
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'ParamEter invalid.'

		RETURN
	END CATCH;

	CREATE TABLE #tblLeagueid (leagueid INT)

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

		INSERT INTO #tblLeagueid
		SELECT rwl.leagueid
		FROM bodb_LicenseeReport.dbo.rptWinlostbyLeague AS rwl WITH (NOLOCK)
			INNER JOIN @TempAg ta on rwl.recommend = ta.custid AND rwl.currency = ta.currency
		WHERE rwl.winlostdate BETWEEN @f AND @TempToDate
		GROUP BY rwl.leagueid
	END

	SELECT
		l.leagueid,
		l.sporttype sportid,
		l.LeagueGroupID
	FROM #tblLeagueid m
		INNER JOIN bodb02.dbo.League AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
	WHERE (@IsIncludeTestLeague = 1 OR l.isTest = 0)
		AND (@SportId = 0 OR l.sporttype = @SportId)
		AND l.sporttype < 100
		AND l.leagueid > 0
	GROUP BY l.leagueid,
		l.sporttype
	ORDER BY l.sporttype

	DROP TABLE #tblLeagueid
END
GO
