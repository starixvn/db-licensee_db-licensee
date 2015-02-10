ALTER  PROCEDURE [dbo].[Lrf_BetList_SelAllByDateHR]
	 @LicenseeID INT ,
	 @UserID	INT,
     @LicenseeType VARCHAR(100) = NULL ,
     @CurrencyID INT=0 ,
	 @Bettype INT,    	 
	 @MatchID INT,
	 @PageSize INT=1000,
	 @PageIndex INT=1,
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
	 @SumPlayerCommEUR MONEY=0 OUTPUT,
	 @SumWinlostGBP MONEY=0 OUTPUT,
	 @SumLicenseeWLGBP MONEY=0 OUTPUT,
	 @SumCommGBP MONEY=0 OUTPUT,
	 @SumPlayerCommGBP MONEY=0 OUTPUT
	 
AS 

/*
Created: Henry@20101208
Task : get Horse Racing tickets for Agent level
DB: DB052.bodb02
Original 
Revisions:    
   -- 20110214@Jacob: Add column discount IN the result SET
   -- 20110216@Jacob: Add column nickname IN the result SET
   -- 20110303@Henry: suppport based currency
   -- 20110308@Henry: get more sporttype (152,153)
   - 20110712@Henry: output column LicenseeWL insteed of AWinlost
   - 20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily
   - 20120724@Jim: add player commision value 	
   - 20121004@Jim: replace @currencyname input param by @currencyID
   - 20130514@Jim: Restrict permission of Licensee Users by currency
   - 20141111@Winnie: change from LicenseeCust to f_SelLicenseeCust 
   - 20150127@Winnie: Add base currency GBP 
*/
 
SET NOCOUNT ON  

SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

DECLARE @TempAg AS TABLE ( CustId INT )
    INSERT  INTO @TempAg( CustId)
    SELECT DISTINCT CustID  
                FROM    bodb_Licensee.dbo.f_SelLicenseeCust(0) lc --WITH ( NOLOCK )  
						INNER JOIN #Currency c ON lc.licenseeID=c.licenseeID AND lc.Currency=c.CurrencyID
                WHERE   [Description] = COALESCE(@LicenseeType,  
                                                     [Description]) 


DECLARE @FromDate DATETIME, @ToDate DATETIME
SELECT @ToDate = CONVERT(DATETIME,CONVERT(NVARCHAR(20), GETDATE(), 101))
SELECT @FromDate = DATEADD(dd,-1,@ToDate)
 
DECLARE @Data TABLE(
	--RowNum INT,
	Username NVARCHAR(50),
	NickName NVARCHAR(50),
	Sporttype INT,
	Bettype SMALLINT,
	Transid BIGINT,
	Matchcode VARCHAR(50),
	Matchid INT,
	Race VARCHAR(50),
	HomeID INT,
	AwayID INT,
	hdp1 SMALLMONEY,
	hdp2 SMALLMONEY,
	modds SMALLMONEY,
	odds SMALLMONEY,
	status NVARCHAR(50),
	stake MONEY,
	winlost MONEY,
	licenseeWL MONEY,
	comm MONEY,
	playercomm MONEY,
	discount MONEY,
	transdate DATETIME,
	winlostdate DATETIME,
	betteam VARCHAR (50),
	leagueid INT,
	liveindicator INT,
	livehomescore SMALLINT,
	liveawayscore SMALLINT,
	ip NVARCHAR(20),
	betstatus VARCHAR(50),
	IsNeutral BIT,
	currency SMALLINT
) 

DECLARE @RowStart INT, @RowEnd INT  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1


