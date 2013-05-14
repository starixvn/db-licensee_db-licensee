ALTER PROCEDURE [dbo].[Lrf_Rpt_CustomerTurnOver]
    @LicenseeID INT ,
    @LicenseeType VARCHAR(100) = NULL,
    @Currency INT,
    @FromDate		SMALLDATETIME,  
	@ToDate		SMALLDATETIME,   
	@OrderItem tinyint = 1, 
	@TopCount INT = 0,
	@excludeTest BIT = 1,
	@PageSize INT = 1000 ,
    @PageIndex INT = 1
    --@TotalRows INT =0 OUTPUT
AS /*
Created: 20111020@Henry
Task : Report Customer Turn Over
DB: DB06.bodb02


Revisions:
   
Param's Explanation:
	+ @excludeTest: remove currency UUS
	+ @TopCount: 
		0: get all
		100: get 100 top by @OrderItem
		500: get 500 top by @OrderItem
	+ @OrderItem:
		1: Deposit
		2: Withdrawal
		3: Turnover
		4: Winloss desc
		5: Winloss asc
	
	
*/
SET NOCOUNT ON



DECLARE @dbtodaydate smalldatetime,  @CutDate datetime
DECLARE @tmpAg	TABLE( custID INT PRIMARY KEY)
DECLARE @RowStart INT, @RowEnd INT
    
SET @dbtodaydate = convert(nvarchar(10),current_timestamp,120)  
SET @CutDate = convert(varchar(4),year(DateAdd(m,-1,getdate()))) + '/' + convert(varchar(2),month(DateAdd(m,-1,getdate()))) + '/1'   

SELECT  @PageIndex = @PageIndex - 1 ,
        @RowStart = @PageSize * @PageIndex + 1 ,
        @RowEnd = @RowStart + @PageSize - 1
 


INSERT INTO @tmpAg
SELECT CustID FROM DB052.bodb_Licensee.dbo.LicenseeCust WITH ( NOLOCK )
WHERE   
	LicenseeID = @LicenseeID
	AND [Description] = COALESCE(@LicenseeType,[Description]) 
	AND (Currency = @Currency)
	AND (@excludeTest = 0 OR (@excludeTest=1 AND Currency<>20))

CREATE TABLE #SumWinlost
(
	Custid int,
	Deposit money,
	AffiliateTransfer money, 
	Withdrawal money, 
	Turnover money,
	Winloss money, 
	Bonus money,
	Adjustment money,
	Outstanding money,
	OpeningBalance money,
	ClosingBalance money,
	DrawGame money,
	TurnoverBA money,
	CommBA money,
	AmountDueToBA money
	
) 
IF @FromDate < @CutDate
BEGIN
	IF @ToDate < @CutDate
	BEGIN
		INSERT INTO #SumWinlost
		SELECT 
				custid, 
				sum(Deposit) as Deposit, 
				sum(Aff2MemTransfer) as AffiliateTransfer, 
				sum(Withdrawal) as Withdrawal, 
				sum(Turnover) as Turnover,
				sum(Winloss) as Winloss, 
				sum(Bonus) as Bonus, 
				sum(Adjustment) as Adjustment, 
				sum(Outstanding) as Outstanding,
				sum(case winlostdate when @fromDate then OpeningBalance else 0 end) OpeningBalance,
				sum(case winlostdate when @ToDate then ClosingBalance else 0 end) ClosingBalance,
				sum(DrawGame) as DrawGame ,
				sum(isnull(Turnover_BA,0)),
				sum(isnull(Comm_BA,0)),
				sum(isnull(AmountDueTo_BA,0))
		FROM   bodb_Report.dbo.rptDepWinlost_bk with (nolock)
		WHERE  winlostdate between @fromDate and @toDate
				AND Recommend IN ( SELECT custid FROM @tmpAg)
			   group by custid
	END
	ELSE
	BEGIN
		INSERT INTO #SumWinlost
		SELECT custid, sum(Deposit) as Deposit, 
				sum(Aff2MemTransfer) as AffiliateTransfer, 
				sum(Withdrawal) as Withdrawal, 
				sum(Turnover) as Turnover, 
				sum(Winloss) as Winloss, 
				sum(Bonus) as Bonus, 
				sum(Adjustment) as Adjustment, 
				sum(Outstanding) as Outstanding,
				sum(case winlostdate when @fromDate then OpeningBalance else 0 end) OpeningBalance,
				sum(case winlostdate when @ToDate then ClosingBalance else 0 end) ClosingBalance,
				sum(DrawGame) as DrawGame ,
				sum(isnull(Turnover_BA,0)),
				sum(isnull(Comm_BA,0)),
				sum(isnull(AmountDueTo_BA,0))
		FROM 
			(SELECT winlostdate, custid, Deposit, Aff2MemTransfer, Withdrawal, Turnover, Winloss,
					Bonus, Adjustment, Outstanding, OpeningBalance, ClosingBalance, DrawGame,Turnover_BA,Comm_BA,AmountDueTo_BA
			 FROM   bodb_Report.dbo.rptDepWinlost_bk with (nolock)
			 WHERE  winlostdate between @fromDate and @toDate
					AND Recommend IN ( SELECT custid FROM @tmpAg)
			 UNION ALL
			 SELECT winlostdate, custid, Deposit, Aff2MemTransfer, Withdrawal, Turnover, Winloss,
					Bonus, Adjustment, Outstanding, OpeningBalance, ClosingBalance, DrawGame,Turnover_BA,Comm_BA,AmountDueTo_BA
			 FROM   bodb_Report.dbo.rptDepWinlost with (nolock)
			 WHERE  winlostdate between @fromDate and @toDate
					AND Recommend IN ( SELECT custid FROM @tmpAg)
			 ) as d
		group by custid
	END
