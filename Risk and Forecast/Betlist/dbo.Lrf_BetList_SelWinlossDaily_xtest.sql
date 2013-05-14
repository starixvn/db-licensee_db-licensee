CREATE PROCEDURE [dbo].[Lrf_BetList_SelWinlossDaily_xtest]
	@winlostdate SMALLDATETIME,
	@LicenseeID INT,
	@CurrencyName VARCHAR(20) = NULL,
	@LicenseeType VARCHAR(100) = NULL,
	@Language VARCHAR(10) = 'en-us',
	@MoveBetsDay SMALLDATETIME,
	@BalanceUpDay SMALLDATETIME,
	@PageSize INT=1000,
	@PageIndex INT=1,
	@TotalRows INT = 0 OUTPUT,
	@SumWinlost MONEY=0 OUTPUT,
	@SumLicenseeWL MONEY=0 OUTPUT,
	@SumComm MONEY=0 OUTPUT,
	@SumWinlostUSD MONEY=0 OUTPUT,
	@SumLicenseeWLUSD MONEY=0 OUTPUT,
	@SumCommUSD MONEY=0 OUTPUT,
	--EUR
	@SumWinlostEUR MONEY=0 OUTPUT,
	@SumLicenseeWLEUR MONEY=0 OUTPUT,
	@SumCommEUR MONEY=0 OUTPUT
AS

/*
Created: 20111904@Henry
Task : Betlist
DB: DB052.bodb02
Original:
Revisions:
	- 20110523@Henry: Support Number Game
	- 20110616@Henry: Suport filter BA tickets  
	- 20110712@Henry: Output Licensee WL + remove BA filter
	- 20110729@Henry: offer 3 new bettypes for Number Game
Param's Explanation: 
	
*/


SET NOCOUNT ON

DECLARE @Data TABLE
(
	RowNum INT,
	Sporttype INT,
	Username nvarchar(50),
	NickName NVARCHAR(50),
	Bettype INT,
	LeagueID INT,
	Transid BIGINT,
	Matchcode VARCHAR(50),
	HomeID INT,
	AwayID INT,
	hdp1 SMALLMONEY,
	hdp2 SMALLMONEY,
	odds SMALLMONEY,
	status nvarchar(50),
	stake MONEY,
	Winlost MONEY,
	LicenseeWL MONEY,
	comm MONEY,
	transdate DATETIME,
	Winlostdate DATETIME,
	betteam VARCHAR (50),
	liveindicator INT,
	livehomescore SMALLINT,
	liveawayscore SMALLINT,
	MatchID INT,
	ip nvarchar(30),
	Betstatus nvarchar(50),
	IsNeutral BIT,
	oddstype INT,
	betid BIGINT,
	currency SMALLINT
)

DECLARE @DataSum TABLE
(
	currency INT,
	totalrows INT,
	SumWinlost MONEY,
	SumLicenseeWL MONEY,
	SumComm MONEY
)


DECLARE @TempAg AS TABLE (custid INT)


INSERT INTO @TempAg (custid)
SELECT CustID FROM [Lrf_f_GetCustId] (@LicenseeID,@licenseetype,@CurrencyName)

DECLARE @RowStart INT, @RowEnd INT  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

	

IF @winlostdate > @MoveBetsDay
BEGIN
	INSERT INTO @DataSum
	SELECT 
		currency,
		COUNT(b.transid),
		SUM(ISNULL(b.winlost-b.actual_stake,0)),
		SUM(ISNULL(CASE WHEN ISNULL(BA.transid,0)=0 THEN - (b.winlost-b.actual_stake) ELSE 0 END,0)),
		SUM(ISNULL(b.comm - b.playercomm,0)) 
	FROM bettrans b WITH (nolock) 
		INNER JOIN match m WITH (nolock) ON b.matchid=m.matchid	
		LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
	WHERE
		b.winlostdate = @winlostdate
		AND b.recommend IN (SELECT custid FROM @TempAg)	
		AND (b.bettype < 31 OR b.bettype BETWEEN 81 AND 120)
		AND b.ruben = 1
	GROUP BY currency

	INSERT INTO @Data
	SELECT A.* 
	FROM	
	(	
		SELECT
			ROW_NUMBER() over(ORDER BY b.transid) AS RowNum,
			m.sporttype,
			b.username,
			SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, len(c.username2)-CHARINDEX('$',c.username2)) AS nickname,
			b.bettype,
			m.leagueID,			
			b.transid,
			m.matchcode,
			m.homeID,
			m.awayID,
			CONVERT(FLOAT, b.hdp1) AS hdp1, 
			CONVERT(FLOAT, b.hdp2) AS hdp2, 
			b.odds,
			b.status,
			b.stake,
			(b.winlost-actual_stake) winlost,
			CASE WHEN BA.transid IS NULL THEN - (b.winlost-b.actual_stake) ELSE 0 END AS LicenseeWL ,
			(b.comm - b.playercomm) as comm,
			b.transdate,
			b.winlostdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.matchid, 
			b.IP AS IP,
			m.betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.OddsType,
			b.betid,
			b.currency
		FROM
			bettrans b WITH (nolock) 
			INNER JOIN match m WITH (nolock) ON b.matchid=m.matchid	
			INNER JOIN customer c WITH (nolock) ON b.custid = c.custid
			LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
		WHERE
			b.winlostdate = @winlostdate
			AND b.recommend IN (SELECT custid FROM @TempAg)	
			AND (b.bettype < 31 OR b.bettype BETWEEN 81 AND 120)
			AND b.ruben = 1
	) A WHERE A.RowNum BETWEEN @RowStart AND @RowEnd
