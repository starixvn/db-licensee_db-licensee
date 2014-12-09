set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

ALTER PROCEDURE [dbo].[Lrf_BetList_SelWinlossParlay]
	@LicenseeID INT ,
    @LicenseeType VARCHAR(100) = NULL ,
	@UserID		INT,
    @CurrencyID INT=0,
    @Bettype INT = 9,
    @ShowBA BIT = 1,
    @ShowSB BIT = 0,
    @ExcludeReject BIT = 0,
	@FromDate SMALLDATETIME,
	@ToDate SMALLDATETIME,
	@Langkey VARCHAR(10) = 'en-US',
	@MoveBetsDay SMALLDATETIME,
	@PageSize INT=1000,
	@PageIndex INT=1,
	@TotalRows INT=0 OUTPUT ,
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
Task : Betlist for Parlay
DB: DB052.bodb02
Original: [Age_BetList_SelWinlossParlay_Ag]
Revisions:    
   -- 20110214@Jacob: Add column discount IN the result SET
   -- 20110216@Jacob: Add column nickname IN the result SET
   -- 20110303@Henry: suppport based currency
   -- 20110506@Henry: fix bug do not have data if only parameter @CustID --> change to param: @LicenseeID, @LicenseeType, @CurrencyName to get the list of agents
   - 20110712@Henry: Add column LicenseeWL
   - 20110809@Henry: add bettype 29 + add columns modds
   - 20111121@Jacob: Add two parameters: ShowBA & Show SB
   - 20111229@Jim: change the way to get odds/oddstype/betteam to web dev
   - 20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily  
   - 20120319@Henry: show main transid for sub-ticket of system parlay 
   - 20120614@Jim: optimize code 
   - 20120726@Jim: add playercomm value 
   - 20121004@Jim: replace @currencyname input param by @currencyID
   - 20130514@Jim:Restrict permission of Licensee Users by currency
   - 20141111@Winnie: change from LicenseeCust to f_SelLicenseeCust 
Param's Explanation: 
	
Example	

declare @p13 int
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
declare @p22 money
set @p22=0


DECLARE @DateFrom DATETIME
DECLARE @DateTo DATETIME
DECLARE @MoveBetsDay DATETIME
SELECT @DateFrom = DATEADD(DAY, -15, GETDATE())
SELECT @DateTo = GETDATE()
SELECT @MoveBetsDay = MAX(eventdate) FROM match14 WITH(NOLOCK)



exec Lrf_BetList_SelWinlossParlay @LicenseeID=4,@LicenseeType=default,@CurrencyName=default,@Bettype=9,@ShowBA=1,@ShowSB=0,@FromDate=@DateFrom,@ToDate=@DateTo,@Language=default,@MoveBetsDay=@MoveBetsDay,@PageSize=1000,@PageIndex=1,@TotalRows=@p13 output,@SumWinlost=@p14 output,@SumLicenseeWL=@p15 output,@SumComm=@p16 output,@SumWinlostUSD=@p17 output,@SumLicenseeWLUSD=@p18 output,@SumCommUSD=@p19 output,@SumWinlostEUR=@p20 output,@SumLicenseeWLEUR=@p21 output,@SumCommEUR=@p22 output
select @p13, @p14, @p15, @p16, @p17, @p18, @p19, @p20, @p21, @p22

*/
SET NOCOUNT ON

SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

CREATE  TABLE #TempAg  (custid INT)
INSERT INTO #TempAg (custid)
SELECT  DISTINCT CustID  
                FROM    bodb_Licensee.dbo.f_SelLicenseeCust(0) lc --WITH ( NOLOCK )  
				INNER JOIN #currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID
                WHERE  [Description] = COALESCE(@LicenseeType,  
                                                     [Description])
----------------------------

----------------------------													 
CREATE NONCLUSTERED INDEX IDX_Index_Ag ON #TempAg (CustID)

CREATE TABLE #AgWinlossMP
(
	username NVARCHAR(50),
	custid INT,
	bettype SMALLINT,		
	refno NVARCHAR(50),		
	transid BIGINT,	
	BetID BIGINT,
	hdp1 SMALLMONEY,
	hdp2 SMALLMONEY,
	odds SMALLMONEY,
	modds SMALLMONEY,
	status NVARCHAR(50),
	Stake MONEY, 
	Actual_Stake	MONEY,
	winlost MONEY,
	licenseeWL MONEY,
	comm MONEY,
	playercomm MONEY,
	transdate DATETIME,
	winlostdate DATETIME,
	betteam NVARCHAR(25),
	liveindicator BIT,
	livehomescore SMALLINT,
	liveawayscore SMALLINT,
	IP VARCHAR(30),
	isNeutral BIT,
	currency SMALLINT,
	isBA INT
)


