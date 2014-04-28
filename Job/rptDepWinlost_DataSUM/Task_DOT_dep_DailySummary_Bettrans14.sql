USE [bodb02]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

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
	PartnerId int, Transfer3rdOthers_Hogaming money default(0), Transfer3rdOthers_OPus money default(0)
	UNIQUE (custid, PartnerId, currency)
	)

Declare @BalanceUpDay smalldatetime
SELECT @BalanceUpDay = winlostdate
FROM Bettrans WITH(NOLOCK)
WHERE bettype = 20000 and matchid = 0 and custid = 3

INSERT INTO #Data (custid,currency, recommend, mrecommend, srecommend, PartnerId, OpeningBalance, Deposit,Aff2MemTransfer,
		Withdrawal, Bonus, Adjustment, Transfer3rd, Transfer3rdOthers_Hogaming, Transfer3rdOthers_OPus)
SELECT
	b.custid, b.currency, b.recommend, b.mrecommend, b.srecommend,
	CASE 
		WHEN bettype in (22008,22009) THEN 1 --Hogaming
		WHEN bettype in (22010,22011) THEN 2 --OPus
		ELSE -1 
	END PartnerId,
	SUM(CASE @date WHEN @BalanceUpDay 
			THEN CASE WHEN bettype = 20000 THEN winlost - actual_stake + playercomm ELSE 0 END 
			ELSE CASE WHEN winlostdate < @date THEN winlost - actual_stake + playercomm ELSE 0 END 
		END), -- openingbalance
	SUM( CASE WHEN winlostdate = @date AND bettype = 22001 then winlost-actual_stake ELSE 0 END), --Deposit
	SUM( CASE WHEN winlostdate = @date AND bettype = 21006 then winlost-actual_stake ELSE 0 END), --Aff2MemTransfer
	-SUM(CASE WHEN winlostdate = @date AND bettype in (22002,22003) then winlost-actual_stake ELSE 0 END),--Withdrawal
	SUM( CASE WHEN winlostdate = @date AND bettype = 22004 then winlost-actual_stake ELSE 0 END),--Bonus
	SUM( CASE WHEN winlostdate = @date AND bettype in (21001, 21002, 21003, 21004, 21005, 22005) then winlost-actual_stake ELSE 0 END), --Adjustment
	SUM( CASE WHEN winlostdate = @date AND bettype in (22006,22007) then winlost-actual_stake ELSE 0 END),--Transfer3rd
	SUM( CASE WHEN winlostdate = @date AND bettype in (22008,22009) then winlost-actual_stake ELSE 0 END),--Transfer3rdOthers_Hogaming
	SUM( CASE WHEN winlostdate = @date AND bettype in (22010,22011) then winlost-actual_stake ELSE 0 END)--Transfer3rdOthers_OPus
FROM bettrans b	with(readpast)
	inner join dep_custsuper s with(nolock) on s.custid = b.srecommend	
WHERE winlostdate <= @date
	and b.custid <> recommend and b.custid <> mrecommend and b.custid <> srecommend	
GROUP BY b.custid, b.currency, b.recommend, b.mrecommend, b.srecommend,
	CASE 
		WHEN bettype in (22008,22009) THEN 1 --Hogaming
		WHEN bettype in (22010,22011) THEN 2 --OPus
		ELSE -1 
	END

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

delete #Data
where Deposit = 0
	and Aff2MemTransfer = 0
	and Withdrawal = 0
	and Bonus = 0
	and Adjustment = 0
	and Transfer3rd = 0
	and Turnover = 0
	and DrawGame = 0
	and Outstanding = 0
	and Winloss = 0
	and openingbalance = 0
	and Playercomm = 0
	and Transfer3rdOthers_Hogaming = 0
	and Transfer3rdOthers_OPus = 0
	
;WITH B AS (  
	SELECT  
		b.custid,
		SUM(b.stake) turnover_ba,  
		SUM(b.comm) AS comm_ba,  
		-SUM(b.winlost - b.actual_stake + b.awinlost + b.comm) AS Amountdueto_ba    
	FROM bettrans14 b with(nolock)  
		inner join DBLIC.bodb_licensee.dbo.LicenseeBATransaction_bk ba with(nolock) 
			on b.transid = ba.transid and b.winlostdate = ba.winlostdate
	WHERE b.winlostdate = @date  
		AND b.ruben = 1  
		AND b.statusID NOT IN (101, 102, 103)  
	GROUP BY b.custid
)  	
UPDATE #Data  
SET  
	turnover_ba = isnull(b.turnover_ba,0),  
	comm_ba = isnull(b.comm_ba,0),  
	Amountdueto_ba = isnull(b.Amountdueto_ba,0)  
FROM B
WHERE #data.custid = b.custid

CREATE TABLE #DataByProduct (
	custid int, sporttype smallint, turnover money default(0), drawTO money default(0), 
	winlost money default(0), playercomm money default(0), betcount int default(0)
)  

INSERT INTO #DataByProduct(custid, sporttype, turnover, drawTO, winlost, playercomm, betcount)
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
	ELSE 0 END, -- sporttype
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
	ELSE 0 END

------
DELETE bodb_Report.dbo.rptDepWinlost WHERE Winlostdate = @date

insert into bodb_Report.dbo.rptDepWinlost
	(winlostdate, custid, currency, OpeningBalance, Deposit, Aff2MemTransfer, Withdrawal, Bonus, Adjustment, Transfer3rd,
	Turnover, DrawGame, Outstanding, Winloss, recommend, mrecommend, srecommend,ClosingBalance, actualrate,
	turnover_ba, comm_ba, Amountdueto_ba, playercomm, Transfer3rdOthers)
