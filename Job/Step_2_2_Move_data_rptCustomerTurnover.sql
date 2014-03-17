--Step 2- Move data 
--run in DB052.bodb02
use bodb02
GO
BEGIN	
	DECLARE @fromdate DATETIME
			,@todate DATETIME
	
	SELECT @fromdate=''
			,@todate=''

	DELETE bodb_LicenseeReport.dbo.rptCustomerTurnover
	WHERE winlostdate BETWEEN @fromdate AND @todate

	EXEC Task_rptCustomerTurnOver_movedata @fromdate
		,@todate
END

