/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet,bodbDownlineNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[LAP_Statement_Mem_History]  
    @CustID			INT,  
    @MonthDate		SMALLDATETIME,  
    @BalanceUpDay	SMALLDATETIME,  
    @MoveBetsDay	SMALLDATETIME,  
    @PageSize		INT = 50,  
    @PageIndex		INT = 1,  
    @BaseCurrency	VARCHAR(3) = '',
    @TotalRows		INT = 0 OUTPUT 
AS
/*
Created:Bobby@20190724   
Task : 112658 - LAP - Customer History Statement
DB: DBEXT/bodb02

Revisions:  
	- 20190724@Bobby: Initialize [RedmineID: #117534]
	
Param's Explanation:     
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @fromDate		SMALLDATETIME
		, @toDate			SMALLDATETIME
		, @curDate			SMALLDATETIME

	SELECT @curDate		= CURRENT_TIMESTAMP
		, @fromDate		= CAST((CONVERT(VARCHAR(7), @MonthDate, 111) + '/01') AS DATE)
		, @toDate		= DATEADD(DAY, -1, DATEADD(M, 1, @fromDate))
		, @TotalRows	= 0

	SELECT @toDate		= @curDate WHERE @toDate > @curDate

	EXEC [dbo].[LAP_Statement_Mem] 
		@CustID			= @CustID
		,@FromDate		= @fromDate
		,@ToDate		= @toDate
		,@BalanceUpDay	= @BalanceUpDay
		,@MoveBetsDay	= @MoveBetsDay
		,@PageSize		= @PageSize
		,@PageIndex		= @PageIndex
		,@BaseCurrency	= @BaseCurrency
		,@TotalRows		= @TotalRows OUTPUT
	
END
GO

