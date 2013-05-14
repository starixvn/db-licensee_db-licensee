set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

ALTER PROCEDURE [dbo].[Lrf_BetList_SelWinlossOutright]
	@LicenseeID INT ,
    @LicenseeType VARCHAR(100) = NULL ,
    @CurrencyID	INT=0,
	@FromDate SMALLDATETIME,
	@ToDate SMALLDATETIME,
	@ShowBA BIT = 1,
    @ShowSB BIT = 0,
    @ExcludeReject BIT = 0,
	@Langkey VARCHAR(10) = 'en-US',
	@MoveBetsDay SMALLDATETIME,
	@PageSize INT=1000,
	@PageIndex INT=0,
	@TotalRows INT=0 OUTPUT,
	@SumWinlost MONEY=0 OUTPUT,
	@SumLicenseeWL MONEY=0 OUTPUT,
	@SumComm MONEY=0 OUTPUT,
	@SumPlayerComm MONEY=0 OUTPUT,
	@SumWinlostUSD MONEY=0 OUTPUT,
	@SumLicenseeWLUSD MONEY=0 OUTPUT,
	@SumCommUSD MONEY=0 OUTPUT,
	@SumPlayerCommUSD MONEY=0 OUTPUT,
	@SumWinlostEUR MONEY=0 OUTPUT,
	@SumLicenseeWLEUR MONEY=0 OUTPUT,
	@SumCommEUR MONEY=0 OUTPUT,
	@SumPlayerCommEUR MONEY=0 OUTPUT
AS
/*
Created: Henry@20101210
Task : get bet tickets for outright, horse racing
DB: DB052.bodb02
Original: [Age_BetList_SelWinlossOutright_Ag]
		
Revisions:    
-- 20110214@Jacob: Add column discount IN the result SET
-- 20110216@Jacob: Add column nickname IN the result SET
-- 20110303@Henry: suppport based currency
-- 20110506@Henry: fix bug do not have data if only parameter @CustID --> change to param: @LicenseeID, @LicenseeType, @CurrencyName to get the list of agents
- 20110712@Henry: Add column LicenseeWL
- 20111121@Jacob: Add 3 parameters: @ShowBA & @Show SB & @ExcludeReject
- 20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily  
- 20120614@Jim: optimize code 
- 20120726@Jim: add player comm value 
- 20121004@Jim: replace @currencyname input param by @currencyID
Example:

declare @p12 int
set @p12=7
declare @p13 money
set @p13=0
declare @p14 money
set @p14=0
declare @p15 money
set @p15=0
declare @p16 money
set @p16=0
declare @p17 money
set @p17=0
declare @p18 money
set @p18=0
declare @p19 money
set @p19=0
declare @p20 money
set @p20=0
declare @p21 money
set @p21=0



DECLARE @DateFrom DATETIME
DECLARE @DateTo DATETIME
DECLARE @MoveBetsDay DATETIME
SELECT @DateFrom = DATEADD(DAY, -15, GETDATE())
SELECT @DateTo = GETDATE()
SELECT @MoveBetsDay = MAX(eventdate) FROM match14 WITH(NOLOCK)


exec Lrf_BetList_SelWinlossOutright @LicenseeID=4,@LicenseeType=default,@CurrencyName=default,@FromDate=@DateFrom,@ToDate=@DateTo,@ShowBA=1,@ShowSB=0,@Language=default,@MoveBetsDay=@MoveBetsDay,@PageSize=1000,@PageIndex=1,@TotalRows=@p12 output,@SumWinlost=@p13 output,@SumLicenseeWL=@p14 output,@SumComm=@p15 output,@SumWinlostUSD=@p16 output,@SumLicenseeWLUSD=@p17 output,@SumCommUSD=@p18 output,@SumWinlostEUR=@p19 output,@SumLicenseeWLEUR=@p20 output,@SumCommEUR=@p21 output
select @p12, @p13, @p14, @p15, @p16, @p17, @p18, @p19, @p20, @p21

*/

SET NOCOUNT ON

DECLARE @TempAg AS TABLE (custid INT)
INSERT INTO @TempAg (custid)
SELECT  CustID  
                FROM    bodb_Licensee.dbo.LicenseeCust WITH ( NOLOCK )  
                WHERE   LicenseeID = @LicenseeID  
                        AND  (@CurrencyID=0 OR (@CurrencyID <> 0 AND  Currency = @CurrencyID))
                        AND [Description] = COALESCE(@LicenseeType,  
                                                     [Description])

CREATE TABLE #AgWinlossOutright
(
	sporttype INT,
	--username NVARCHAR(50),
	--NickName NVARCHAR(50),
	CustID INT,
	bettype SMALLINT,			
	transid BIGINT,
	matchcode VARCHAR(50),
	homeID INT,
	awayID INT,
	hdp1 SMALLMONEY,
	hdp2 SMALLMONEY,
	odds SMALLMONEY,
	status NVARCHAR(50),
	stake MONEY,
	winlost MONEY,
	licenseeWL MONEY,
	comm MONEY,
	playercomm MONEY,
	transdate DATETIME,
	betteam NVARCHAR(50),
	liveindicator BIT,
	livehomescore SMALLINT,
	liveawayscore SMALLINT,
	leagueID INT,
	matchid INT, 
	IP VARCHAR(30),
	betstatus VARCHAR(50),
	isNeutral BIT,
	winlostdate DATETIME,
	currency SMALLINT,
	isBA INT
)


