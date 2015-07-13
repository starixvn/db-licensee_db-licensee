USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Task_DOT_dep_DailySummary_Bettrans14]    Script Date: 06/10/2015 02:53:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.Task_DOT_dep_DailySummary_Bettrans14    Script Date: 4/14/2015 10:03:51 AM ******/


ALTER PROCEDURE [dbo].[Task_DOT_dep_DailySummary_Bettrans14]
	@winlostdate datetime
AS
/*	
	Task : Summary data for deposit member
	DB: DBACC/bodb02
	Revisions:	
		- 20100112@viet: created SP
		- 20101115@viet: change the way to get 'openingbalance' for balance-up-day's data
		- 20110516@Henry: change bettype to new range 
		- 20110804@Viet: enhance SP, only read data from bettrans once
		- 20110826@Viet: change the way to get 'openingbalance' for balance-up-day's data
		- 20111007@Viet: remove redundant rows		
		- 20111021@Viet: offer BA  
		- 20120803@Henry: add column playercomm
		- 20120911@Viet: add new product by bettype
        - 20130124@Daniel: Change link server alias		
		- 20130626@Don: 
			+ Adding one column to rptDepWinlost (Transfer3rdOthers)
			+ Adding one step to generate data to rptDepWinlost_Transfer3rdOthers
		- 20130920@Don: Updated from production environment is that prevent from duplicate data rows when fill data to #DataByProduct
	    - 20130904@Jim: support Virtual Horse Racing
		- 20130927@Don: Fix bug about value of winlost/turnover (greater real value)
		- 20131014@Jim: support Virtual Tennis
		- 20131128@Jim: revert code to Group by All Virtual Sport into sporttypeID=180
		- 20140310@Francis: support Keno product
		- 20140422@Victor: support Playtech Casino procduct
		- 20140515@Victor: Change Playtech Casino summary data process
		- 20140814@Don: Add AG Casino
		- 20140912@Victor: support AG Casino 3rd party product
		- 20141120@Don: Adjustment to serve to change KeenOcean's currency RMB to HK$
		- 20141129@Don: Fixed bug cause rptDepWinlost not to get data in November 29, 2014 (Redmine ID: 26866 related to revision 20141120@Don)
		- 20150116@Winnie: get tranferin tranferout for AG Casino
		- 20150324@Patrick: Re-arrange code to easy to plugin 3rd product
		- 20150414@Winnie: Re-add transferin/transfer out which have transferAmout=0 for AGBalance
		- 20150618@Patrick: #36263: Fix super balance issue for: AGC, GD & VG
		- 20150625@Patrick: #37769: Remove dummy account & exclude cancel transfer tickets for AG Casino (merge)
		- 20150630@Patrick: #38387: Support bettrade

	Param's Explanation:
	• @date: The date need to summary
*/
SET NOCOUNT ON
declare @date datetime
select @date = @winlostdate

CREATE TABLE #Data(custid int, currency int, 
	OpeningBalance money default(0), Deposit money default(0), Aff2MemTransfer money default(0), Withdrawal money default(0), Bonus money default(0), 
	Adjustment money default(0), Turnover money default(0), Outstanding money default(0), Winloss money default(0),
	recommend int, mrecommend int, srecommend int,
	Transfer3rd money default(0), DrawGame money default(0),
	turnover_ba money default (0), comm_ba money default(0), Amountdueto_ba money default(0), playercomm money default(0), 
	PartnerId int, Transfer3rdOthers money default(0),Transfer3rdOthers_In money default(0),Transfer3rdOthers_Out money default(0),
	comm_bettrade money default(0), amountdueto_bettrade money default(0)
	UNIQUE (custid, PartnerId, currency)
	)

Declare @BalanceUpDay smalldatetime
SELECT @BalanceUpDay = winlostdate
FROM Bettrans WITH(NOLOCK)
WHERE bettype = 20000 and matchid = 0 and custid = 3

