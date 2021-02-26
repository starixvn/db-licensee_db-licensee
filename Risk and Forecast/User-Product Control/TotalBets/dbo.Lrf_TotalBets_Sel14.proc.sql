/*<info serverAlias="DBBOF-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER  PROCEDURE [dbo].[Lrf_TotalBets_Sel14]	
	@PageSize		INT=50,
	@PageIndex		INT=0,
	@TotalRows		INT=0 OUTPUT,
	@AgentList		VARCHAR(MAX),
	@BaseCurrency	VARCHAR(3)= ''
AS
/*
Created: 20101201@Henry
Task: Retrieve Total Bet values for First Goal/Last Goal.
DB: DBBOF.bodb02
Original: [Age_TotalBets_Sel14_Ag]
Revisions:
	- 201134@Alex:Allow to choose all type of licensee AND all currency + suppport based currency
	- 20110801@Henry: Remove PT + exclude BA ticket
	- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
	- 20121004@Jim: replace @currencyname input param by @currencyID.
	- 20130514@Jim:Restrict permission of Licensee Users by currency
	- 20140508@Kyan: add new bettype 1H FG/LG (127)
	- 20140718@Hannah: Change liveindicator datatype to INT to fix running live matches are not being showed at the top list (RedmineID:19136)
	- 20141110@Winnie: Change from LicenseeCust table to [f_SelLicenseeCust] function
	- 20150123@Jim: support base on Currency GBP
	- 20150617@Jim:  Enhance Total Bets with sum values of running stakes  (Feature #36839)
	- 20170227@Harper: LRF - Get data by @AgentList instead of @UserID [RedmineID: #71679]
	- 20180802@Sophia: HA - remove ruben to use new index on DB042 [Redmine: #98631]
	- 20190611@Amanda: Add Base Currency parameter [Redmine: #112531]
	- 20210224@Mark: Change alias DB042 to DBBOF [Redmine: #150375]

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
		matchid INT,
		homeID INT,
		awayID INT,
		livehomescore INT,
		liveawayscore INT,

		WinLost_HomeFG MONEY,
		--
		WinLost_HomeFG_ori MONEY,
		
		WinLost_HomeLG MONEY,
		--
		WinLost_HomeLG_ori MONEY,
		
		WinLost_AwayFG MONEY,
		--
		WinLost_AwayFG_ori MONEY,
		
		WinLost_AwayLG MONEY,
		--
		WinLost_AwayLG_ori MONEY,
		
		WinLost_NoGoal MONEY,
		--
		WinLost_NoGoal_ori MONEY,
		
		WinLost_1HHomeFG MONEY,
		--
		WinLost_1HHomeFG_ori MONEY,
		
		WinLost_1HHomeLG MONEY,
		--
		WinLost_1HHomeLG_ori MONEY,
		
		WinLost_1HAwayFG MONEY,
		--
		WinLost_1HAwayFG_ori MONEY,
		
		WinLost_1HAwayLG MONEY,
		--
		WinLost_1HAwayLG_ori MONEY,
		
		WinLost_1HNoGoal MONEY,
		--
		WinLost_1HNoGoal_ori MONEY,
		
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
			m.matchid,
			m.homeid,
			m.awayid,
			a.livehomescore,
			a.liveawayscore,	
			
			-- FG/LG
			SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 1 AND hdp2 = 1 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.Rate ELSE -actual_stake*e.Rate END END) AS WinLost_HomeFG,
			--
			SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 1 AND hdp2 = 1 THEN stake*e.Rate END END) AS WinLost_HomeFG_ori,
			
			SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 1 AND hdp2 = 2 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.Rate ELSE -actual_stake*e.Rate END END) AS WinLost_HomeLG,
			--
			SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 1 AND hdp2 = 2 THEN stake*e.Rate   END END) AS WinLost_HomeLG_ori,
			
			--
			SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 2 AND hdp2 = 1 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.Rate ELSE -actual_stake*e.Rate END END) AS WinLost_AwayFG,
			--
			SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 2 AND hdp2 = 1 THEN stake* e.Rate   END END) AS WinLost_AwayFG_ori,

			SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 2 AND hdp2 = 2 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.Rate ELSE -actual_stake*e.Rate END END) AS WinLost_AwayLG,
			---
			SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 2 AND hdp2 = 2 THEN stake* e.Rate  END END) AS WinLost_AwayLG_ori,
			
			SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 0 AND hdp2 = 0 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.Rate ELSE -actual_stake*e.Rate END END) AS WinLost_NoGoal,
			--
			SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 0 AND hdp2 = 0 THEN stake*e.Rate   END END) AS WinLost_NoGoal_ori,
			
			--1H Total FG/LG
			SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 1 AND hdp2 = 1 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.Rate ELSE -actual_stake*e.Rate END END) AS WinLost_1HHomeFG,
			--
			SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 1 AND hdp2 = 1 THEN stake*e.Rate END END) AS WinLost_1HHomeFG_ori,
			
			SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 1 AND hdp2 = 2 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.Rate ELSE -actual_stake*e.Rate END END) AS WinLost_1HHomeLG,
			--
			SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 1 AND hdp2 = 2 THEN stake *e.Rate  END END) AS WinLost_1HHomeLG_ori,
			
			SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 2 AND hdp2 = 1 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.Rate ELSE -actual_stake*e.Rate END END) AS WinLost_1HAwayFG,
			--
			SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 2 AND hdp2 = 1 THEN stake*e.Rate  END END) AS WinLost_1HAwayFG_ori,

			SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 2 AND hdp2 = 2 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.Rate ELSE -actual_stake*e.Rate END END) AS WinLost_1HAwayLG, 
			--
			SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 2 AND hdp2 = 2 THEN stake*e.Rate  END END) AS WinLost_1HAwayLG_ori,
			
			SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 0 AND hdp2 = 0 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.Rate ELSE -actual_stake*e.Rate END END) AS WinLost_1HNoGoal,
			--
			SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 0 AND hdp2 = 0 THEN stake*e.Rate  END END) AS WinLost_1HNoGoal_ori,
		
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral
		FROM
			bettrans a WITH (NOLOCK)
			INNER JOIN @TempAg ag ON a.recommend = ag.CustId AND a.currency = ag.Currency
			INNER JOIN match m WITH (NOLOCK) ON m.matchid = a.matchid 	
			INNER JOIN @ExchangeRate e ON e.exchangeid = a.currency
		WHERE 		
			a.bettype in (14,127) AND -- FG/LG: 14, 1H FG/LG: 127
			a.statusID IN (0,1) AND
			m.eventstatus = 'running'  AND
			a.tpositiontaking <>0
			
		GROUP BY
			a.liveindicator,
			m.homeid,
			m.awayid,
			m.matchid,
			m.matchcode,
			m.leagueid,
			a.livehomescore,
			a.liveawayscore,
			m.showtime,
			m.isNeutral
		ORDER BY
		m.matchcode

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
			* FROM @Data
	) c WHERE c.RowNum BETWEEN @RowStart AND @RowEnd


	SELECT 
		SUM(WinLost_HomeFG_ori) WinLost_HomeFG,
		
		SUM(WinLost_HomeLG_ori) WinLost_HomeLG,
		
		--
		SUM(WinLost_AwayFG_ori) WinLost_AwayFG,
		
		SUM(WinLost_AwayLG_ori) WinLost_AwayLG,
		--
		SUM(WinLost_NoGoal_ori) WinLost_NoGoal,
		--
		SUM(WinLost_1HHomeFG_ori) WinLost_1HHomeFG,
		
		--
		SUM(WinLost_1HHomeLG_ori) WinLost_1HHomeLG,
		
		--
		SUM(WinLost_1HAwayFG_ori) WinLost_1HAwayFG,
		
		--
		SUM(WinLost_1HAwayLG_ori) WinLost_1HAwayLG,
		--
		SUM(WinLost_1HNoGoal_ori) WinLost_1HNoGoal
	FROM @Data	
END

GO