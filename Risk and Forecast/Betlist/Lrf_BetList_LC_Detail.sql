USE [bodb02]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Lrf_BetList_LC_Detail]
	@LicenseeId		INT,
	@UserId			INT,
	@CustId			INT,
	@RefNo			BIGINT,
	@TransType		TINYINT			= 0,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME
AS

/*
	Created: Kos@20150923
	Task : Get ticket detail from table betransLC (AG Casino)
	DB: DBEXT.bodb02
	Original:
	Revisions:
	Parameters:
		- @TransType
			+ 0 : All (DRAW/WON/LOSE/Reject/Void/Refund/Running/Waiting)
			+ 1 : DRAW/WON/LOSE/Refund
			+ 2 : Reject/Void
			+ 3 : Running/Waiting
*/

BEGIN
	SET NOCOUNT ON

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
		INSERT INTO @tmpStatus(statusId)
		SELECT 0 UNION ALL 
		SELECT 1
	END

	DECLARE @tmpBettransLC TABLE (
		TransId			BIGINT,
		SportType		SMALLINT,
		BetType			SMALLINT,
		TransDate		DATETIME,
		WinLostDate		SMALLDATETIME,
		Status			VARCHAR(10),
		StatusId		TINYINT,
		Odds			SMALLMONEY,
		Stake			MONEY,
		Actual_Stake	MONEY,
		WinLost			MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		IP				NVARCHAR(15),
		TransDesc		NVARCHAR(1000)
	)

	IF EXISTS ( SELECT 1 FROM dbo.bettrans WITH (NOLOCK) WHERE transid = @RefNo )
	BEGIN
		INSERT INTO @tmpBettransLC
		SELECT
			blc.transid,
			blc.productID AS SportType,
			blc.gameID AS BetType,
			blc.transdate,
			blc.winlostdate,
			blc.status,
			blc.statusID,
			blc.odds,
			blc.stake,
			blc.actual_stake,
			(blc.winlost - blc.actual_stake) AS WinLost,
			blc.comm,
			blc.playercomm,
			blc.ip,
			blc.transdesc
		FROM dbo.bettransLC AS blc WITH (NOLOCK)
		WHERE blc.custid = @CustId 
			AND blc.RefNo = @RefNo
			AND blc.statusID IN (SELECT statusId FROM @tmpStatus)
	END
	ELSE IF EXISTS ( SELECT 1 FROM dbo.bettrans14 WITH (NOLOCK) WHERE transid = @RefNo )
	BEGIN
		INSERT INTO @tmpBettransLC
		SELECT
			blc.transid,
			blc.productID AS SportType,
			blc.gameID AS BetType,
			blc.transdate,
			blc.winlostdate,
			blc.status,
			blc.statusID,
			blc.odds,
			blc.stake,
			blc.actual_stake,
			(blc.winlost - blc.actual_stake) AS WinLost,
			blc.comm,
			blc.playercomm,
			blc.ip,
			blc.transdesc
		FROM dbo.bettransLC14 AS blc WITH (NOLOCK)
		WHERE blc.custid = @CustId AND blc.RefNo = @RefNo
	END
	ELSE IF EXISTS ( SELECT 1 FROM DBARC.bodb_Archive.dbo.bettrans_bk WITH (NOLOCK) WHERE transid = @RefNo )
	BEGIN
		INSERT INTO @tmpBettransLC
		SELECT
			blc.transid,
			blc.productID AS SportType,
			blc.gameID AS BetType,
			blc.transdate,
			blc.winlostdate,
			blc.status,
			blc.statusID,
			blc.odds,
			blc.stake,
			blc.actual_stake,
			(blc.winlost - blc.actual_stake) AS WinLost,
			blc.comm,
			blc.playercomm,
			blc.ip,
			blc.transdesc
		FROM DBARC.bodb_Archive.dbo.bettransLC_bk AS blc WITH (NOLOCK)
		WHERE blc.custid = @CustId AND blc.RefNo = @RefNo
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
	FROM @tmpBettransLC

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
		TransDesc
	FROM @tmpBettransLC AS b
		INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@FromDate, @ToDate)) AS e
			ON e.ExchangeDate = b.WinLostDate AND e.exchangeid = @currency

END

GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_LC_Detail] TO [bodbAdminNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_LC_Detail] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_LC_Detail] TO [vnteam] AS [dbo]