CREATE TABLE #DepositCustSuper(CustID INT, Currency INT)
DECLARE @Sql VARCHAR(500)
SET @Sql = 
    'INSERT INTO #DepositCustSuper(CustID, Currency)
    SELECT CustID, Currency
    FROM OPENQUERY(DBLIC,''SELECT CustID, Currency FROM bodb_licensee.dbo.f_SelDepCustSuper('''''''')'')'
EXEC(@Sql)

--get bettype transfer of 3rd products
DECLARE @CasinoPartner TABLE (PartnerId INT, TransferId INT, CancelTransferId INT)
INSERT INTO @CasinoPartner(PartnerId, TransferId, CancelTransferId)
SELECT PartnerId, TransferId, CancelTransferId
FROM bodb_report.dbo.tblCasinoPartners WITH(NOLOCK)
WHERE TransferId IS NOT NULL OR CancelTransferId IS NOT NULL

--create table transferdata to calculate cancel tickets
CREATE TABLE #RefNoList (RefNo BIGINT)
CREATE TABLE #TransferData (CustId INT, currency TINYINT, recommend INT, mrecommend INT, srecommend INT, TransferIn MONEY, TransferOut MONEY, PartnerId INT)

INSERT INTO #Data (custid,currency, recommend, mrecommend, srecommend, PartnerId, OpeningBalance, Deposit,Aff2MemTransfer,
		Withdrawal, Bonus, Adjustment, Transfer3rd, Transfer3rdOthers,Transfer3rdOthers_In,Transfer3rdOthers_Out)
SELECT
	b.custid, 
	--b.currency, 
	CASE 
		WHEN b.recommend IN (14373731, 14373733) AND @date < '20141128' THEN 13
		WHEN b.recommend IN (14373731, 14373733) AND @date >= '20141128' THEN 66 
		ELSE b.currency 
	END,
	b.recommend, b.mrecommend, b.srecommend,
	CASE WHEN bettype in (p.TransferId, p.CancelTransferId) THEN p.PartnerId	ELSE -1 END PartnerId,
	SUM(CASE @date WHEN @BalanceUpDay 
			THEN CASE WHEN bettype = 20000 THEN winlost - actual_stake + playercomm ELSE 0 END 
			ELSE CASE WHEN winlostdate < @date THEN CASE WHEN bettype = 903 THEN 0 ELSE winlost - actual_stake + playercomm END ELSE 0 END 
		END), -- openingbalance: exclude betrade comm ticket
	SUM( CASE WHEN winlostdate = @date AND bettype = 22001 then winlost-actual_stake ELSE 0 END), --Deposit
	SUM( CASE WHEN winlostdate = @date AND bettype = 21006 then winlost-actual_stake ELSE 0 END), --Aff2MemTransfer
	-SUM(CASE WHEN winlostdate = @date AND bettype in (22002,22003) then winlost-actual_stake ELSE 0 END),--Withdrawal
	SUM( CASE WHEN winlostdate = @date AND bettype = 22004 then winlost-actual_stake ELSE 0 END),--Bonus
	SUM( CASE WHEN winlostdate = @date AND bettype in (21001, 21002, 21003, 21004, 21005, 22005) then winlost-actual_stake ELSE 0 END), --Adjustment
	SUM( CASE WHEN winlostdate = @date AND bettype in (22006,22007) then winlost-actual_stake ELSE 0 END),--Transfer3rd
	SUM( CASE WHEN winlostdate = @date AND bettype IN (p.TransferId, p.CancelTransferId) then winlost-actual_stake ELSE 0 END), --Transfer3rdOthers
	SUM( CASE WHEN winlostdate = @date AND bettype IN (p.TransferId, p.CancelTransferId) AND (winlost-actual_stake) < 0 THEN -(winlost-actual_stake) ELSE 0 END), --Transfer3rdOthers_In
	SUM( CASE WHEN winlostdate = @date AND bettype IN (p.TransferId, p.CancelTransferId) AND (winlost-actual_stake) > 0 THEN -(winlost-actual_stake) ELSE 0 END) --Transfer3rdOthers_Out
