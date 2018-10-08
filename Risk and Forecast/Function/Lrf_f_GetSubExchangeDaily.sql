/*<info serverAlias="DBACC-bodb02,DB042-bodb02" selecters="bodbLicenseeNet,bodbAdminNet,Dot_Casino" viewers="vnteam" isFunction="1" isNested="0"></info>*/
ALTER FUNCTION [dbo].[Lrf_f_GetSubExchangeDaily]
    (
      @FromDate			SMALLDATETIME,
      @ToDate			SMALLDATETIME
    )
RETURNS @tempDate TABLE (
	FirstExchangeDateByMonth			SMALLDATETIME,
	LastExchangeDateByMonth				SMALLDATETIME,
	ExchangeId							INT,
	Code								VARCHAR(5),
	MYR									FLOAT, 
	USD									FLOAT, 
	EUR									FLOAT, 
	CNY									FLOAT, 
	GBP									FLOAT, 
	HKD									FLOAT, 
	THB									FLOAT, 
	IDR									FLOAT, 
	Actualrate							FLOAT
	)
AS
/*  
	Created: 20171206@Don
	Task: New way to get exchange rate
	DB: DBEXT.bodb02,DBACC-bodb02,DB042.bodb02
	Revisions:  

	Param's Explanation:  			
	- 20171206@Don: Initial version
	- 20181008@Joseph: Deploy to 2 servers DBACC-bodb02,DB042.bodb02 (used by SP betlists) [Redmine #80941]

*/
BEGIN

	DECLARE @tblDate AS TABLE(number INT PRIMARY KEY, firstday SMALLDATETIME, lastday SMALLDATETIME, lastexchangeday SMALLDATETIME)

	DECLARE @MonthDist INT

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
			FROM dbo.ExchangeDailyOanda ex WITH(NOLOCK) 
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
			FirstExchangeDateByMonth, 
			LastExchangeDateByMonth,
			ExchangeId,
			Code,
			MYR, 
			USD, 
			EUR, 
			CNY, 
			GBP, 
			HKD, 
			THB, 
			IDR, 
			Actualrate
	) 
		SELECT 
			dt.firstday, 
			dt.lastday, 
			ex.ExchangeId, 
			ex.Code, 
			ex.MYR, 
			ex.USD, 
			ex.EUR, 
			ex.CNY, 
			ex.GBP, 
			ex.HKD, 
			ex.THB, 
			ex.IDR / 1000 AS IDR, 
			ex.Actualrate
		FROM dbo.ExchangeDailyOanda ex WITH(NOLOCK)
			INNER JOIN @tblDate dt ON ex.ExchangeDate = dt.lastexchangeday

	RETURN

END
GO