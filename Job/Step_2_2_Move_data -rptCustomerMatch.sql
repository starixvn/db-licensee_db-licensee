--Step 2- Move data to rptCustomerMatch

--check create table DB052.bodb_licenseereport.rptCustomerMatch.sql
--check DBEXT_Task_rptCustomerMatch_movedata
--check DBEXT_Task_rptCustomerMatch_Bettrans14

--run in DB052.bodb02
BEGIN
	--move from DBRPT.bodb_report.dbo.rptCustomerMatch to bodb_licenseeReport.dbo.rptCustomerMatch
	DECLARE @fromdate DATETIME
		,@todate DATETIME

	SELECT @fromdate = min(winlostdate)
		,@todate = max(winlostdate)
	FROM DBRPT.bodb_report.dbo.rptCustomerMatch WITH (NOLOCK)

	--DELETE bodb_LicenseeReport.dbo.rptCustomerMatch
	--WHERE winlostdate BETWEEN @fromdate AND @todate

	EXEC Task_rptCustomerMatch_movedata @fromdate
		,@todate


	--Bettrans14
	SELECT @fromdate = min(winlostdate)
		,@todate = max(winlostdate)
	FROM bettrans14(NOLOCK)
	--bettrans14 to bodb_licenseeReport.dbo.rptCustomerMatch
	WHILE (@fromdate <= @todate)
	BEGIN
		PRINT @Fromdate

		EXEC Task_rptCustomerMatch_Bettrans14 @fromdate

		SELECT @fromdate = DATEADD(DAY, 1, @fromdate)

		--wait for 2s
		WAITFOR DELAY '00:00:02';
	END
END

