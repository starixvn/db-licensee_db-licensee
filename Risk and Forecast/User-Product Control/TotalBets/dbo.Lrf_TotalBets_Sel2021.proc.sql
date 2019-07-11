/*<info serverAlias="DB042-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Lrf_TotalBets_Sel2021]	
	@PageSize		INT=50,
	@PageIndex		INT=0,
	@TotalRows		INT=0 OUTPUT,
	@AgentList		VARCHAR(MAX),
	@BaseCurrency	VARCHAR(3) = ''
AS 
/*
Created: 20101201@Henry
Task: Retrieve Total Bet values for MoneyLine.
DB: DB042.bodb02
Original: [Age_TotalBets_Sel2021_Ag]
Revisions:
	- 201133@Alex:Allow to choose all type of licensee AND all currency + suppport based currency
	- 20110801@Henry: Remove PT + exclude BA ticket
	- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
	- 20121004@Jim: replace @currencyname input param by @currencyID
	- 20130514@Jim:Restrict permission of Licensee Users by currency
	- 20140718@Hannah: Change liveindicator datatype to INT to fix running live matches are not being showed at the top list (RedmineID:19136)
	- 20141110@Winnie: Change from LicenseeCust table to [f_SelLicenseeCust] function
	- 20150124@Winnie: Add base currency GBP 
	- 20150617@Jim:  Enhance Total Bets with sum values of running stakes  (Feature #36839)
	- 20170227@Harper: LRF - Get data by @AgentList instead of @UserID [RedmineID: #71679]
	- 20180802@Sophia: HA - Status IN (0,1) to use new index on DB042 [Redmine: #98631]
	- 20190611@Amanda: Add Base Currency parameter [Redmine: #112531]

Param's Explanation:
	+ @AgentList: xml structure
					<ROOT>
					<Agent AgentId="12345" Currency="3"/>  
					<Agent AgentId="12345" Currency="5"/>  
					</ROOT>
*/

SET NOCOUNT ON

DECLARE @Today smalldatetime 
SET @Today = convert(VARCHAR(10), CURRENT_TIMESTAMP, 120) 

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

