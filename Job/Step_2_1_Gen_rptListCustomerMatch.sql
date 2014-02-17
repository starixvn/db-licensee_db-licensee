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

	DELETE bodb_report.dbo.rptListCustomerMatch
	WHERE winlostdate BETWEEN @fromdate AND @todate
	Declare @_fromdate datetime,@_todate datetime
	select @_fromdate
	EXEC Task_rptCustomerMatch_Bettrans_bk @fromdate
		,@todate
END