IF @Todate > @MoveBetsDay
BEGIN
	IF @ShowBA = 1
	BEGIN		
		INSERT INTO #AgWinlossOutright 		
		SELECT
			l.sporttype,
			--b.username,
			--SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, len(c.username2)-CHARINDEX('$',c.username2)) AS nickname,   		
			b.custid,
			b.bettype,					
			b.transid,
			m.matchcode,
			m.teamID,
			0,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.status,
			b.stake,
			(b.winlost-actual_stake),
			0 AS LicenseeWL ,
			b.comm,
			b.playercomm  AS PlayerComm,
			b.transdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			l.leagueID,
			b.matchid, 
			b.IP AS IP,
			NULL,
			CONVERT(BIT,0) AS IsNeutral,
			b.winlostdate,
			b.currency ,
			1 AS isBA
		FROM
			bettrans b WITH (NOLOCK) 
			INNER JOIN outright m WITH (NOLOCK) ON b.matchid=m.orid	
			INNER JOIN League l WITH (NOLOCK) ON m.leagueID=l.leagueID	
			--INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid	
			--INNER JOIN customer c WITH(NOLOCK) ON c.custid=b.custid	   	 	
		WHERE
			b.recommend IN (SELECT custid FROM @TempAg)	AND
			b.Winlostdate>=@FromDate AND
			b.Winlostdate<=@ToDate AND
			b.Bettype=10 AND
			b.Ruben=1 AND
			b.tpositiontaking=0 AND
			(@ExcludeReject = 0 OR (@ExcludeReject=1 AND b.statusID NOT IN (101, 102, 103)))
			
		
			
	END			

	IF @ShowSB = 1
	BEGIN		
		INSERT INTO #AgWinlossOutright 		
		SELECT
			l.sporttype,
			--b.username,
			--SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, len(c.username2)-CHARINDEX('$',c.username2)) AS nickname,   		
			b.custid,
			b.bettype,					
			b.transid,
			m.matchcode,
			m.teamID,
			0,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.status,
			b.stake,
			(b.winlost-actual_stake),
			-(b.winlost-b.actual_stake)AS LicenseeWL ,
			b.comm,
			b.playercomm AS PlayerComm,
			b.transdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			l.leagueID,
			b.matchid, 
			b.IP AS IP,
			NULL,
			CONVERT(BIT,0) AS IsNeutral,
			b.winlostdate,
			b.currency ,
			0 AS isBA
		FROM
			bettrans b WITH (NOLOCK) 
			INNER JOIN outright m WITH (NOLOCK) ON b.matchid=m.orid	
			INNER JOIN League l WITH (NOLOCK) ON m.leagueID=l.leagueID	
			--INNER JOIN customer c WITH(NOLOCK) ON c.custid=b.custid	   	 				
		WHERE
			b.recommend IN (SELECT custid FROM @TempAg)	AND
			b.Winlostdate>=@FromDate AND
			b.Winlostdate<=@ToDate AND
			b.Bettype=10 AND
			b.Ruben=1 AND
			b.tpositiontaking<>0 AND
			(@ExcludeReject = 0 OR (@ExcludeReject=1 AND b.statusID NOT IN (101, 102, 103))) 
			
			
			
			
	END		
	
	
END

