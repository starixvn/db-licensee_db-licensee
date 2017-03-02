USE [bodb02]
GO
ALTER PROCEDURE [dbo].[Lrf_Rpt_CasinoProgressiveWins] 
	 @FromDate		SMALLDATETIME,  
	 @ToDate		SMALLDATETIME,  
	 @showMGCRnG	BIT = 0,
	 @MoveBetsDay	SMALLDATETIME,
	 @BalanceUpDay	SMALLDATETIME,
	 @AgentList	VARCHAR(MAX)
 AS  
/*  Created: Sophia  
	Date: 20151119
    Task : Casino Progressive Wins [RedmineID: #47601]
    DB: DBEXT/bodb02  
   
    Revisions:
		- 20160714@Percy: Enhance Performance - using OPENQUERY instead of linked-server [RedmineID: #60208]
		- 20170302@Paul: Get @AgentList by web instead of @UserId, @CurrencyID, @LicenseeID, Remove @excludeTest [Redmine: #71679]

	Param's Explanation: 
	 
*/
BEGIN 
	SET NOCOUNT ON  	
	
	DECLARE @_FromDate SMALLDATETIME, @_ToDate SMALLDATETIME
	DECLARE @tempAg	TABLE( custID INT,Currency INT)   	 
	DECLARE @sporttype TABLE(sporttype INT)

	CREATE TABLE #PayOutTrans
	(
		winlostDate DATETIME,
		CustId		INT,
		username2	NVARCHAR(100),
		Username	NVARCHAR(100),
		Refno		BIGINT,
		WinAmount	MONEY,
		GameId		SMALLINT,
		ProductId	SMALLINT,
		currency	INT
	)

	CREATE TABLE #JackPotWin
	( 
	  winlostDate SMALLDATETIME, 
	  CustId INT,
	  ExternalId VARCHAR (50) ,
	  SystemId VARCHAR (30), 
	  RefNo BIGINT,
	  WinAmount MONEY, 
	  Bettype SMALLINT, 
	  SportType SMALLINT, 
	  TransDesc NVARCHAR(1000),
	  Currency INT,
	  TranId3rd VARCHAR(64)
	)

	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	
		INSERT INTO @tempAg(CustId, Currency)
		SELECT AgentId, Currency 
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;

	IF @showMGCRnG =1  -- MicroGamming - RNG Casino
	BEGIN 
		INSERT INTO @sporttype (sporttype)
		VALUES(205)
	END

	INSERT INTO #PayOutTrans
	SELECT winlostDate, p.CustId, c.username2, p.Username, Refno, WinAmount, GameId, ProductId, tma.currency
	FROM
		DBACC.bodb02.dbo.PayOutTrans p WITH (NOLOCK)
		INNER JOIN bodb_licensee.dbo.Licenseecustinfo c WITH (NOLOCK) ON c.CustId = p.CustId
		INNER JOIN @TempAg tma ON tma.CustID=c.recommend --AND c.currency = tma.currency
	WHERE
		Winlostdate BETWEEN @FromDate AND @ToDate
		AND ProductId IN (SELECT sporttype FROM @sporttype)
	
	IF @MoveBetsDay < @ToDate
	BEGIN 
		INSERT INTO #JackPotWin (WinlostDate, CustId, ExternalId, SystemID, RefNo, WinAmount, Bettype, Sporttype, TransDesc, Currency, TranId3rd)
		SELECT	p.WinlostDate, p.CustId, p.username2 as ExternalId, p.Username as SystemID, 
				p.RefNo, p.WinAmount, p.GameId as Bettype, p.ProductId as Sporttype, b.transdesc, p.currency, b.TranId3rd
		FROM
			#PayOutTrans p
			INNER JOIN dbo.BettransRNG b WITH (NOLOCK) ON p.RefNo = b.TransId
	END

	IF @FromDate <= @MoveBetsDay
	BEGIN 	
		INSERT INTO #JackPotWin (WinlostDate, CustId, ExternalId, SystemID, RefNo, WinAmount, Bettype, Sporttype, TransDesc, currency, TranId3rd)
		SELECT	p.WinlostDate, p.CustId, p.username2 as ExternalId, p.Username as SystemID, 
				p.RefNo, p.WinAmount, p.GameId as Bettype, p.ProductId as Sporttype, b.transdesc, p.currency, b.TranId3rd
		FROM
			#PayOutTrans p
			INNER JOIN dbo.BettransRNG14 b WITH (NOLOCK) ON p.RefNo = b.TransId

	END

	IF @FromDate < @BalanceUpDay
	BEGIN
		SET @_FromDate = @FromDate 

		IF @BalanceUpDay < @ToDate
			SET @_ToDate = @BalanceUpDay
		ELSE 
			SET @_ToDate = @Todate
		
		DECLARE @OPENQUERY NVARCHAR(MAX)
		
		SELECT @OPENQUERY = 'SELECT	T.WinlostDate, T.CustId, p.username2, T.Username, 
								T.RefNo, T.WinAmount, T.GameId, T.ProductId, T.transdesc, p.currency, T.TranId3rd
								FROM (SELECT * FROM OPENQUERY (DBACC,''SELECT p.*, b.transdesc, b.TranId3rd, b.transid FROM bodb02.dbo.PayOutTrans p WITH (NOLOCK)
											 INNER JOIN bodb_archive.dbo.BettransRNG_BK b WITH (NOLOCK) ON p.RefNo = b.TransId
											 WHERE p.WinlostDate BETWEEN ''''' + CONVERT(VARCHAR(10),@_FromDate,120) + 
												   ''''' AND ''''' + CONVERT(VARCHAR(10),@_ToDate,120) + ''''''')) T
								INNER JOIN #PayOutTrans p ON p.Refno = T.transid'
	
		INSERT INTO #JackPotWin (WinlostDate, CustId, ExternalId, SystemID, RefNo, WinAmount, Bettype, Sporttype, TransDesc, currency, TranId3rd)
		EXEC (@OPENQUERY)
	END 
	
	DROP TABLE #PayOutTrans

	SELECT *
	INTO #TempExchange 
	FROM dbo.Lrf_f_GetExchangeDaily(@FromDate,@ToDate)
	--WHERE exchangeid IN (SELECT DISTINCT Currency FROM #JackPotWin)

	----Get Data

	SELECT j.WinlostDate, J.CustId, j.ExternalId, j.SystemID, 
		  j.RefNo, j.WinAmount, j.Bettype, j.Sporttype, j.transdesc, j.currency, j.TranId3rd,
		  j.WinAmount * e.EUR AS WinAmountEUR,
		  j.WinAmount * e.USD AS WinAmountUSD,
		  j.WinAmount * e.GBP AS WinAmountGBP
	FROM  #JackPotWin j
	INNER JOIN #TempExchange e
		ON j.winlostdate = e.ExchangeDate AND j.currency = e.ExchangeId
	
	DROP TABLE #TempExchange
	DROP TABLE #JackPotWin
END
GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_CasinoProgressiveWins] TO [bodbLicenseeNet] AS [dbo]
GO