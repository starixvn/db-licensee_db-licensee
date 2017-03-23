USE [bodb02]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Lrf_TotalBets_Sel430]
	@PageSize		INT				= 50,
	@PageIndex		INT				= 1,
	@TotalRows		INT				= 0 OUTPUT,
	@AgentList		VARCHAR(MAX)
AS

/*
	Created: Henry@20101209
	Task : Betlist for Correct score and first correct score
	DB: DBEXT.bodb02
	Original:
	Revisions:
		- 20111229@Jim: change the way to get odds/oddstype/betteam to web dev
		- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily
		- 20121004@Jim: replace @currencyname input param by @currencyID
		- 20130514@Jim:Restrict permission of Licensee Users by currency
		- 20140620@Florent: offer new bettypes 152 - Half Time/Full Time Correct Score
		- 20141110@Winnie: Change from LicenseeCust table to [f_SelLicenseeCust] function
		- 20150124@Winnie: Add base currency GBP 
		- 20150420@Jim: add more bettype 165, 166
		- 20151203@Bobby: Database - Change datatype [Redmine: #48660]
		- 20151207@Kos: Include bet type 405 2H Correct Score [Redmine: #47959]
		- 20160129@Kos: Include bet type 413 Correct Score (aos) and [414] 1H Correct Score (aos) [Redmine: #50897]
		- 20170227@Harper: LRF - Get data by @AgentList instead of @UserID [RedmineID: #71679]

Param's Explanation:
	+ @AgentList: xml structure
					<ROOT>
					<Agent AgentId="12345" Currency="3"/>  
					<Agent AgentId="12345" Currency="5"/>  
					</ROOT>
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @Data TABLE(
		CustID			INT,
		Sporttype		INT,
		Username		NVARCHAR(50),
		Bettype			SMALLINT,
		Transid			BIGINT,
		refno			BIGINT,
		Matchcode		VARCHAR(50),
		HomeID			INT,
		AwayID			INT,
		hdp1			SMALLMONEY,
		hdp2			SMALLMONEY,
		odds			MONEY,
		modds			MONEY,
		status			NVARCHAR(50),
		Stake			MONEY, 
		Actual_Stake	MONEY,
		transdate		DATETIME,
		betteam			VARCHAR(50),
		livehomescore	SMALLINT,
		liveawayscore	SMALLINT,
		liveindicator	INT,
		discount		DECIMAL(9,8),
		LeagueID		INT,
		ip				NVARCHAR(30),
		IsNeutral		BIT,
		oddstype		TINYINT,
		winlostdate		DATETIME,
		currency		SMALLINT,
		transdesc		NVARCHAR(200)
	)

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
		b.IP,
		ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
		b.Oddstype,
		b.winlostdate,
		b.currency,
		ISNULL(b.transdesc, '') AS transdesc
	FROM 
		dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
		INNER JOIN @TempAg ag ON b.recommend = ag.CustId AND b.currency = ag.Currency
	WHERE b.bettype IN (4, 30, 152, 165, 166, 405, 413, 414)
		AND b.statusID IN (0, 1)
		AND b.tpositiontaking <> 0 
	ORDER BY b.status, b.transid

	DECLARE @RowStart INT, 
		@RowEnd INT

	SELECT @PageIndex = @PageIndex - 1, 
		@RowStart = @PageSize * @PageIndex + 1, 
		@RowEnd = @RowStart + @PageSize - 1

	DECLARE @Today SMALLDATETIME 
	SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120) 

	IF @TotalRows = 0
	BEGIN 
		 SELECT @TotalRows = COUNT(transid) FROM @Data
	END

	SELECT A.* 
	FROM
		(
			SELECT
				ROW_NUMBER() OVER(ORDER BY b.status, b.transid) AS RowNum,
				SUBSTRING(c.username2, CHARINDEX('$',c.username2) + 1, LEN(c.username2) - CHARINDEX('$',c.username2)) AS nickname,
				b.*,
				stake * e.USD AS stakeUSD,
				stake * e.EUR AS stakeEUR,
				stake * e.GBP AS stakeGBP,
				actual_stake * e.USD AS actual_stakeUSD,
				actual_stake * e.EUR AS actual_stakeEUR,
				actual_stake * e.GBP AS actual_stakeGBP
			FROM 
				@Data AS b
				INNER JOIN dbo.customer AS c WITH (NOLOCK) ON c.custid = b.custid
				INNER JOIN (SELECT *  FROM Lrf_f_GetExchangeDaily(@Today, @Today)) AS e ON e.exchangeid = b.currency
		) A 
	WHERE A.RowNum BETWEEN @RowStart AND @RowEnd
	
END


GO
GRANT EXECUTE ON [dbo].[Lrf_TotalBets_Sel430] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_TotalBets_Sel430] TO vnteam
 