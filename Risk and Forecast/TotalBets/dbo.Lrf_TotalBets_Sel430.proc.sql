set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

ALTER PROCEDURE [dbo].[Lrf_TotalBets_Sel430]
	@LicenseeID INT,
	@CurrencyID INT=0,
	@UserID		INT,
	@LicenseeType VARCHAR(100) = NULL,
	@Langkey VARCHAR(10) = 'en-US',
	@PageSize INT=50,
	@PageIndex INT=1,
	@TotalRows INT=0 OUTPUT
 AS

/*
Created: Henry@20101209
Task : Betlist for Correct score and first correct score
DB: DB052.bodb02
Original:
Revisions:
	--20111229@Jim : change the way to get odds/oddstype/betteam to web dev
    --20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
	--20121004@Jim: replace @currencyname input param by @currencyID
	--20130514@Jim:Restrict permission of Licensee Users by currency
*/

SET NOCOUNT ON

DECLARE @Data TABLE(
	CustID INT,
	Sporttype INT,
	Username NVARCHAR(50),
	Bettype SMALLINT,
	Transid BIGINT,
	refno BIGINT,
	Matchcode VARCHAR(50),
	HomeID INT,
	AwayID INT,
	hdp1 SMALLMONEY,
	hdp2 SMALLMONEY,
	odds SMALLMONEY,
	modds SMALLMONEY,
	status NVARCHAR(50),
	Stake MONEY, 
	Actual_Stake	MONEY,
	transdate DATETIME,
	betteam VARCHAR (50),
	livehomescore SMALLINT,
	liveawayscore SMALLINT,
	liveindicator INT,
	discount DECIMAL(9,8),
	LeagueID INT,
	ip NVARCHAR(30),
	IsNeutral BIT,
	oddstype TINYINT,
	winlostdate DATETIME,
	currency SMALLINT
)

SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

DECLARE @TempAg AS TABLE (custid INT)
INSERT INTO @TempAg (custid)
SELECT  CustID  
                FROM    bodb_Licensee.dbo.LicenseeCust lc WITH ( NOLOCK )  
				INNER JOIN #currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID
                WHERE   [Description] = COALESCE(@LicenseeType,[Description])  
------------------------
DROP TABLE #currency
-------------------------                                                   
INSERT INTO @Data
	SELECT
		b.CustID, 
		m.sporttype,
		b.username,
		b.bettype,		
		b.transid,
		b.refno,
		m.matchcode,
		m.homeID,
		m.awayID,
		CONVERT(FLOAT, b.hdp1) AS hdp1, 
		CONVERT(FLOAT, b.hdp2) AS hdp2, 
		b.odds,
		b.modds,
		b.status,
		b.stake,
		b.actual_stake, 
		b.transdate,		
		b.betteam,
		b.livehomescore,
		b.liveawayscore,
		b.liveindicator, 
		b.discount,
		m.leagueID, 
		IP AS IP,
		ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
		b.Oddstype,
		b.winlostdate,
		b.currency
 	FROM 
		bettrans b WITH (NOLOCK)
		INNER JOIN match m WITH (NOLOCK) ON  b.matchid=m.matchid 				
	WHERE 
		b.Recommend IN (SELECT custid FROM @TempAg)
		AND b.bettype IN (4,30)
		AND b.statusID IN (0,1)
		AND b.tpositiontaking <> 0 
	ORDER BY b.status, b.transid

DECLARE @RowStart INT, @RowEnd INT  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

DECLARE @Today SMALLDATETIME 
SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120) 


IF @TotalRows = 0  
BEGIN 
	 SELECT @TotalRows = count(transid) FROM @Data
END


SELECT A.* 
FROM
(
	SELECT  
			ROW_NUMBER() over(ORDER BY b.status, b.transid) AS RowNum,
			SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, len(c.username2)-CHARINDEX('$',c.username2)) AS nickname,
			b.* ,
			stake*e.USD stakeUSD,
			stake*e.EUR stakeEUR,
			actual_stake * e.USD actual_stakeUSD,
			actual_stake * e.EUR actual_stakeEUR
	FROM 
		@Data b
		INNER JOIN customer c WITH(NOLOCK) ON c.custid=b.custid	
		INNER JOIN (SELECT *  FROM Lrf_f_GetExchangeDaily(@Today,@Today))e 
		ON e.exchangeid = b.currency
) A WHERE A.RowNum BETWEEN @RowStart AND @RowEnd


GO
GRANT EXECUTE ON [dbo].[Lrf_TotalBets_Sel430] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_TotalBets_Sel430] TO vnteam
 