select @date, custid, d.currency, SUM(OpeningBalance), SUM(Deposit), SUM(Aff2MemTransfer), SUM(Withdrawal), SUM(Bonus), SUM(Adjustment), SUM(Transfer3rd),
	SUM(Turnover), SUM(DrawGame), SUM(Outstanding), SUM(Winloss), recommend, mrecommend, srecommend, 
	SUM(OpeningBalance + Deposit + Aff2MemTransfer - Withdrawal + Bonus + Adjustment - Outstanding + Winloss + playercomm + Transfer3rd + Transfer3rdOthers_Hogaming + Transfer3rdOthers_OPus), -- closingbalance
	MIN(e.actualrate), SUM(turnover_ba), SUM(comm_ba) , SUM(Amountdueto_ba), SUM(playercomm), SUM(Transfer3rdOthers_Hogaming + Transfer3rdOthers_OPus) Transfer3rdOthers
from #Data d
	inner join exchangedailyoanda e with(nolock) on d.currency = e.exchangeid
where exchangedate = @date
group by custid, currency, recommend, mrecommend, srecommend

-- Insert Playtech Casino summary data to rptDepWinlostByProduct
DECLARE @BackupDay DATE
SELECT @BackupDay = ISNULL(MIN(Winlostdate),'') FROM DBPTCS.bodb_PlaytechCS.dbo.bettrans_PlaytechCS

IF @date >= @BackupDay -- Get data in bettrans_PlaytechCS table
BEGIN
	INSERT INTO #DataByProduct(custid, sporttype, turnover, winlost, betcount, drawTO)
	SELECT b.CustID, 
		254 AS SportType,
		ISNULL(SUM(b.Stake),0) AS Turnover,
		ISNULL(SUM(b.Winlost - b.Actual_Stake),0) AS Winlost,
		ISNULL(COUNT(*),0) AS Betcount,
		ISNULL(SUM(CASE WHEN b.StatusID = 111 THEN b.Stake ELSE 0 END),0) AS DrawTO
	FROM DBPTCS.bodb_PlaytechCS.dbo.bettrans_PlaytechCS b WITH (ROWLOCK)
	WHERE Winlostdate = @date
	GROUP BY b.CustID
END
ELSE -- Get data in bettrans_PlaytechCS_bk table
BEGIN
	INSERT INTO #DataByProduct(custid, sporttype, turnover, winlost, betcount, drawTO)
	SELECT b.CustID, 
		254 AS SportType,
		ISNULL(SUM(b.Stake),0) AS Turnover,
		ISNULL(SUM(b.Winlost - b.Actual_Stake),0) AS Winlost,
		ISNULL(COUNT(*),0) AS Betcount,
		ISNULL(SUM(CASE WHEN b.StatusID = 111 THEN b.Stake ELSE 0 END),0) AS DrawTO
	FROM DBPTCSARC.bodb_PlaytechCS_archive.dbo.bettrans_PlaytechCS_bk b WITH (ROWLOCK)
	WHERE Winlostdate = @date
	GROUP BY b.CustID
END

-----
DELETE bodb_Report.dbo.rptDepWinlostByProduct WHERE Winlostdate = @date 

insert into bodb_Report.dbo.rptDepWinlostByProduct (
	winlostdate, custid, sporttype, turnover, drawTO, winlost, playercomm, betcount, outstanding)
select @date, custid, sporttype, turnover, drawTO, winlost, playercomm, betcount, 0
from #DataByProduct

DROP TABLE #DataByProduct

/* Fill data to rptDepWinlost_Transfer3rdOthers */
CREATE TABLE #rptDepWinlost_Transfer3rdOthers (
	CustId int
	,Currency int
	,PartnerId int
	,Recommend int
	,MRecommend int
	,SRecommend int
	,TransferAmount money default(0)
)

INSERT INTO #rptDepWinlost_Transfer3rdOthers(CustId,Currency,PartnerId,Recommend,MRecommend,SRecommend,TransferAmount)
	SELECT CustId,Currency,PartnerId,Recommend,MRecommend,SRecommend
		,SUM(
			CASE 
				WHEN PartnerId = 1 THEN Transfer3rdOthers_Hogaming --Hogaming
				WHEN PartnerId = 2 THEN Transfer3rdOthers_OPus --OPus
				ELSE 0
			END 
		) TransferAmount
	FROM #Data
	WHERE PartnerId > -1
	GROUP BY CustId,Currency,PartnerId,Recommend,MRecommend,SRecommend

DELETE #rptDepWinlost_Transfer3rdOthers WHERE TransferAmount = 0

DELETE bodb_Report.dbo.rptDepWinlost_Transfer3rdOthers WHERE Winlostdate = @date

INSERT INTO bodb_Report.dbo.rptDepWinlost_Transfer3rdOthers(winlostdate,CustId,Currency,PartnerId,Recommend,MRecommend,SRecommend,TransferAmount)
	SELECT @date,CustId,Currency,PartnerId,Recommend,MRecommend,SRecommend,TransferAmount
	FROM #rptDepWinlost_Transfer3rdOthers

DROP TABLE #rptDepWinlost_Transfer3rdOthers

/* End -- Fill data to rptDepWinlost_Transfer3rdOthers */

DROP TABLE #Data

SET NOCOUNT OFF