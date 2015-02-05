set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go
ALTER  PROCEDURE [dbo].[Lrf_BetList_SelWinlostRacing]
	@LicenseeID INT ,
	@UserID		INT,
    @LicenseeType VARCHAR(100) = NULL ,
    @CurrencyID	INT=0,
	@date	DATETIME,
	@leagueid		INT,
	@raceNo			VARCHAR(10), 
	@PageSize INT=1000,
	@PageIndex INT=1,
	@TotalRows INT=0 OUTPUT ,
	@SumWinlost MONEY=0 OUTPUT,
	@SumStake MONEY=0 OUTPUT,
	@SumLicenseeWL MONEY=0 OUTPUT,
	@SumComm MONEY=0 OUTPUT,
	@SumPlayerComm MONEY=0 OUTPUT,
	@SumWinlostEUR MONEY=0 OUTPUT,
	@SumStakeEUR  MONEY=0 OUTPUT,
	@SumLicenseeWLEUR MONEY=0 OUTPUT,
	@SumCommEUR MONEY=0 OUTPUT,
	@SumPlayerCommEUR MONEY=0 OUTPUT ,
	@SumWinlostUSD MONEY=0 OUTPUT,
	@SumStakeUSD  MONEY=0 OUTPUT,
	@SumLicenseeWLUSD MONEY=0 OUTPUT,
	@SumCommUSD MONEY=0 OUTPUT,
	@SumPlayerCommUSD MONEY=0 OUTPUT,
	@SumWinlostGBP MONEY=0 OUTPUT,
	@SumStakeGBP  MONEY=0 OUTPUT,
	@SumLicenseeWLGBP MONEY=0 OUTPUT,
	@SumCommGBP MONEY=0 OUTPUT,
	@SumPlayerCommGBP MONEY=0 OUTPUT 
	
AS
/*
	Created by: Henry
	Date: 2011-09-21
	Task: Racing Detailed Bet List
	DB: DBRPT/BODB02 

	Revisions:
	- 20111010@Henry: Change column name
	- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
    - 20120614@Jim: optimize code 	
	- 20120726@Jim: add playercomm value 	
	- 20121004@Jim: replace @currencyname input param by @currencyID
    - 20130123@Daniel: Change link server alias
	- 20130305@Jim: change input param @winlostdate by @date 
	- 20130402@Jim: support base currency by USD
	- 20130514@Jim:Restrict permission of Licensee Users by currency
	- 20141111@Winnie: change from LicenseeCust to f_SelLicenseeCust 
	- 20150127@Winnie: add base currency GBP
	Param's Explanation:
		
*/

BEGIN
	SET NOCOUNT ON
	
	DECLARE @MoveBetsDay SMALLDATETIME
	SELECT    
		 @MoveBetsDay=MAX(eventdate)  
	FROM match14 WITH(NOLOCK)  
	
	SELECT CurrencyID
	  ,LicenseeID
	  INTO #Currency
	FROM  DBLIC.bodb_licensee.dbo.CurrencyUser WITH (NOLOCK)
	WHERE  usrID=@userID 
		AND LicenseeID=@LicenseeID 
		AND SystemID=1
		AND isActive=1
		AND (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))


	DECLARE @TempAg AS TABLE ( CustId INT )
	INSERT  INTO @TempAg(CustId)
	SELECT    CustId  
      FROM      custInfo WITH ( NOLOCK )  
      WHERE     CustID IN (  
                SELECT  DISTINCT CustID   
				FROM  OPENQUERY(DBLIC, 'SELECT * FROM bodb_licensee.dbo.f_SelLicenseeCust(0)') lc
						INNER JOIN  #currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID 
                WHERE   [Description] = COALESCE(@LicenseeType,  
                                                     [Description]) )  
                AND RoleId = 2  
	------------

	------------
	DECLARE @LicenseeName VARCHAR(50)
	SELECT @LicenseeName = LicenseeName FROM DBLIC.bodb_Licensee.dbo.Licensees WITH (NOLOCK)
	WHERE LicenseeID = @LicenseeID
	
	DECLARE @str_compare varchar (30)
	
	SELECT @str_compare = @LicenseeName + '$'

	CREATE TABLE #DataTmp
	(
		username nvarchar(50),  
		nickname NVARCHAR(50),
		transid bigint,  
		race VARCHAR(50),
		transdate DATETIME,  
		bettype SMALLINT,    	 
		matchid INT,   
		winOdds SMALLMONEY,  
		placeOdds SMALLMONEY,  
		odds SMALLMONEY,  
		stake MONEY,  
		winlost MONEY,  
		licenseeWL MONEY,
		comm MONEY,
		playercomm MONEY,
		winStatus VARCHAR(20),
		placeStatus VARCHAR(20),
		status nvarchar(50),  
		homeID INT,  
		awayID INT,  
		matchcode VARCHAR(50),  
		virtualrate FLOAT,
		isShowOTExRate BIT,
		currency INT,
		winlostdate SMALLDATETIME,
		leagueid int
	)