END	
ELSE
BEGIN
	INSERT INTO #SumWinlost
	SELECT custid, sum(Deposit) as Deposit, 
				sum(Aff2MemTransfer) as AffiliateTransfer, 
				sum(Withdrawal) as Withdrawal, 
				sum(Turnover) as Turnover, 
				sum(Winloss) as Winloss, 
				sum(Bonus) as Bonus, 
				sum(Adjustment) as Adjustment, 
				sum(Outstanding) as Outstanding,
				sum(case winlostdate when @fromDate then OpeningBalance else 0 end) OpeningBalance,
				sum(case winlostdate when @ToDate then ClosingBalance else 0 end) ClosingBalance,
				sum(DrawGame) as DrawGame,
				sum(isnull(Turnover_BA,0)),
				sum(isnull(Comm_BA,0)),
				sum(isnull(AmountDueTo_BA,0))
	FROM   bodb_Report.dbo.rptDepWinlost with (nolock)
	WHERE  winlostdate between @fromDate and @toDate
			AND Recommend IN ( SELECT custid FROM @tmpAg)
	group by custid
END

  

IF @OrderItem=5
BEGIN
	IF @TopCount=0
	BEGIN
		select 
			c.username, 
			SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS nickname ,
			toptbl.*
		from 
		(
			select
				rpt.*,
				ROW_NUMBER() OVER ( ORDER BY rpt.Winloss ) AS RowNum
			from #SumWinlost rpt
			where rpt.Winloss <> 0
		) as toptbl
		inner join Customer c WITH ( NOLOCK ) ON c.custid=toptbl.custid
		WHERE   toptbl.RowNum BETWEEN @RowStart AND @RowEnd 
		ORDER BY RowNum ASC
		
		SELECT 
			COUNT(DISTINCT CustID) as TotalRows,
			sum(Deposit) as SumDeposit,
			sum(AffiliateTransfer) as SumAffiliateTransfer,
			sum(Withdrawal) as SumWithdrawal,
			sum(Turnover) as SumTurnover,
			sum(Winloss) as SumWinloss,
			sum(Bonus) as SumBonus,
			sum(Adjustment) as SumAdjustment,
			sum(Outstanding) as SumOutstanding,
			sum(OpeningBalance) as SumOpeningBalance,
			sum(ClosingBalance) as SumClosingBalance,
			sum(DrawGame) as SumDrawGame ,
			sum(TurnoverBA) as SumTurnoverBA ,
			sum(CommBA) as SumCommBA,
			sum(AmountDueToBA) as SumAmountDueToBA
			
		FROM #SumWinlost rpt
		where rpt.Winloss <> 0
	END
	ELSE
	BEGIN
		select 
			c.username, 
			SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS nickname ,
			toptbl.*
		from 
		(
			select 
				top(@TopCount) rpt.*,
				ROW_NUMBER() OVER ( ORDER BY rpt.Winloss ) AS RowNum
			from #SumWinlost rpt
			where rpt.Winloss <> 0
		) as toptbl
		inner join Customer c WITH ( NOLOCK ) ON c.custid=toptbl.custid
		WHERE   toptbl.RowNum BETWEEN @RowStart AND @RowEnd 
		ORDER BY RowNum ASC
		
		
		SELECT 
			COUNT(DISTINCT CustID) as TotalRows,
			sum(Deposit) as SumDeposit,
			sum(AffiliateTransfer) as SumAffiliateTransfer,
			sum(Withdrawal) as SumWithdrawal,
			sum(Turnover) as SumTurnover,
			sum(Winloss) as SumWinloss,
			sum(Bonus) as SumBonus,
			sum(Adjustment) as SumAdjustment,
			sum(Outstanding) as SumOutstanding,
			sum(OpeningBalance) as SumOpeningBalance,
			sum(ClosingBalance) as SumClosingBalance,
			sum(DrawGame) as SumDrawGame ,
			sum(TurnoverBA) as SumTurnoverBA ,
			sum(CommBA) as SumCommBA,
			sum(AmountDueToBA) as SumAmountDueToBA
			
		FROM  
			(
				select 
					top(@TopCount) rpt.*,
					ROW_NUMBER() OVER ( ORDER BY rpt.Winloss ) AS RowNum
				from #SumWinlost rpt
				where rpt.Winloss <> 0
				ORDER BY RowNum ASC
			) A
		
		
	
		
	END
