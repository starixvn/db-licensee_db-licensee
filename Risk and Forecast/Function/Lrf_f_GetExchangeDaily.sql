/*<info serverAlias="DBEXT-bodb02,DBACC-bodb02,DBBOF-bodb02" selecters="wsv_lap,wsv_nap,Dot_Casino" viewers="" isFunction="1" isNested="0"></info>*/

ALTER FUNCTION [dbo].[Lrf_f_GetExchangeDaily]
    (
      @fromdate DATETIME,
      @todate DATETIME
      
    )
RETURNS @tempDate TABLE 
(		exchangedate DATETIME,
		ExchangeId INT,
		Code VARCHAR(5),
		MYR FLOAT,
		USD FLOAT,
		EUR FLOAT,
		CNY FLOAT,
		GBP FLOAT,
		HKD FLOAT,
		THB FLOAT,
		IDR FLOAT,
		INH FLOAT,
		BDT FLOAT,
		INR FLOAT,
		USDT FLOAT,
		TRY FLOAT,
		NPR FLOAT,
		PHP FLOAT,
		JPY FLOAT,
		MXN FLOAT,
		NGN FLOAT,
		BRL FLOAT,
		actualrate FLOAT,
	UNIQUE CLUSTERED(exchangedate,	exchangeid))
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
	- 20171031@Harper: Fix rate for IDR currency [RedmineID: #85203]
	- 20180724@Sophia: HA - remove table ExchangeDaily [Redmine: #98631]
	- 20190426@Joseph: Add INH base currency [Redmine: #112603]
	- 20210224@Mark: Add BDT and INR as Base Currencies[Redmine #150375]
	- 20220914@Evan: Add USDT as Base Currencies[Redmine #177481]
	- 20240112@Evan: Support based currency TRY & NPR and add PHP [Redmine #197693]
	- 20240507@Kelvin: LAP - Support based currency JPY, MXN, NGN [RedmineID: #200904]
	- 20241111@Kelvin: LAP - Support BRL base currency [RedmineID: #208662]

*/
BEGIN

DECLARE @tmpFromDate DATETIME, @tmpToDate DATETIME, @maxExchangeDate DATETIME, @tmpDate DATETIME, @LastDate DATETIME, @ReferencedExchangeDate DATETIME
DECLARE @i INT, @UUS FLOAT = 2E-101;
 
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

	--select @LastDate
	SET @LastDate = @tmpToDate
	IF @LastDate > @ReferencedExchangeDate 
		SET @LastDate = @ReferencedExchangeDate
			
	SET @tmpDate = @tmpFromDate
	
	WHILE (@tmpDate<=@tmpToDate AND @tmpDate<=@todate)
	BEGIN
		INSERT INTO @tempDate (exchangedate,ExchangeId,Code,MYR, USD, EUR, CNY, GBP, HKD, THB, IDR, INH, BDT, INR, USDT, TRY, NPR, PHP, JPY, MXN, NGN, BRL, actualrate)
		SELECT @tmpDate,a.ExchangeId,Code,MYR, USD, EUR, CNY, GBP, HKD, THB, IDR / 1000 AS IDR, VND / 1000 AS INH, BDT, INR,CASE WHEN a.ExchangeId = 20 THEN @UUS ELSE ISNULL(b.USDT,1) END AS USDT, TRY, NPR, PHP, JPY, MXN, NGN, BRL, actualrate
		FROM ExchangeDailyOanda a WITH (NOLOCK) 
			LEFT JOIN ExchangeDaily_Crypto b WITH(NOLOCK) ON a.ExchangeId = b.ExchangeId AND b.ExchangeDate = @LastDate
		WHERE a.ExchangeDate = @LastDate
	
		SET @tmpDate = DATEADD(dd,1,@tmpDate)
	END

	SET @i = @i + 1
	SET @tmpFromDate = DATEADD(m,1,@tmpFromDate)
	
END

RETURN 

END


GO