IF @Todate > @MoveBetsDay
BEGIN
	
	IF @ShowBA = 1
	BEGIN
		INSERT INTO #AgWinlossMP 
		SELECT
			b.username,
			b.custid,
			b.bettype,		
			CONVERT(NVARCHAR,b.refno),		
			CASE WHEN bettype <> 29 THEN b.transid
				ELSE CASE WHEN ISNULL(b.BetID,0)=0 THEN b.transid ELSE betid END
				END AS transid,	
			ISNULL(b.BetID,0),
			b.hdp1,
			b.hdp2,
			b.odds,
			b.modds,
			b.status,
			b.stake,
			b.actual_stake, 
			(b.winlost-actual_stake),
			0 AS LicenseeWL ,
			b.comm,
			b.playercomm  AS PlayerComm,
			b.transdate,
			b.winlostdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.IP AS IP,
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			1 AS IsBA
		FROM
			bettrans b WITH (nolock) 
			--INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid	 
		WHERE
			b.recommend IN (SELECT custid FROM #TempAg)	AND
			 ((@CurrencyID=0 AND b.currency IN (SELECT currencyId FROM #currency))  OR (@CurrencyID<>0 AND Currency=@CurrencyID)) AND
			b.Winlostdate>=@FromDate AND
			b.Winlostdate<=@ToDate AND
			b.Bettype=@BetType AND
			b.matchid = @BetType AND
			b.Ruben=1 AND
			b.tpositiontaking=0 AND
			(@ExcludeReject = 0 OR (@ExcludeReject=1 AND b.statusID NOT IN (101, 102, 103)))
			
		
	END

	IF @ShowSB = 1
	BEGIN
		INSERT INTO #AgWinlossMP 
		SELECT
			b.username,
			b.custid,
			b.bettype,		
			CONVERT(NVARCHAR,b.refno),		
			CASE WHEN bettype <> 29 THEN b.transid
				ELSE CASE WHEN ISNULL(b.BetID,0)=0 THEN b.transid ELSE betid END
				END AS transid,
			ISNULL(b.BetID,0),
			b.hdp1,
			b.hdp2,
			b.odds,
			b.modds,
			b.status,
			b.stake,
			b.actual_stake, 
			(b.winlost-actual_stake),
			 -(b.winlost-b.actual_stake) AS LicenseeWL ,
			b.comm,
			b.playercomm  AS PlayerComm,
			b.transdate,
			b.winlostdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.IP AS IP,
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			0 AS isBA
		FROM
			bettrans b WITH (nolock) 				
			--LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) on b.transid = BA.transid
		WHERE
			b.recommend IN (SELECT custid FROM #TempAg)	AND
			 ((@CurrencyID=0 AND b.currency IN (SELECT currencyId FROM #currency))  OR (@CurrencyID<>0 AND Currency=@CurrencyID)) AND
			b.Winlostdate>=@FromDate AND
			b.Winlostdate<=@ToDate AND
			b.Bettype = @Bettype AND
			b.matchid = @Bettype AND
			b.Ruben=1 AND
			b.tpositiontaking<>0 AND
			(@ExcludeReject = 0 OR (@ExcludeReject=1 AND b.statusID NOT IN (101, 102, 103))) 
	END
	
	
	
END

IF @Fromdate <= @MoveBetsDay
BEGIN
	IF @ShowBA = 1
	BEGIN
		INSERT INTO #AgWinlossMP 
		SELECT
			b.username,
			b.custid,
			b.bettype,		
			CONVERT(NVARCHAR,b.refno),		
			CASE WHEN bettype <> 29 THEN b.transid
				ELSE CASE WHEN ISNULL(b.BetID,0)=0 THEN b.transid ELSE betid END
				END AS transid,		
			ISNULL(b.BetID,0),
			b.hdp1,
			b.hdp2,
			b.odds,
			b.modds,
			b.status,
			b.stake,
			b.actual_stake, 
			(b.winlost-actual_stake),
			0 AS LicenseeWL ,
			b.comm,
			b.playercomm AS PlayerComm,
			b.transdate,
			b.winlostdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.IP AS IP,
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			1 AS isBA
		FROM
			bettrans14 b WITH (nolock) 
			--INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid	
		WHERE
			b.recommend IN (SELECT custid FROM #TempAg)	AND
			 ((@CurrencyID=0 AND b.currency IN (SELECT currencyId FROM #currency)) OR (@CurrencyID<>0 AND Currency=@CurrencyID)) AND
			b.Winlostdate>=@FromDate AND
			b.Winlostdate<=@ToDate AND
			b.Bettype=@BetType AND
			b.matchid = @BetType AND
			b.Ruben=1 AND
			b.tpositiontaking=0 AND
			(@ExcludeReject = 0 OR (@ExcludeReject=1 AND b.statusID NOT IN (101, 102, 103))) 
			
			
	END

	IF @ShowSB = 1
	BEGIN
		INSERT INTO #AgWinlossMP 
		SELECT
			b.username,
			b.custid,
			b.bettype,		
			CONVERT(NVARCHAR,b.refno),		
			CASE WHEN bettype <> 29 THEN b.transid
				ELSE CASE WHEN ISNULL(b.BetID,0)=0 THEN b.transid ELSE betid END
				END AS transid,
			ISNULL(b.BetID,0),
			b.hdp1,
			b.hdp2,
			b.odds,
			b.modds,
			b.status,
			b.stake,
			b.actual_stake, 
			(b.winlost-actual_stake),
			 -(b.winlost-b.actual_stake) AS LicenseeWL ,
			b.comm,
			b.playercomm  AS PlayerComm,
			b.transdate,
			b.winlostdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.IP AS IP,
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			0 AS isBA
		FROM
			bettrans14 b WITH (nolock) 				
			--LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) on b.transid = BA.transid
		WHERE
			b.recommend IN (SELECT custid FROM #TempAg)	AND
			 ((@CurrencyID=0 AND b.currency IN (SELECT currencyId FROM #currency))  OR (@CurrencyID<>0 AND Currency=@CurrencyID)) AND
			b.Winlostdate>=@FromDate AND
			b.Winlostdate<=@ToDate AND
			b.Bettype = @Bettype AND
			b.matchid = @Bettype AND
			b.Ruben=1 AND
			b.tpositiontaking<>0 AND
			(@ExcludeReject = 0 OR (@ExcludeReject=1 AND b.statusID NOT IN (101, 102, 103))) 		
	END
	
	
	
END

CREATE NONCLUSTERED INDEX IDX_Index_Ag ON #AgWinlossMP (Currency)
SELECT * INTO #TempExchange
FROM Lrf_f_GetExchangeDaily(@FromDate,@ToDate)
WHERE exchangeid IN (SELECT DISTINCT Currency FROM #AgWinlossMP)

DECLARE @RowStart INT, @RowEnd INT  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

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
FROM #AgWinlossMP b
INNER JOIN  #TempExchange e
ON e.ExchangeDate = b.winlostdate  AND e.exchangeid = b.currency

SELECT A.* ,'' betstatus, '' matchcode, 0 homeid, 0 awayid, 0 leagueid, 0 matchid, 0 sporttype
FROM
(
	SELECT  
			ROW_NUMBER() over(ORDER BY Transid) AS RowNum,
			b.* ,
			SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, len(c.username2)-CHARINDEX('$',c.username2)) AS nickname,
			--USD
			stake * e.USD stakeUSD,
			actual_stake * e.USD actual_stakeUSD,
			winlost * e.USD winlostUSD,
			LicenseeWL * e.USD LicenseeWLUSD,
			comm * e.USD commUSD,
			playercomm*e.USD PlayerCommUSD,
			--EUR
			stake * e.EUR stakeEUR,
			actual_stake * e.EUR actual_stakeEUR,
			winlost * e.EUR winlostEUR,
			LicenseeWL * e.EUR LicenseeWLEUR,
			comm * e.EUR commEUR,
			playercomm*e.EUR PlayerCommEUR 
			
	FROM #AgWinlossMP b
		INNER JOIN customer c WITH(NOLOCK) ON c.custid=b.custid
		INNER JOIN  #TempExchange e
		ON e.ExchangeDate = b.winlostdate  AND e.exchangeid = b.currency
) A WHERE A.RowNum BETWEEN @RowStart AND @RowEnd

DROP TABLE #AgWinlossMP
DROP TABLE #TempAg
DROP TABLE #TempExchange
DROP TABLE #currency


GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelWinlossParlayt] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelWinlossParlay] TO [vnteam]
