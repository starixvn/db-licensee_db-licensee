/*<info serverAlias="DBSID-bodb02" selecters="bodbLicenseeNet,bodbAdminNet,Dot_Casino" viewers="" isFunction="1" isNested="0"></info>*/

CREATE FUNCTION [dbo].[SiteDB_Lrf_f_GetExchangeDaily]
    (
      @fromdate DATETIME,
      @todate DATETIME
      
    )
RETURNS @tempDate TABLE (exchangedate DATETIME,ExchangeId INT,Code VARCHAR(5),MYR FLOAT, USD FLOAT, EUR FLOAT, CNY FLOAT,GBP FLOAT,HKD FLOAT,THB FLOAT,IDR FLOAT,INH FLOAT, BDT FLOAT, INR FLOAT, actualrate FLOAT, UNIQUE CLUSTERED(exchangedate,exchangeid))
AS

 /*
	Created: 20220801@Victoria
	Task : Get exchange daily for LRF reports. The values are the same in 1 month
	DB: DBSID-bodb02
	Revisions:	
	- 20220801@Victoria: Create Function [Redmine #175297]
*/
BEGIN

DECLARE @tmpFromDate DATETIME, @tmpToDate DATETIME, @maxExchangeDate DATETIME, @tmpDate DATETIME, @gapDate DATETIME, @ReferencedExchangeDate DATETIME
DECLARE @i INT


--Get the data after 1st of June 2012 in ExchangeDailyOanda
--Get the Referenced Exchange Date
SELECT @maxExchangeDate=MAX(exchangedate) FROM CustDB.dbo.ExchangeDailyOanda WITH (NOLOCK)
SELECT @ReferencedExchangeDate = (SELECT a.ExchangeDate FROM (SELECT TOP 1 ExchangeDate, COUNT (1) AS ExchangeCount
				FROM CustDB.dbo.ExchangeDailyOanda WITH (NOLOCK)
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
		INSERT INTO @tempDate (exchangedate,ExchangeId,Code,MYR, USD, EUR, CNY, GBP, HKD, THB, IDR, INH, BDT, INR, actualrate)
		SELECT @tmpDate,ExchangeId,Code,MYR, USD, EUR, CNY, GBP, HKD, THB, IDR / 1000 AS IDR, VND / 1000 AS INH, BDT, INR, actualrate
		FROM CustDB.dbo.ExchangeDailyOanda WITH (NOLOCK)
		WHERE ExchangeDate = CASE WHEN @tmpToDate > @ReferencedExchangeDate THEN @ReferencedExchangeDate ELSE @tmpToDate END
	
		SET @tmpDate = DATEADD(dd,1,@tmpDate)
	END

	SET @i = @i + 1
	SET @tmpFromDate = DATEADD(m,1,@tmpFromDate)
END

RETURN 

END


GO