END
ELSE
BEGIN
	IF @TopCount=0
	BEGIN
		select 
			c.username, 
			SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS nickname ,
			toptbl.*
		from 
		(
			select rpt.*,
			ROW_NUMBER() OVER ( ORDER BY 
									case @orderItem
									when 1 then rpt.Deposit
									when 2 then rpt.Withdrawal
									when 3 then rpt.Turnover
									when 4 then rpt.Winloss
				end desc  ) AS RowNum
			from #SumWinlost rpt
			where  
				case 
					when @orderItem=1 and rpt.Deposit > 0 then 1
					when @orderItem=2 and rpt.Withdrawal > 0 then 1
					when @orderItem=3 and rpt.Turnover > 0 then 1
					when @orderItem=4 and rpt.Winloss <> 0 then 1
					end = 1
					
		) as toptbl
			inner join Customer c WITH ( NOLOCK ) ON c.custid=toptbl.custid
		WHERE   toptbl.RowNum BETWEEN @RowStart AND @RowEnd 
		ORDER BY RowNum ASC
		
		SELECT 
			COUNT(DISTINCT CustID) as TotalRows,
			sum(Deposit) as SumDeposit,
			sum(AffiliateTransfer) as SumAffiliateTransfer,
			sum(Withdrawal) as SumWithdrawal,
			sum(Turnover) as SumTurnover,
			sum(Winloss) as SumWinloss,
			sum(Bonus) as SumBonus,
			sum(Adjustment) as SumAdjustment,
			sum(Outstanding) as SumOutstanding,
			sum(OpeningBalance) as SumOpeningBalance,
			sum(ClosingBalance) as SumClosingBalance,
			sum(DrawGame) as SumDrawGame ,
			sum(TurnoverBA) as SumTurnoverBA ,
			sum(CommBA) as SumCommBA,
			sum(AmountDueToBA) as SumAmountDueToBA
			
		FROM  #SumWinlost rpt
		where  
			case 
				when @orderItem=1 and rpt.Deposit > 0 then 1
				when @orderItem=2 and rpt.Withdrawal > 0 then 1
				when @orderItem=3 and rpt.Turnover > 0 then 1
				when @orderItem=4 and rpt.Winloss <> 0 then 1
				end = 1	
	END 
	ELSE
	BEGIN
		select 
			c.username, 
			SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS nickname ,
			toptbl.*
		from 
		(
			select 
				top(@TopCount) rpt.*,
				ROW_NUMBER() OVER ( ORDER BY 
									case @orderItem
									when 1 then rpt.Deposit
									when 2 then rpt.Withdrawal
									when 3 then rpt.Turnover
									when 4 then rpt.Winloss
									end desc  ) AS RowNum
			from #SumWinlost rpt
			where
				case 
					when @orderItem=1 and rpt.Deposit >0 then 1
					when @orderItem=2 and rpt.Withdrawal >0 then 1
					when @orderItem=3 and rpt.Turnover >0 then 1
					when @orderItem=4 and rpt.Winloss <>0 then 1
					end = 1
			
			
		) as toptbl
		inner join bodb02.dbo.Customer c WITH ( NOLOCK ) ON c.custid=toptbl.custid
		WHERE   toptbl.RowNum BETWEEN @RowStart AND @RowEnd 
		ORDER BY RowNum ASC
		
		SELECT 
			COUNT(DISTINCT CustID) as TotalRows,
			sum(Deposit) as SumDeposit,
			sum(AffiliateTransfer) as SumAffiliateTransfer,
			sum(Withdrawal) as SumWithdrawal,
			sum(Turnover) as SumTurnover,
			sum(Winloss) as SumWinloss,
			sum(Bonus) as SumBonus,
			sum(Adjustment) as SumAdjustment,
			sum(Outstanding) as SumOutstanding,
			sum(OpeningBalance) as SumOpeningBalance,
			sum(ClosingBalance) as SumClosingBalance,
			sum(DrawGame) as SumDrawGame ,
			sum(TurnoverBA) as SumTurnoverBA ,
			sum(CommBA) as SumCommBA,
			sum(AmountDueToBA) as SumAmountDueToBA
		FROM
		(
			select 
				top(@TopCount) rpt.*,
				ROW_NUMBER() OVER ( ORDER BY 
									case @orderItem
									when 1 then rpt.Deposit
									when 2 then rpt.Withdrawal
									when 3 then rpt.Turnover
									when 4 then rpt.Winloss
									end desc  ) AS RowNum
			from #SumWinlost rpt
			where
				case 
					when @orderItem=1 and rpt.Deposit >0 then 1
					when @orderItem=2 and rpt.Withdrawal >0 then 1
					when @orderItem=3 and rpt.Turnover >0 then 1
					when @orderItem=4 and rpt.Winloss <>0 then 1
					end = 1
			ORDER BY RowNum ASC
		) A
	END
END

DROP TABLE #SumWinlost

GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_CustomerTurnOver] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_CustomerTurnOver] TO [vnteam] 