INSERT INTO @Data
SELECT 
		b.UserName,
		SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, len(c.username2)-CHARINDEX('$',c.username2)) AS nickname,
		l.sporttype AS sporttype,
		b.bettype,		
		b.transid,
		m.matchcode,
		b.matchid,
		m.GroupMatch AS Race,
		m.teamID AS homeID,
		0 AS awayID,
		b.hdp1, 
		b.hdp2,
		modds,
		b.odds,
		b.status,
		b.stake,
		(winlost-actual_stake)  winlost,
		b.awinlost,
		b.comm,
		b.playercomm , 
		b.discount,
		b.transdate,
		b.winlostdate,
		'' AS Betteam,    
		m.leagueID,
		0 AS liveindicator , 
		b.livehomescore, 
		b.liveawayscore,
		b.IP, 
		'' betstatus,
		CONVERT(BIT,0) AS IsNeutral,
		b.currency
	FROM  
	  bettrans b WITH (nolock)
	  INNER JOIN outright m WITH (nolock) ON b.matchid=m.orid   
	  INNER JOIN League l WITH (nolock) ON m.leagueID=l.leagueID 
	  INNER JOIN customer c WITH(NOLOCK) ON c.custid=b.custid	   
	WHERE  
	  b.MatchId= @MatchID
	  AND b.Bettype= @Bettype  
	  AND b.Recommend IN (SELECT * from @TempAg)
	  AND ((@CurrencyID=0 AND b.currency IN (SELECT currencyId FROM #currency))  OR (@CurrencyID<>0 AND b.Currency=@CurrencyID))
	  AND m.eventdate BETWEEN @FromDate AND @ToDate
	  
	ORDER BY b.transid DESC  

DECLARE @Today SMALLDATETIME 
SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)
DECLARE @Fdate DATETIME
DECLARE @Tdate DATETIME 
SELECT @Fdate=min(b.winlostdate),@Tdate=max(b.winlostdate)
FROM @Data b 

SELECT 
	@TotalRows = COUNT(transid),
	@SumWinlost=SUM(ISNULL(winlost,0)),
	@SumLicenseeWL=SUM(ISNULL(LicenseeWL,0)),
	@SumComm=SUM(ISNULL(comm,0)) ,
	@SumPlayerComm=SUM(ISNULL(playercomm,0)) ,
	
	--USD
	@SumWinlostUSD=SUM(ISNULL(winlost*e.USD,0)),
	@SumLicenseeWLUSD=SUM(ISNULL(LicenseeWL*e.USD,0)),
	@SumCommUSD=SUM(ISNULL(comm*e.USD,0)) ,
	@SumPlayerCommUSD=SUM(ISNULL(playercomm*e.USD,0)) ,
	--EUR
	@SumWinlostEUR=SUM(ISNULL(winlost*e.EUR,0)),
	@SumLicenseeWLEUR=SUM(ISNULL(LicenseeWL*e.EUR,0)),
	@SumCommEUR=SUM(ISNULL(comm*e.EUR,0)),
	@SumPlayerCommEUR=SUM(ISNULL(playercomm*e.EUR,0)),
	--GBP
	@SumWinlostGBP=SUM(ISNULL(winlost*e.GBP,0)),
	@SumLicenseeWLGBP=SUM(ISNULL(LicenseeWL*e.GBP,0)),
	@SumCommGBP=SUM(ISNULL(comm*e.GBP,0)),
	@SumPlayerCommGBP=SUM(ISNULL(playercomm*e.GBP,0)) 	 	
	
FROM @Data b
	INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@FDate,@TDate)) e  
	ON e.ExchangeDate = (CASE WHEN b.winlostdate <= @Today THEN  b.winlostdate ELSE @Today END)   AND e.exchangeid = b.currency


SELECT c.* FROM 
(
	SELECT 
			ROW_NUMBER() over(ORDER BY b.transid DESC) AS RowNum,
			b.*,
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
			playercomm*e.EUR PlayerCommEUR,
			--GBP
			stake*e.GBP stakeGBP,
			winlost*e.GBP winlostGBP,
			LicenseeWL*e.GBP LicenseeWLGBP,
			comm*e.GBP commGBP,
			playercomm*e.GBP PlayerCommGBP
			
	FROM	@Data b
		INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@FDate,@TDate)) e 
		ON e.ExchangeDate = (CASE WHEN b.winlostdate <= @Today THEN  b.winlostdate ELSE @Today END)   AND e.exchangeid = b.currency
) c WHERE c.RowNum BETWEEN @RowStart AND @RowEnd

IF @Bettype = 33 OR @Bettype = 43
BEGIN
	--get data from bettransm for bettype 33,43
	SELECT 
		BM.refno, 
		BM.finalodds,
		BM.odds, 
		BM.status, 
		BM.apositiontaking, 
		0 AS mpositiontaking, 
		0 AS spositiontaking,
		BM.bettype  
	FROM bettransm BM WITH (NOLOCK)
	INNER JOIN @Data B ON BM.refno = B.transid
	WHERE B.Bettype = @Bettype

END
DROP TABLE #Currency 

GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelAllByDateHR] TO [bodbLicenseeNet]

GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelAllByDateHR] TO [vnteam]
