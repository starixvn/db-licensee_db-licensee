--Step:2 run in DB06
--Create table DBRPT.rptCustomerMatch

--sp : DBACC_Task_rptCustomerMatch_Bettrans_bk.sql


--gen data to bodb_report.dbo.rptCustomerMatch
truncate table bodb_report.dbo.rptCustomerMatch
BEGIN
	DECLARE @fromdate DATETIME,@todate DATETIME

	SELECT @fromdate = '2014-01-01'

	SELECT @todate = max(winlostdate)
	FROM bodb_archive.dbo.bettrans_bk with (NOLOCK)

	DELETE bodb_report.dbo.rptCustomerMatch
	WHERE winlostdate BETWEEN @fromdate AND @todate
	
	Declare @_fromdate datetime,@_todate datetime
	select @_fromdate=@fromdate

	
	WHILE (@_fromdate <= @todate)
	BEGIN
		PRINT @_fromdate

		EXEC Task_rptCustomerMatch_Bettrans_bk @_fromdate
		,@_fromdate

		SELECT @_fromdate = DATEADD(DAY, 1, @_fromdate)
		--wait for 2s
		WAITFOR DELAY '00:00:02';
	END
	
	
END