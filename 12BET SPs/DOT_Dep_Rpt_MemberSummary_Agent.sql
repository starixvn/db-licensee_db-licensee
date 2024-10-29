/*<info serverAlias="DBACC-bodb02" executers="ow_12bet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[DOT_Dep_Rpt_MemberSummary_Agent]
	@fromDate smalldatetime,
	@toDate smalldatetime,
	@CustId INT,
	@agentid NVARCHAR(3500)
AS
/*
DB: DB06.bodb02
Revisions: 
--20130723@Benson(DB06): Get Transfer_Opus data from rptDepWinlost_Transfer3rdOthers.
--20130806@Benson(DB06): fix Transfer3rd_Opus return null 
--20131107@BEnson(DB06): fix today Withdrawal Positive and negative exchange
--20140327@Benson(DB06): add HoGaming column
--20140819@Howard(DB06): Add AG Column
--20150327@Hugo(DB06)  : Add GD Report Data
--20150424@Angus(DB06)  : Add VB Report Data
--20150925@Angus(DB06)  : Add CRYSTAL Report Data
--20160721@Matthew(DB06) : Add LBKeno Report Data
--20170306@Matthew(DB06) :Add Opal Report Data
--20170605@Simon(DB06) :Add BetSoft(Amber) Report Data
--20170721@Benson(DB06): Turnover Data exclude cashout data
--20170814@ZiYang(DB06) :Add iSoftBet(Quartz) Report Data
--20171124@Angus(DB06) :Add CitiBet(Exchange) Report Data
--20180806@James(DB06) :Add Topaz(FG) Report Data
--20190313@James(DB06) :Add IMone Report Data
--20190319@Angus(DB06) :Add BTi Report Data
--20190716@James(DB06) :Add VRLottery Report Data
--20190916@Rong(DB06) :Add Sapphire Report Data
--20191218@Benson: Add select promotion column
--20191227@Benson: hotfix column of promotion not aligned
--20200107@Benson: new FG replace old FG, PartnerId 13->18 | bettype 22032,22033 -> 22042,22043
--20200317@Rong(DB06) :Add KYGaming Report Data
--20200630@James(DB06) :Add Moonstone Report Data
--20200813@Angus:Add Loyalty Program bet type in the promotion
--20201208@Rong(DB06) :Add EA and N2Live Report Data
--20210310@Ruby(DB06) :Add IDNPoker Report Data
--20210419@Ruby(DB06) :Add BG Report Data
--20210518@Max(DB06) :Add AVPMini, AVPSlot Report Data
--20220211@Benson(DB06.bodb02): Split Transfer out of bettrans
--20220325@Mei (DB06X): change function strsplit to STRING_SPLIT
--20220722@Ruby(DB06) :Add EVO Report Data
--20220830@Ruby(DB06) :Add Betradar Report Data
--20220830@Ruby(DB06) :Add PP Report Data
--20221125@Ruby: Remove CB sport, HoGaming, Opus, GD, VB, LBKeno, iSoftBet(Quartz), IDNPoker Report Data
--20230320@Benson: add promotion bettyp(4299,4300,4298,4297,17004,3007,1699,1698,3150,1906,3899,3898,4600,4599,4598,2499,8700)
--20230505@Mark(DB06):Add SGWin Report Data
--20230607@KenYang(DB06):Add PMSports, PMLive Report Data
--20230727@Ruby(DB06):Add BT1 Report Data
--20231225@KenYang(DB06):Add JILISlot, PGSoft Report Data
--20240104@Benson: Add Saba Reward Risk free Rebate (bettype: 17007) in the promotion
--20240410@Eddie: Change metadata 'Dot_Admin,Dot_Member' to 'ow_12bet' - [Redmine: #202118]
--20240620@Benson: Add Saba Coins Cash Exchange (bettype: 17008) in the promotion 
--20241011@KenYang(DB06): 1.Add Spribe Report Data. 
                          2.Remove IMone, VRLottery, Moonstone, EA, N2Live, BG, SGWin, PMSports, PMLive transfer columns
*/
SET @agentid = [dbo].[f_StrRtrimLastSeparator] (@agentid,',')

