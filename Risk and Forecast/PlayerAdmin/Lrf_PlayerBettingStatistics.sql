/*<info serverAlias="DBACC-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Lrf_PlayerBettingStatistics]
	@CustID			INT,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME
AS
/*  Created: Walter  
	Date: 2019-09-04
    Task : Get Player Betting Statistics
    DB: DBACC-bodb02  
   
    Revisions:
		- 20190903@Walter: Initialize SP [RedmineID: #112658]
		- 20190930@Amanda: Get data from bettrans instead sum table [RedmineID: #112658]

	Param's Explanation:  
	  + @CustID: MemberId
	  + @MoveBetsDay: The day we move tickets to bettrans14
	  + @BalanceUpDay: archive tickets day

	Sample: 
	exec Lrf_PlayerBettingStatistics_xtest 
	@CustID=1026204,
	@FromDate='2019-09-01 00:00:00',
	@ToDate='2019-09-30 00:00:00',
	@MoveBetsDay='2019-09-20 00:00:00',
	@BalanceUpDay='2019-09-21 00:00:00'
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tempStatistics 
	(
		WinLost MONEY,
		Stake MONEY,
		StatusId TINYINT
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
		SELECT (b.winlost - b.actual_stake) as WinLost, b.stake as Stake, b.statusID as StatusId
		FROM
			bodb02.dbo.bettrans b WITH (NOLOCK)
		WHERE 
            custid = @CustID
            AND b.winlostdate BETWEEN @TempFromDate AND @TDate
            AND  
				(
					b.bettype <= 30
					OR b.bettype BETWEEN 121 AND 999
					OR b.Bettype BETWEEN 1301 and 1399 --new tennis's bettypes
					OR b.Bettype BETWEEN 9001 and 9086 -- E-Sports 2.0
					OR b.bettype = 38 -- bet builder
				)
			AND (b.bettype < 901 OR b.bettype > 904)
			AND (b.bettype < 911 OR b.bettype > 914)
			AND b.statusID IN (111,112,113,101,102,103) -- Draw/Won/Lose/Rejected/Void/Refund
			AND NOT EXISTS (SELECT 1 FROM bodb_licensee.dbo.LicenseeBATransaction_active ba WHERE ba.TransID = b.transid)
	END

	IF @FDate <= @MoveBetsDay AND @TDate > @BalanceUpDay
	BEGIN
		IF @TDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @TDate
			
		IF @FDate <= @BalanceUpDay
			SET @TempFromDate = DATEADD(DAY, 1, @BalanceUpDay)
		ELSE
			SET @TempFromDate = @FDate

		INSERT INTO #tempStatistics
		SELECT (b.winlost - b.actual_stake) as WinLost, b.stake as Stake, b.statusID as StatusId
		FROM
			bodb02.dbo.bettrans14 b WITH (NOLOCK)
		WHERE 
            custid = @CustID
			AND b.winlostdate BETWEEN @TempFromDate AND @TempToDate
			AND  
				(
					b.bettype <= 30
					OR b.bettype BETWEEN 121 AND 999
					OR b.Bettype BETWEEN 1301 and 1399 --new tennis's bettypes
					OR b.Bettype BETWEEN 9001 and 9086 -- E-Sports 2.0
					OR b.bettype = 38 -- bet builder
				)
			AND (b.bettype < 901 OR b.bettype > 904)
			AND (b.bettype < 911 OR b.bettype > 914)
			AND b.statusID IN (111,112,113,101,102,103) -- Draw/Won/Lose/Rejected/Void/Refund
			AND NOT EXISTS (SELECT 1 FROM bodb_licensee.dbo.LicenseeBATransaction_bk ba WHERE ba.TransID = b.transid)
	END
	
	IF @FDate <= @BalanceUpDay
	BEGIN
		IF @TDate >= @BalanceUpDay
			SET @TempToDate = @BalanceUpDay
		ELSE
			SET @TempToDate = @TDate

		INSERT INTO #tempStatistics
		SELECT (b.winlost - b.actual_stake) as WinLost, b.stake as Stake, b.statusID as StatusId
		FROM
			bodb_Archive.dbo.bettrans_bk b WITH (NOLOCK, INDEX = IX_custId)
		WHERE
            custid = @CustID			
			AND b.winlostdate BETWEEN @FDate AND @TempToDate
			AND  
				(
					b.bettype <= 30
					OR b.bettype BETWEEN 121 AND 999
					OR b.Bettype BETWEEN 1301 and 1399 --new tennis's bettypes
					OR b.Bettype BETWEEN 9001 and 9086 -- E-Sports 2.0
					OR b.bettype = 38 -- bet builder
				)
			AND (b.bettype < 901 OR b.bettype > 904)
			AND (b.bettype < 911 OR b.bettype > 914)
			AND b.statusID IN (111,112,113,101,102,103) -- Draw/Won/Lose/Rejected/Void/Refund
			AND NOT EXISTS (SELECT 1 FROM bodb_licensee.dbo.LicenseeBATransaction_bk ba WHERE ba.TransID = b.transid)
	END

	SELECT SUM(CASE WHEN StatusId = 112 THEN 1 ELSE 0 END) AS Won,
		 SUM(CASE WHEN StatusId = 113 THEN 1 ELSE 0 END) AS Lose,
		 SUM(CASE WHEN StatusId = 111 THEN 1 ELSE 0 END) AS Draw,
		 SUM(CASE WHEN StatusId IN (101, 102, 103) THEN 1 ELSE 0 END) AS Cancelled
	FROM #tempStatistics

	SELECT ISNULL(SUM(WinLost) / SUM(Stake), 0) AS Margin,
		ISNULL(SUM(Stake) / SUM(1), 0) AS AverageBetSize,
		ISNULL(SUM(CASE WHEN StatusId = 112 THEN WinLost ELSE 0 END), 0) AS Winnings,
		ISNULL(SUM(CASE WHEN StatusId = 113 THEN WinLost ELSE 0 END), 0) AS Loss
	FROM #tempStatistics

	DROP TABLE #tempStatistics
END