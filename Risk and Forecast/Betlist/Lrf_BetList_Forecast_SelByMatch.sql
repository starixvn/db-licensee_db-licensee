set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go


ALTER   PROCEDURE [dbo].[Lrf_BetList_Forecast_SelByMatch]
	@MatchID INT,
	@LicenseeID INT,
	@CurrencyID INT=0,
	@UserID		INT,
	@LicenseeType VARCHAR(100) = NULL,
	@Bettype INT = 0,
	@Langkey VARCHAR(10) = 'en-US',
	@betteam VARCHAR(20) = NULL,
	@liveindicator INT = -1,
	@PageSize INT=1000,
	@PageIndex INT=1,
	@BetChoice VARCHAR(10) = 'All',
	@TotalRows INT=0 OUTPUT
AS

/*
Created: Victor@20130802
Task : Forecast
DB: DB052.bodb02
Original: [Lrf_BetList_Forecast_SelByMatch]
Revisions:
Param's explanation:
 - BetChoice: one of the following list: 'All','Home', 'Away', 'Over', 'Under'
	+ Full: List all tickets bet on FT Handicap or FT Over/Under (@bettype must be 0)
	+ Half: List all tickets bet on HT Handicap or HT Over/Under (bettype must be 0)
	+ Home: List all Tickets bet on Home team
	+ Away: List all tickets bet on Away team
	+ Over: List all tickets bet on 'Over' 
	+ Under: List all tickets bet on 'Under'
*/
BEGIN
	SET NOCOUNT ON

	SELECT  currencyID,LicenseeID into #currency
	FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
	WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

	DECLARE @TempAg AS TABLE (custid INT)
	INSERT INTO @TempAg (custid)
	SELECT  CustID  
					FROM    bodb_Licensee.dbo.LicenseeCust lc WITH ( NOLOCK )
					INNER JOIN #currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID		
					WHERE   [Description] = COALESCE(@LicenseeType,  
														 [Description]) 

	SET @betteam = RTRIM(LTRIM(ISNULL(@betteam,'')))

	CREATE TABLE #Data
	(
		CustID INT,
		Sporttype INT,
		Username NVARCHAR(50),
		Bettype SMALLINT,
		Transid BIGINT,
		Matchcode VARCHAR(50),
		Race VARCHAR(50),
		LeagueID INT,
		HomeID INT,
		AwayID INT,
		hdp1 SMALLMONEY,
		hdp2 SMALLMONEY,
		odds SMALLMONEY,
		status NVARCHAR(50),
		stake MONEY,
		transdate DATETIME,
		betteam VARCHAR (50),
		liveindicator INT,
		livehomescore SMALLINT,
		liveawayscore SMALLINT,
		discount DECIMAL(9,8),
		ip NVARCHAR(20),
		IsNeutral BIT,
		oddstype TINYINT,
		betid BIGINT,
		winlostdate DATETIME,
		currency SMALLINT,
		playercomm MONEY,
		refno BIGINT,
		showtime NVARCHAR(50) -- table - shoe - hand of Live Casino
	)


	INSERT INTO #Data
	SELECT 
		b.CustID,
		m.sporttype,
		b.Username,      		
		b.Bettype,     
		b.TransID,     
		m.Matchcode,   
		'' AS Race,
		m.leagueid, 
		m.HomeID,
		m.AwayID, 
		CONVERT(FLOAT, b.hdp1) AS hdp1, 
		CONVERT(FLOAT, b.hdp2) AS hdp2, 
		b.odds,
		--b.status,   
		CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
		ELSE b.status   
		END as status, 
		b.stake,  
		b.Transdate,   		
		b.betteam,
		b.Liveindicator,
		b.Livehomescore, 
		b.Liveawayscore, 		 	
		b.discount,
		b.IP AS IP,
		ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
		b.Oddstype,
		b.betid,
		b.winlostdate,
		b.currency,
		b.playercomm,
		b.refno,
		isnull(m.showtime,'') as showtime
	FROM 
		Bettrans b WITH (NOLOCK) 
		INNER JOIN Match m WITH (NOLOCK) ON b.matchid=m.matchid 
	WHERE
		b.matchid=@matchid AND 
		((@bettype=0 AND b.bettype IN (1,3,7,8)) OR (@bettype!=0 AND b.bettype=@bettype)) AND
		b.recommend IN (SELECT custid FROM @TempAg) AND
		b.statusID IN (0,1) AND
		((@Liveindicator=-1) OR (@Liveindicator=0 AND b.Liveindicator = 0) OR (@Liveindicator=1 AND b.Liveindicator = 1)) AND
		((@betteam='') OR (@betteam<>'' AND b.betteam = @betteam))
			
	ORDER BY
		b.status, b.transid


	DECLARE @RowStart INT, @RowEnd INT  
	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

	DECLARE @Today SMALLDATETIME 
	SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)

	-- Filter data by BetChoice
	IF (@BetChoice LIKE 'Home')
	BEGIN
		DELETE FROM #Data WHERE betteam NOT LIKE 'h'
	END
	ELSE IF (@BetChoice LIKE 'Away')
	BEGIN
		DELETE FROM #Data WHERE betteam NOT LIKE 'a'
	END
	ELSE IF (@BetChoice LIKE 'Over')
	BEGIN
		DELETE FROM #Data WHERE betteam NOT LIKE 'h'
	END
	ELSE IF (@BetChoice LIKE 'Under')
	BEGIN
		DELETE FROM #Data WHERE betteam NOT LIKE 'a'
	END
	ELSE IF (@BetChoice LIKE 'Full')
	BEGIN
		DELETE FROM #Data WHERE bettype IN (7,8)
	END
	ELSE IF (@BetChoice LIKE 'Half')
	BEGIN
		DELETE FROM #Data WHERE bettype IN (1,3)
	END
	ELSE
	BEGIN
		DELETE FROM #Data
	END

	IF @TotalRows = 0  
	BEGIN 
		 SELECT @TotalRows = COUNT(transid) FROM #Data
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
				b.playercomm*e.USD PlayerCommUSD,
				b.playercomm*e.EUR PlayerCommEUR
		FROM #Data b
		INNER JOIN customer c WITH(NOLOCK) ON c.custid=b.custid 
		INNER JOIN 
			(SELECT * FROM Lrf_f_GetExchangeDaily(@Today,@Today))e 
		ON e.exchangeid = b.currency
	) A WHERE A.RowNum BETWEEN @RowStart AND @RowEnd
 
	------------------------
	DROP TABLE #Currency
	DROP TABLE #Data
	------------------------
	
END
GO

GRANT EXECUTE ON [dbo].[Lrf_BetList_Forecast_SelByMatch] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_Forecast_SelByMatch] TO vnteam
GO