IF @Fromdate <= @MoveBetsDay
BEGIN
	IF @ShowBA = 1
	BEGIN		
		INSERT INTO #AgWinlossOutright 		
		SELECT
			l.sporttype,
			--b.username,
			--SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, len(c.username2)-CHARINDEX('$',c.username2)) AS nickname,   		
			b.custid,
			b.bettype,					
			b.transid,
			m.matchcode,
			m.teamID,
			0,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.status,
			b.stake,
			(b.winlost-actual_stake),
			0 AS LicenseeWL ,
			b.comm,
			b.playercomm AS PlayerComm,
			b.transdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			l.leagueID,
			b.matchid, 
			b.IP AS IP,
			NULL,
			CONVERT(BIT,0) AS IsNeutral,
			b.winlostdate,
			b.currency ,
			1 AS isBA
		FROM
			bettrans14 b WITH (NOLOCK) 
			INNER JOIN outright14 m WITH (NOLOCK) ON b.matchid=m.orid	
			INNER JOIN League l WITH (NOLOCK) ON m.leagueID=l.leagueID	
			--INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
			--INNER JOIN customer c WITH(NOLOCK) ON c.custid=b.custid	   	 		
		WHERE
			b.recommend IN (SELECT custid FROM @TempAg)	AND
			b.Winlostdate>=@FromDate AND
			b.Winlostdate<=@ToDate AND
			b.Bettype=10 AND
			b.Ruben=1 AND
			b.tpositiontaking=0 AND
			(@ExcludeReject = 0 OR (@ExcludeReject=1 AND b.statusID NOT IN (101, 102, 103))) 
		
	END	

	IF @ShowSB = 1
	BEGIN		
		INSERT INTO #AgWinlossOutright 		
		SELECT
			l.sporttype,
			--b.username,
			--SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, len(c.username2)-CHARINDEX('$',c.username2)) AS nickname,   		
			b.custid,
			b.bettype,					
			b.transid,
			m.matchcode,
			m.teamID,
			0,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.status,
			b.stake,
			(b.winlost-actual_stake),
			-(b.winlost-b.actual_stake)AS LicenseeWL ,
			b.comm,
			b.playercomm AS PlayerComm,
			b.transdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			l.leagueID,
			b.matchid, 
			b.IP AS IP,
			NULL,
			CONVERT(BIT,0) AS IsNeutral,
			b.winlostdate,
			b.currency ,
			0 AS isBA
		FROM
			bettrans14 b WITH (NOLOCK) 
			INNER JOIN outright14 m WITH (NOLOCK) ON b.matchid=m.orid	
			INNER JOIN League l WITH (NOLOCK) ON m.leagueID=l.leagueID	
			--LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) on b.transid = BA.transid
			--INNER JOIN customer c WITH(NOLOCK) ON c.custid=b.custid	   	 				
		WHERE
			b.recommend IN (SELECT custid FROM @TempAg)	AND
			b.Winlostdate>=@FromDate AND
			b.Winlostdate<=@ToDate AND
			b.Bettype=10 AND
			b.Ruben=1 AND
			b.tpositiontaking<>0 AND
			(@ExcludeReject = 0 OR (@ExcludeReject=1 AND b.statusID NOT IN (101, 102, 103))) 
	END		
	
	
	
END


DECLARE @RowStart INT, @RowEnd INT  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

CREATE NONCLUSTERED INDEX IDX_Index_Ag ON #AgWinlossOutright (Currency)
SELECT * INTO #TempExchange
FROM Lrf_f_GetExchangeDaily(@FromDate,@ToDate)
WHERE exchangeid IN (SELECT DISTINCT Currency FROM #AgWinlossOutright)

SELECT 
	@TotalRows = COUNT(transid),
	@SumWinlost=SUM(ISNULL(winlost,0)),
	@SumLicenseeWL=SUM(ISNULL(LicenseeWL,0)),
	@SumComm=SUM(ISNULL(comm,0)) ,
	@SumPlayerComm=SUM(ISNULL(playercomm,0)),
	--USD
	@SumWinlostUSD=SUM(ISNULL(winlost*e.USD,0)),
	@SumLicenseeWLUSD=SUM(ISNULL(LicenseeWL*e.USD,0)),
	@SumCommUSD=SUM(ISNULL(comm*e.USD,0)) ,
	@SumPlayerCommUSD=SUM(ISNULL(playercomm*e.USD,0)),
	--EUR
	@SumWinlostEUR=SUM(ISNULL(winlost*e.EUR,0)),
	@SumLicenseeWLEUR=SUM(ISNULL(LicenseeWL*e.EUR,0)),
	@SumCommEUR=SUM(ISNULL(comm*e.EUR,0)),
	@SumPlayerCommEUR=SUM(ISNULL(playercomm*e.EUR,0))	
	
FROM #AgWinlossOutright b
	INNER JOIN  #TempExchange e
	ON e.ExchangeDate = b.winlostdate  AND e.exchangeid = b.currency


SELECT A.* 
FROM
(
	SELECT  
			ROW_NUMBER() over(ORDER BY Transid) AS RowNum,
			b.* ,
			c.username,
			SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, len(c.username2)-CHARINDEX('$',c.username2)) AS nickname,
			
			--USD
			stake*e.USD stakeUSD,
			winlost*e.USD winlostUSD,
			LicenseeWL*e.USD LicenseeWLUSD,
			comm*e.USD commUSD,
			playercomm*e.USD PlayerCommUSD,
			
			--EUR
			stake*e.EUR stakeEUR,
			winlost*e.EUR winlostEUR,
			LicenseeWL*e.EUR LicenseeWLEUR,
			comm*e.EUR commEUR,
			playercomm*e.EUR PlayerCommEUR
			
	FROM 
		#AgWinlossOutright b
		INNER JOIN customer c WITH(NOLOCK) ON c.custid=b.custid
		INNER JOIN  #TempExchange e
		ON e.ExchangeDate = b.winlostdate  AND e.exchangeid = b.currency
) A WHERE A.RowNum BETWEEN @RowStart AND @RowEnd

DROP TABLE #AgWinlossOutright
DROP TABLE #TempExchange 

GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelWinlossOutright] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelWinlossOutright] TO [VNTeam]