IF @date > @MoveBetsDay 	
BEGIN
	INSERT INTO #DataTmp
	SELECT	b.username,
			REPLACE(c.username2, @str_compare, '') nickname,
			b.transid,
			o.groupmatch as race,  
			b.transdate,
			b.bettype,
			b.matchid,
			b.hdp1 winOdds,
			b.hdp2 placeOdds,
			b.odds,			
			b.stake,
			(b.winlost - b.actual_stake) winlost,
			(b.awinlost + b.mwinlost + b.swinlost) AS LicenseeWL,
			b.comm  AS comm,
			b.playercomm  AS PlayerComm, 
			CASE b.livehomescore WHEN 2 THEN 'WON' WHEN 4 THEN 'LOSE' ELSE '' END winStatus,
			CASE b.liveawayscore WHEN 2 THEN 'WON' WHEN 4 THEN 'LOSE' ELSE 'Refund' END placeStatus,
			b.status,
			o.teamid, 
			0,
			o.matchcode,
			b.virtualrate,
			CASE WHEN b.currency2 IS NULL THEN CONVERT(BIT,0) ELSE CONVERT(BIT,1) END AS isShowOTExRate,
			b.currency,
			b.winlostdate,
			o.leagueid
	FROM	bettrans b (NOLOCK)
			INNER JOIN outright o (NOLOCK) ON b.matchid = o.orid 
			INNER JOIN customer c (NOLOCK) ON b.custid = c.custid
	WHERE	
			b.ruben = 1 
			AND b.bettype in (31,32,33) 
			AND b.statusID NOT IN (101,102,103,121)
			AND b.currency = @currencyID 
			AND b.winlostdate = @date
			AND o.leagueid = @leagueid 
			AND o.groupmatch = @raceNo
			AND b.recommend IN (SELECT custid FROM @TempAg)
			AND ((@CurrencyID=0 AND b.currency IN (SELECT currencyId FROM #currency))  OR (@CurrencyID<>0 AND b.Currency=@CurrencyID))
	ORDER BY b.username
END
ELSE
BEGIN
	INSERT INTO #DataTmp
	SELECT	b.username,
			REPLACE(c.username2, @str_compare, '') nickname,
			b.transid,
			o.groupmatch as race, 
			b.transdate,
			b.bettype,
			b.matchid,
			b.hdp1 winOdds,
			b.hdp2 placeOdds,
			b.odds,			
			b.stake,
			(b.winlost - b.actual_stake) winlost,
			(b.awinlost + b.mwinlost + b.swinlost) AS LicenseeWL,
			b.comm  AS comm,
			b.playercomm AS PlayerComm, 
			CASE b.livehomescore WHEN 2 THEN 'WON' WHEN 4 THEN 'LOSE' ELSE '' END winStatus,
			CASE b.liveawayscore WHEN 2 THEN 'WON' WHEN 4 THEN 'LOSE' ELSE 'Refund' END placeStatus,
			b.status,
			o.teamid, 
			0,
			o.matchcode,
			b.virtualrate,
			CASE WHEN b.currency2 IS NULL THEN CONVERT(BIT,0) ELSE CONVERT(BIT,1) END AS isShowOTExRate,
			b.currency,
			b.winlostdate,
			o.leagueid
	FROM	bettrans14 b (NOLOCK)
			INNER JOIN outright14 o (NOLOCK) ON b.matchid = o.orid 
			INNER JOIN customer c (NOLOCK) ON b.custid = c.custid
	WHERE	b.ruben = 1 
			AND b.bettype in (31,32,33) 
			AND b.statusID NOT IN (101,102,103,121)
			AND b.currency = @currencyID 
			AND b.winlostdate = @date
			AND o.leagueid = @leagueid 
			AND o.groupmatch = @raceNo
			AND b.recommend IN (SELECT custid FROM @TempAg)
			AND ((@CurrencyID=0 AND b.currency IN (SELECT currencyId FROM #currency))  OR (@CurrencyID<>0 AND b.Currency=@CurrencyID))
	ORDER BY b.username
END

DECLARE @RowStart INT, @RowEnd INT  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

CREATE NONCLUSTERED INDEX IDX_Index_Ag ON #DataTmp(Currency)

SELECT * INTO #TempExchange
FROM Lrf_f_GetExchangeDaily(@date,@date)
WHERE exchangeid IN (SELECT DISTINCT Currency FROM #DataTmp)

SELECT 
	@TotalRows = count(transid),
	@SumWinlost=SUM(isnull(winlost,0)),
	@SumStake = sum(isnull(stake,0)),
	@SumLicenseeWL=SUM(isnull(LicenseeWL,0)),
	@SumComm=SUM(isnull(comm,0)) ,
	@SumPlayerComm=SUM(ISNULL(playercomm,0)),
	
	--EUR
	@SumWinlostEUR=SUM(isnull(winlost*e.EUR,0)),
	@SumStakeEUR = sum(isnull(stake * e.EUR,0)),
	@SumLicenseeWLEUR=SUM(isnull(LicenseeWL*e.EUR,0)),
	@SumCommEUR=SUM(isnull(comm*e.EUR,0)),
	@SumPlayerCommEUR=SUM(ISNULL(Playercomm*e.EUR,0)),	
	--USD
	@SumWinlostUSD=SUM(isnull(winlost*e.USD,0)),
	@SumStakeUSD = sum(isnull(stake * e.USD,0)),
	@SumLicenseeWLUSD=SUM(isnull(LicenseeWL*e.USD,0)),
	@SumCommUSD=SUM(isnull(comm*e.USD,0)),
	@SumPlayerCommUSD=SUM(ISNULL(Playercomm*e.USD,0)),
	--GBP
	@SumWinlostGBP=SUM(isnull(winlost*e.GBP,0)),
	@SumStakeGBP = sum(isnull(stake * e.GBP,0)),
	@SumLicenseeWLGBP=SUM(isnull(LicenseeWL*e.GBP,0)),
	@SumCommGBP=SUM(isnull(comm*e.GBP,0)),
	@SumPlayerCommGBP=SUM(ISNULL(Playercomm*e.GBP,0))
	
FROM #DataTmp b
	INNER JOIN  #TempExchange e
	ON e.exchangeid = b.currency

SELECT A.* 
FROM
(
	SELECT  
			ROW_NUMBER() over(ORDER BY b.username) as RowNum,
			151 as sporttype,
			b.* ,
			--EUR
			stake*e.EUR stakeEUR,
			winlost*e.EUR winlostEUR,
			LicenseeWL*e.EUR LicenseeWLEUR,
			comm*e.EUR commEUR,
			playercomm*e.EUR PlayerCommEUR,
			--USD
			stake*e.USD stakeUSD,
			winlost*e.USD winlostUSD,
			LicenseeWL*e.USD LicenseeWLUSD,
			comm*e.USD commUSD,
			playercomm*e.USD PlayerCommUSD,
			--GBP
			stake*e.GBP stakeGBP,
			winlost*e.GBP winlostGBP,
			LicenseeWL*e.GBP LicenseeWLGBP,
			comm*e.GBP commGBP,
			playercomm*e.GBP PlayerCommGBP
			
	FROM #DataTmp b
		INNER JOIN  #TempExchange e
		ON e.exchangeid = b.currency
	
) A WHERE A.RowNum between @RowStart AND @RowEnd

-------------------------------------
DECLARE @BettransDetail TABLE(  
	refno BIGINT,  
	odds SMALLMONEY,  
	stake MONEY,
	status NVARCHAR(10),  
	apositiontaking SMALLMONEY,  
	bettype SMALLINT,
	Betteam nvarchar (10),
	stakeEUR MONEY,
	stakeUSD MONEY,
	stakeGBP MONEY

	 )   

	 IF @date>@MoveBetsDay 
		 BEGIN
			INSERT INTO @BettransDetail
			SELECT 
				BM.refno, 
				BM.odds, 
				BM.stake,
				BM.status, 
				BM.apositiontaking, 
				BM.bettype,
				BM.betteam,
				BM.stake*e.EUR,
				BM.stake*e.USD,
				BM.stake*e.GBP		
			FROM bettransm BM WITH (NOLOCK)
			INNER JOIN #DataTmp B ON BM.refno = B.transid
			INNER JOIN #TempExchange e ON e.ExchangeDate = B.winlostdate   AND e.exchangeid = B.currency
			WHERE B.Bettype IN (33,43)
		END
			
	ELSE 
		BEGIN
			INSERT INTO @BettransDetail
			SELECT 
				BM.refno, 
				BM.odds, 
				BM.stake,
				BM.status, 
				BM.apositiontaking, 
				BM.bettype,
				BM.betteam,
				BM.stake*e.EUR,
				BM.stake*e.USD,
				BM.stake*e.GBP 	
			FROM bettransm14 BM WITH (NOLOCK)
			INNER JOIN #DataTmp B ON BM.refno = B.transid
			INNER JOIN #TempExchange e ON e.ExchangeDate = B.winlostdate   AND e.exchangeid = B.currency
			WHERE B.Bettype IN (33,43)
		END	
	

SELECT * FROM @BettransDetail ORDER BY RefNo,Bettype 
-------------------------------------
DROP TABLE #DataTmp
DROP TABLE #TempExchange	
DROP TABLE #currency 	
END



GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelWinlostRacing] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelWinlostRacing] TO [vnteam] AS [dbo]