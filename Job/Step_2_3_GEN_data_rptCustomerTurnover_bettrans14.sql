--Step 2- Move data 
--run in DB052.bodb02
use bodb02
GO
BEGIN	
	DECLARE @fromdate DATETIME
		,@todate DATETIME
	/*	
	SELECT @fromdate = min(winlostdate)
		,@todate = max(winlostdate)
	FROM bettrans14(NOLOCK)
	*/
	SELECT @FROMDATE=''
			,@TODATE=''
	
	--bettrans14 to bodb_licenseeReport.dbo.rptCustomerTurnover_temp
	WHILE (@fromdate <= @todate)
	BEGIN
		PRINT @Fromdate

		EXEC dbo.Task_rptCustomerTurnOver_Bettrans14 @fromdate

		SELECT @fromdate = DATEADD(DAY, 1, @fromdate)

		--wait for 2s
		WAITFOR DELAY '00:00:02';
	END
END

