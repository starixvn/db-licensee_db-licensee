USE bodb02
GO

ALTER PROCEDURE [dbo].[Lrf_TotalBets_SelHR]  	
	@PageSize	INT=50,  
	@PageIndex	INT=1,
	@AgentList	VARCHAR(MAX)	
AS  
  
/*  
Created: 20101201@Henry  
Task : Retrieve Total Bet values for bettype HR  
DB: DB052.bodb02  
Original: [Age_TotalBets_SelHR_Ag]  
Revisions:  
	- 20110206@Henry: Fix getting Member Turnover AND comm  
	- 201134@Alex: Allow to choose all type of licensee AND all currency + suppport based currency
	- 20110727@Henry: Show net revenue instead of comm
	- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
	- 20121004@Jim: replace @currencyname input param by @currencyID
	- 20130514@Jim:Restrict permission of Licensee Users by currency	
	- 20141110@Winnie: Change from LicenseeCust table to [f_SelLicenseeCust] function
	- 20150123@Jim: support base on Currency GBP
	- 20170227@Harper: LRF - Get data by @AgentList instead of @UserID [RedmineID: #71679]

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

DECLARE @FromDate DATETIME  
SELECT @FromDate = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP,120)  

 
DECLARE @TotalBets TABLE(   transid bigint, bettype SMALLINT, matchid INT, stake MONEY,discount decimal(9,8), apositiontaking smallmoney,awinlost money, ruben INT,winlostdate smalldatetime,currency int ,  
                            GroupMatch VARCHAR(50), MatchCode VARCHAR(50), oddsstatus VARCHAR(50), eventdate smalldatetime,   
                            kickofftime DATETIME, teamID INT, leagueId INT)  
                              
DECLARE @Data TABLE(  
	winlostdate smalldatetime,
	currency INT,
	leagueid INT,  
	matchid INT,  
	race VARCHAR(50),  
	HorseNo VARCHAR(50),  
	teamid INT,  
	oddsstatus VARCHAR(50),  
	eventdate DATETIME,  
	kickofftime DATETIME,  
	Total_Win MONEY,  
	Total_Win_Comm MONEY,  
	Total_Win_WL	MONEY,
	
	Total_Place MONEY, 
	Total_Place_Comm MONEY,  
	Total_Place_WL MONEY,  
	
	Total_WinPlace MONEY, 
	Total_WinPlace_Comm MONEY,
	Total_WinPlace_WL MONEY
	
)                              
  
INSERT INTO @TotalBets(     transid, bettype, matchid, stake,  discount, apositiontaking,awinlost, ruben,winlostdate ,currency,  
                            GroupMatch, MatchCode, oddsstatus, eventdate, kickofftime, teamID, leagueId)  
    SELECT   
		b1.transid,  
		b1.bettype,   
		b1.matchid,   
		b1.stake,   
		b1.discount,   
		b1.apositiontaking,
		b1.awinlost,
		b1.ruben, 
		b1.winlostdate ,
		b1.currency,
		m1.GroupMatch,   
		m1.MatchCode,   
		m1.oddsstatus,   
		m1.eventdate,   
		m1.kickofftime,   
		m1.teamID,   
		m1.leagueId  
	 
	FROM bettrans b1 (NOLOCK) 
		INNER JOIN outright m1 (NOLOCK) ON b1.matchid = m1.orid
		INNER JOIN @TempAg ag ON b1.recommend = ag.CustId AND b1.currency = ag.Currency

	WHERE   	  
	  b1.bettype IN (31,32,33) AND   
	  b1.statusID NOT IN (101,102,103)  AND
	  m1.eventdate = @fromdate 
	  --b1.status NOT IN('reject','void','Refund')  
	  
  
DECLARE @RowCount INT, @RowStart INT, @RowEnd INT    
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1   
  
INSERT INTO @Data  
SELECT 
	b2.winlostdate,
	b2.currency,
	b2.leagueId,  
	b2.Matchid,  
	b2.GroupMatch AS Race,  
	b2.MatchCode AS HorseNo,  
	b2.TeamId,  
	b2.oddsstatus,  
	b2.eventdate,  
	b2.kickofftime,  
	SUM(CASE WHEN b2.bettype=31 THEN CASE WHEN b2.apositiontaking<>0 THEN b2.apositiontaking * b2.stake ELSE b2.stake END ELSE 0 END) AS Total_Win,  
	SUM(CASE WHEN b2.bettype=31 THEN (b2.discount * b2.stake) ELSE 0 END) AS Total_Win_Comm,  
	SUM(CASE WHEN b2.bettype=31 AND b2.ruben=1 THEN b2.awinlost ELSE 0 END) AS Total_Win_WL,  

	SUM(CASE WHEN b2.bettype=32 THEN CASE WHEN b2.apositiontaking<>0 THEN b2.apositiontaking * b2.stake ELSE b2.stake END ELSE 0 END) AS Total_Place,  
	SUM(CASE WHEN b2.bettype=32 THEN (b2.discount * b2.stake) ELSE 0 END) AS Total_Place_Comm,  
	SUM(CASE WHEN b2.bettype=32 AND b2.ruben=1 THEN b2.awinlost ELSE 0 END) AS Total_Place_WL,

	SUM(CASE WHEN b2.bettype=33 THEN CASE WHEN bm.apositiontaking<>0 THEN bm.apositiontaking * bm.stake ELSE bm.stake END ELSE 0 END) AS Total_WinPlace,  
	SUM(CASE WHEN b2.bettype=33 THEN (bm.stake * bm.discount) ELSE 0 END) AS Total_WinPlace_Comm,
	SUM(CASE WHEN b2.bettype=33 AND b2.ruben=1 THEN bm.awinlost ELSE 0 END) AS Total_WinPlace_WL  
FROM @TotalBets b2 
	LEFT JOIN bettransm bm (NOLOCK) ON b2.transid = bm.refno 
	--INNER JOIN ExchangeDaily e (NOLOCK) ON e.ExchangeDate = (CASE WHEN b2.winlostdate <= @Today THEN b2.winlostdate ELSE @Today END) AND e.exchangeid = b2.currency
GROUP BY 
	b2.winlostdate,
	b2.currency,
	b2.leagueId,  
	b2.GroupMatch,  
	b2.Matchid,  
	b2.MatchCode,  
	b2.TeamId,  
	b2.oddsstatus,  
	b2.eventdate,  
	b2.kickofftime  
ORDER BY   
CASE WHEN b2.oddsstatus = 'running' THEN -1 ELSE 0 END ASC, b2.leagueId, CAST(b2.GroupMatch as INT), CAST(b2.MatchCode as INT)  

  
SELECT c.* FROM  
(    
	SELECT   
		ROW_NUMBER() over (order by CASE WHEN oddsstatus = 'running' THEN -1 ELSE 0 END ASC, leagueId, CAST(Race as INT), CAST(HorseNo as INT)) as RowNum ,  
		b.winlostdate,
		b.currency,
		b.leagueid,  
		b.matchid,  
		b.race,  
		b.HorseNo,  
		b.teamid,  
		b.oddsstatus,  
		b.eventdate,  
		b.kickofftime,  
		b.Total_Win,  
		b.Total_Win_Comm,  
		b.Total_Win_WL,
		
		b.Total_Place, 
		b.Total_Place_Comm,  
		b.Total_Place_WL,  
		
		b.Total_WinPlace, 
		b.Total_WinPlace_Comm,
		b.Total_WinPlace_WL,
		--USD
		b.Total_Win * e.USD as Total_WinUSD,  
		b.Total_Win_Comm * e.USD as Total_Win_CommUSD,  
		b.Total_Win_WL * e.USD as Total_Win_WLUSD,
		
		b.Total_Place * e.USD as Total_PlaceUSD, 
		b.Total_Place_Comm * e.USD as Total_Place_CommUSD,  
		b.Total_Place_WL * e.USD as Total_Place_WLUSD,  
		
		b.Total_WinPlace * e.USD as Total_WinPlaceUSD, 
		b.Total_WinPlace_Comm * e.USD as Total_WinPlace_CommUSD,
		b.Total_WinPlace_WL * e.USD as Total_WinPlace_WLUSD,
		--EUR
		b.Total_Win * e.EUR as Total_WinEUR,  
		b.Total_Win_Comm * e.EUR as Total_Win_CommEUR,  
		b.Total_Win_WL * e.EUR as Total_Win_WLEUR,
		
		b.Total_Place * e.EUR as Total_PlaceEUR, 
		b.Total_Place_Comm * e.EUR as Total_Place_CommEUR,  
		b.Total_Place_WL * e.EUR as Total_Place_WLEUR,  
		
		b.Total_WinPlace * e.EUR as Total_WinPlaceEUR, 
		b.Total_WinPlace_Comm * e.EUR as Total_WinPlace_CommEUR,
		b.Total_WinPlace_WL * e.EUR as Total_WinPlace_WLEUR,
		--GBP
		b.Total_Win * e.GBP as Total_WinGBP,  
		b.Total_Win_Comm * e.GBP as Total_Win_CommGBP,  
		b.Total_Win_WL * e.GBP as Total_Win_WLGBP,
		
		b.Total_Place * e.GBP as Total_PlaceGBP, 
		b.Total_Place_Comm * e.GBP as Total_Place_CommGBP,  
		b.Total_Place_WL * e.GBP as Total_Place_WLGBP,  
		
		b.Total_WinPlace * e.GBP as Total_WinPlaceGBP, 
		b.Total_WinPlace_Comm * e.GBP as Total_WinPlace_CommGBP,
		b.Total_WinPlace_WL * e.GBP as Total_WinPlace_WLGBP
	FROM 
		@Data  b
		INNER JOIN (SELECT *  FROM Lrf_f_GetExchangeDaily(@FromDate,@FromDate))e  
		ON e.exchangeid = b.currency
) c  WHERE c.RowNum between @RowStart AND @RowEnd         


SELECT 
	count(matchid) TotalRows, 
	SUM(Total_Win) SumTotal_Win,
	SUM(Total_Place) SumTotal_Place,
	SUM(Total_WinPlace) SumTotal_WinPlace,
	SUM(Total_Win_WL) SumTotal_Win_WL,
	SUM(Total_Place_WL) SumTotal_Place_WL,
	SUM(Total_WinPlace_WL) SumTotal_WinPlace_WL,
	SUM(Total_Win_Comm) SumTotal_Win_Comm,
	SUM(Total_Place_Comm) SumTotal_Place_Comm,
	SUM(Total_WinPlace_Comm) SumTotal_WinPlace_Comm,
	--USD
	SUM(Total_Win * e.USD) SumTotal_WinUSD,
	SUM(Total_Place * e.USD) SumTotal_PlaceUSD,
	SUM(Total_WinPlace * e.USD) SumTotal_WinPlaceUSD,
	SUM(Total_Win_WL * e.USD) SumTotal_Win_WLUSD,
	SUM(Total_Place_WL * e.USD) SumTotal_Place_WLUSD,
	SUM(Total_WinPlace_WL * e.USD) SumTotal_WinPlace_WLUSD,
	SUM(Total_Win_Comm * e.USD) SumTotal_Win_CommUSD,
	SUM(Total_Place_Comm * e.USD) SumTotal_Place_CommUSD,
	SUM(Total_WinPlace_Comm * e.USD) SumTotal_WinPlace_CommUSD,
	--EUR
	SUM(Total_Win * e.EUR) SumTotal_WinEUR,
	SUM(Total_Place * e.EUR) SumTotal_PlaceEUR,
	SUM(Total_WinPlace * e.EUR) SumTotal_WinPlaceEUR,
	SUM(Total_Win_WL * e.EUR) SumTotal_Win_WLEUR,
	SUM(Total_Place_WL * e.EUR) SumTotal_Place_WLEUR,
	SUM(Total_WinPlace_WL * e.EUR) SumTotal_WinPlace_WLEUR,
	SUM(Total_Win_Comm * e.EUR) SumTotal_Win_CommEUR,
	SUM(Total_Place_Comm * e.EUR) SumTotal_Place_CommEUR,
	SUM(Total_WinPlace_Comm * e.EUR) SumTotal_WinPlace_CommEUR,
	--GBP
	SUM(Total_Win * e.GBP) SumTotal_WinGBP,
	SUM(Total_Place * e.GBP) SumTotal_PlaceGBP,
	SUM(Total_WinPlace * e.GBP) SumTotal_WinPlaceGBP,
	SUM(Total_Win_WL * e.GBP) SumTotal_Win_WLGBP,
	SUM(Total_Place_WL * e.GBP) SumTotal_Place_WLGBP,
	SUM(Total_WinPlace_WL * e.GBP) SumTotal_WinPlace_WLGBP,
	SUM(Total_Win_Comm * e.GBP) SumTotal_Win_CommGBP,
	SUM(Total_Place_Comm * e.GBP) SumTotal_Place_CommGBP,
	SUM(Total_WinPlace_Comm * e.GBP) SumTotal_WinPlace_CommGBP
FROM 
	@Data  b
	INNER JOIN (SELECT *  FROM Lrf_f_GetExchangeDaily(@FromDate,@FromDate))e 
	ON e.exchangeid = b.currency
	
GO
GRANT EXECUTE ON [dbo].[Lrf_TotalBets_SelHR] TO [bodbLicenseeNet]

GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_TotalBets_SelHR] TO [vnteam]

