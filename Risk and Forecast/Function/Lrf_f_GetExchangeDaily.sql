USE [bodb02]
GO

SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  User Defined Function dbo.Lrf_f_GetExchangeDaily    Script Date: 9/23/2016 10:19:23 AM ******/
ALTER FUNCTION [dbo].[Lrf_f_GetExchangeDaily]
    (
      @fromdate DATETIME,
      @todate DATETIME
      
    )
RETURNS @tempDate TABLE (exchangedate DATETIME,ExchangeId INT,Code VARCHAR(5),MYR FLOAT, USD FLOAT, EUR FLOAT, CNY FLOAT,GBP FLOAT,HKD FLOAT,THB FLOAT,IDR FLOAT, actualrate FLOAT, UNIQUE CLUSTERED(exchangedate,exchangeid))
AS

 /*
	Created: 20120209@Henry
	Task : Get exchange daily for LRF reports. The values are the same in 1 month
	DB: DB052.bodb02, DB06.bodb02
	Revisions:	
	- 20120608@Henry: If the date range smaller than 1st of June 2012 then get from ExchangeDaily else get from ExchangeDailyOanda
	- 20150123@Jim: return base on GBP
	- 20160425@Francis: return rates of the latest day that has full ExchangeRate in ExchangeDailyOanda table in case current date's rates are missing
	- 20160914@Jim:  Add HKD base currency into OANDA Exchange rate [RedmineID : #63975]
	- 20170613@Paul: return THB, IDR rates [RedmineID: #75030]
*/
BEGIN

DECLARE @tmpFromDate DATETIME, @tmpToDate DATETIME, @maxExchangeDate DATETIME, @tmpDate DATETIME, @gapDate DATETIME, @ReferencedExchangeDate DATETIME
DECLARE @i INT

SET @gapDate = '2012-06-01'

--Get the data before 1st of June 2012 in ExchangeDaily table
IF @todate < @gapDate
BEGIN
	INSERT INTO @tempDate (exchangedate,ExchangeId,Code,MYR, USD, EUR, CNY, GBP, HKD, THB, IDR, actualrate)
	SELECT exchangedate,ExchangeId,Code,MYR, USD, EUR, CNY, 1 AS GBP, 1 AS HKD, 1 AS THB, 1 AS IDR, actualrate
	FROM ExchangeDaily WITH (NOLOCK)
	WHERE ExchangeDate BETWEEN @fromdate AND @todate
	
	RETURN
END
ELSE IF @todate >= @gapDate AND @fromdate < @gapDate
BEGIN
	INSERT INTO @tempDate (exchangedate,ExchangeId,Code,MYR, USD, EUR, CNY, GBP, HKD, THB, IDR, actualrate)
	SELECT exchangedate,ExchangeId,Code,MYR, USD, EUR, CNY, 1 AS GBP, 1 AS HKD, 1 AS THB, 1 AS IDR, actualrate
	FROM ExchangeDaily WITH (NOLOCK)
	WHERE ExchangeDate BETWEEN @fromdate AND dateadd(day,-1,@gapDate)
	
	SET @fromdate = @gapDate
END

--Get the data after 1st of June 2012 in ExchangeDailyOanda
--Get the Referenced Exchange Date
SELECT @maxExchangeDate=MAX(exchangedate) FROM ExchangeDailyOanda WITH (NOLOCK)
SELECT @ReferencedExchangeDate = (SELECT a.ExchangeDate FROM (SELECT TOP 1 ExchangeDate, COUNT (1) AS ExchangeCount
				FROM ExchangeDailyOanda WITH (NOLOCK)
				WHERE ExchangeDate BETWEEN CAST(CONVERT(VARCHAR(10),DATEADD(dd,-(DAY(@maxExchangeDate)-1),@maxExchangeDate),111) AS SMALLDATETIME)
									AND CAST(CONVERT(VARCHAR(10),@maxExchangeDate,111) AS SMALLDATETIME)
				GROUP BY ExchangeDate
				ORDER BY 2 DESC, 1 DESC) a )


SET @tmpFromDate = @fromdate
SET @i = 0

WHILE (datediff (m,@tmpFromDate,@todate)>=0)
BEGIN
	IF @i = 1
	BEGIN
		SET @tmpFromDate = CAST(CONVERT(VARCHAR(10),DATEADD(dd,-(DAY(@tmpFromDate)-1),@tmpFromDate),111) AS SMALLDATETIME)
	END

	SET @tmpToDate = CAST(CONVERT(VARCHAR(10),  DATEADD(s,-1,DATEADD(mm, DATEDIFF(m,0,@tmpFromDate)+1,0)), 111) AS SMALLDATETIME)
	
	--IF @tmpToDate>@ReferencedExchangeDate 
	--	SET @tmpToDate=@ReferencedExchangeDate
			
	SET @tmpDate = @tmpFromDate
	
	WHILE (@tmpDate<=@tmpToDate AND @tmpDate<=@todate)
	BEGIN
		INSERT INTO @tempDate (exchangedate,ExchangeId,Code,MYR, USD, EUR, CNY, GBP, HKD, THB, IDR, actualrate)
		SELECT @tmpDate,ExchangeId,Code,MYR, USD, EUR, CNY, GBP, HKD, THB, IDR, actualrate
		FROM ExchangeDailyOanda WITH (NOLOCK)
		WHERE ExchangeDate = CASE WHEN @tmpToDate > @ReferencedExchangeDate THEN @ReferencedExchangeDate ELSE @tmpToDate END
	
		SET @tmpDate = DATEADD(dd,1,@tmpDate)
	END

	SET @i = @i + 1
	SET @tmpFromDate = DATEADD(m,1,@tmpFromDate)
END



RETURN 

END



GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT VIEW DEFINITION ON [dbo].[Lrf_f_GetExchangeDaily] TO [vnteam]
GO 
 GRANT SELECT ON [dbo].[Lrf_f_GetExchangeDaily] TO [Dot_Casino]
GO 
 GRANT SELECT ON [dbo].[Lrf_f_GetExchangeDaily] TO [bodbLicenseeNet]
GO 
 GRANT SELECT ON [dbo].[Lrf_f_GetExchangeDaily] TO [bodbAdminNet]
GO 
