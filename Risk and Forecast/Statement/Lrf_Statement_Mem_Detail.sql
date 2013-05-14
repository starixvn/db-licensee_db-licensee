SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Lrf_Statement_Mem_Detail]  
    @CustID INT ,  
    @FromDate DATETIME ,  
    @Bettype SMALLINT,
	@BalanceUpDay DATETIME 
AS /*  
Created:   Minzy
Task :Enhance statement page
DB: DB052.bodb02  
Original: 
Revisions:  

Param's Explanation:   
	+ @Bettype:
		1: deposit
		2: withdrawal

*/  
	SET NOCOUNT ON  
	DECLARE @ToDate DATETIME
	select @ToDate = DATEADD(D,1,@FromDate)

	DECLARE @fdate datetime, @tdate datetime
	select @fdate = @FromDate, @tdate = @ToDate

	CREATE TABLE #temp   
		(  
		  winlostdate DATETIME ,  
		  bettype SMALLINT ,  
		  actual_stake MONEY ,  
		  winlost MONEY ,  
		)   


	IF @ToDate >= @BalanceUpDay
	BEGIN
		INSERT INTO #temp(winlostdate,bettype,actual_stake,winlost)
		SELECT	winlostdate,bettype,actual_stake,winlost
		FROM bettrans with(nolock)  
		WHERE custid = @custid  
			AND winlostdate BETWEEN @FromDate AND @ToDate  
			AND bettype = CASE  WHEN @Bettype = 1 THEN 22001 ELSE 22002 END
	END
	IF @FromDate < @BalanceUpDay
	BEGIN
		INSERT INTO #temp(winlostdate,bettype,actual_stake,winlost)
		SELECT accdate,@Bettype,0,totalamt
		FROM DB06.bodb_Report.dbo.Statement WITH ( NOLOCK )    
		WHERE custid = @custid  
			AND accdate BETWEEN @FromDate AND @ToDate  
			AND transtype =  CASE  WHEN @Bettype = 1 THEN 'DDEP' ELSE 'DWIT' END
	END
	SELECT t.winlostdate Date,b.typenamee Remark,(t.winlost - t.actual_stake) [Credit/Deposit]
	FROM #temp t INNER JOIN bettype  b ON t.bettype=b.typeid
	WHERE (t.winlost - t.actual_stake)  <> 0
	ORDER BY t.winlostdate
	DROP TABLE #temp
	

  
	

  
	
GRANT EXECUTE ON [dbo].[Lrf_Statement_Mem_Detail] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Statement_Mem_Detail] TO [vnteam]
GO

 