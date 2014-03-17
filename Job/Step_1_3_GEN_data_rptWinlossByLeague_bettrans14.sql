--Step 2- gen data from dbo.bettrans14 to rptWinlossbyLeague
--run in DB052.bodb02
use bodb02
GO
BEGIN	
	DECLARE @fromdate DATETIME
		,@todate DATETIME
	/*	
	SELECT min(winlostdate)
		,max(winlostdate)
	FROM bettrans14(NOLOCK)
	*/
	SELECT @FROMDATE=''
			,@TODATE=''
	
	--bettrans14 to bodb_licenseeReport.dbo.rptWinlossByleague
	WHILE (@fromdate <= @todate)
	BEGIN
		PRINT @Fromdate

		EXEC dbo.Task_rptWinlostbyleague_Bettrans14 @fromdate

		SELECT @fromdate = DATEADD(DAY, 1, @fromdate)

		--wait for 2s
		WAITFOR DELAY '00:00:02';
	END
END

