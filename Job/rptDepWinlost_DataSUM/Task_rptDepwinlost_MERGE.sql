USE [bodb_Report]
GO
/****** Object:  StoredProcedure [dbo].[Task_rptDepwinlost_MERGE]    Script Date: 04/09/2014 21:16:12 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Task_rptDepwinlost_MERGE] 	
	@cnt int,
	@strXML varchar(MAX)
AS
/*   
 Task : Summary data for deposit member  
 DB: DB06.bodb_report
 Revisions:   
  - 20120930@viet: create SP   
  - 20130627@Don: modify formula to calculate ClosingBalance, plus Tranfer3rdOthers
                 
 Param's Explanation:  
 • @winlostdate: The date need to summary  
*/  
SET NOCOUNT ON
SET DEADLOCK_PRIORITY LOW	

IF EXISTS(SELECT 1 FROM bodb02.dbo.SystemSettings WITH(NOLOCK) WHERE VValue = '1' AND VName = 'isCalculatingDEPdata')
BEGIN	
	RETURN
END

DECLARE @_xml XML
SELECT @_xml = CONVERT(XML, @strXML)
SELECT	
	CAST(T.C.value('./@a0', 'int') as smalldatetime) winlostdate, 
	T.C.value('./@a1', 'int') custid, 
	T.C.value('./@a2', 'int') currency,
	isnull(T.C.value('./@a3', 'money'), 0) deposit,
	isnull(T.C.value('./@a4', 'money'), 0) withdrawal,
	isnull(T.C.value('./@a5', 'money'), 0) aff2memtransfer,
	isnull(T.C.value('./@a6', 'money'), 0) bonus,
	isnull(T.C.value('./@a7', 'money'), 0) adjustment,
	isnull(T.C.value('./@a8', 'money'), 0) turnover,
	isnull(T.C.value('./@a9', 'money'), 0) outstanding,
	isnull(T.C.value('./@b0', 'money'), 0) winloss,
	T.C.value('./@b1', 'int') recommend,
	T.C.value('./@b2', 'int') mrecommend,
	T.C.value('./@b3', 'int') srecommend,
	isnull(T.C.value('./@b4', 'money'), 0) transfer3rd,
	isnull(T.C.value('./@b5', 'money'), 0) drawgame,
	isnull(T.C.value('./@b6', 'money'), 0) turnover_ba,
	isnull(T.C.value('./@b7', 'money'), 0) comm_ba,
	isnull(T.C.value('./@b8', 'money'), 0) amountdueto_ba,
	isnull(T.C.value('./@b9', 'money'), 0) playercomm,
	isnull(T.C.value('./@c0', 'money'), 0) transfer3rdothers,
	cast(0 as money) AS OpeningBalance,
	cast(0 as money) AS ClosingBalance,
	cast(0 as float) AS actualrate
INTO #TEMP		
from @_xml.nodes('/root/r') as [T](C)

UPDATE d
	SET openingbalance = s.closingbalance				
FROM #TEMP d
	INNER JOIN dbo.rptdepwinlost s with(rowlock) on d.custid = s.custid and d.winlostdate = dateadd(dd, 1, s.winlostdate)	
 
declare @updated_list as table(custid int, winlostdate smalldatetime)
UPDATE d
	SET winlostdate = s.winlostdate
		,custid = s.custid
		,currency = s.currency
		,OpeningBalance = s.OpeningBalance
		,Deposit = s.Deposit
		,Withdrawal = s.Withdrawal
		,Aff2MemTransfer = s.Aff2MemTransfer
		,Bonus = s.Bonus
		,Adjustment = s.Adjustment
		,Turnover = s.Turnover
		,Outstanding = s.Outstanding
		,Winloss = s.Winloss
		,ClosingBalance = s.openingbalance + s.Deposit + s.Aff2MemTransfer - s.Withdrawal + s.Bonus + s.Adjustment - s.Outstanding + s.Winloss + s.playercomm + s.Transfer3rd + s.transfer3rdothers
		--,recommend = s.recommend
		--,mrecommend = s.mrecommend
		--,srecommend = s.srecommend
		--,actualrate = s.actualrate
		,Transfer3rd = s.Transfer3rd
		,DrawGame = s.DrawGame		
		,Turnover_BA = s.Turnover_BA
		,Comm_BA = s.Comm_BA
		,AmountDueTo_BA = s.AmountDueTo_BA
		,playercomm = s.playercomm
		,Transfer3rdOthers = s.transfer3rdothers
OUTPUT inserted.custid, inserted.winlostdate into @updated_list		
FROM dbo.rptDepWinlost d WITH(ROWLOCK, UPDLOCK)
	INNER JOIN #TEMP s on d.custid = s.custid and d.winlostdate = s.winlostdate

DELETE D
FROM #TEMP D
	INNER JOIN @updated_list s on d.custid = s.custid and d.winlostdate = s.winlostdate

insert into dbo.rptDepWinlost   
	(winlostdate, custid, currency, OpeningBalance, Deposit, Aff2MemTransfer, Withdrawal, Bonus, Adjustment, Transfer3rd,  
	Turnover, DrawGame, Outstanding, Winloss, recommend, mrecommend, srecommend,ClosingBalance, actualrate,  
	turnover_ba, comm_ba, Amountdueto_ba, playercomm, Transfer3rdOthers)
select winlostdate, custid, s.currency, OpeningBalance, Deposit, Aff2MemTransfer, Withdrawal, Bonus, Adjustment, Transfer3rd,  
	Turnover, DrawGame, Outstanding, Winloss, recommend, mrecommend, srecommend,   
	OpeningBalance + Deposit + Aff2MemTransfer - Withdrawal + Bonus + Adjustment - Outstanding + Winloss + playercomm + Transfer3rd, -- closingbalance  
	e.actualrate,turnover_ba, comm_ba, Amountdueto_ba , playercomm, Transfer3rdOthers
from #TEMP s
	inner join bodb02.dbo.exchangedailyoanda e with(nolock) on s.currency = e.exchangeid and s.winlostdate = e.exchangedate 

drop table #TEMP
SET NOCOUNT OFF