--Step :1 rptWinlostbyleague
--SP : DBACC_Task_rptWinlostbyleague_bk.sql
--run data IN DB06.BODB02
USE bodb02
GO
DECLARE @FROMDATE DATETIME, @TODATE DATETIME
SELECT @FROMDATE='',@TODATE=''

BEGIN 
	IF exists ( SELECT TOP 1 1 FROM bodb_report.dbo.rptWinlostbyLeague WHERE winlostdate >=@FROMDATE AND winlostdate<=@TODATE)
		DELETE BODB_REPORT.DBO.rptWinlostbyLeague WHERE winlostdate >=@FROMDATE AND winlostdate<=@TODATE

	EXEC dbo.Task_rptWinlostbyleague_bk @FROMDATE, @TODATE
		
	--WAIT
	--WAITFOR DELAY '00:00:02';
END