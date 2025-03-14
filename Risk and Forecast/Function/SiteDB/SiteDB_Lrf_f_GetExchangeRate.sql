/*<info serverAlias="DBSID-bodb02" selecters="wsv_lap" viewers="" isFunction="1" isNested="1"></info>*/

ALTER FUNCTION [dbo].[SiteDB_Lrf_f_GetExchangeRate]
(
    @FromDate				SMALLDATETIME,
    @ToDate					SMALLDATETIME,
    @BaseCurrency			VARCHAR(12) = '',
    @DefaultBaseCurrency	VARCHAR(12) = ''			
 )
RETURNS @tempDate TABLE (
	FromDate			SMALLDATETIME,
	ToDate				SMALLDATETIME,
	ExchangeId			INT,
	Code				VARCHAR(5),
	USD					FLOAT, 
	EUR					FLOAT,
	GBP					FLOAT, 
	Rate				FLOAT,
	DefaultRate			FLOAT
	)
AS

/*
	Created: Victoria
	Task : Get exchange rate
	DB: DBSID-bodb02
	Original: Lrf_f_GetExchangeRate

	Revisions:	
		- 20220729@Victoria: Create function[Redmine #175297]
		- 20220914@Evan: Add USDT as Base Currencies [Redmine #177481]
		- 20231005@Evan: Add PHP as Base Currencies, list currencies currently supported [Redmine #194863]
		- 20231215@Evan: Support Base Currency MP [Redmine #198400]
		- 20240112@Evan: Support based currency TRY & NPR [Redmine #197693]
		- 20240507@Kelvin: LAP - Support based currency JPY, MXN, NGN [RedmineID: #200904]
		- 20241111@Kelvin: LAP - Support BRL base currency [RedmineID: #208662]
		- 20250314@Kelvin: LAP - Support based PKR [RedmineID: #219424]

*/

