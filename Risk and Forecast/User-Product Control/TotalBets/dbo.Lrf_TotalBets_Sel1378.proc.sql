/*<info serverAlias="DB042-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
USE bodb02
GO

ALTER PROCEDURE [dbo].[Lrf_TotalBets_Sel1378]	
	@LicenseeID		INT,
	@PageSize		INT=50,
	@PageIndex		INT=0,
	@TotalRows		INT=0 OUTPUT,
	@AgentList		VARCHAR(MAX),
	@BaseCurrency	VARCHAR(3) = ''
AS

/*
Created: 20101201@Henry
Task : Retrieve Total Bet values for bettype 1,3,7,8
DB: DB042.bodb02
Original: Age_TotalBets_Sel1378_Ag

Revisions:
 - 201133@Alex :  Allow to choose all type of licensee AND all currency + suppport based currency
 - 20110801@Henry: Remove PT + exclude BA ticket
 - 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
 - 20121004@Jim: replace @currencyname input param by @currencyID
 - 20130514@Jim:Restrict permission of Licensee Users by currency 
 - 20140717@Francis: Change liveindicator datatype to INT to fix running live matches are not being showed at the top list (RedmineID:19136)
 - 20130718@Hannah: Group each match for Bodog (#19163)
 - 20141110@Winnie: Change from LicenseeCust table to [f_SelLicenseeCust] function
 - 20150124@Winnie: Add base currency GBP 
 - 20150617@Jim:  Enhance Total Bets with sum values of running stakes  (Feature #36839)
 - 20170227@Harper: LRF - Get data by @AgentList instead of @UserID [RedmineID: #71679]
 - 20180727@Sophia: HA - remove Bodog [Redmine: #98631]
 - 20180802@Sophia: HA - remove ruben to use new index on DB042 [Redmine: #98631]
 - 20190611@Amanda: Add Base Currency parameter [Redmine: #112531]

Param's Explanation:
	+ @AgentList: xml structure
					<ROOT>
					<Agent AgentId="12345" Currency="3"/>  
					<Agent AgentId="12345" Currency="5"/>  
					</ROOT> 
Param's Explanation:
• @custid: agent ID

*/

SET NOCOUNT ON
DECLARE @Today SMALLDATETIME 
SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120) 

CREATE TABLE #tempAg ( CustId INT,Currency INT )
DECLARE @DocHandler INT

BEGIN TRY
	EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	INSERT INTO #tempAg (custID, currency)
	SELECT AgentId, Currency
	FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

	EXEC sp_xml_removedocument @DocHandler
END TRY

BEGIN CATCH
	SELECT ErrCode = 100
			,ErrMsg = N'Paramter invalid.'

	RETURN
END CATCH;

DECLARE @RowCount INT, @RowStart INT, @RowEnd INT
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 

DECLARE @Data AS TABLE
(
	showtime			NVARCHAR (50),
	leagueid			INT,
	matchcode			NVARCHAR(50),
	liveindicator		INT,
	matchid				INT,
	homeID				INT,
	awayID				INT,
	livehomescore		INT,
	liveawayscore		INT,
	home_odds_HDP		MONEY,
	home_odds_HDP_ori	MONEY,
	away_odds_HDP		MONEY,
	away_odds_HDP_ori	MONEY,
	home_odds_HTHDP		MONEY,
	home_odds_HTHDP_ori MONEY,
	away_odds_HTHDP		MONEY,
	away_odds_HTHDP_ori MONEY,
	home_odds_OU		MONEY,
	home_odds_OU_ori	MONEY,
	away_odds_OU		MONEY,
	away_odds_OU_ori	MONEY,
	home_odds_HTOU		MONEY,
	home_odds_HTOU_ori	MONEY,
	away_odds_HTOU		MONEY,
	away_odds_HTOU_ori	MONEY,
	BetCount_HDP		INT,
	BetCount_HTHDP		INT,
	BetCount_OU			INT,
	BetCount_HTOU		INT,
	isNeutral			BIT
)

DECLARE @ExchangeRate AS TABLE (ExchangeId INT, Rate FLOAT)
DECLARE @SQL VARCHAR(200)