DECLARE @dbtodaydate SMALLDATETIME
SET @dbtodaydate = CONVERT(NVARCHAR(10),CURRENT_TIMESTAMP,120)

DECLARE @CutDate datetime
SELECT @CutDate =  min(winlostdate) from bodb_report.dbo.rptdepwinlost with(nolock) 

DECLARE @TodayData TABLE (
	custid int, currency int, OpeningBalance money default(0), Deposit money default(0), 
	Withdrawal money default(0), Bonus money default(0), Adjustment money default(0), Turnover money default(0), 
	DrawGame money default(0),	Outstanding money default(0),Winloss money default(0),Transfer3rd money default(0),
	ClosingBalance money default(0),Aff2MemTransfer money default(0),recommend int, mrecommend int, srecommend int, 
	actualrate float, Promotion money, Transfer3rd_AG money default(0),
	Transfer3rd_CRYSTAL money default(0),
	Transfer3rd_Opal money default(0), Transfer3rd_BetSoft money default(0), Transfer3rd_CitiBet money default(0),
	Transfer3rd_Topaz money default(0), Transfer3rd_BTi money default(0),
	Transfer3rd_Sapphire money default(0), Transfer3rd_KYGaming money default(0),
	Transfer3rd_AVPMini money default(0), Transfer3rd_AVPSlot money default(0),
	Transfer3rd_EVO money default(0), Transfer3rd_Betradar money default(0), Transfer3rd_PP money default(0),
	Transfer3rd_BT1 money default(0), Transfer3rd_JILISlot money default(0), Transfer3rd_PGSoft money default(0), Transfer3rd_Spribe money default(0))

DECLARE @WinlostTmp TABLE (
	winlostdate datetime, custid int, currency int, OpeningBalance money default(0), Deposit money default(0), 
	Withdrawal money default(0), Bonus money default(0), Adjustment money default(0), Turnover money default(0), 
	DrawGame money default(0),	Outstanding money default(0),Winloss money default(0),Transfer3rd money default(0),
	ClosingBalance money default(0),Aff2MemTransfer money default(0), recommend int, mrecommend int, srecommend int, 
	actualrate float, Promotion money)

DECLARE @WinlostTmp_CastOutTurnover TABLE (
	custid int, Turnover money default(0), winlostdate datetime
)
--Get Transfer 3rd Winlost data
DECLARE @WinlostTransfer3rd TABLE(
	CustId int , winlostdate datetime, Transfer3rd_AG money,
	Transfer3rd_CRYSTAL money, Transfer3rd_Opal money, Transfer3rd_BetSoft money,
	Transfer3rd_CitiBet money, Transfer3rd_Topaz money, Transfer3rd_BTi money,
	Transfer3rd_Sapphire money, Transfer3rd_KYGaming money,
	Transfer3rd_AVPMini money, Transfer3rd_AVPSlot money, Transfer3rd_EVO money, Transfer3rd_Betradar money, Transfer3rd_PP money,
	Transfer3rd_BT1 money, Transfer3rd_JILISlot money, Transfer3rd_PGSoft money, Transfer3rd_Spribe money)

