USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_TotalBets_Sel14]    Script Date: 05/23/2014 10:18:23 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER  PROCEDURE [dbo].[Lrf_TotalBets_Sel14]
	@LicenseeID INT,
	@CurrencyID INT=0,
	@UserID		INT,
	@licenseetype VARCHAR(100) = NULL,
	@PageSize INT=50,
	@PageIndex INT=0,
	@TotalRows INT=0 OUTPUT
AS
/*
Created: 20101201@Henry
Task: Retrieve Total Bet values for First Goal/Last Goal.
DB: DB052.bodb02
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
*/

SET NOCOUNT ON
DECLARE @Today SMALLDATETIME 
SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120) 

SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

DECLARE @TempAg AS TABLE (CustID INT)
INSERT INTO @TempAg (CustID)
SELECT DISTINCT CustID  
                FROM    bodb_Licensee.dbo.[f_SelLicenseeCust](0) lc --WITH ( NOLOCK )
						INNER JOIN #currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID
                WHERE   [Description] = COALESCE(@LicenseeType,  
                                                     [Description])
                                                    
-------------------------
DROP TABLE #currency
-------------------------

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
	WinLost_HomeFGUSD MONEY,
	WinLost_HomeFGEUR MONEY,

	WinLost_HomeLG MONEY,
	WinLost_HomeLGUSD MONEY,
	WinLost_HomeLGEUR MONEY,

	WinLost_AwayFG MONEY,
	WinLost_AwayFGUSD MONEY,
	WinLost_AwayFGEUR MONEY,

	WinLost_AwayLG MONEY,
	WinLost_AwayLGUSD MONEY,
	WinLost_AwayLGEUR MONEY,

	WinLost_NoGoal MONEY,
	WinLost_NoGoalUSD MONEY,
	WinLost_NoGoalEUR MONEY,
	
	WinLost_1HHomeFG MONEY,
	WinLost_1HHomeFGUSD MONEY,
	WinLost_1HHomeFGEUR MONEY,

	WinLost_1HHomeLG MONEY,
	WinLost_1HHomeLGUSD MONEY,
	WinLost_1HHomeLGEUR MONEY,

	WinLost_1HAwayFG MONEY,
	WinLost_1HAwayFGUSD MONEY,
	WinLost_1HAwayFGEUR MONEY,

	WinLost_1HAwayLG MONEY,
	WinLost_1HAwayLGUSD MONEY,
	WinLost_1HAwayLGEUR MONEY,

	WinLost_1HNoGoal MONEY,
	WinLost_1HNoGoalUSD MONEY,
	WinLost_1HNoGoalEUR MONEY,
	
	isNeutral BIT
)

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
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 1 AND hdp2 = 1 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END) ELSE -actual_stake END END) AS WinLost_HomeFG,
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 1 AND hdp2 = 1 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.USD ELSE -actual_stake*e.USD END END) AS WinLost_HomeFGUSD,
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 1 AND hdp2 = 1 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.EUR ELSE -actual_stake*e.EUR END END) AS WinLost_HomeFGEUR,

		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 1 AND hdp2 = 2 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END) ELSE -actual_stake END END) AS WinLost_HomeLG,
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 1 AND hdp2 = 2 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.USD ELSE -actual_stake*e.USD END END) AS WinLost_HomeLGUSD,
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 1 AND hdp2 = 2 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.EUR ELSE -actual_stake*e.EUR END END) AS WinLost_HomeLGEUR,

		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 2 AND hdp2 = 1 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END) ELSE -actual_stake END END) AS WinLost_AwayFG,
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 2 AND hdp2 = 1 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.USD ELSE -actual_stake*e.USD END END) AS WinLost_AwayFGUSD,
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 2 AND hdp2 = 1 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.EUR ELSE -actual_stake*e.EUR END END) AS WinLost_AwayFGEUR,

		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 2 AND hdp2 = 2 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END) ELSE -actual_stake END END) AS WinLost_AwayLG,
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 2 AND hdp2 = 2 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.USD ELSE -actual_stake*e.USD END END) AS WinLost_AwayLGUSD,
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 2 AND hdp2 = 2 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.EUR ELSE -actual_stake*e.EUR END END) AS WinLost_AwayLGEUR,

		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 0 AND hdp2 = 0 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END) ELSE -actual_stake END END) AS WinLost_NoGoal,
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 0 AND hdp2 = 0 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.USD ELSE -actual_stake*e.USD END END) AS WinLost_NoGoalUSD,
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 0 AND hdp2 = 0 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.EUR ELSE -actual_stake*e.EUR END END) AS WinLost_NoGoalEUR,
		
		--1H Total FG/LG
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 1 AND hdp2 = 1 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END) ELSE -actual_stake END END) AS WinLost_1HHomeFG,
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 1 AND hdp2 = 1 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.USD ELSE -actual_stake*e.USD END END) AS WinLost_1HHomeFGUSD,
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 1 AND hdp2 = 1 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.EUR ELSE -actual_stake*e.EUR END END) AS WinLost_1HHomeFGEUR,

		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 1 AND hdp2 = 2 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END) ELSE -actual_stake END END) AS WinLost_1HHomeLG,
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 1 AND hdp2 = 2 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.USD ELSE -actual_stake*e.USD END END) AS WinLost_1HHomeLGUSD,
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 1 AND hdp2 = 2 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.EUR ELSE -actual_stake*e.EUR END END) AS WinLost_1HHomeLGEUR,

		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 2 AND hdp2 = 1 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END) ELSE -actual_stake END END) AS WinLost_1HAwayFG,
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 2 AND hdp2 = 1 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.USD ELSE -actual_stake*e.USD END END) AS WinLost_1HAwayFGUSD,
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 2 AND hdp2 = 1 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.EUR ELSE -actual_stake*e.EUR END END) AS WinLost_1HAwayFGEUR,

		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 2 AND hdp2 = 2 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END) ELSE -actual_stake END END) AS WinLost_1HAwayLG,
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 2 AND hdp2 = 2 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.USD ELSE -actual_stake*e.USD END END) AS WinLost_1HAwayLGUSD,
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 2 AND hdp2 = 2 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.EUR ELSE -actual_stake*e.EUR END END) AS WinLost_1HAwayLGEUR,

		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 0 AND hdp2 = 0 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END) ELSE -actual_stake END END) AS WinLost_1HNoGoal,
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 0 AND hdp2 = 0 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.USD ELSE -actual_stake*e.USD END END) AS WinLost_1HNoGoalUSD,
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 0 AND hdp2 = 0 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.EUR ELSE -actual_stake*e.EUR END END) AS WinLost_1HNoGoalEUR,
		
		ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral
	FROM
		bettrans 		a  WITH (NOLOCK)
		INNER JOIN match 	m  WITH (NOLOCK) ON m.matchid       = a.matchid 	
		INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@Today,@Today))e 
		ON e.exchangeid=a.currency
	WHERE 
		a.recommend in (SELECT custid FROM @TempAg) AND
		--a.bettype = 14 AND
		a.bettype in (14,127) AND -- FG/LG: 14, 1H FG/LG: 127
		a.ruben=0 AND
		a.statusID = 0 AND
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
	
GO
GRANT EXECUTE ON [dbo].[Lrf_TotalBets_Sel14] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_TotalBets_Sel14] TO [vnteam]