SELECT @SQL =	'SELECT ExchangeId, ' + CASE WHEN ISNULL(@BaseCurrency, '') <> '' THEN @BaseCurrency ELSE '1' END + ' AS Rate ' +
				'FROM Lrf_f_GetExchangeDaily(''' + CONVERT(VARCHAR(10), @Today, 120) + ''',''' + CONVERT(VARCHAR(10), @Today, 120) + ''') e ' +
				'WHERE EXISTS (SELECT TOP (1) 1 FROM #tempAg a WHERE a.Currency = e.ExchangeId)'
			
INSERT INTO @ExchangeRate(ExchangeId, Rate)
EXECUTE(@SQL)

INSERT INTO @Data
SELECT
		m.showtime, 
		m.leagueID,
		m.matchcode,
		b.liveindicator,
		m.matchid,
		m.homeID,
		m.awayID,
		b.livehomescore,
		b.liveawayscore,
		SUM(CASE WHEN bettype=1 AND betteam = 'h' THEN Stake ELSE 0 END) AS home_odds_HDP,
		SUM(CASE WHEN bettype=1 AND betteam = 'h' THEN Stake_ori ELSE 0 END) AS home_odds_HDP_ori,
		SUM(CASE WHEN bettype=1 AND betteam = 'a' THEN Stake ELSE 0 END) AS away_odds_HDP,
		SUM(CASE WHEN bettype=1 AND betteam = 'a' THEN Stake_ori ELSE 0 END) AS away_odds_HDP_ori,
	    SUM(CASE WHEN bettype=7 AND betteam = 'h' THEN Stake ELSE 0 END) AS home_odds_HTHDP,
		SUM(CASE WHEN bettype=7 AND betteam = 'h' THEN Stake_ori ELSE 0 END) AS home_odds_HTHDP_ori,
		SUM(CASE WHEN bettype=7 AND betteam = 'a' THEN Stake ELSE 0 END) AS away_odds_HTHDP,
		SUM(CASE WHEN bettype=7 AND betteam = 'a' THEN Stake_ori ELSE 0 END) AS away_odds_HTHDP_ori,
		SUM(CASE WHEN bettype=3 AND betteam = 'h' THEN Stake ELSE 0 END) AS home_odds_OU,
		SUM(CASE WHEN bettype=3 AND betteam = 'h' THEN Stake_ori ELSE 0 END) AS home_odds_OU_ori,
		SUM(CASE WHEN bettype=3 AND betteam = 'a' THEN Stake ELSE 0 END) AS away_odds_OU,
		SUM(CASE WHEN bettype=3 AND betteam = 'a' THEN Stake_ori ELSE 0 END) AS away_odds_OU_ori,
		SUM(CASE WHEN bettype=8 AND betteam = 'h' THEN Stake ELSE 0 END) AS home_odds_HTOU,
		SUM(CASE WHEN bettype=8 AND betteam = 'h' THEN Stake_ori ELSE 0 END) AS home_odds_HTOU_ori,
		SUM(CASE WHEN bettype=8 AND betteam = 'a' THEN Stake ELSE 0 END) AS away_odds_HTOU,
		SUM(CASE WHEN bettype=8 AND betteam = 'a' THEN Stake_ori ELSE 0 END) AS away_odds_HTOU_ori,
		SUM(CASE WHEN bettype=1 THEN BetCount ELSE 0 END) AS BetCount_HDP,
		SUM(CASE WHEN bettype=7 THEN BetCount ELSE 0 END) AS BetCount_HTHDP,
		SUM(CASE WHEN bettype=3 THEN BetCount ELSE 0 END) AS BetCount_OU,
		SUM(CASE WHEN bettype=8 THEN BetCount ELSE 0 END) AS BetCount_HTOU,
		ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral
	FROM
		(SELECT
			matchid, bettype, betteam,
			liveindicator, livehomescore, liveawayscore,
			SUM(stake * CASE WHEN ABS(odds) <1 THEN 1 ELSE ABS(odds) END * e.Rate) Stake,
			SUM(stake * e.Rate) Stake_ori,
			COUNT(*) BetCount
		FROM bettrans b WITH (NOLOCK)
		INNER JOIN #tempAg ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency
       	INNER JOIN @ExchangeRate e ON e.exchangeid = b.currency
		WHERE	bettype IN (1,3,7,8)
				AND statusID IN (0,1)				
				AND tpositiontaking <> 0
		GROUP BY matchid, bettype, betteam, liveindicator, livehomescore, liveawayscore) AS b
		INNER JOIN match 	m  WITH (NOLOCK) ON m.matchid       = b.matchid 	
	WHERE	
		m.eventstatus = 'running'	
	GROUP BY
		m.showtime, 
		m.leagueID,
		m.matchcode,
		b.liveindicator,
		m.matchid,
		m.homeID,
		m.awayID,
		b.livehomescore,
		b.liveawayscore,
		m.isNeutral
	ORDER BY b.liveindicator desc, m.matchcode

DECLARE @LicenseeID_temp INT

--SELECT @LicenseeID_temp = LicenseeID 
--FROM bodb_licensee.dbo.licensees WITH (NOLOCK)
--WHERE LicenseeName = 'Bodog'

SELECT @LicenseeID_temp = 14 ---- LicenseeID of Bodog


IF (@licenseeID_temp <> @LicenseeID)
BEGIN
	IF @TotalRows = 0  
	BEGIN  
		SELECT @TotalRows = COUNT(matchid) FROM @Data
	END

	SELECT 
		c.*
	FROM
	(
		SELECT
			ROW_NUMBER() over (ORDER BY matchcode) AS RowNum ,
			* 
		FROM @Data
	) c WHERE c.RowNum between @RowStart AND @RowEnd
END
ELSE
BEGIN
	UPDATE b
	SET 
		b.livehomescore = m.livehomescore,
		b.liveawayscore = m.liveawayscore,
		b.liveindicator = 1
	FROM @Data b
		INNER JOIN bodb02.dbo.match m WITH (NOLOCK)	ON m.matchid = b.matchid 
	WHERE b.matchid IN 
	(
		SELECT DISTINCT(matchid)
		FROM @Data
		WHERE liveindicator = 1
	)

	IF @TotalRows = 0  
	BEGIN  
		SELECT @TotalRows = COUNT(DISTINCT matchid) FROM @Data
	END

	SELECT 
		c.*
	FROM
	(
		SELECT
			ROW_NUMBER() over (ORDER BY m.matchcode) AS RowNum ,
			m.showtime, 
			m.leagueID,
			m.matchcode,
			b.liveindicator,
			m.matchid,
			m.homeID,
			m.awayID,
			b.livehomescore,
			b.liveawayscore,
			SUM(home_odds_HDP) AS home_odds_HDP,
			SUM(away_odds_HDP) AS away_odds_HDP,
			SUM(home_odds_HTHDP) AS home_odds_HTHDP,
			SUM(away_odds_HTHDP) AS away_odds_HTHDP,
			SUM(home_odds_OU) AS home_odds_OU,
			SUM(away_odds_OU) AS away_odds_OU,
			SUM(home_odds_HTOU) AS home_odds_HTOU,
			SUM(away_odds_HTOU) AS away_odds_HTOU,
			SUM(BetCount_HDP) AS BetCount_HDP,
			SUM(BetCount_HTHDP) AS BetCount_HTHDP,
			SUM(BetCount_OU) AS BetCount_OU,
			SUM(BetCount_HTOU) AS BetCount_HTOU,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral
		FROM @Data AS b
			INNER JOIN match m  WITH (NOLOCK) ON m.matchid = b.matchid 	
		GROUP BY
			m.showtime, 
			m.leagueID,
			m.matchcode,
			b.liveindicator,
			m.matchid,
			m.homeID,
			m.awayID,
			b.livehomescore,
			b.liveawayscore,
			m.isNeutral
	) c WHERE c.RowNum between @RowStart AND @RowEnd
	
END
-- sum data 
	SELECT 
			SUM(home_odds_HDP_ori) AS home_odds_HDP,
			SUM(away_odds_HDP_ori) AS away_odds_HDP,
			SUM(home_odds_HTHDP_ori) AS home_odds_HTHDP,
			SUM(away_odds_HTHDP_ori) AS away_odds_HTHDP,
			SUM(home_odds_OU_ori) AS home_odds_OU,
			SUM(away_odds_OU_ori) AS away_odds_OU,
			SUM(home_odds_HTOU_ori) AS home_odds_HTOU,
			SUM(away_odds_HTOU_ori) AS away_odds_HTOU,
			SUM(BetCount_HDP) AS BetCount_HDP,
			SUM(BetCount_HTHDP) AS BetCount_HTHDP,
			SUM(BetCount_OU) AS BetCount_OU,
			SUM(BetCount_HTOU) AS BetCount_HTOU	
	FROM @Data

	DROP TABLE #tempAg
GO