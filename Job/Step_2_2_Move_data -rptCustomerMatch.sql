--Step 2- Move data to rptListCustomerMatch

--check create table DB052.bodb_licenseereport.rptListCustomerMatch.sql
--check DBEXT_Task_rptListCustomerMatch_movedata
--check DBEXT_Task_rptListCustomerMatch_Bettrans14

--run in DB052.bodb02
BEGIN
	--move from DBRPT.bodb_report.dbo.rptListCustomerMatch to bodb_licenseeReport.dbo.rptListCustomerMatch
	DECLARE @fromdate DATETIME
		,@todate DATETIME

	SELECT @fromdate = min(winlostdate)
		,@todate = max(winlostdate)
	FROM DBRPT.bodb_report.dbo.rptListCustomerMatch WITH (NOLOCK)

	--DELETE bodb_LicenseeReport.dbo.rptListCustomerMatch
	--WHERE winlostdate BETWEEN @fromdate AND @todate

	EXEC Task_rptListCustomerMatch_movedata @fromdate
		,@todate


	--Bettrans14
	SELECT @fromdate = min(winlostdate)
		,@todate = max(winlostdate)
	FROM bettrans14(NOLOCK)
	--bettrans14 to bodb_licenseeReport.dbo.rptListCustomerMatch
	WHILE (@fromdate <= @todate)
	BEGIN
		PRINT @Fromdate

		EXEC Task_rptListCustomerMatch_Bettrans14 @fromdate

		SELECT @fromdate = DATEADD(DAY, 1, @fromdate)

		--wait for 2s
		WAITFOR DELAY '00:00:02';
	END
END

