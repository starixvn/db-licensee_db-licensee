/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_PlayerBettingStatistics]
	@CustID			INT,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@AgentList		VARCHAR(MAX)
AS
/*  Created: Walter  
	Date: 2019-09-04
    Task : Get Player Betting Statistics
    DB: DB052.bodb02  
   
    Revisions:
		- 20190903@Walter: Initialize SP [RedmineID: #112658]

	Param's Explanation:  
	  + @CustID: MemberId
	  + @MoveBetsDay: The day we move tickets to bettrans14
	  + @AgentList: xml structure
					  <ROOT>
					   <Agent AgentId="12345" Currency="3"/>  
					   <Agent AgentId="12345" Currency="5"/>  
					  </ROOT>
	Sample: 
	exec Lrf_PlayerBettingStatistics_xtest 
	@CustID=1026204,
	@FromDate='2019-08-01 00:00:00',
	@ToDate='2019-08-30 00:00:00',
	@MoveBetsDay='2019-08-15 00:00:00',
	@AgentList='<ROOT><Agent AgentId="1025646" Currency="67"/></ROOT>'
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @tempAgent          TABLE (agentId INT, Currency INT)

	DECLARE @tempStatus         TABLE (Won INT, Lose INT, Draw INT, Cancelled INT)

	CREATE TABLE #tempStatistics 
	(
		WinLost MONEY,
		ActualStake MONEY,
		Stake MONEY,
		StatusId TINYINT,
		BetCount INT
	)

	DECLARE @DocHandler     INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList
		INSERT INTO @tempAgent
		(agentId, currency)
	SELECT AgentId, Currency
	FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data
		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
				, ErrMsg = N'Paramter invalid.'
		RETURN
	END CATCH;

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

		INSERT INTO @tempStatus
		SELECT SUM(CASE WHEN b.statusID = 112 THEN 1 ELSE 0 END) AS Won,
			SUM(CASE WHEN b.statusID = 113 THEN 1 ELSE 0 END) AS Lose,
			SUM(CASE WHEN b.statusID = 111 THEN 1 ELSE 0 END) AS Draw,
			SUM(CASE WHEN b.statusID IN (101,102,103) THEN 1 ELSE 0 END) AS Cancelled
		FROM
			bettrans b WITH (NOLOCK)
			INNER JOIN @tempAgent a ON b.recommend = a.agentId AND b.currency = a.currency
		WHERE 
            custid = @CustID
			AND b.tpositiontaking <> 0
			AND b.winlostdate BETWEEN @TempFromDate AND @TDate
			AND (b.bettype < 901 OR b.bettype > 904) -- Exclude Cash out
			AND (b.bettype < 911 OR b.bettype > 914) -- Exclude BetTrade
			AND b.statusID IN (111,112,113,101,102,103) -- Draw/Won/Lose/Rejected/Void/Refund

		INSERT INTO #tempStatistics
		SELECT (b.winlost - b.actual_stake) as WinLost, b.actual_stake as ActualStake, b.stake as Stake, b.statusID as StatusId, 1 AS BetCount
		FROM
			bettrans b WITH (NOLOCK)
			INNER JOIN @tempAgent a ON b.recommend = a.agentId AND b.currency = a.currency
		WHERE 
            custid = @CustID
			AND b.tpositiontaking <> 0
			AND b.winlostdate BETWEEN @TempFromDate AND @TDate
			AND (b.bettype < 901 OR b.bettype > 904) -- Exclude Cash out
			AND (b.bettype < 911 OR b.bettype > 914) -- Exclude BetTrade
			AND b.statusID IN (111,112,113,101,102,103) -- Draw/Won/Lose/Rejected/Void/Refund
	END

	IF @FDate <= @MoveBetsDay 
	BEGIN
		IF @TDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @TDate

		INSERT INTO @tempStatus
		SELECT SUM(CASE WHEN b.statusID = 112 THEN 1 ELSE 0 END) AS Won,
			SUM(CASE WHEN b.statusID = 113 THEN 1 ELSE 0 END) AS Lose,
			SUM(CASE WHEN b.statusID = 111 THEN 1 ELSE 0 END) AS Draw,
			SUM(CASE WHEN b.statusID IN (101,102,103) THEN 1 ELSE 0 END) AS Cancelled
		FROM
			bodb_licenseereport.dbo.rptLicWinloss2 b WITH (NOLOCK)
			INNER JOIN @tempAgent a ON b.recommend = a.agentId AND b.Currency = a.Currency
		WHERE  
            custid = @CustID
			AND b.isBA = 0
			AND b.Winlostdate BETWEEN @FDate AND @TempToDate
			AND b.sporttype = 0
			AND (b.bettype < 901 OR b.bettype > 904) -- Exclude Cash out
			AND (b.bettype < 911 OR b.bettype > 914) -- Exclude BetTrade			
			AND b.statusID IN (111,112,113,101,102,103) -- Draw/Won/Lose/Rejected/Void/Refund

		INSERT INTO #tempStatistics
		SELECT b.winlost as WinLost, 0 as ActualStake, b.turnover as Stake, b.statusID as StatusId, b.BetCount
		FROM
			bodb_licenseereport.dbo.rptLicWinloss2 b WITH (NOLOCK)
			INNER JOIN @tempAgent a ON b.recommend = a.agentId AND b.Currency = a.Currency
		WHERE  
            custid = @CustID
			AND b.isBA = 0
			AND b.Winlostdate BETWEEN @FDate AND @TempToDate
			AND b.sporttype = 0
			AND (b.bettype < 901 OR b.bettype > 904) -- Exclude Cash out
			AND (b.bettype < 911 OR b.bettype > 914) -- Exclude BetTrade			
			AND b.statusID IN (111,112,113,101,102,103) -- Draw/Won/Lose/Rejected/Void/Refund
	END

	SELECT ISNULL(SUM(Won), 0) AS Won,
		ISNULL(SUM(Lose), 0) AS Lose,
		ISNULL(SUM(Draw), 0) AS Draw,
		ISNULL(SUM(Cancelled), 0) AS Cancelled
	FROM @tempStatus

	SELECT ISNULL(SUM(WinLost - ActualStake) / SUM(Stake), 0) AS Margin,
		ISNULL(SUM(Stake) / SUM(BetCount), 0) AS AverageBetSize,
		ISNULL(SUM(CASE WHEN StatusId = 112 THEN (WinLost - ActualStake) ELSE 0 END), 0) AS Winnings,
		ISNULL(SUM(CASE WHEN StatusId = 113 THEN (WinLost - ActualStake) ELSE 0 END), 0) AS Loss
	FROM #tempStatistics

	DROP TABLE #tempStatistics
END