IF (@fromDate < @CutDate) OR (@toDate < @CutDate)
BEGIN
	INSERT INTO @WinlostTmp
	SELECT b.winlostdate, b.custid, b.currency, b.OpeningBalance, b.Deposit, b.Withdrawal, b.Bonus, b.Adjustment, b.Turnover, b.DrawGame, b.Outstanding, 
		   b.Winloss, b.Transfer3rd, b.ClosingBalance, b.Aff2MemTransfer, b.recommend, b.mrecommend, b.srecommend, b.actualrate, b.Promotion
	FROM bodb_Report.dbo.rptDepWinlost_bk b WITH(NOLOCK)
	WHERE  (winlostdate BETWEEN @fromDate AND @toDate)
		AND b.custid = @Custid AND b.recommend IN (SELECT value FROM STRING_SPLIT(@agentid,',')) 

	INSERT INTO @WinlostTmp_CastOutTurnover
	SELECT custid, SUM(turnover), winlostdate
	FROM bodb_Report.dbo.rptDepWinlostByProduct_BK WITH(NOLOCK)
	WHERE (winlostdate BETWEEN @fromDate AND @toDate)
		AND custid = @Custid AND sporttype = -6
	GROUP BY winlostdate, custid

	INSERT INTO @WinlostTransfer3rd (CustId, winlostdate, Transfer3rd_AG,
	Transfer3rd_CRYSTAL, Transfer3rd_Opal, Transfer3rd_BetSoft, Transfer3rd_CitiBet, Transfer3rd_Topaz,
	Transfer3rd_BTi, Transfer3rd_Sapphire, Transfer3rd_KYGaming,
	Transfer3rd_AVPMini, Transfer3rd_AVPSlot, Transfer3rd_EVO, Transfer3rd_Betradar, Transfer3rd_PP,
	Transfer3rd_BT1, Transfer3rd_JILISlot, Transfer3rd_PGSoft, Transfer3rd_Spribe)
	SELECT custid, winlostdate, SUM(CASE PartnerId WHEN 3 THEN TransferAmount ELSE 0 END), --AG
								SUM(CASE PartnerId WHEN 7 THEN TransferAmount ELSE 0 END), --CRYSTAL
								SUM(CASE PartnerId WHEN 9 THEN TransferAmount ELSE 0 END), --Opal
								SUM(CASE PartnerId WHEN 10 THEN TransferAmount ELSE 0 END), --BetSoft(Amber)
								SUM(CASE PartnerId WHEN 12 THEN TransferAmount ELSE 0 END), --CitiBet(Exchange)
								SUM(CASE WHEN PartnerId IN (13,18) THEN TransferAmount ELSE 0 END), --Topaz(FG)
								SUM(CASE PartnerId WHEN 15 THEN TransferAmount ELSE 0 END), --BTi
								SUM(CASE PartnerId WHEN 17 THEN TransferAmount ELSE 0 END), --Sapphire
								SUM(CASE PartnerId WHEN 19 THEN TransferAmount ELSE 0 END), --KYGaming
								SUM(CASE PartnerId WHEN 25 THEN TransferAmount ELSE 0 END), --AVPMini
								SUM(CASE PartnerId WHEN 26 THEN TransferAmount ELSE 0 END), --AVPSlot
								SUM(CASE PartnerId WHEN 27 THEN TransferAmount ELSE 0 END), --EVO
								SUM(CASE PartnerId WHEN 28 THEN TransferAmount ELSE 0 END), --Betradar
								SUM(CASE PartnerId WHEN 29 THEN TransferAmount ELSE 0 END), --PP
								SUM(CASE PartnerId WHEN 33 THEN TransferAmount ELSE 0 END), --BT1
								SUM(CASE PartnerId WHEN 34 THEN TransferAmount ELSE 0 END), --JILISlot
								SUM(CASE PartnerId WHEN 35 THEN TransferAmount ELSE 0 END), --PGSoft
								SUM(CASE PartnerId WHEN 14 THEN TransferAmount ELSE 0 END)  --Spribe
	FROM bodb_Report.dbo.rptDepWinlost_Transfer3rdOthers_bk  WITH (NOLOCK) 
	WHERE  (winlostdate BETWEEN @fromDate AND @toDate)	
		AND custid = @Custid AND recommend IN (SELECT value FROM STRING_SPLIT(@agentid,','))  
	GROUP BY winlostdate,CustId

END