FROM dbo.bettrans b	with(readpast)
	--inner join dep_custsuper s with(nolock) on s.custid = b.srecommend
	INNER JOIN #DepositCustSuper s WITH(NOLOCK) ON s.custid = b.srecommend AND s.Currency = b.currency
	LEFT JOIN @CasinoPartner p ON b.bettype IN (p.TransferId, p.CancelTransferId)
WHERE winlostdate <= @date
	and b.custid <> recommend and b.custid <> mrecommend and b.custid <> srecommend	
GROUP BY b.custid, 
	--b.currency, 
	CASE 
		WHEN b.recommend IN (14373731, 14373733) AND @date < '20141128' THEN 13
		WHEN b.recommend IN (14373731, 14373733) AND @date >= '20141128' THEN 66 
		ELSE b.currency 
	END,
	b.recommend, b.mrecommend, b.srecommend,
	CASE WHEN bettype in (p.TransferId, p.CancelTransferId) THEN p.PartnerId	ELSE -1 END

INSERT INTO #RefNoList(RefNo)
SELECT refno
FROM dbo.bettrans b with(rowlock)
	INNER JOIN @CasinoPartner p ON b.bettype = p.CancelTransferId
	INNER JOIN dbo.customer c with(nolock) on b.custid = c.custid
	INNER JOIN #DepositCustSuper s WITH(NOLOCK) ON s.custid = c.srecommend AND s.Currency = b.currency
WHERE b.matchid = 0 AND b.winlostdate <= @date AND roleid = 1
GROUP BY refno
		
--get cancel transfer data
INSERT INTO #TransferData(CustId, currency, recommend, mrecommend, srecommend, PartnerId, TransferIn, TransferOut)
SELECT b.CustId, b.currency, b.recommend, b.mrecommend, b.srecommend, p.PartnerId
	, SUM( CASE WHEN b.winlostdate = @date AND (b.winlost-b.actual_stake) < 0 THEN -(b.winlost-b.actual_stake) ELSE 0 END) --TransferIn
	, SUM( CASE WHEN b.winlostdate = @date AND (b.winlost-b.actual_stake) > 0 THEN -(b.winlost-b.actual_stake) ELSE 0 END) --TransferOut
FROM dbo.bettrans b with(rowlock)
	INNER JOIN @CasinoPartner p ON b.bettype in (p.CancelTransferId, p.TransferId)
