USE bodb02
GO
ALTER PROCEDURE dbo.Lrf_ShowNotificationWhenProcessingData @AvailableWinlostDate SMALLDATETIME OUTPUT
	, @EstimatedTime DATETIME = NULL OUTPUT
AS  
/* 
	Created: 20150908@Patrick
	Task: Show notification when processing data
	DB: DB052.bodb02
	Revision:   
  
*/  
BEGIN  
	SET NOCOUNT ON  
	DECLARE @MoveBetDay SMALLDATETIME, @MaxWinlostDate SMALLDATETIME, @EndMoveBetTime DATETIME
		, @StartMoveBetTime DATETIME, @TotalDays TINYINT, @EstimatedTimeForMoveBet SMALLINT
		, @EstimatedTimeForGenReport SMALLINT, @Today DATETIME

	SELECT @EstimatedTimeForMoveBet = 45 --45 minutes
		, @EstimatedTimeForGenReport = 15 --15 minutes
		, @Today = GETDATE()

	DECLARE @MoveBetDayTable TABLE (BalanceUpDay SMALLDATETIME, MoveBetDay SMALLDATETIME)
	DECLARE @MoveBetSchedule TABLE(ScheduleId TINYINT, MoveBetDay SMALLDATETIME)

	INSERT INTO @MoveBetDayTable(BalanceUpDay, MoveBetDay)
	EXEC dbo.Lrf_SelBalanceUpDay

	SELECT @MoveBetDay = MoveBetDay
	FROM @MoveBetDayTable
	
	SELECT @MaxWinlostDate = MAX(Winlostdate) 
	FROM bodb_Licensee.dbo.rptLicWinloss2 WITH (NOLOCK)

	SET @AvailableWinlostDate =  @MaxWinlostDate

	INSERT INTO @MoveBetSchedule(ScheduleId, MoveBetDay)
	EXEC DBTXN.bodb02.dbo.Task_MoveBetsDayByScheduleSel

	SELECT @TotalDays = COUNT(1)
	FROM @MoveBetSchedule
	IF ISNULL(@TotalDays, 0) = 0 --no move bet on that day
	BEGIN
		RETURN
	END

	--SELECT @TotalDays as '@TotalDays'

	SELECT TOP 1 @EndMoveBetTime = logdate
	FROM DBACC.bodb02.dbo.userlog WITH(NOLOCK)
	WHERE userid = 25520 AND doing = 'Task_DailySummary : End (with Finish)'
	ORDER BY logid DESC
	
	SELECT TOP 1 @StartMoveBetTime = logdate
	FROM DBACC.bodb02.dbo.userlog WITH(NOLOCK)
	WHERE userid = 25520 AND doing = 'Task_DailySummary : MoveBet start'
	ORDER BY logid DESC
	
	IF @MaxWinlostDate < @MoveBetDay--movebet is running + generate data does not running
	BEGIN
		IF CAST(@EndMoveBetTime AS DATE) = CAST(@Today AS DATE) --totalmovebetdays > 1 & completed a part
			SELECT @EstimatedTime = DATEADD(mi, ((@TotalDays * @EstimatedTimeForGenReport) + ((@TotalDays - 1) * @EstimatedTimeForMoveBet)), @StartMoveBetTime)
		ELSE
			SELECT @EstimatedTime = DATEADD(mi, (@TotalDays * (@EstimatedTimeForGenReport + @EstimatedTimeForMoveBet)), @StartMoveBetTime)
	END
	ELSE IF @MaxWinlostDate = @MoveBetDay --AND CAST(@StartMoveBetTime AS DATE) = CAST(@Today AS DATE)
		AND DATEDIFF(mi, @EndMoveBetTime, GETDATE()) < (@TotalDays * @EstimatedTimeForGenReport + ((@TotalDays - 1) * @EstimatedTimeForMoveBet)) 
		--recently movebet done & report is doing generation
	BEGIN
		IF CAST(@EndMoveBetTime AS DATE) = CAST(@Today AS DATE)
			SELECT @EstimatedTime = DATEADD(mi, ((@TotalDays * @EstimatedTimeForGenReport) + ((@TotalDays - 1) * @EstimatedTimeForMoveBet)), @StartMoveBetTime)
		ELSE
			SELECT @EstimatedTime = DATEADD(mi, (@TotalDays * (@EstimatedTimeForGenReport + @EstimatedTimeForMoveBet)), @StartMoveBetTime)

		SET @AvailableWinlostDate = DATEADD(DD, -1, @MaxWinlostDate)
	END

	IF @EstimatedTime IS NOT NULL AND @EstimatedTime < GETDATE() --incase estimation incorrect
		SET @EstimatedTime = DATEADD(mi, 5, GETDATE())

END
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_ShowNotificationWhenProcessingData] TO [vnteam]
GO 
GRANT EXECUTE ON [dbo].[Lrf_ShowNotificationWhenProcessingData] TO [bodbLicenseeNet]
GO 
GRANT EXECUTE ON [dbo].[Lrf_ShowNotificationWhenProcessingData] TO [bodbDownlineNet]
GO 