IF (@fromDate >= @CutDate) OR (@toDate >= @CutDate)
BEGIN
	INSERT INTO @WinlostTmp
	SELECT b.winlostdate, b.custid, b.currency, b.OpeningBalance, b.Deposit, b.Withdrawal, b.Bonus, b.Adjustment, b.Turnover, b.DrawGame, b.Outstanding, 
		   b.Winloss, b.Transfer3rd, b.ClosingBalance, b.Aff2MemTransfer, b.recommend, b.mrecommend, b.srecommend, b.actualrate, b.Promotion
	FROM bodb_Report.dbo.rptDepWinlost b WITH(NOLOCK)
	WHERE  (winlostdate between @fromDate AND @toDate)
		AND winlostdate <> @dbtodaydate
		AND b.custid = @Custid	AND b.recommend IN (SELECT value FROM STRING_SPLIT(@agentid,',')) 

	INSERT INTO @WinlostTmp_CastOutTurnover
	SELECT custid, SUM(turnover), winlostdate
	FROM bodb_Report.dbo.rptDepWinlostByProduct WITH(NOLOCK)
	WHERE (winlostdate between @fromDate AND @toDate)
		AND winlostdate <> @dbtodaydate
		AND custid = @Custid AND sporttype = -6
	GROUP BY winlostdate, custid

	INSERT INTO @WinlostTransfer3rd (CustId, winlostdate, Transfer3rd_AG,
	Transfer3rd_CRYSTAL, Transfer3rd_Opal, Transfer3rd_BetSoft, Transfer3rd_CitiBet, Transfer3rd_Topaz,
	Transfer3rd_BTi, Transfer3rd_Sapphire, Transfer3rd_KYGaming,
	Transfer3rd_AVPMini, Transfer3rd_AVPSlot, Transfer3rd_EVO, Transfer3rd_Betradar, Transfer3rd_PP,
	Transfer3rd_BT1, Transfer3rd_JILISlot, Transfer3rd_PGSoft, Transfer3rd_Spribe)
	SELECT custid, winlostdate, SUM(CASE PartnerId WHEN 3 THEN TransferAmount ELSE 0 END) , --AG
								SUM(CASE PartnerId WHEN 7 THEN TransferAmount ELSE 0 END),  --CRYSTAL
								SUM(CASE PartnerId WHEN 9 THEN TransferAmount ELSE 0 END),  --Opal
								SUM(CASE PartnerId WHEN 10 THEN TransferAmount ELSE 0 END),  --BetSoft(Amber)
								SUM(CASE PartnerId WHEN 12 THEN TransferAmount ELSE 0 END),  --CitiBet(Exchange)
								SUM(CASE WHEN PartnerId IN (13,18) THEN TransferAmount ELSE 0 END),  --Topaz(FG)
								SUM(CASE PartnerId WHEN 15 THEN TransferAmount ELSE 0 END),  --BTi
								SUM(CASE PartnerId WHEN 17 THEN TransferAmount ELSE 0 END),  --Sapphire
								SUM(CASE PartnerId WHEN 19 THEN TransferAmount ELSE 0 END),  --KYGaming
								SUM(CASE PartnerId WHEN 25 THEN TransferAmount ELSE 0 END),  --AVPMini
								SUM(CASE PartnerId WHEN 26 THEN TransferAmount ELSE 0 END),  --AVPSlot
								SUM(CASE PartnerId WHEN 27 THEN TransferAmount ELSE 0 END),  --EVO
								SUM(CASE PartnerId WHEN 28 THEN TransferAmount ELSE 0 END),  --Betradar
								SUM(CASE PartnerId WHEN 29 THEN TransferAmount ELSE 0 END),  --PP
								SUM(CASE PartnerId WHEN 33 THEN TransferAmount ELSE 0 END),  --BT1
								SUM(CASE PartnerId WHEN 34 THEN TransferAmount ELSE 0 END),  --JILISlot
								SUM(CASE PartnerId WHEN 35 THEN TransferAmount ELSE 0 END),  --PGSoft
								SUM(CASE PartnerId WHEN 14 THEN TransferAmount ELSE 0 END)   --Spribe
	FROM bodb_Report.dbo.rptDepWinlost_Transfer3rdOthers WITH (NOLOCK) 
	WHERE  (winlostdate BETWEEN @fromDate AND @toDate) AND winlostdate <> @dbtodaydate
		AND custid = @Custid AND recommend IN (SELECT value FROM STRING_SPLIT(@agentid,','))  
	GROUP BY winlostdate,CustId
