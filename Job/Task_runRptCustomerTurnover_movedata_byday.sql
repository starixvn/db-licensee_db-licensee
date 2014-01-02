USE [bodb02]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER  PROCEDURE [dbo].[Task_runRptCustomerTurnover_movedata_byday]
    @Fromdate smalldatetime,
	@Todate smalldatetime
AS
/*	
	Created	: Florent Nguyen
	Task: run RptCustomerTurnover_movedata by day
	Date: 2013-12-17		
*/
SET NOCOUNT ON;

WHILE (@fromdate<=@todate)
BEGIN
	PRINT @Fromdate
	EXEC dbo.Task_rptCustomerTurnOver_movedata
		@Fromdate,@Fromdate	
	SELECT @fromdate =DATEADD(DAY,1,@fromdate)
	--wait for 2s
	WAITFOR DELAY '00:00:02';
END