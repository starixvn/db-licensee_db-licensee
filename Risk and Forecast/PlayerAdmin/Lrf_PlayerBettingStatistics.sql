/*<info serverAlias="DBACC-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_PlayerBettingStatistics]
	@CustId			INT,
	@ProductList	VARCHAR(500),
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME
AS

/*
	Created: Walter
	Date: 2019-09-04
	Task: Get Player Betting Statistics
	DB: DBACC.bodb02

	Revisions:
		- 20190903@Walter: Initialize SP [RedmineID: #112658]
		- 20190930@Amanda: Get data from bettrans instead sum table [RedmineID: #112658]
		- 20200508@Vickie: Add new bet types for E-Sports 2.0 [RedmineID: #132548]
		- 20201006@Kos: Fix issue divide by zero [RedmineID: #143061]
		- 20210330@Hogan: Integrate Cricket AIO [RedmineID: #150386]
		- 20211109@Kos: Merge Sports Lottery into Sportsbook [RedmineID: #163191]
					- Add new param @ProductList VARCHAR(500)
		- 20220406@Hogan: Exclude Draw/Void/Reject/Refund tickets from Margin value [RedmineID: #167871]
		- 20250122@Kelvin: Drop BA functions [RedmineID: #216882]


	Param's Explanation:
		+ @ProductList: SB and all products grouped under SB (SB,SLT,...)

	Sample: exec Lrf_PlayerBettingStatistics_xtest
				@CustID=1026204,
				@ProductList='SB,SLT',
				@FromDate='2019-09-01 00:00:00',
				@ToDate='2019-09-30 00:00:00',
				@MoveBetsDay='2019-09-20 00:00:00',
				@BalanceUpDay='2019-09-21 00:00:00'
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @BetType TABLE (BetType INT PRIMARY KEY, ProductCode VARCHAR(10))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @BetType (BetType, ProductCode)
	SELECT DISTINCT BetType, ProductPrefix
	FROM f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', @ProductList, @IsTest)
	WHERE BetType NOT IN (901, 902, 903, 904, 911, 912, 913, 914)

	CREATE TABLE #tempStatistics
	(
		WinLost		MONEY,
		Stake		MONEY,
		StatusId	TINYINT,
		HalfWL		BIT
	)

	DECLARE @TempFromDate	SMALLDATETIME,
		@TempToDate		SMALLDATETIME,
		@FDate			SMALLDATETIME,
		@TDate			SMALLDATETIME

	--to Deal With Parameter Sniffing
	SELECT @FDate = @FromDate, @TDate = @ToDate

	IF @TDate > @MoveBetsDay
	BEGIN
		IF @FDate <= @MoveBetsDay 
			SET @TempFromDate =  DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FDate

		INSERT INTO #tempStatistics
		SELECT
			(b.winlost - b.actual_stake) AS WinLost,
			b.stake,
			b.statusID,
			CASE WHEN b.statusID IN (112, 113) THEN
				CASE
					WHEN ABS(b.modds) = 0.25 AND b.bettype NOT IN (29,38) THEN 1
					ELSE 0
				END
			ELSE 0 END AS HalfWL
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @BetType AS bt ON bt.BetType = b.bettype
		WHERE
			b.custid = @CustId
			AND b.winlostdate BETWEEN @TempFromDate AND @TDate
			AND b.statusID IN (111, 112, 113, 101, 102, 103) -- Draw/Won/Lose/Rejected/Void/Refund
	END

	IF @FDate <= @MoveBetsDay AND @TDate >= @BalanceUpDay
	BEGIN
		IF @TDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @TDate

		IF @FDate < @BalanceUpDay
			SET @TempFromDate = @BalanceUpDay
		ELSE
			SET @TempFromDate = @FDate

		INSERT INTO #tempStatistics
		SELECT
			(b.winlost - b.actual_stake) AS WinLost,
			b.stake,
			b.statusID,
			CASE WHEN b.statusID IN (112, 113) THEN
				CASE
					WHEN ABS(b.modds) = 0.25 AND b.bettype NOT IN (29,38) THEN 1
					ELSE 0
				END
			ELSE 0 END AS HalfWL
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN @BetType AS bt ON bt.BetType = b.bettype
		WHERE
			b.custid = @CustId
			AND b.winlostdate BETWEEN @TempFromDate AND @TempToDate
	END

	IF @FDate < @BalanceUpDay
	BEGIN
		IF @TDate >= DATEADD(dd, -1, @BalanceUpDay)
			SET @TempToDate = DATEADD(dd, -1, @BalanceUpDay)
		ELSE
			SET @TempToDate = @TDate

		INSERT INTO #tempStatistics
		SELECT
			(b.winlost - b.actual_stake) AS WinLost,
			b.stake,
			b.statusID,
			CASE WHEN b.statusID IN (112, 113) THEN
				CASE
					WHEN ABS(b.modds) = 0.25 AND b.bettype NOT IN (29,38) THEN 1
					ELSE 0
				END
			ELSE 0 END AS HalfWL
		FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX = IX_custId)
			INNER JOIN @BetType AS bt ON bt.BetType = b.bettype
		WHERE
			b.custid = @CustID
			AND b.winlostdate BETWEEN @FDate AND @TempToDate
	END

	SELECT ISNULL(SUM(CASE WHEN StatusId = 112 THEN 1 ELSE 0 END), 0) AS Won,
		ISNULL(SUM(CASE WHEN StatusId = 113 THEN 1 ELSE 0 END), 0) AS Lose,
		ISNULL(SUM(CASE WHEN StatusId = 111 THEN 1 ELSE 0 END), 0) AS Draw,
		ISNULL(SUM(CASE WHEN StatusId IN (101, 102, 103) THEN 1 ELSE 0 END), 0) AS Cancelled
	FROM #tempStatistics

	SELECT ISNULL(SUM(CASE WHEN StatusId IN (112,113) THEN WinLost ELSE 0 END) / NULLIF(SUM(CASE WHEN StatusId IN (112,113) AND HalfWL = 0 THEN Stake WHEN HalfWL = 1 THEN Stake/2 ELSE 0 END), 0), 0) AS Margin,
		ISNULL(SUM(Stake) / SUM(1), 0) AS AverageBetSize,
		ISNULL(SUM(CASE WHEN StatusId = 112 THEN WinLost ELSE 0 END), 0) AS Winnings,
		ISNULL(SUM(CASE WHEN StatusId = 113 THEN WinLost ELSE 0 END), 0) AS Loss
	FROM #tempStatistics

	DROP TABLE #tempStatistics
END
GO