WHERE refno IN (SELECT refno FROM #RefNoList)
GROUP BY b.custid, b.currency, b.recommend, b.mrecommend, b.srecommend, p.PartnerId
	
;WITH B AS (
	SELECT
		b.custid,
		SUM( CASE WHEN [status] not in ('VOID', 'REJECT', 'Refund') then stake ELSE 0 END) Turnover,--Turnover
		SUM( CASE WHEN [status] = 'DRAW' then stake ELSE 0 END) DrawGame, --DrawGame
		SUM( CASE WHEN ruben=0 then actual_stake ELSE 0 END) Outstanding, --Outstanding
		SUM( CASE WHEN ruben=1 then winlost-actual_stake ELSE 0 END) Winloss, --Winloss				
		SUM( CASE WHEN ruben=1 then b.playercomm ELSE 0 END) Playercomm --Playercomm
	FROM bettrans14 b with(nolock)
		inner join #Data d on b.custid = d.custid and d.PartnerId = -1
	WHERE b.winlostdate = @date
	GROUP BY b.custid
)
UPDATE #Data
SET
	Turnover = case when PartnerId = -1 then isnull(b.Turnover,0) else 0 end,
	DrawGame = case when PartnerId = -1 then isnull(b.DrawGame,0) else 0 end, 
	Outstanding = case when PartnerId = -1 then isnull(b.Outstanding,0) else 0 end, 
	Winloss = case when PartnerId = -1 then isnull(b.Winloss,0) else 0 end, 
	Playercomm = case when PartnerId = -1 then isnull(b.Playercomm,0) else 0 end 
FROM B 
WHERE #Data.custid = b.custid

DELETE #Data
WHERE Deposit = 0
	AND Aff2MemTransfer = 0
	AND Withdrawal = 0
	AND Bonus = 0
	AND Adjustment = 0
	AND Transfer3rd = 0
	AND Turnover = 0
	AND DrawGame = 0
	AND Outstanding = 0
	AND Winloss = 0
	AND openingbalance = 0
	AND Playercomm = 0
	AND Transfer3rdOthers = 0
	AND Transfer3rdOthers_In = 0
	AND Transfer3rdOthers_Out = 0
	
CREATE TABLE #BATransactionHistory (TransId BIGINT, WinlostDate SMALLDATETIME)
DECLARE @sqlQuery VARCHAR(1024)
SELECT @sqlQuery = 'SELECT transid, WinlostDate
						FROM OPENQUERY(DBLIC, ''SELECT transid, WinlostDate
						FROM bodb_Licensee.dbo.LicenseeBATransaction_bk WITH (NOLOCK) WHERE WinlostDate = ''''' + CAST(@date AS VARCHAR(20)) + ''''''')'

INSERT INTO #BATransactionHistory (transid, WinlostDate)
EXEC (@sqlQuery)

;WITH B AS (  
	SELECT  
		b.custid,
		SUM(b.stake) turnover_ba,  
		SUM(b.comm) AS comm_ba,  
		-SUM(b.winlost - b.actual_stake + b.awinlost + b.comm) AS Amountdueto_ba    
	FROM bettrans14 b with(nolock)  
		--inner join DBLIC.bodb_licensee.dbo.LicenseeBATransaction_bk ba with(nolock) 
		INNER JOIN #BATransactionHistory ba
			on b.transid = ba.transid and b.winlostdate = ba.winlostdate
	WHERE b.winlostdate = @date  
		AND b.ruben = 1  
		AND b.statusID NOT IN (101, 102, 103)  
	GROUP BY b.custid
)  	
UPDATE #Data  
SET  
	turnover_ba = ISNULL(b.turnover_ba,0),  
	comm_ba = ISNULL(b.comm_ba,0),  
	Amountdueto_ba = ISNULL(b.Amountdueto_ba,0)  
FROM B
WHERE #data.custid = b.custid

;WITH bettradeData AS (  
	SELECT b.custid
		, SUM(CASE WHEN b.bettype = 903 THEN b.awinlost ELSE 0 END) AS comm_bettrade
		, SUM(CASE WHEN bt.CustId IS NOT NULL AND b.bettype NOT IN (902,903) THEN b.winlost - b.actual_stake ELSE 0 END) AS WLBeticket --WL of bet ticket of bettrade
		, SUM(CASE WHEN b.bettype = 902 THEN b.winlost - b.actual_stake ELSE 0 END) AS WLBoughtTicket --WL of bought ticket of bettrade
	FROM dbo.bettrans b with(rowlock)  
		LEFT JOIN dbo.f_GetBetTradeCustList('All') bt ON b.custid = bt.Custid AND b.Currency = bt.currency
	WHERE b.winlostdate = @date  
		AND (b.bettype < 31 OR b.bettype BETWEEN 121 AND 999 OR b.bettype BETWEEN 1301 AND 1399)
		AND b.ruben = 1  
		AND b.statusID NOT IN (101, 102, 103)  
	GROUP BY b.custid
)  
UPDATE #Data  
SET comm_bettrade = ISNULL(d.comm_bettrade, 0)
	, Amountdueto_bettrade = ISNULL(d.WLBeticket, 0) + ISNULL(d.WLBoughtTicket, 0) - ISNULL(d.comm_bettrade, 0)
FROM bettradeData d
WHERE #Data.custid = d.custid

DROP TABLE #BATransactionHistory

CREATE TABLE #DataByProduct (
	custid int, sporttype smallint, currency int, turnover money default(0), drawTO money default(0), 
	winlost money default(0), playercomm money default(0), betcount int default(0)
)  

INSERT INTO #DataByProduct(custid, sporttype, currency, turnover, drawTO, winlost, playercomm, betcount)
SELECT  
	b.custid, 
	CASE
		WHEN bettype IN (31,32,33,41,42,43) THEN 151 -- Horse Racing
		WHEN bettype IN (71,72) THEN 251 --casino
		WHEN bettype BETWEEN 81 AND 120 THEN 161 -- Number Game 
		WHEN bettype = 1000 THEN 253 --games
		WHEN bettype BETWEEN 1101 AND 1199 THEN 162 --Live Casino
		WHEN bettype BETWEEN 1201 AND 1299 THEN 180 --Virtual Sport
		WHEN bettype BETWEEN 1501 AND 1599 THEN 202 --Keno
		WHEN bettype BETWEEN 1800 AND 1899 THEN 250 -- AGC
		WHEN bettype BETWEEN 1700 AND 1799 THEN 255 -- GD
		WHEN bettype BETWEEN 1900 AND 1999 THEN 249 -- VG
		WHEN bettype = 901 THEN -2 -- BetTrade - Sold
		WHEN bettype = 902 THEN -3 -- BetTrade - Bought
		WHEN bettype = 903 THEN -4 -- BetTrade - Commission
	ELSE 0 END, -- sporttype
	b.currency,
	SUM(CASE WHEN [status] not in ('VOID', 'REJECT', 'Refund') then stake ELSE 0 END),--Turnover  
	SUM(case when [status] = 'DRAW' then stake else 0 end), -- Draw game TO			
	SUM(CASE WHEN ruben=1 then b.winlost-b.actual_stake ELSE 0 END), --Winloss      
	SUM(CASE WHEN ruben=1 then b.playercomm ELSE 0 END), --Playercomm      
	SUM(CASE WHEN [status] not in ('VOID', 'REJECT', 'Refund') then 1 ELSE 0 END) --betcount
FROM bettrans14 b with(rowlock)   
	inner join ( SELECT DISTINCT custid FROM #data ) d on b.custid = d.custid  
WHERE winlostdate = @date	
GROUP BY b.custid,
	CASE
		WHEN bettype IN (31,32,33,41,42,43) THEN 151 -- Horse Racing
		WHEN bettype IN (71,72) THEN 251 --casino
		WHEN bettype BETWEEN 81 AND 120 THEN 161 -- Number Game 
		WHEN bettype = 1000 THEN 253 --games
		WHEN bettype BETWEEN 1101 AND 1199 THEN 162 -- Live Casino
		WHEN bettype BETWEEN 1201 AND 1299  THEN 180 --Virtual Sport
		WHEN bettype BETWEEN 1501 AND 1599 THEN 202 --Keno
		WHEN bettype BETWEEN 1800 AND 1899 THEN 250 -- AGC
		WHEN bettype BETWEEN 1700 AND 1799 THEN 255 -- GD
		WHEN bettype BETWEEN 1900 AND 1999 THEN 249 -- VG
		WHEN bettype = 901 THEN -2 -- BetTrade - Sold
		WHEN bettype = 902 THEN -3 -- BetTrade - Bought
		WHEN bettype = 903 THEN -4 -- BetTrade - Commission
	ELSE 0 END,
	b.currency

------
DELETE bodb_Report.dbo.rptDepWinlost WHERE Winlostdate = @date

insert into bodb_Report.dbo.rptDepWinlost
	(winlostdate, custid, currency, OpeningBalance, Deposit, Aff2MemTransfer, Withdrawal, Bonus, Adjustment, Transfer3rd,
	Turnover, DrawGame, Outstanding, Winloss, recommend, mrecommend, srecommend,ClosingBalance, actualrate,
	turnover_ba, comm_ba, Amountdueto_ba, playercomm, Transfer3rdOthers, comm_bettrade, amountdueto_bettrade)
select @date, custid, d.currency, SUM(OpeningBalance), SUM(Deposit), SUM(Aff2MemTransfer), SUM(Withdrawal), SUM(Bonus), SUM(Adjustment), SUM(Transfer3rd),
	SUM(Turnover), SUM(DrawGame), SUM(Outstanding), SUM(Winloss), recommend, mrecommend, srecommend, 
	SUM(OpeningBalance + Deposit + Aff2MemTransfer - Withdrawal + Bonus + Adjustment - Outstanding + Winloss + playercomm + Transfer3rd + Transfer3rdOthers - comm_bettrade), -- closingbalance
	MIN(e.actualrate), SUM(turnover_ba), SUM(comm_ba) , SUM(Amountdueto_ba), SUM(playercomm), SUM(Transfer3rdOthers), --Transfer3rdOthers
	SUM(comm_bettrade), SUM(amountdueto_bettrade)
from #Data d
	inner join exchangedailyoanda e with(nolock) on d.currency = e.exchangeid
where exchangedate = @date
group by custid, currency, recommend, mrecommend, srecommend

-----
DELETE bodb_Report.dbo.rptDepWinlostByProduct WHERE Winlostdate = @date 

insert into bodb_Report.dbo.rptDepWinlostByProduct (
	winlostdate, custid, sporttype, currency, turnover, drawTO, winlost, playercomm, betcount, outstanding)
select @date, custid, sporttype, currency, turnover, drawTO, winlost, playercomm, betcount, 0
from #DataByProduct

DROP TABLE #DataByProduct

-- Execute SP to insert data for Playtech Casino
EXEC Task_DOT_PlaytechCS_DailySummary @winlostdate = @date

-- Execute SP to insert data for AG Casino
EXEC Task_DOT_AGCasino_DailySummary @winlostdate = @date

/* Fill data to rptDepWinlost_Transfer3rdOthers */
CREATE TABLE #rptDepWinlost_Transfer3rdOthers (
	CustId int
	,Currency int
	,PartnerId int
	,Recommend int
	,MRecommend int
	,SRecommend int
	,TransferAmount money default(0)
	,TransferIn money default(0)
	,TransferOut money default(0)
)

INSERT INTO #rptDepWinlost_Transfer3rdOthers(CustId,Currency,PartnerId,Recommend,MRecommend,SRecommend,TransferAmount,TransferIn,TransferOut)
	SELECT b.CustId,b.Currency,b.PartnerId,b.Recommend,b.MRecommend,b.SRecommend
		, SUM(Transfer3rdOthers) --TransferAmount
		, SUM(Transfer3rdOthers_In - ISNULL(d.TransferIn, 0)) --TransferIn
		, SUM(Transfer3rdOthers_Out - ISNULL(d.TransferOut, 0)) --TransferOut
	FROM #Data b
	INNER JOIN bodb02.dbo.customer c with(nolock) on b.custid = c.custid  
	INNER JOIN bodb02.dbo.customer agent with(nolock) on b.recommend = agent.custid  
	LEFT JOIN #TransferData d on b.custid = d.CustId and b.currency = d.currency and b.PartnerId = d.PartnerId
	WHERE b.PartnerId > -1
	AND (c.username2 IS NOT NULL OR (c.username2 IS NULL AND agent.username NOT LIKE '%ACC%'))	
	GROUP BY b.CustId,b.Currency,b.PartnerId,b.Recommend,b.MRecommend,b.SRecommend

DELETE #rptDepWinlost_Transfer3rdOthers WHERE TransferAmount = 0 AND TransferIn=0 AND TransferOut=0

DELETE bodb_Report.dbo.rptDepWinlost_Transfer3rdOthers WHERE Winlostdate = @date

INSERT INTO bodb_Report.dbo.rptDepWinlost_Transfer3rdOthers(winlostdate,CustId,Currency,PartnerId,Recommend,MRecommend,SRecommend,TransferAmount,TransferIn,TransferOut)
	SELECT @date,CustId,Currency,PartnerId,Recommend,MRecommend,SRecommend,TransferAmount,TransferIn,TransferOut
	FROM #rptDepWinlost_Transfer3rdOthers

DROP TABLE #rptDepWinlost_Transfer3rdOthers

/* End -- Fill data to rptDepWinlost_Transfer3rdOthers */

DROP TABLE #Data
DROP TABLE #DepositCustSuper

SET NOCOUNT OFF
GO
GRANT EXECUTE ON [dbo].[Task_DOT_dep_DailySummary_Bettrans14] TO [Dot_Admin] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Task_DOT_dep_DailySummary_Bettrans14] TO [vnteam] AS [dbo]