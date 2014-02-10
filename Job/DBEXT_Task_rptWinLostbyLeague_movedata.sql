USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Task_rptWinLostbyLeague_movedata]    Script Date: 10/02/2014 5:07:13 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER  PROCEDURE [dbo].[Task_rptWinLostbyLeague_movedata]
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
	 SELECT winlostdate ,matchid ,oddsid ,odds ,oddstype,bettype ,
			stake ,	winlost,awinlost,comm ,playercomm,recommend ,leagueid ,
			statusID ,betcount ,isBA 
	FROM 
	OPENQUERY (DBRPT,
			''SELECT winlostdate ,matchid ,oddsid ,	odds ,oddstype,bettype ,
			stake ,	winlost,awinlost,comm ,playercomm,recommend ,leagueid ,
			statusID ,betcount ,isBA
			  FROM  bodb_report.dbo.rptWinlostbyLeague rpt
			WHERE rpt.winlostdate BETWEEN '''''+ CAST (@fromdate AS VARCHAR)+''''' AND '''''+ CAST (@todate AS VARCHAR)+''''''')'
	PRINT @sql
	EXEC (@Sql)
END 