END

IF @Winlostdate <= @MoveBetsDay AND @Winlostdate >=@BalanceUpDay
BEGIN	
	INSERT INTO @DataSum
	SELECT 
		currency,
		COUNT(b.transid),
		SUM(ISNULL(b.winlost - b.actual_stake,0)),
		SUM(ISNULL(CASE WHEN BA.transid IS NULL THEN - (b.winlost-b.actual_stake) ELSE 0 END,0)),
		SUM(ISNULL(b.comm - b.playercomm,0)) 
		FROM bettrans14 b WITH (NOLOCK)	 
		INNER JOIN match14 m WITH (nolock) ON b.matchid=m.matchid 
		LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
	WHERE
		b.winlostdate = @winlostdate
		AND b.recommend IN (SELECT custid FROM @TempAg)	
		AND (b.bettype < 31 OR b.bettype BETWEEN 81 AND 120)
	GROUP BY currency	

	INSERT INTO @Data
	SELECT A.* 
	FROM	
	(
		SELECT
			ROW_NUMBER() over(ORDER BY b.transid) AS RowNum,
			m.sporttype,
			b.username,
			SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, len(c.username2)-CHARINDEX('$',c.username2)) AS nickname,
			b.bettype,
			m.leagueID,			
			b.transid,
			m.matchcode,
			m.homeID,
			m.awayID,
			CONVERT(FLOAT, b.hdp1) AS hdp1, 
			CONVERT(FLOAT, b.hdp2) AS hdp2, 
			--dbo.Lrf_f_GetOddsByBettype(b.odds,b.bettype,b.oddstype) AS odds,
			b.odds,
			b.status,
			b.stake,
			(b.winlost-actual_stake) winlost,
			CASE WHEN BA.transid IS NULL THEN - (b.winlost-b.actual_stake) ELSE 0 END AS LicenseeWL,
			(b.comm - b.playercomm) as comm,
			b.transdate,
			b.winlostdate,
			--dbo.Lrf_f_GetChoice(b.betteam, b.bettype,@Language) betteam,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.matchid, 
			b.IP AS IP,
			m.betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			--dbo.Lrf_f_ShowOddsByBettype(b.bettype,b.oddstype) AS OddsType ,
			b.OddsType,
			b.betid,
			b.currency
		FROM
			bettrans14 b WITH (NOLOCK)	
			INNER JOIN match14 m WITH (nolock) ON b.matchid=m.matchid 	
			INNER JOIN customer c WITH (nolock) ON b.custid = c.custid 	
			LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
		WHERE
			b.winlostdate = @winlostdate
			AND c.recommend IN (SELECT custid FROM @TempAg)
			AND (b.bettype < 31 OR b.bettype BETWEEN 81 AND 120)
			AND statusID NOT IN (101,102,103)
	) A WHERE A.RowNum BETWEEN @RowStart AND @RowEnd	
	
END

--Update Betteam, odds and oddstype
UPDATE @Data
SET betteam = dbo.Lrf_f_GetChoice(betteam,bettype,@Language)
WHERE bettype IN (14,16)
	
UPDATE @Data
SET odds = CASE WHEN OddsType = 1 THEN odds + 1
				WHEN OddsType = 5 THEN odds * 100
				ELSE odds END		
WHERE bettype IN (1,2,3,7,12,8,20)	
OR bettype BETWEEN 81 AND 88
OR bettype BETWEEN 90 AND 120

UPDATE @Data
SET OddsType = 0 
WHERE bettype NOT IN (1,2,3,7,12,8,20)
AND bettype NOT BETWEEN 81 AND 88
AND bettype NOT BETWEEN 90 AND 120


SELECT  
		b.* ,
		--USD
		stake*e.USD stakeUSD,
		Winlost*e.USD WinlostUSD,
		LicenseeWL*e.USD LicenseeWLUSD,
		comm*e.USD commUSD,
		--EUR
		stake*e.EUR stakeEUR,
		Winlost*e.EUR WinlostEUR,
		LicenseeWL*e.EUR LicenseeWLEUR,
		comm*e.EUR commEUR
FROM @Data b
INNER JOIN 
	ExchangeDaily e (NOLOCK) 
ON  e.exchangeid = b.currency
WHERE exchangedate = @winlostdate


--SUM
SELECT @TotalRows =SUM(TotalRows),
	@SumWinlost=SUM(SumWinlost),
	@SumLicenseeWL=SUM(SumLicenseeWL),
	@SumComm=SUM(SumComm),
	--USD
	@SumWinlostUSD=SUM(SumWinlost*e.USD),
	@SumLicenseeWLUSD=SUM(SumLicenseeWL*e.USD),
	@SumCommUSD=SUM(SumComm * e.USD),
	--EUR
	@SumWinlostEUR=SUM(SumWinlost*e.EUR),
	@SumLicenseeWLEUR=SUM(SumLicenseeWL*e.EUR),
	@SumCommEUR=SUM(SumComm * e.EUR)
FROM @DataSum b INNER JOIN exchangedaily e WITH (nolock)
ON b.currency = e.exchangeid
WHERE exchangedate = @winlostdate


GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelWinlossDaily_xtest] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelWinlossDaily_xtest] TO vnteam
