USE [bodb02]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Lrf_BetList_RNG_Detail]
	@LicenseeId		INT,
	@UserId			INT,
	@CustId			INT,
	@RefNo			BIGINT,
	@TransType		TINYINT			= 0,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME
AS

/*
	Created: Kos@20150921
	Task : Get ticket detail from table bettransRnG (Microgaming RNG Game)
	DB: DBEXT.bodb02
	Original:
	Revisions:
		- 20150924@Kos: Add column BetCheck to return TranId3rd for showing ticket result
		- 20151029@Kos: Change SportType of Microgaming RNG Casino
		- 20151223@Kos: Support RNG Casino Single Wallet and use SportBettypeMatrix [Redmine: #48958]
		- 20160406@Kos: Support Voidbridge [#Redmine: 54925]

	Parameters:
		- @TransType
			+ 0 : All (DRAW/WON/LOSE/Reject/Void/Refund/Running/Waiting)
			+ 1 : DRAW/WON/LOSE/Refund
			+ 2 : Reject/Void
			+ 3 : Running/Waiting
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SportBettype TABLE(ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

	INSERT INTO @SportBettype
	EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel @mode = 5

	DELETE FROM @SportBettype
	WHERE ProductID NOT IN (6, 17, 22)	-- Support Microgaming RNG Casino, RNG Casino Single Wallet, Voidbridge
		OR (ProductID = 6 AND SubProduct = '')

	DECLARE @tmpStatus TABLE (statusId TINYINT)

	IF @TransType = 0
	BEGIN
		INSERT INTO @tmpStatus
		SELECT 111 UNION ALL
		SELECT 112 UNION ALL
		SELECT 113 UNION ALL
		SELECT 101 UNION ALL
		SELECT 102 UNION ALL
		SELECT 103 UNION ALL
		SELECT 0 UNION ALL
		SELECT 1
	END
	ELSE IF @TransType = 1
	BEGIN
		INSERT INTO @tmpStatus
		SELECT 111 UNION ALL
		SELECT 112 UNION ALL
		SELECT 113 UNION ALL
		SELECT 103
	END
	ELSE IF @TransType = 2
	BEGIN
		INSERT INTO @tmpStatus
		SELECT 101 UNION ALL
		SELECT 102
	END 
	ELSE IF @TransType = 3
	BEGIN
		INSERT INTO @tmpStatus
		SELECT 0 UNION ALL
		SELECT 1
	END

	DECLARE @tmpBettransRnG TABLE (
		TransId			BIGINT,
		SportType		SMALLINT,
		BetType			SMALLINT,
		TransDate		DATETIME,
		WinLostDate		SMALLDATETIME,
		Status			VARCHAR(10),
		StatusId		TINYINT,
		Odds			MONEY,
		Stake			MONEY,
		Actual_Stake	MONEY,
		WinLost			MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		IP				NVARCHAR(15),
		TransDesc		NVARCHAR(1000),
		BetCheck		VARCHAR(64)
	)

	IF EXISTS ( SELECT 1 FROM dbo.bettrans WITH (NOLOCK) WHERE transid = @RefNo )
	BEGIN
		INSERT INTO @tmpBettransRnG
		SELECT
			brng.transid,
			brng.productID AS SportType,
			brng.gameID AS BetType,
			brng.transdate,
			brng.winlostdate,
			brng.status,
			brng.statusID,
			brng.odds,
			brng.stake,
			brng.actual_stake,
			(brng.winlost - brng.actual_stake) AS WinLost,
			brng.comm,
			brng.playercomm,
			brng.ip,
			brng.transdesc,
			brng.TranId3rd AS BetCheck
		FROM dbo.bettransRnG AS brng WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON brng.gameID = sbt.Bettype
		WHERE brng.custid = @CustId 
			AND brng.RefNo = @RefNo
			AND brng.statusID IN (SELECT statusId FROM @tmpStatus)
	END
	ELSE IF EXISTS ( SELECT 1 FROM dbo.bettrans14 WITH (NOLOCK) WHERE transid = @RefNo )
	BEGIN
		INSERT INTO @tmpBettransRnG
		SELECT
			brng.transid,
			brng.productID AS SportType,
			brng.gameID AS BetType,
			brng.transdate,
			brng.winlostdate,
			brng.status,
			brng.statusID,
			brng.odds,
			brng.stake,
			brng.actual_stake,
			(brng.winlost - brng.actual_stake) AS WinLost,
			brng.comm,
			brng.playercomm,
			brng.ip,
			brng.transdesc,
			brng.TranId3rd AS BetCheck
		FROM dbo.bettransRnG14 AS brng WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON brng.gameID = sbt.Bettype
		WHERE brng.custid = @CustId AND brng.RefNo = @RefNo
	END
	ELSE IF EXISTS ( SELECT 1 FROM DBARC.bodb_Archive.dbo.bettrans_bk WITH (NOLOCK) WHERE transid = @RefNo )
	BEGIN
		INSERT INTO @tmpBettransRnG
		SELECT
			brng.transid,
			brng.productID AS SportType,
			brng.gameID AS BetType,
			brng.transdate,
			brng.winlostdate,
			brng.status,
			brng.statusID,
			brng.odds,
			brng.stake,
			brng.actual_stake,
			(brng.winlost - brng.actual_stake) AS WinLost,
			brng.comm,
			brng.playercomm,
			brng.ip,
			brng.transdesc,
			brng.TranId3rd AS BetCheck
		FROM DBARC.bodb_Archive.dbo.bettransRnG_bk AS brng WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON brng.gameID = sbt.Bettype
		WHERE brng.custid = @CustId AND brng.RefNo = @RefNo
	END

	-- get currency (for security)
	DECLARE @currency INT

	SELECT currencyID,
		LicenseeID 
	INTO #currency
	FROM dbo.Lrf_f_GetCurrencybyUser(@LicenseeId, @UserId, 1)	-- System is default=1 (LRF)

	SELECT @currency = c.currency
	FROM dbo.custinfo AS c WITH (NOLOCK)
		INNER JOIN #Currency AS cy ON c.Currency = cy.CurrencyID 
	WHERE c.custid = @custid

	DROP TABLE #Currency

	-- get from date - to date
	DECLARE @Fromdate DATETIME
	DECLARE @Todate DATETIME 

	SELECT @Fromdate = MIN(WinLostDate),
		@Todate = MAX(WinLostDate) 
	FROM @tmpBettransRnG

	SELECT 
		TransId,
		SportType,
		BetType,
		TransDate,
		WinLostDate,
		Status,
		StatusId,
		Odds,
		Stake,
		Actual_Stake,
		CAST(Stake * e.USD AS MONEY) AS StakeUSD,
		CAST(Stake * e.EUR AS MONEY) AS StakeEUR,
		CAST(Stake * e.MYR AS MONEY) AS StakeMYR,
		CAST(Stake * e.GBP AS MONEY) AS StakeGBP,
		WinLost,
		CAST(WinLost * e.USD AS MONEY) AS WinLostUSD,
		CAST(WinLost * e.EUR AS MONEY) AS WinLostEUR,
		CAST(WinLost * e.MYR AS MONEY) AS WinLostMYR,
		CAST(WinLost * e.GBP AS MONEY) AS WinLostGBP,
		Comm,
		CAST(Comm * e.USD AS MONEY) AS CommUSD,
		CAST(Comm * e.EUR AS MONEY) AS CommEUR,
		CAST(Comm * e.MYR AS MONEY) AS CommMYR,
		CAST(Comm * e.GBP AS MONEY) AS CommGBP,
		PlayerComm,
		CAST(PlayerComm * e.USD AS MONEY) AS PlayerCommUSD,
		CAST(PlayerComm * e.EUR AS MONEY) AS PlayerCommEUR,
		CAST(PlayerComm * e.MYR AS MONEY) AS PlayerCommMYR,
		CAST(PlayerComm * e.GBP AS MONEY) AS PlayerCommGBP,
		IP,
		TransDesc,
		BetCheck
	FROM @tmpBettransRnG AS b
		INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@FromDate, @ToDate)) AS e
			ON e.ExchangeDate = b.WinLostDate AND e.exchangeid = @currency

END


GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_RNG_Detail] TO [bodbAdminNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_RNG_Detail] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_RNG_Detail] TO [vnteam] AS [dbo]