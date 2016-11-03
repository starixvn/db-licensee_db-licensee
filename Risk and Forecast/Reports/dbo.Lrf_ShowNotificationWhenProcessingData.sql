USE [bodb02]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Lrf_ShowNotificationWhenProcessingData] @AvailableWinlostDate SMALLDATETIME OUTPUT
	, @EstimatedTime DATETIME = NULL OUTPUT
AS  
/* 
	Created: 20150908@Patrick
	Task: Show notification when processing data
	DB: DB052.bodb02
	Revision:   
		- 20160726@Francis: Revise SP to display notification during movebet process even though data is ready
		- 20161022@Jim:move table to bodb_licenseereport [RedmineID :#60449]
*/  
BEGIN  
	SET NOCOUNT ON  
	DECLARE @TotalDayMoveBetCompleted TINYINT, @TotalDayMoveBet TINYINT
	        , @EstimatedTimeForMoveBet SMALLINT, @EstimatedTimeForGenReport SMALLINT
	        , @StartMoveBetTime DATETIME, @Tomorrow DATETIME, @Today DATETIME

	--DECLARE @MoveBetDayTable TABLE (BalanceUpDay SMALLDATETIME, MoveBetDay SMALLDATETIME)
	--INSERT INTO @MoveBetDayTable(BalanceUpDay, MoveBetDay)
	--EXEC dbo.Lrf_SelBalanceUpDay

	--SELECT @MoveBetDay = MoveBetDay
	--FROM @MoveBetDayTable

	SELECT @EstimatedTimeForMoveBet = 45 --45 minutes
		, @EstimatedTimeForGenReport = 10 --10 minutes
		, @Tomorrow = DATEADD(dd, 1, CAST(GETDATE() AS DATE))
		, @Today = CAST(GETDATE() AS DATE)
		, @StartMoveBetTime = NULL
		
	SELECT @AvailableWinlostDate = MAX(Winlostdate) 
	FROM bodb_licenseereport.dbo.rptLicWinloss2 WITH (NOLOCK)

	DECLARE @MoveBetSchedule TABLE(ScheduleId TINYINT, MoveBetDay SMALLDATETIME)
	
	INSERT INTO @MoveBetSchedule(ScheduleId, MoveBetDay)
	EXEC DBTXN.bodb02.dbo.Task_MoveBetsDayByScheduleSel

	SELECT @TotalDayMoveBet = ISNULL(COUNT(1),0)
	FROM @MoveBetSchedule
	
	IF @TotalDayMoveBet = 0 BEGIN PRINT 'no movebet today' RETURN END--no movebet today
	
	SELECT @TotalDayMoveBetCompleted = ISNULL(COUNT(1),0)
	FROM DBACC.bodb02.dbo.userlog WITH(NOLOCK)
	WHERE userid = 25520 AND doing = 'Task_DailySummary : End (with Finish)'
		AND logdate > @Today AND logdate < @Tomorrow
	
	IF @TotalDayMoveBetCompleted = @TotalDayMoveBet BEGIN PRINT 'movebet has been finished' RETURN END --movebet has been finished
	
	--get latest start time of movebet
	SELECT TOP 1 @StartMoveBetTime = logdate
	FROM DBACC.bodb02.dbo.userlog WITH(NOLOCK)
	WHERE userid = 25520 AND doing LIKE 'Task_DailySummary : MoveBet start%'
		  AND logdate > @Today AND logdate < @Tomorrow
	ORDER BY logid DESC
	
	IF @StartMoveBetTime IS NULL BEGIN PRINT 'move bet has not been started yet' RETURN END --move bet has not been started yet
	
	SELECT @EstimatedTime = DATEADD(mi,((@TotalDayMoveBet-@TotalDayMoveBetCompleted) * @EstimatedTimeForMoveBet
										 + (@TotalDayMoveBet * @EstimatedTimeForGenReport)), @StartMoveBetTime)
	
	/*
	SELECT TOP 1 @EndMoveBetTime = logdate
	FROM DBACC.bodb02.dbo.userlog WITH(NOLOCK)
	WHERE userid = 25520 AND doing = 'Task_DailySummary : End (with Finish)'
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
	*/

	IF @EstimatedTime IS NOT NULL AND @EstimatedTime < GETDATE() --incase estimation is incorrect
		SET @EstimatedTime = DATEADD(mi, 5, GETDATE())

END
GO
GRANT EXECUTE ON [dbo].[Lrf_ShowNotificationWhenProcessingData] TO [bodbDownlineNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Lrf_ShowNotificationWhenProcessingData] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_ShowNotificationWhenProcessingData] TO [vnteam] AS [dbo]