DECLARE @Data as TABLE
(
	showtime nvarchar (50),
	leagueid INT,
	matchcode nvarchar(50),
	liveindicator INT,
	matchid INT,
	homeID INT,
	awayID INT,
	livehomescore INT,
	liveawayscore INT,
	
	home_odds MONEY,
	
	home_odds_ori MONEY,
	
	away_odds MONEY,
	
	away_odds_ori MONEY,
	
	WinLost_home MONEY,
	
	WinLost_home_ori MONEY,
	
	WinLost_away MONEY,
	
	WinLost_away_ori MONEY,
	
	home_odds_HT MONEY,
	
	home_odds_HT_ori MONEY,
	
	away_odds_HT MONEY,
	
	away_odds_HT_ori MONEY,

	WinLost_home_HT MONEY,
	
	WinLost_home_HT_ori MONEY,
	
	WinLost_away_HT MONEY,
	
	WinLost_away_HT_ori MONEY,

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
		
		sum((CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'h' THEN stake*e.Rate ELSE 0 END)*(CASE WHEN abs(odds) <1 THEN 1 ELSE abs(odds) END) ELSE 0 END)) AS home_odds,
		--
		sum(CASE WHEN bettype = 20 AND betteam = 'h' THEN stake*e.Rate ELSE 0 END) AS home_odds_ori,
		--
		sum((CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'a' THEN stake*e.Rate ELSE 0 END)*(CASE WHEN abs(odds) <1 THEN 1 ELSE abs(odds) END) ELSE 0 END)) AS away_odds,
		---
		sum(CASE WHEN bettype = 20 AND betteam = 'a' THEN stake*e.Rate ELSE 0 END) AS away_odds_ori,
		---
		sum(CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'h' THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds END)*e.Rate ELSE -actual_stake*e.Rate END) ELSE 0 END ) AS WinLost_home,
		---
		sum(CASE WHEN bettype = 20 AND betteam = 'h' THEN stake*e.Rate ELSE 0 END) AS WinLost_home_ori,
		--
		sum(CASE WHEN bettype = 20 THEN (CASE WHEN betteam = 'a' THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds END)*e.Rate ELSE -actual_stake*e.Rate END) ELSE 0 END) AS WinLost_away,
		--
		sum(CASE WHEN bettype = 20 AND betteam = 'a' THEN stake*e.Rate ELSE 0 END) AS WinLost_away_ori,
		--
		sum((CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'h' THEN stake*e.Rate ELSE 0 END)*(CASE WHEN abs(odds) <1 THEN 1 ELSE abs(odds) END) ELSE 0 END)) AS home_odds_HT,
		---
		sum(CASE WHEN bettype = 21 AND betteam = 'h' THEN stake*e.Rate ELSE 0 END) AS home_odds_HT_ori,

		--
		sum((CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'a' THEN stake*e.Rate ELSE 0 END)*(CASE WHEN abs(odds) <1 THEN 1 ELSE abs(odds) END) ELSE 0 END)) AS away_odds_HT,
		--
		sum(CASE WHEN bettype = 21 AND betteam = 'a' THEN stake*e.Rate ELSE 0 END) AS away_odds_HT_ori,
		
		sum(CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'h' THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds END)*e.Rate ELSE -actual_stake*e.Rate END) ELSE 0 END) AS WinLost_home_HT,	
		--
		sum(CASE WHEN bettype = 21 AND betteam = 'h' THEN stake*e.Rate ELSE 0 END) AS WinLost_home_HT_ori,
		--
		sum(CASE WHEN bettype = 21 THEN (CASE WHEN betteam = 'a' THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds END)*e.Rate ELSE -actual_stake*e.Rate END) ELSE 0 END) AS WinLost_away_HT,
		--
		sum(CASE WHEN bettype = 21 AND betteam = 'a' THEN stake*e.Rate ELSE 0 END) AS WinLost_away_HT_ori,
		
		isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral
			
	FROM
		bettrans a  WITH (NOLOCK)
		INNER JOIN @TempAg ag ON a.recommend = ag.CustId AND a.currency = ag.Currency
		INNER JOIN match 	m  WITH (NOLOCK) ON m.matchid       = a.matchid 
		INNER JOIN @ExchangeRate e ON e.exchangeid = a.currency	
	WHERE 		
		a.bettype IN (20,21) AND
		a.statusID IN (0,1) AND
		m.eventstatus = 'running' AND
		a.tpositiontaking <> 0
		
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
	SELECT @TotalRows = count(matchid) FROM @Data
END

SELECT c.* FROM
(
	SELECT
		ROW_NUMBER() over (order by matchcode) as RowNum ,
		showtime ,
	leagueid  ,
	matchcode  ,
	liveindicator  ,
	matchid  ,
	homeID  ,
	awayID  ,
	livehomescore  ,
	liveawayscore  ,
	
	home_odds  ,
	
	away_odds  ,
	
	WinLost_home  ,

	WinLost_away  ,

	home_odds_HT  ,
 
	away_odds_HT  ,
	 
	WinLost_home_HT  ,
	
	WinLost_away_HT  ,
	
	isNeutral BIT
	FROM @Data
) c WHERE c.RowNum between @RowStart AND @RowEnd

SELECT 
	SUM(home_odds_ori) home_odds,
	 
	SUM(away_odds_ori) away_odds,
	
	SUM(WinLost_home_ori) WinLost_home,
	
	SUM(WinLost_away_ori) WinLost_away,
	
	SUM(home_odds_HT_ori) home_odds_HT,
	
	SUM(away_odds_HT_ori) away_odds_HT,
	
	SUM(WinLost_home_HT_ori) WinLost_home_HT,
	
	SUM(WinLost_away_HT_ori) WinLost_away_HT
FROM @Data

GO