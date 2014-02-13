--Step 2- Move data 

--check create table _temp
--check Task_rptCustomerTurnOver_movedata
--check Task_rptCustomerTurnOver_Bettrans14

--run in DB052.bodb02
BEGIN
	--move from DBRPT.bodb_report.dbo.rptCustomerTurnover to bodb_licenseeReport.dbo.rptCustomerTurnover_temp
	DECLARE @fromdate DATETIME
		,@todate DATETIME

	SELECT @fromdate = min(winlostdate)
		,@todate = max(winlostdate)
	FROM DBRPT.bodb_report.dbo.rptCustomerTurnover WITH (NOLOCK)

	DELETE bodb_LicenseeReport.dbo.rptCustomerTurnover
	WHERE winlostdate BETWEEN @fromdate AND @todate

	EXEC Task_rptCustomerTurnOver_movedata @fromdate
		,@todate

	SELECT @fromdate = min(winlostdate)
		,@todate = max(winlostdate)
	FROM bettrans14(NOLOCK)
	--bettrans14 to bodb_licenseeReport.dbo.rptCustomerTurnover_temp
	WHILE (@fromdate <= @todate)
	BEGIN
		PRINT @Fromdate

		EXEC Task_rptCustomerTurnOver_Bettrans14 @fromdate

		SELECT @fromdate = DATEADD(DAY, 1, @fromdate)

		--wait for 2s
		WAITFOR DELAY '00:00:02';
	END
END

