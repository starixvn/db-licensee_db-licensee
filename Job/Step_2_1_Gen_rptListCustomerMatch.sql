--Step:2 run in DB06
--Create table DBRPT.rptListCustomerMatch

--sp : DBACC_Task_rptListCustomerMatch_Bettrans_bk.sql


--gen data to bodb_report.dbo.rptCustomerTurnover
truncate table bodb_report.dbo.rptListCustomerMatch
BEGIN
	DECLARE @fromdate DATETIME,@todate DATETIME

	SELECT @fromdate = '2014-01-01'

	SELECT @todate = max(winlostdate)
	FROM bodb_archive.dbo.bettrans_bk with (NOLOCK)

	DELETE bodb_report.dbo.rptCustomerTurnover
	WHERE winlostdate BETWEEN @fromdate AND @todate
	
	EXEC Task_rptListCustomerMatch_Bettrans_bk @fromdate
		,@todate
END