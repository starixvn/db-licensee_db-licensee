USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Task_rptWinLostbyLeague_movedata]    Script Date: 31/12/2013 4:46:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

Create  PROCEDURE [dbo].[Task_rptWinLostbyLeague_movedata]
    @Fromdate smalldatetime,
	@Todate smalldatetime
AS
/*	
	Created	: Florent Nguyen
	Task: Pull data from table DBRPT.bodb_report.dbo.rptWinlostbyLeague
	Date: 2013-12-31
	DB: DB052.bodb02
	Original: 
	Revision:
	Parameter's Explanation:			
*/
BEGIN 
SET NOCOUNT ON

DECLARE @sql NVARCHAR(MAX)
 SELECT @sql=
	'INSERT INTO bodb_LicenseeReport.dbo.rptWinlostbyLeague
	 SELECT * FROM 
	OPENQUERY (DBRPT,
			''SELECT * FROM  bodb_report.dbo.rptWinlostbyLeague rpt
			WHERE rpt.winlostdate BETWEEN '''''+ CAST (@fromdate AS VARCHAR)+''''' AND '''''+ CAST (@todate AS VARCHAR)+''''''')'
	PRINT @sql
	EXEC (@Sql)
END 

exec Task_rptWinLostbyLeague_movedata  '2013-10-01','2013-12-31'