BEGIN
	DECLARE @tblDate AS TABLE(number INT PRIMARY KEY, firstday SMALLDATETIME, lastday SMALLDATETIME, lastexchangeday SMALLDATETIME)

	DECLARE @MonthDist INT, @UUS FLOAT = 2E-101;

	IF (@FromDate > @ToDate)
		RETURN

	SELECT @MonthDist = DATEDIFF(MONTH, @FromDate, @ToDate)

	WHILE (@MonthDist >= 0)
	BEGIN
		INSERT INTO @tblDate(number)
			VALUES(@MonthDist)

		SET @MonthDist = @MonthDist - 1
	END

	UPDATE @tblDate 
	SET
		firstday = CONVERT(VARCHAR(25), DATEADD(dd, -(DAY(DATEADD(MONTH, number, @FromDate))-1), DATEADD(MONTH, number, @FromDate)), 101),
		lastday = CONVERT(VARCHAR(25), DATEADD(dd, -(DAY(DATEADD(MONTH, 1, DATEADD(MONTH, number, @FromDate)))), DATEADD(MONTH, 1, DATEADD(MONTH, number, @FromDate))), 101)

	UPDATE dt
	SET
		lastexchangeday = tmp.exchangedate
	FROM @tblDate dt
		CROSS APPLY (
			SELECT TOP 1 ExchangeDate 
			FROM CustDB.dbo.ExchangeDailyOanda ex WITH(NOLOCK) 
			WHERE ex.ExchangeDate BETWEEN CONVERT(SMALLDATETIME, DATEADD(DAY, -7, dt.firstday)) AND dt.lastday 
			GROUP BY ExchangeDate
			ORDER BY COUNT(*) DESC, ExchangeDate DESC
		) tmp

	;WITH cteNumber AS (
		SELECT TOP 1 number FROM @tblDate ORDER BY number ASC
		UNION ALL
		SELECT TOP 1 number FROM @tblDate ORDER BY number DESC
	)
	UPDATE dt
	SET
		firstday = CASE WHEN firstday < @FromDate THEN @FromDate ELSE firstday END,
		lastday = CASE WHEN lastday > @ToDate THEN @ToDate ELSE lastday END
	FROM @tblDate dt 
		INNER JOIN cteNumber ON dt.number = cteNumber.number

	INSERT INTO @tempDate(
			FromDate, 
			ToDate,
			ExchangeId,
			Code,
			USD,
			EUR,
			GBP, 
			Rate, 
			DefaultRate
	) 
		SELECT 
			dt.firstday, 
			dt.lastday, 
			ex.ExchangeId, 
			ex.Code,
			ex.USD, 
			ex.EUR,
			ex.GBP,
			CASE
				WHEN @BaseCurrency = 'USD' THEN ex.USD
				WHEN @BaseCurrency = 'EUR' THEN ex.EUR
				WHEN @BaseCurrency = 'GBP' THEN ex.GBP
				WHEN @BaseCurrency = 'HKD' THEN ex.HKD
				WHEN @BaseCurrency = 'MYR' THEN ex.MYR
				WHEN @BaseCurrency = 'CNY' THEN ex.CNY
				WHEN @BaseCurrency = 'THB' THEN ex.THB
				WHEN @BaseCurrency = 'IDR' THEN ex.IDR / 1000
				WHEN @BaseCurrency = 'INH' THEN ex.VND / 1000
				WHEN @BaseCurrency = 'BDT' THEN ex.BDT
				WHEN @BaseCurrency = 'INR' THEN ex.INR
				WHEN @BaseCurrency = 'USDT' AND ExchangeId = 20 THEN @UUS
				WHEN @BaseCurrency IN ('MP','PHP') THEN ex.PHP
				WHEN @BaseCurrency = 'AUD' THEN ex.AUD
				WHEN @BaseCurrency = 'CHF' THEN ex.CHF
				WHEN @BaseCurrency = 'SGD' THEN ex.SGD
				WHEN @BaseCurrency = 'KRW' THEN ex.KRW
				WHEN @BaseCurrency = 'JPY' THEN ex.JPY
				WHEN @BaseCurrency = 'TWD' THEN ex.TWD
				WHEN @BaseCurrency = 'TRY' THEN ex.TRY
				WHEN @BaseCurrency = 'NPR' THEN ex.NPR
				WHEN @BaseCurrency = 'MXN' THEN ex.MXN
				WHEN @BaseCurrency = 'NGN' THEN ex.NGN
				WHEN @BaseCurrency = 'BRL' THEN ex.BRL
				WHEN @BaseCurrency = 'PKR' THEN ex.PKR
				ELSE 1
			END AS Rate,
			CASE
				WHEN @DefaultBaseCurrency = 'USD' THEN ex.USD
				WHEN @DefaultBaseCurrency = 'EUR' THEN ex.EUR
				WHEN @DefaultBaseCurrency = 'GBP' THEN ex.GBP
				WHEN @DefaultBaseCurrency = 'HKD' THEN ex.HKD
				WHEN @DefaultBaseCurrency = 'MYR' THEN ex.MYR
				WHEN @DefaultBaseCurrency = 'CNY' THEN ex.CNY
				WHEN @DefaultBaseCurrency = 'THB' THEN ex.THB
				WHEN @DefaultBaseCurrency = 'IDR' THEN ex.IDR / 1000
				WHEN @DefaultBaseCurrency = 'INH' THEN ex.VND / 1000
				WHEN @DefaultBaseCurrency = 'BDT' THEN ex.BDT
				WHEN @DefaultBaseCurrency = 'INR' THEN ex.INR
				WHEN @DefaultBaseCurrency = 'USDT' AND ExchangeId = 20 THEN @UUS
				WHEN @DefaultBaseCurrency IN ('MP','PHP') THEN ex.PHP
				WHEN @DefaultBaseCurrency = 'AUD' THEN ex.AUD
				WHEN @DefaultBaseCurrency = 'CHF' THEN ex.CHF
				WHEN @DefaultBaseCurrency = 'SGD' THEN ex.SGD
				WHEN @DefaultBaseCurrency = 'KRW' THEN ex.KRW
				WHEN @DefaultBaseCurrency = 'JPY' THEN ex.JPY
				WHEN @DefaultBaseCurrency = 'TWD' THEN ex.TWD
				WHEN @DefaultBaseCurrency = 'TRY' THEN ex.TRY
				WHEN @DefaultBaseCurrency = 'NPR' THEN ex.NPR
				WHEN @DefaultBaseCurrency = 'MXN' THEN ex.MXN
				WHEN @DefaultBaseCurrency = 'NGN' THEN ex.NGN
				WHEN @DefaultBaseCurrency = 'BRL' THEN ex.BRL
				WHEN @DefaultBaseCurrency = 'PKR' THEN ex.PKR
				ELSE 1
			END AS DefaultRate
		FROM CustDB.dbo.ExchangeDailyOanda ex WITH(NOLOCK)
			INNER JOIN @tblDate dt ON ex.ExchangeDate = dt.lastexchangeday

	IF @BaseCurrency = 'USDT' OR @DefaultBaseCurrency = 'USDT'
	BEGIN
		UPDATE a
		SET a.Rate = CASE WHEN @BaseCurrency = 'USDT' THEN b.USDT ELSE a.Rate END , 
			a.DefaultRate = CASE WHEN @DefaultBaseCurrency = 'USDT' THEN b.USDT ELSE a.DefaultRate END
		FROM @tempDate a 
			INNER JOIN CustDB.dbo.ExchangeDaily_Crypto b WITH(NOLOCK) ON a.ExchangeId = b.ExchangeId
			INNER JOIN @tblDate c ON b.ExchangeDate = c.lastexchangeday
	END

	RETURN
END
GO