END

IF (@toDate >= @dbtodaydate)
BEGIN 
	DECLARE @TodayOpeningBalance MONEY
	SELECT @TodayOpeningBalance = d.ClosingBalance
	FROM bodb_report.dbo.rptdepwinlost d WITH(NOLOCK)
	WHERE d.custid = @CustId AND d.winlostdate = DATEADD(dd, -1, @dbtodaydate)

	INSERT INTO @TodayData (custid, currency, recommend, mrecommend, srecommend, OpeningBalance, Deposit, Aff2MemTransfer, Withdrawal, Bonus, Adjustment,
							Transfer3rd, Turnover, DrawGame, Outstanding, Winloss, Transfer3rd_AG, Transfer3rd_CRYSTAL, Transfer3rd_Opal,
							Transfer3rd_BetSoft, Transfer3rd_CitiBet, Transfer3rd_Topaz, Transfer3rd_BTi, Transfer3rd_Sapphire, Transfer3rd_KYGaming,
							Transfer3rd_AVPMini, Transfer3rd_AVPSlot, Transfer3rd_EVO, Transfer3rd_Betradar, Transfer3rd_PP,
							Transfer3rd_BT1, Transfer3rd_JILISlot, Transfer3rd_PGSoft, Transfer3rd_Spribe, Promotion)
	SELECT 
		ISNULL(B.custid, T.CustId) AS custid,
		ISNULL(B.currency, T.Currency) AS Currency, 
		ISNULL(B.recommend, T.recommend) AS recommend, 
		ISNULL(B.mrecommend, T.mrecommend) AS mrecommend, 
		ISNULL(B.srecommend, T.srecommend) AS srecommend,
		@TodayOpeningBalance AS OpeningBalance,
		ISNULL(Deposit, 0), ISNULL(Aff2MemTransfer, 0), ISNULL(Withdrawal, 0), ISNULL(Bonus, 0), ISNULL(Adjustment, 0),
		ISNULL(Transfer3rd, 0), ISNULL(Turnover, 0), ISNULL(DrawGame, 0), ISNULL(Outstanding, 0), ISNULL(Winloss, 0),
		ISNULL(Transfer3rd_AG, 0),
		ISNULL(Transfer3rd_CRYSTAL, 0), ISNULL(Transfer3rd_Opal, 0), ISNULL(Transfer3rd_BetSoft, 0),
		ISNULL(Transfer3rd_CitiBet, 0), ISNULL(Transfer3rd_Topaz, 0),
		ISNULL(Transfer3rd_BTi, 0), ISNULL(Transfer3rd_Sapphire, 0), ISNULL(Transfer3rd_KYGaming, 0),
		ISNULL(Transfer3rd_AVPMini, 0), ISNULL(Transfer3rd_AVPSlot, 0), ISNULL(Transfer3rd_EVO, 0), ISNULL(Transfer3rd_Betradar, 0), ISNULL(Transfer3rd_PP, 0),
		ISNULL(Transfer3rd_BT1, 0), ISNULL(Transfer3rd_JILISlot, 0), ISNULL(Transfer3rd_PGSoft, 0), ISNULL(Transfer3rd_Spribe, 0),  ISNULL(Promotion, 0)
	FROM
	(
		SELECT custid, currency, recommend, mrecommend, srecommend,
			SUM(CASE WHEN winlostdate = @dbtodaydate AND bettype <> 911 AND [status] NOT IN ('VOID', 'REJECT', 'Refund') THEN stake ELSE 0 END) AS 'Turnover',
			SUM(CASE WHEN winlostdate = @dbtodaydate AND [status] = 'DRAW' THEN stake ELSE 0 END) AS 'DrawGame',
			SUM(CASE WHEN ruben = 0 THEN actual_stake ELSE 0 END) AS 'Outstanding',
			SUM(CASE WHEN winlostdate = @dbtodaydate AND bettype NOT IN (17000,17003,4299,4300,4298,4297,17004,3007,1699,1698,3150,1906,3899,3898,4600,4599,4598,2499,8700,17007,17008) AND ruben = 1 THEN winlost-actual_stake+playercomm ELSE 0 END) AS 'Winloss',
			SUM(CASE WHEN winlostdate = @dbtodaydate AND bettype IN (17000,17003,4299,4300,4298,4297,17004,3007,1699,1698,3150,1906,3899,3898,4600,4599,4598,2499,8700,17007,17008) THEN winlost-actual_stake ELSE 0 END) AS 'Promotion' -- Promotion, Royalty Program
		FROM bodb02.dbo.bettrans WITH(NOLOCK)
		WHERE custid = @CustId AND recommend IN (SELECT value FROM STRING_SPLIT(@agentid,',')) 
		GROUP BY custid, currency, recommend, mrecommend, srecommend
	) AS B
	FULL JOIN
	(
		SELECT custid, currency, recommend, mrecommend, srecommend,
		   SUM(CASE WHEN bettype = 22001 THEN winlost-actual_stake ELSE 0 END) AS 'Deposit',
		   SUM(CASE WHEN bettype = 21006 THEN winlost-actual_stake ELSE 0 END) AS 'Aff2MemTransfer',
		   SUM(CASE WHEN bettype IN (22002,22003) THEN winlost-actual_stake ELSE 0 END)*-1 AS 'Withdrawal',
		   SUM(CASE WHEN bettype = 22004 THEN winlost-actual_stake ELSE 0 END) AS 'Bonus',
		   SUM(CASE WHEN bettype IN (21001,21002,21003,21004,21005,22005) THEN winlost-actual_stake ELSE 0 END) AS 'Adjustment',
		   SUM(CASE WHEN bettype IN (22006,22007) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd',
		   SUM(CASE WHEN bettype IN (22008,22009) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_HoGaing', 
		   SUM(CASE WHEN bettype IN (22014,22015) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_AG',
		   SUM(CASE WHEN bettype IN (22020,22021) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_CRYSTAL',
		   SUM(CASE WHEN bettype IN (22024,22025) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_Opal',
		   SUM(CASE WHEN bettype IN (22026,22027) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_BetSoft',
		   SUM(CASE WHEN bettype IN (22030,22031) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_CitiBet',
		   SUM(CASE WHEN bettype IN (22032,22033,22042,22043) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_Topaz',
		   SUM(CASE WHEN bettype IN (22036,22037) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_BTi',
		   SUM(CASE WHEN bettype IN (22040,22041) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_Sapphire',
		   SUM(CASE WHEN bettype IN (22044,22045) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_KYGaming',
		   SUM(CASE WHEN bettype IN (22056,22057) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_AVPMini',
		   SUM(CASE WHEN bettype IN (22058,22059) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_AVPSlot',
		   SUM(CASE WHEN bettype IN (22060,22061) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_EVO',
		   SUM(CASE WHEN bettype IN (22062,22063) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_Betradar',
		   SUM(CASE WHEN bettype IN (22064,22065) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_PP',
		   SUM(CASE WHEN bettype IN (22072,22073) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_BT1',
		   SUM(CASE WHEN bettype IN (22074,22075) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_JILISlot',
		   SUM(CASE WHEN bettype IN (22076,22077) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_PGSoft',
		   SUM(CASE WHEN bettype IN (22034,22035) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_Spribe'
		FROM bodb02.dbo.Transfer WITH(NOLOCK)
		WHERE custid = @CustId AND recommend in (SELECT value FROM STRING_SPLIT(@agentid,','))
			AND winlostdate = @dbtodaydate
		GROUP BY custid, currency, recommend, mrecommend, srecommend
	)AS T
	ON B.custid = T.custid

	UPDATE d
	SET ClosingBalance = OpeningBalance + Deposit + Aff2MemTransfer - Withdrawal + Bonus + Adjustment - Outstanding + Winloss + 
		Transfer3rd_AG + Transfer3rd_CRYSTAL +Transfer3rd_Opal + Transfer3rd_BetSoft +
		Transfer3rd_CitiBet + Transfer3rd_Topaz + Transfer3rd_BTi + Transfer3rd_Sapphire + Transfer3rd_KYGaming + 
		Transfer3rd_AVPMini + Transfer3rd_AVPSlot + Transfer3rd_EVO + Transfer3rd_Betradar + Transfer3rd_PP +
		Transfer3rd_BT1 + Transfer3rd_JILISlot + Transfer3rd_PGSoft + Transfer3rd_Spribe + Promotion,
		actualrate = e.ActualRate
	FROM @TodayData d 
		INNER JOIN exchangedailyoanda e WITH(NOLOCK) ON d.currency = e.ExchangeId
END

    UPDATE @WinlostTmp 
    SET Turnover = (A.Turnover - B.Turnover)    
    FROM @WinlostTmp AS A INNER JOIN @WinlostTmp_CastOutTurnover AS B 
		ON A.Custid = B.Custid AND A.winlostdate = B.winlostdate

SELECT b.*, ISNULL(o.Transfer3rd_AG,0) AS Transfer3rd_AG,
	   ISNULL(o.Transfer3rd_CRYSTAL, 0) AS Transfer3rd_CRYSTAL,
	   ISNULL(o.Transfer3rd_Opal, 0) AS Transfer3rd_Opal, ISNULL(o.Transfer3rd_BetSoft, 0) AS Transfer3rd_BetSoft,
	   ISNULL(o.Transfer3rd_CitiBet, 0) AS Transfer3rd_CitiBet, ISNULL(o.Transfer3rd_Topaz, 0) AS Transfer3rd_Topaz,
	   ISNULL(o.Transfer3rd_BTi, 0) AS Transfer3rd_BTi,
	   ISNULL(o.Transfer3rd_Sapphire, 0) AS Transfer3rd_Sapphire, ISNULL(o.Transfer3rd_KYGaming, 0) AS Transfer3rd_KYGaming,
	   ISNULL(o.Transfer3rd_AVPMini, 0) AS Transfer3rd_AVPMini, ISNULL(o.Transfer3rd_AVPSlot, 0) AS Transfer3rd_AVPSlot, 
	   ISNULL(o.Transfer3rd_EVO, 0) AS Transfer3rd_EVO, ISNULL(o.Transfer3rd_Betradar, 0) AS Transfer3rd_Betradar, ISNULL(o.Transfer3rd_PP, 0) AS Transfer3rd_PP,
	   ISNULL(o.Transfer3rd_BT1, 0) AS Transfer3rd_BT1, ISNULL(o.Transfer3rd_JILISlot, 0) AS Transfer3rd_JILISlot, ISNULL(o.Transfer3rd_PGSoft, 0) AS Transfer3rd_PGSoft, ISNULL(o.Transfer3rd_Spribe, 0) AS Transfer3rd_Spribe
FROM @WinlostTmp b
	LEFT JOIN @WinlostTransfer3rd o ON b.winlostdate = o.winlostdate
UNION
SELECT @dbtodaydate, d.* FROM @TodayData d
ORDER BY b.winlostdate


