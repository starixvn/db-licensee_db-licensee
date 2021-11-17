ALTER PROCEDURE [dbo].[Acc_Rpt_BAWinloss]  
 @Currency		INT = 0,
 @FromDate		SMALLDATETIME,  
 @ToDate		SMALLDATETIME,   
 @MoveBetsDay SMALLDATETIME,
 @ReportType	TINYINT=1,  
 @drawfilter SMALLINT = 1 
AS  
/*  Created: Henry  
	Date: 2012-07-13
    Task : BA Winloss Report 
    DB: bodb_MoveBet 
   
    Revisions:  
		- 20120718@Henry: turn INH to VND
	
	Param's Explanation:  
	  + @ReportType: 1-Daily; 2-Monthly;  
	  +	@drawfilter: 'No Draw' filter is supportted (1:Normal 2:No Draw 3:No Draw for Turnover only)
*/  
BEGIN  
	SET NOCOUNT ON  

	DECLARE @TempFromDate SMALLDATETIME  
	DECLARE @TempToDate SMALLDATETIME 
	

	CREATE TABLE #tmp(  
		winlostdate		DATETIME,  
		Currency		INT,
		TurnOver		MONEY,   	
		Winlost			MONEY,  
		Betcount BIGINT
	
	)  
	
	CREATE TABLE #TempExchange
	(
		ExchangeDate SMALLDATETIME,
		ExchangeId	INT,
		Code VARCHAR(10),
		EUR float,
	)
	
	IF @Todate > @MoveBetsDay  
	--get FROM bettrans  
	BEGIN  
		IF @FromDate <= @MoveBetsDay   
			SET @TempFromDate =  DATEADD(DAY,1,@MoveBetsDay)  
		ELSE  
			SET @TempFromDate = @FromDate  
			
		INSERT INTO #tmp
		SELECT   
			b.winlostdate,
			b.Currency,
			SUM( stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
					ELSE 1 END
				ELSE 1 END
			) turnover,
			SUM(b.winlost - b.actual_stake) AS Winlost,
			COUNT(b.transid)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			   BetCount		
		FROM dbo.bettrans b WITH (NOLOCK)   
		WHERE 
			b.winlostdate BETWEEN @TempFromDate AND @Todate AND
			b.ruben=1 AND   
			b.statusID NOT IN (101, 102, 103) AND
			(@Currency = 0 OR  (@Currency <> 0 AND b.Currency = @Currency))
		GROUP BY   
			b.winlostdate,b.currency,b.statusID
	END		

	IF @FromDate <= @MoveBetsDay 
	BEGIN
		IF @ToDate >= @MoveBetsDay
				SET @TempToDate = @MoveBetsDay
			ELSE
				SET  @TempToDate = @ToDate
				
		INSERT INTO #tmp
		SELECT   
			b.winlostdate,
			b.currency,
			SUM(b.turnover
			*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111  THEN 0
					WHEN b.statusID IN (114,115) THEN 0.5
					ELSE 1 END
				ELSE 1 END
			),  
			sum(b.winlost) AS Winlost,
			SUM(b.betcount)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END	
			
		FROM rptLicWinloss b WITH ( NOLOCK )  
		WHERE 
			b.winlostdate BETWEEN @FromDate AND @TempToDate AND 
			b.roleid = 2 AND
			b.statusID <> 101 AND --exclude REJECT bets
			(@Currency = 0 OR  (@Currency <> 0 AND b.Currency = @Currency))
		GROUP BY   
			b.winlostdate,b.currency,b.statusID	
	END

	CREATE NONCLUSTERED INDEX IDX_Index ON #tmp(Currency)

	--remove currency test
	DELETE FROM #tmp WHERE Currency = 20


	INSERT INTO #TempExchange (ExchangeDate,ExchangeId,Code,EUR)
	SELECT ExchangeDate,ExchangeId,Code,EUR FROM Lrf_f_GetExchangeDaily(@FromDate,@ToDate)
	WHERE exchangeid IN (SELECT DISTINCT Currency FROM #tmp)

	SELECT 
		--b.winlostdate,
		CASE
			WHEN @ReportType = 1 THEN CONVERT(VARCHAR(8),b.winlostdate,112)  
			WHEN @ReportType = 2 THEN CONVERT(VARCHAR(6),b.winlostdate,112) 
		END ReportType,
		b.currency,
		e.Code AS CurrencyName,
		sum(b.Turnover) AS Turnover,
		sum(b.winlost) AS Winlost,
		sum(b.betcount) AS BetCount,
			
		sum(b.Turnover * e.EUR) AS TurnoverEUR,
		sum(b.winlost * e.EUR) AS WinlostEUR
		
	FROM #tmp b 
		INNER JOIN #TempExchange e 
		ON b.Winlostdate = e.ExchangeDate AND b.currency = e.ExchangeId
	GROUP BY 
			CASE
				WHEN @ReportType = 1 THEN CONVERT(VARCHAR(8),b.winlostdate,112)  
				WHEN @ReportType = 2 THEN CONVERT(VARCHAR(6),b.winlostdate,112) 
			END
			,b.currency,e.Code
	ORDER BY 
			CASE
				WHEN @ReportType = 1 THEN CONVERT(VARCHAR(8),b.winlostdate,112)  
				WHEN @ReportType = 2 THEN CONVERT(VARCHAR(6),b.winlostdate,112) 
			END DESC
			,e.Code
	
	DROP TABLE #tmp

	DROP TABLE #TempExchange

END   
GO
GRANT EXECUTE ON [dbo].[Acc_Rpt_BAWinloss] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_Rpt_BAWinloss] TO [vnteam]   