/*<info serverAlias="DBBOF-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_TotalBets_Sel25] 	
	@PageSize		INT=50,
	@PageIndex		INT=0,
	@TotalRows		INT=0 OUTPUT,
	@AgentList		VARCHAR(MAX),
	@BaseCurrency	VARCHAR(12) = ''
 AS

/*
Created: 20101201@Henry
Task : Retrieve Total bets for bettype 25
DB: DBBOF.bodb02
Original:[Age_TotalBets_Sel25_Ag]
Revisions:
	- 201133@Alex:Allow to choose all type of licensee AND all currency + suppport based currency
	- 20110801@Henry: Remove PT + exclude BA ticket
	- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
	- 20120703@Henry: Add new bettype 123 for Draw/No Draw
	- 20121004@Jim: replace @currencyname input param by @currencyID
	- 20130514@Jim:Restrict permission of Licensee Users by currency
	- 20140718@Hannah: Change liveindicator datatype to INT to fix running live matches are not being showed at the top list (RedmineID:19136)
	- 20141110@Winnie: Change from LicenseeCust table to [f_SelLicenseeCust] function
	- 20150124@Winnie: Add base currency GBP 
	- 20150413@Jim: add more bettype Odd/Even (3rd) (157) ,Extra Time 1H 1X2 (167)
	- 20150617@Jim:  Enhance Total Bets with sum values of running stakes  (Feature #36839)
	- 20170227@Harper: LRF - Get data by @AgentList instead of @UserID [RedmineID: #71679]
	- 20180802@Sophia: HA - use new index on DB042 [Redmine: #98631]
	- 20190611@Amanda: Add Base Currency parameter [Redmine: #112531]
	- 20210224@Mark: Change alias DB042 to DBBOF [Redmine: #150375]
	- 20220914@Evan: Expand length of @BaseCurrency [Redmine #177481]

Param's Explanation:
	+ @AgentList: xml structure
					<ROOT>
					<Agent AgentId="12345" Currency="3"/>  
					<Agent AgentId="12345" Currency="5"/>  
					</ROOT>
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @Today SMALLDATETIME 
	SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120) 

	DECLARE @TempAg AS TABLE ( CustId INT,Currency INT )
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
				,@AgentList
		INSERT INTO @TempAg (custID, currency)
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

	DECLARE @Data AS Table
	(
		showtime NVARCHAR (50),
		leagueid INT,
		matchcode NVARCHAR(50),
		liveindicator INT,
		livehomescore INT,
		liveawayscore INT,
		matchid INT,
		homeID INT,
		awayID INT,
		bettype INT,
		
		home_odds_OE MONEY,
		
		home_odds_OE_ori MONEY,
		
		away_odds_OE MONEY,
		
		away_odds_OE_ori MONEY,
		
		home_odds_OE_1st MONEY,
		
		home_odds_OE_1st_ori MONEY,
		
		away_odds_OE_1st MONEY,
		
		away_odds_OE_1st_ori MONEY,
		
		odds_1 MONEY,
		
		odds_x MONEY,
		
		odds_2 MONEY,
		
		odds_1_1st MONEY,
		
		odds_x_1st MONEY,
		
		odds_2_1st MONEY,
		
		home_odds_DND MONEY,
		
		away_odds_DND MONEY,
		
		BetCount_OE INT,
		BetCount_OE_1st INT,
		BetCount_1x2 INT,
		BetCount_1x2_1st INT,
		BetCount_DND INT,
		isNeutral BIT
	)

	DECLARE @ExchangeRate AS TABLE (ExchangeId INT, Rate FLOAT)

	INSERT INTO @ExchangeRate(ExchangeId, Rate)
	SELECT ExchangeId, Rate
	FROM dbo.Lrf_f_GetExchangeRate(@Today, @Today, @BaseCurrency, '') e
	WHERE EXISTS (SELECT 1 FROM @TempAg a WHERE a.Currency = e.ExchangeId)

	INSERT INTO @Data
	SELECT 
			m.showtime, 
			m.leagueid,
			m.matchcode, 
			a.liveindicator, 
			a.livehomescore,
			a.liveawayscore,
			m.matchid,
			m.homeid,
			m.awayid,
			CASE  WHEN a.bettype IN (2,12) THEN 2
				WHEN a.bettype IN (5,15) THEN 5	
				ELSE a.bettype END  bettype,
			sum((CASE WHEN bettype in (2,157) AND betteam = 'h' THEN stake*e.Rate ELSE 0 END)*(CASE WHEN ABS(odds) <1 THEN 1 ELSE ABS(odds) END)) AS home_odds_OE,
			--
			sum((CASE WHEN bettype in (2,157) AND betteam = 'h' THEN stake*e.Rate ELSE 0 END)) AS home_odds_OE_ori,
			
			sum((CASE WHEN bettype in (2,157) AND betteam = 'a' THEN stake*e.Rate ELSE 0 END)*(CASE WHEN ABS(odds) <1 THEN 1 ELSE ABS(odds) END)) AS away_odds_OE,
			--
			sum((CASE WHEN bettype in (2,157) AND betteam = 'a' THEN stake*e.Rate ELSE 0 END) ) AS away_odds_OE_ori,
			
			sum((CASE WHEN bettype=12 AND betteam = 'h' THEN stake*e.Rate ELSE 0 END)*(CASE WHEN ABS(odds) <1 THEN 1 ELSE ABS(odds) END)) AS home_odds_OE_1st,
			--
			sum((CASE WHEN bettype=12 AND betteam = 'h' THEN stake*e.Rate ELSE 0 END)) AS home_odds_OE_1st_ori,
			
			sum((CASE WHEN bettype=12 AND betteam = 'a' THEN stake*e.Rate ELSE 0 END)*(CASE WHEN ABS(odds) <1 THEN 1 ELSE ABS(odds) END)) AS away_odds_OE_1st,
			--
			sum((CASE WHEN bettype=12 AND betteam = 'a' THEN stake*e.Rate ELSE 0 END)) AS away_odds_OE_1st_ori,
			
			--league.lcolor,
			sum(CASE WHEN bettype=5 AND betteam = '1' THEN stake*e.Rate ELSE 0 END) AS odds_1,
			
			sum(CASE WHEN bettype=5 AND betteam = 'x' THEN stake*e.Rate ELSE 0 END) AS odds_x,

			sum(CASE WHEN bettype=5 AND betteam = '2' THEN stake*e.Rate ELSE 0 END) AS odds_2,

			sum(CASE WHEN bettype IN (15,167) AND betteam = '1' THEN stake*e.Rate ELSE 0 END) AS odds_1_1st,
			
			sum(CASE WHEN bettype IN (15,167) AND betteam = 'x' THEN stake*e.Rate ELSE 0 END) AS odds_x_1st,
			
			sum(CASE WHEN bettype IN (15,167) AND betteam = '2' THEN stake*e.Rate ELSE 0 END) AS odds_2_1st,

			sum(Case when bettype=123 and betteam = 'h' then  stake*e.Rate else 0 end) AS home_odds_DND,
			
			sum(Case when bettype=123 and betteam = 'a' then  stake*e.Rate else 0 end) AS away_odds_DND,

			sum(CASE WHEN bettype in (2,157)  THEN 1 ELSE 0 END) AS BetCount_OE,
			sum(CASE WHEN bettype=12 THEN 1 ELSE 0 END) AS BetCount_OE_1st,
			sum(CASE WHEN bettype=5 THEN 1 ELSE 0 END) AS BetCount_1x2,
			sum(CASE WHEN bettype IN (15,167) THEN 1 ELSE 0 END) AS BetCount_1x2_1st,
			sum(case when bettype=123 then 1 else 0 end) as BetCount_DND,
			isnull(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral
		FROM
			bettrans AS a  WITH (NOLOCK)
			INNER JOIN @TempAg ag ON a.recommend = ag.CustId AND a.currency = ag.Currency
			INNER JOIN match AS m  WITH (NOLOCK) ON m.matchid       = a.matchid 
			INNER JOIN @ExchangeRate e ON e.exchangeid = a.currency
		WHERE 	
			a.bettype in (2, 12, 5, 15,123,157,167)
			AND a.statusID in (0,1)	
			AND m.eventstatus='running'
			AND a.tpositiontaking <> 0
		GROUP BY a.liveindicator, 
			a.livehomescore,
			a.liveawayscore,
			m.homeid,
			m.awayid,
			m.matchid,
			m.matchcode, 
			m.leagueid,
			m.showtime,
			m.isNeutral,
			CASE  WHEN a.bettype IN (2,12) THEN 2
				WHEN a.bettype IN (5,15) THEN 5	
				ELSE a.bettype END
			
		ORDER BY m.matchcode

	IF @TotalRows = 0  
	BEGIN  
		SELECT @TotalRows = COUNT(matchid) FROM @Data
	END

	SELECT c.* FROM
	(
		SELECT 
			ROW_NUMBER() over (ORDER BY matchcode) AS RowNum ,
			*
		FROM @Data
	) c WHERE c.RowNum BETWEEN @RowStart AND @RowEnd

	SELECT 
		SUM(home_odds_OE_ori) home_odds_OE ,
	
		SUM(away_odds_OE_ori) away_odds_OE , 
		
		SUM(home_odds_OE_1st_ori) home_odds_OE_1st,
		
		SUM(away_odds_OE_1st_ori) away_odds_OE_1st,
		
		SUM(odds_1) odds_1,
		
		SUM(odds_x) odds_x,
		
		SUM(odds_2) odds_2,
		
		SUM(odds_1_1st) odds_1_1st,
		
		SUM(odds_x_1st) odds_x_1st,
		
		SUM(odds_2_1st) odds_2_1st,
		
		SUM(home_odds_DND) home_odds_DND,
		
		SUM(away_odds_DND) away_odds_DND
	FROM @Data
END

GO