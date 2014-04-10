USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Task_DOT_dep_DailySummary_TST_NEW]    Script Date: 04/09/2014 20:21:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Task_DOT_dep_DailySummary_TST_NEW] 
	@winlostdate datetime
AS
/*	
	Task : Summary data (TST standards) for deposit member
	Creator: Daniel
	DB: DB06.bodb02
	Revisions:	
		- 20111007@Daniel: remove redundant rows		
		- 20121006@Viet: enhance SP to save server's resources
		             
	Param's Explanation:
	• @winlostdate: The date need to summary
	
	[Task_DOT_dep_DailySummary_TST] '2012-9-5'
*/
SET NOCOUNT ON
declare @date datetime
select @date = @winlostdate

declare @balanceupday smalldatetime
select TOP 1 @balanceupday = winlostdate from bettrans with(nolock) where bettype = 20000
IF @date <= DATEADD(dd, 1, @balanceupday) RETURN -- NOT enough data here.. need to dig data from bettrans_bk to calcualte for this case

CREATE TABLE #DATA(custid int PRIMARY KEY, currency int, 
	OpeningBalance money default(0), Turnover money default(0), Outstanding money default(0), 
	ReturnAmt money default(0), ClosingBalance money default(0),
	recommend int, mrecommend int, srecommend int
)	

INSERT INTO #DATA (custid, currency, recommend, mrecommend, srecommend)
	select custid, currency, recommend, mrecommend, srecommend
from dbo.customer with(nolock)
where srecommend in (select custid from dep_custsuper with(nolock))
	and RoleID = 1
	
SELECT c.custid, c.currency, winlostdate, DATEADD(dd, DATEDIFF(dd, 0, transdate), 0) as transdate, ruben
	,sum(isnull(winlost,0)) as winlost
	,sum(isnull(stake,0)) as stake
	,sum(isnull(actual_stake,0)) as actual_stake
	,sum(isnull(playercomm,0)) as playercomm
INTO #bettrans_TEMP
FROM #DATA c 
	INNER JOIN bettrans b on c.custid = b.custid
WHERE b.winlostdate >= DATEADD(dd, -1, @date)
	and matchid > 0
	and b.bettype < 19999
	and [status] not in ('VOID', 'REJECT', 'Refund')
	and (winlostdate = @date or DATEADD(dd, DATEDIFF(dd, 0, transdate), 0) = @date)
GROUP BY c.custid, c.currency, winlostdate, DATEADD(dd, DATEDIFF(dd, 0, transdate), 0), ruben

DECLARE @MoveBetsDay smalldatetime
SELECT @MoveBetsDay = max(eventdate) FROM match14 WITH(NOLOCK)
IF @date <= DATEADD(dd, 1, @MoveBetsDay)
BEGIN
	INSERT INTO #bettrans_TEMP(custid, currency, winlostdate, transdate, ruben, winlost, stake, actual_stake, playercomm)
	SELECT c.custid, c.currency, winlostdate, DATEADD(dd, DATEDIFF(dd, 0, transdate), 0) as transdate, ruben
		,sum(isnull(winlost,0))
		,sum(isnull(stake,0))
		,sum(isnull(actual_stake,0))
		,sum(isnull(playercomm,0))	
	FROM #DATA c 
		INNER JOIN bettrans14 b with(nolock) on c.custid = b.custid
	WHERE b.winlostdate >= DATEADD(dd, -1, @date)		
		and [status] not in ('VOID', 'REJECT', 'Refund')
		and (winlostdate = @date or DATEADD(dd, DATEDIFF(dd, 0, transdate), 0) = @date)
	GROUP BY c.custid, c.currency, winlostdate, DATEADD(dd, DATEDIFF(dd, 0, transdate), 0), ruben	
END

UPDATE data
SET openingbalance = isnull(s.closingbalance,0)
	,outstanding = isnull(s.outstanding,0)
FROM #DATA data
	INNER JOIN bodb_Report.dbo.rptDepWinlostTST s with(nolock) on data.custid = s.custid
where s.winlostdate = dateadd(dd, -1, @date)

;WITH B AS (
	SELECT
		custid, 
		SUM(actual_stake) Turnover,
		SUM(CASE WHEN winlostdate = @date and ruben=0 then actual_stake ELSE 0 END)-- RUNNING tickets got transdate today, winlostdate today
		+ SUM(CASE WHEN winlostdate > @date then actual_stake ELSE 0 END)--tickets got transdate today, but winlostdate in next days
			as Outstanding	
	FROM #bettrans_TEMP
	WHERE transdate = @date
	GROUP BY custid
)
UPDATE data
SET
	Turnover = IsNull(B.Turnover, 0),
	Outstanding = data.Outstanding + IsNull(b.Outstanding, 0)
FROM #DATA data
	INNER JOIN B ON data.custid = B.custid
	
;WITH B AS (
	SELECT custid
		,-isnull(sum(case when transdate < @date and ruben = 1 then actual_stake else 0 end),0) as Outstanding
		,isnull(sum(winlost + playercomm),0) as returnAMT
	FROM #bettrans_TEMP
	WHERe winlostdate = @date
	GROUP by custid
)
UPDATE data
SET Outstanding = data.Outstanding + IsNull(B.Outstanding, 0)
	,ReturnAmt = isnull(b.ReturnAmt,0)
	,ClosingBalance = data.openingbalance + isnull(r.deposit,0) + isnull(r.aff2memtransfer,0) 
		- isnull(r.withdrawal,0) + isnull(r.bonus,0) + isnull(r.adjustment,0)
		+ isnull(r.transfer3rd,0) - isnull(data.Turnover,0) + isnull(B.ReturnAmt,0)
FROM #DATA data
	LEFT JOIN B ON data.custid = B.custid
	LEFT JOIN bodb_Report.dbo.rptDepWinlost r with(nolock) on data.custid = r.custid
WHERE r.winlostdate = @date	

DELETE bodb_Report.dbo.rptDepWinlostTST WHERE Winlostdate = @date

insert into bodb_Report.dbo.rptDepWinlostTST (winlostdate, custid, currency, Turnover, recommend, mrecommend, srecommend, OpeningBalance, Outstanding, ReturnAmt, ClosingBalance)
select @date, custid, currency, Turnover, recommend, mrecommend, srecommend, OpeningBalance, Outstanding, ReturnAmt, ClosingBalance
from #DATA

DROP TABLE #DATA
DROP TABLE #bettrans_TEMP

