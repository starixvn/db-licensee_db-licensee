/*<info serverAlias="DBACC-bodb02" executers="Dot_Admin,Dot_Member" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Dot_Dep_Rpt_DailySummaryTopV2_Agent]	
	@currency int,
	@fromDate datetime,
	@toDate datetime,
	@orderItem tinyint = 1, -- 1-Deposit/2-Withdrawal/3-Turnover/4-Winloss desc/5-Winloss asc
	@agentid NVARCHAR(3500),
	@topcnt int = 100	-- default 100, 0 is select all
AS
/*
DB: DB061.bodb02
Revisions:
--20191218@Benson: Add select promotion column
*/
CREATE TABLE #SumWinlost
(custid int,
 Deposit money,
 Aff2MemTransfer money, 
 Withdrawal money, 
 Turnover money,
 Winloss money, 
 Bonus money,
 Adjustment money,
 Outstanding money,
 OpeningBalance money,
 ClosingBalance money,
 DrawGame money,
 Promotion money)

declare @tblcust table (custid int PRIMARY KEY, username varchar(30), username2 varchar(50))
insert into @tblcust
select custid, username, username2 from customer with(nolock) 
where recommend in (SELECT val FROM strSplit(@agentid,','))

DECLARE @CutDate datetime
SELECT @CutDate =  min(winlostdate) from bodb_report.dbo.rptdepwinlost with(nolock) 

IF @FromDate < @CutDate
BEGIN
	IF @ToDate < @CutDate
	BEGIN
		INSERT INTO #SumWinlost
		SELECT custid, sum(Deposit) as Deposit, 
				sum(Aff2MemTransfer) as Aff2MemTransfer, 
				sum(Withdrawal) as Withdrawal, 
				sum(Turnover) as Turnover, 
				sum(Winloss) as Winloss, 
				sum(Bonus) as Bonus, 
				sum(Adjustment) as Adjustment, 
				sum(Outstanding) as Outstanding,
				sum(case winlostdate when @fromDate then OpeningBalance else 0 end) OpeningBalance,
				sum(case winlostdate when @ToDate then ClosingBalance else 0 end) ClosingBalance,
				sum(DrawGame) as DrawGame,
				sum(Promotion) as Promotion
		FROM   bodb_Report.dbo.rptDepWinlost_bk with(nolock)
		WHERE  winlostdate between @fromDate and @toDate
				AND custid in (select custid from @tblcust)	
			    AND currency = @currency
			   group by custid
	END
	ELSE
	BEGIN
		INSERT INTO #SumWinlost
		SELECT custid, sum(Deposit) as Deposit, 
				sum(Aff2MemTransfer) as Aff2MemTransfer, 
				sum(Withdrawal) as Withdrawal, 
				sum(Turnover) as Turnover, 
				sum(Winloss) as Winloss, 
				sum(Bonus) as Bonus, 
				sum(Adjustment) as Adjustment, 
				sum(Outstanding) as Outstanding,
				sum(case winlostdate when @fromDate then OpeningBalance else 0 end) OpeningBalance,
				sum(case winlostdate when @ToDate then ClosingBalance else 0 end) ClosingBalance,
				sum(DrawGame) as DrawGame,
				sum(Promotion) as Promotion
		FROM 
			(SELECT winlostdate, custid, Deposit, Aff2MemTransfer, Withdrawal, Turnover, Winloss,
					Bonus, Adjustment, Outstanding, OpeningBalance, ClosingBalance, DrawGame, Promotion
			 FROM   bodb_Report.dbo.rptDepWinlost_bk with(nolock)
			 WHERE  winlostdate between @fromDate and @toDate
					AND custid in (select custid from @tblcust)	
				    AND currency = @currency
			 UNION ALL
			 SELECT winlostdate, custid, Deposit, Aff2MemTransfer, Withdrawal, Turnover, Winloss,
					Bonus, Adjustment, Outstanding, OpeningBalance, ClosingBalance, DrawGame, Promotion
			 FROM   bodb_Report.dbo.rptDepWinlost with(nolock)
			 WHERE  winlostdate between @fromDate and @toDate
					AND custid in (select custid from @tblcust)
				    AND currency = @currency
			 ) as d
		group by custid
	END
END
ELSE
BEGIN
	INSERT INTO #SumWinlost
	SELECT custid, sum(Deposit) as Deposit, 
				sum(Aff2MemTransfer) as Aff2MemTransfer, 
				sum(Withdrawal) as Withdrawal, 
				sum(Turnover) as Turnover, 
				sum(Winloss) as Winloss, 
				sum(Bonus) as Bonus, 
				sum(Adjustment) as Adjustment, 
				sum(Outstanding) as Outstanding,
				sum(case winlostdate when @fromDate then OpeningBalance else 0 end) OpeningBalance,
				sum(case winlostdate when @ToDate then ClosingBalance else 0 end) ClosingBalance,
				sum(DrawGame) as DrawGame,
				sum(Promotion) as Promotion
	FROM   bodb_Report.dbo.rptDepWinlost with(nolock)
	WHERE  winlostdate between @fromDate and @toDate
			AND custid in (select custid from @tblcust)
		    AND currency = @currency
	group by custid
END

IF @orderItem=5
BEGIN
	IF @topcnt=0
	BEGIN
		select c.username,c.username2, toptbl.*
		from 
		(
			select rpt.*
			from #SumWinlost rpt
			where rpt.Winloss <> 0
		) as toptbl
		inner join @tblcust c on toptbl.custid=c.custid
		order by toptbl.Winloss
	END
	ELSE
	BEGIN
		select c.username,c.username2, toptbl.*
		from 
		(
			select top(@topcnt) rpt.*
			from #SumWinlost rpt

			where rpt.Winloss <> 0
			order by rpt.Winloss
		) as toptbl
		inner join @tblcust c on toptbl.custid=c.custid
		
	END
END
ELSE
BEGIN
	IF @topcnt=0
	BEGIN
		select c.username,c.username2, toptbl.*
		from 
		(
			select rpt.*
			from #SumWinlost rpt
			where  
				case 
					when @orderItem=1 and rpt.Deposit > 0 then 1
					when @orderItem=2 and rpt.Withdrawal > 0 then 1
					when @orderItem=3 and rpt.Turnover > 0 then 1
					when @orderItem=4 and rpt.Winloss <> 0 then 1
					end = 1
		) as toptbl
			inner join @tblcust c on toptbl.custid=c.custid
		order by 
				case @orderItem
					when 1 then toptbl.Deposit
					when 2 then toptbl.Withdrawal
					when 3 then toptbl.Turnover
					when 4 then toptbl.Winloss
				end desc 
	END 
	ELSE
	BEGIN
		select c.username,c.username2, toptbl.*
		from 
		(
			select top(@topcnt) rpt.*
			from #SumWinlost rpt
			where
				case 
					when @orderItem=1 and rpt.Deposit >0 then 1
					when @orderItem=2 and rpt.Withdrawal >0 then 1
					when @orderItem=3 and rpt.Turnover >0 then 1
					when @orderItem=4 and rpt.Winloss <>0 then 1
					end = 1
			order by 
				case @orderItem
					when 1 then rpt.Deposit
					when 2 then rpt.Withdrawal
					when 3 then rpt.Turnover
					when 4 then rpt.Winloss
				end desc
		) as toptbl
		inner join @tblcust c on toptbl.custid=c.custid
	END
END
GO