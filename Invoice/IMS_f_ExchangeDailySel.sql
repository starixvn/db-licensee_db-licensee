USE [bodb02]
GO

CREATE FUNCTION [dbo].[IMS_f_ExchangeDailySel] (@fromdate DATETIME
	, @todate DATETIME
)
	
/*  
	Created: Kevin
	Date: 20130418
	Task : Report - Licensee Settlement Report
	DB: DB052.bodb02
	Revisions:  
		20150202@Patrick: Add more GBP currency

	Param's Explanation:  			
*/
RETURNS @tempDate TABLE (exchangedate DATETIME, ExchangeId INT, Code VARCHAR(5)
		, MYR FLOAT, USD FLOAT, EUR FLOAT, CNY FLOAT, GBP FLOAT
		, actualrate FLOAT, UNIQUE CLUSTERED(exchangedate, exchangeid))
AS 
BEGIN
	DECLARE @tmpFromDate DATETIME, @tmpToDate DATETIME, @maxExchangeDate DATETIME
		, @tmpDate DATETIME, @gapDate DATETIME, @i INT

	SELECT @maxExchangeDate = MAX(exchangedate) 
	FROM dbo.ExchangeDailyOanda (NOLOCK)

	SELECT @tmpFromDate = @fromdate, @i = 0
	WHILE (DATEDIFF (m, @tmpFromDate, @todate) >= 0)
	BEGIN
		IF @i = 1
		BEGIN
			SET @tmpFromDate = CAST(CONVERT(VARCHAR(10), DATEADD(dd, -(DAY(@tmpFromDate) -1), @tmpFromDate), 111) AS DATETIME)
		END

		SET @tmpToDate = CAST(CONVERT(VARCHAR(10), DATEADD(s, -1, DATEADD(mm, DATEDIFF(m, 0, @tmpFromDate) +1, 0)), 111) AS DATETIME)

		IF @tmpToDate > @maxExchangeDate
		BEGIN
			SET @tmpToDate = @maxExchangeDate
		END

		SET @tmpDate = @tmpFromDate
		WHILE (@tmpDate <= @tmpToDate AND @tmpDate <= @todate)
		BEGIN
			INSERT INTO @tempDate (exchangedate, ExchangeId, Code, MYR, USD, EUR, CNY, GBP, actualrate)
			SELECT @tmpDate,ExchangeId,Code,MYR, USD, EUR, CNY, GBP, actualrate
			FROM dbo.ExchangeDailyOanda WITH (NOLOCK)
			WHERE ExchangeDate = @tmpToDate
	
			SET @tmpDate = DATEADD(dd, 1, @tmpDate)
		END

		SET @i = @i + 1
		SET @tmpFromDate = DATEADD(m, 1, @tmpFromDate)
	END
RETURN 
END



GO


