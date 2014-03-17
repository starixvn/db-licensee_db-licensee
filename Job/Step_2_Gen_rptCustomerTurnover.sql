--Step:2 run in DB06
--DBACC_Task_rptCustomerTurnOver_Bettrans_bk.sql

--gen data to bodb_report.dbo.rptCustomerTurnover
TRUNCATE TABLE bodb_report.dbo.rptCustomerTurnover
BEGIN
	DECLARE @fromdate DATETIME,@todate DATETIME

	SELECT @fromdate = ''
			,@todate = ''
	/*
	SELECT @todate = max(winlostdate)
	FROM bodb_archive.dbo.bettrans_bk with (NOLOCK)
	*/
	DELETE bodb_report.dbo.rptCustomerTurnover
	WHERE winlostdate BETWEEN @fromdate AND @todate
	
	EXEC dbo.Task_rptCustomerTurnOver_Bettrans_bk @fromdate
		,@todate
END