/*<info serverAlias="DBACC-bodb02" executers="Dot_Admin,Dot_Member" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[DOT_Dep_Rpt_MemberSummary_Agent_V2]
	@fromDate smalldatetime,
	@toDate smalldatetime,
	@CustId INT,
	@agentid NVARCHAR(3500)
AS
/*
DB: DB06.bodb02
Revisions: 
--20121003@StevenHuang(DB06):1.copy from  DOT_Dep_Rpt_MemberSummary_Agent
							 2.add field return SBTOver, CATOver, NOTOver, SBWL, CAWL, NOWL
--20121106@Steven: Turnover Report By Izhar Request (SB/LV/NO/151:HR/180:VS)
--20130430@benson(DB06):modify @CutDate Get from bodb_report.dbo.rptdepwinlost min date
--20130718@KevinLiao(DB06): re-write sp.
--20130723@Benson(DB06): Get Transfer_Opus data from rptDepWinlost_Transfer3rdOthers.
--20130806@Benson(DB06): fix Transfer3rd_Opus return null 
--20131107@BEnson(DB06): fix today Withdrawal Positive and negative exchange
--20140325@Benson(DB06): add field return KEDraw, KETOver, KEWL
--20140326@Benson(DB06): add field return Transfer3rd_HoGaing data
--20140804@Michael(DB06): add field return (RNG) RNDraw, RNTOver, RNWL
--20140818@Howard(DB06): Add AG Report Data
--20141216@Benson(DB06): fix RNDraw,RNTover,RNWL column both get winlost value
--20150327@Hugo(DB06): Add GD Report Data
--20150424@Angus(DB06): Add VB Report Data
--20150925@Angus(DB06): Add CRYSTAL Report Data
--20160203@Benson: fix OneRNG issue add sporttpye:208
--20160721@Matthew(DB06): Add LBKeno Report Data
--20160802@Matthew(DB06):Add VB/MG Tover/Draw/WL
--20161013@Matthew(DB06.bodb02): Fix VB/MG sporttype
--20161109@Matthew(DB06.bodb02): Add CB sporttype
--20161205@Matthew(DB06.bodb02): Add GG/ALLBET Tover/Draw/WL
--20170306@Matthew(DB06.bodb02): Add Opal Report Data
--20170605@Simon(DB06.bodb02): Add BetSoft(Amber) Report Data
--20170724@Benson(DB06.bodb02): Add Cash Out information
--20170815@ZiYang(DB06.bodb02): Add iSoftBet(Quartz) Report Data
--20170926@AngusHung(DB06.bodb02): Add KenoLottery Report Data
--20170927@AngusHung(DB06.bodb02): Add BetRadar Virtual Sports Report Data
--20171124@AngusHung(DB06.bodb02): Add CitiBet(ExChange) Report Data
--20180515@Benson(DB06.bodb02): Add BetRadar Virtual Sports(192,193) Report Data
--20180806@JamesChu(DB06.bodb02): Add Topaz(FG) Report Data
--20180905@Benson(DB06.bodb02): Add mini game(SportType:209) in RNG relate column
--20190111@Angus(DB06.bodb02): Add Happy5(SportType:164) Report Data
--20190303@JamesChu(DB06.bodb02): Add IMone Report Data
--20190319@Angus(DB06) :Add BTi Report Data
--20190716@JamesChu(DB06.bodb02): Add VRLottery Report Data
--20190916@Rong(DB06.bodb02): Add Sapphire Report Data
--20191218@Benson: Add select promotion column
--20191227@Benson: hotfix column of promotion not aligned
--20200107@Benson: new FG replace old FG, PartnerId 13->18 | bettype 22032,22033 -> 22042,22043
--20200317@Rong(DB06.bodb02): Add KYGaming Report Data
--20200331@James(DB06.bodb02): Add Virtual Games(245), Virtual Soccer Champions Cup(196), Virtual Soccer Asian Cup(194)  Report Data
--20200429@James(DB06.bodb02): Add Table Game(222) Report Data
--20200629@Rong(DB06.bodb02): Add AE Sexy(243) Report Data
--20200630@James(DB06.bodb02): Add Moonstone Report Data
--20200801@Rong(DB06.bodb02): Add SABA Club(200) Report Data
--20200813@Angus:Add Loyalty Program bet type in the promotion
--20201113@Ruby(DB06.bodb02): Replace AE Sexy with AE Casino Report Data
--20201202@Ruby(DB06.bodb02): Add SA(244) Report Data
--20201208@Rong(DB06.bodb02): Add EA and N2Live Report Data
--20210217@Benson(DB06.bodb02): Add Happy 5 Linked Games(SportType:168) Report Data
--20210310@Ruby(DB06.bodb02): Add IDNPoker Report Data
--20210423@Ruby(DB06.bodb02): Add Sports Lottery(SportType:169) Report Data
--20210503@Ruby(DB06.bodb02): Add BG Report Data
--20210518@Max(DB06.bodb02): Add AVPMini,AVPSlot Report Data
--20210526@Edward(DB06.bodb02): Add Arcadia Gaming(SportType:165) Report Data
--20210625@Ruby(DB06.bodb02): Add Vgaming(SportType:171) Report Data
--20220211@Benson(DB06.bodb02): Split Transfer out of bettrans
--20220325@Mei (DB06X): change function strsplit to STRING_SPLIT
--20220518@Rong(DB06.bodb02): Add LG Virtual Sports(SportType:231) Report Data
--20220801@Max(DB06.bodb02): Add MaxGame(SportType:237) Report Data
--20220810@Ruby(DB06.bodb02): Add EVO Report Data
--20220914@Benson(DB06.bodb02): fix Transfer3rd_EVO value error, use Transfer3rd_AVPSlot value display to evo
--20220830@Ruby(DB06.bodb02): Add Betradar Report Data
--20220830@Ruby(DB06.bodb02): Add PP Report Data
--20220927@Ruby(DB06.bodb02): Add BTC(SportType:175) Report Data

*/
BEGIN
	SET NOCOUNT ON
	
	SET @agentid = [dbo].[f_StrRtrimLastSeparator] (@agentid,',')
	
	DECLARE @dbtodaydate smalldatetime ,
			@CutDate datetime
	SET @dbtodaydate = convert(nvarchar(10),current_timestamp,120)
	SELECT @CutDate =  min(winlostdate) from bodb_report.dbo.rptdepwinlost with(nolock) 

	DECLARE @TodayData TABLE (
		custid int PRIMARY KEY, currency int, OpeningBalance money default(0), Deposit money default(0), Aff2MemTransfer money default(0),
		Withdrawal money default(0), Bonus money default(0), Adjustment money default(0), Turnover money default(0), Outstanding money default(0), 
		SBDraw money default(0), SBTOver money default(0), SBWL money default(0), 
		HRDraw money default(0), HRTOver money default(0), HRWL money default(0),
		NODraw money default(0), NOTOver money default(0), NOWL money default(0),
		CADraw money default(0), CATOver money default(0), CAWL money default(0), 
		VSDraw money default(0), VSTOver money default(0), VSWL money default(0),
		KEDraw money default(0), KETOver money default(0), KEWL money default(0), --KENO
		RNDraw money default(0), RNTOver money default(0), RNWL money default(0), --RNG
		MRNDraw money default(0), MRNTOver money default(0), MRNWL money default(0), --RNG Mobile
		VBDraw money default(0), VBTOver money default(0), VBWL money default(0), --VB
		MGDraw money default(0), MGTOver money default(0), MGWL money default(0), --MG
		CBDraw money default(0), CBTOver money default(0), CBWL money default(0), --CB
		GGDraw money default(0), GGTOver money default(0), GGWL money default(0), --GG
		ALLBETDraw money default(0), ALLBETTOver money default(0), ALLBETWL money default(0), --ALLBET
		CODraw money default(0), COTOver money default(0), COWL money default(0), --Cash Out
		KLDraw money default(0), KLTOver money default(0), KLWL money default(0), --KENO Lottery
		VS2Draw money default(0), VS2TOver money default(0), VS2WL money default(0), --BetRadar Virtual Sports
		H5Draw money default(0), H5TOver money default(0), H5WL money default(0), --Happy5
		VGDraw money default(0), VGTOver money default(0), VGWL money default(0), --Virtual Games
		TGDraw money default(0), TGTOver money default(0), TGWL money default(0), --Table Game
		AECASINODraw money default(0), AECASINOTOver money default(0), AECASINOWL money default(0), --AE Casino
		SCDraw money default(0), SCTOver money default(0), SCWL money default(0), --SABA Club
		SADraw money default(0), SATOver money default(0), SAWL money default(0), --SA
		H5LDraw money default(0), H5LTOver money default(0), H5LWL money default(0), --Happy 5 Linked Games
		SLDraw money default(0), SLTOver money default(0), SLWL money default(0), --Sports Lottery
		ARCADraw money default(0), ARCATOver money default(0), ARCAWL money default(0), --Arcadia Gaming
		VgamingDraw money default(0), VgamingTOver money default(0), VgamingWL money default(0), --Vgaming
		VS3Draw money default(0), VS3TOver money default(0), VS3WL money default(0), --LG Virtual Sports
		MaxGameDraw money default(0), MaxGameTOver money default(0), MaxGameWL money default(0), --MaxGame
		BTCDraw money default(0), BTCTOver money default(0), BTCWL money default(0), --Bitcoin
		Winloss money default(0), ClosingBalance money default(0), Transfer3rd money default(0), DrawGame money default(0),
		recommend int, mrecommend int, srecommend int, actualrate float, Promotion money, Transfer3rd_Opus money default(0), Transfer3rd_HoGaing money default(0),
		Transfer3rd_AG money default(0), Transfer3rd_GD money default(0), Transfer3rd_VB money default(0),Transfer3rd_CRYSTAL money default(0),Transfer3rd_LBKeno money default(0),
		Transfer3rd_Opal money default(0), Transfer3rd_BetSoft money default(0), Transfer3rd_iSoftBet money default(0), Transfer3rd_CitiBet money default(0), Transfer3rd_Topaz money default(0),
		Transfer3rd_IMone money default(0), Transfer3rd_BTi money default(0), Transfer3rd_VRLottery money default(0), Transfer3rd_Sapphire money default(0), Transfer3rd_KYGaming money default(0),
		Transfer3rd_Moonstone money default(0), Transfer3rd_EA money default(0), Transfer3rd_N2Live money default(0), Transfer3rd_IDNPoker money default(0), Transfer3rd_BG money default(0),
		Transfer3rd_AVPMini money default(0),Transfer3rd_AVPSlot money default(0),Transfer3rd_EVO money default(0),Transfer3rd_Betradar money default(0), Transfer3rd_PP money default(0))
		
	DECLARE @WinlostTmp TABLE (
		winlostdate datetime, custid int, currency int, OpeningBalance money default(0), Deposit money default(0), Aff2MemTransfer money default(0),
		Withdrawal money default(0), Bonus money default(0), Adjustment money default(0), Turnover money default(0), Outstanding money default(0),
		SBDraw money default(0), SBTOver money default(0), SBWL money default(0), 
		HRDraw money default(0), HRTOver money default(0), HRWL money default(0),
		NODraw money default(0), NOTOver money default(0), NOWL money default(0),
		CADraw money default(0), CATOver money default(0), CAWL money default(0), 
		VSDraw money default(0), VSTOver money default(0), VSWL money default(0),
		KEDraw money default(0), KETOver money default(0), KEWL money default(0), --KENO
		RNDraw money default(0), RNTOver money default(0), RNWL money default(0), --RNG
		MRNDraw money default(0), MRNTOver money default(0), MRNWL money default(0), --RNG Mobile
		VBDraw money default(0), VBTOver money default(0), VBWL money default(0), --VB
		MGDraw money default(0), MGTOver money default(0), MGWL money default(0), --MG
		CBDraw money default(0), CBTOver money default(0), CBWL money default(0), --CB
		GGDraw money default(0), GGTOver money default(0), GGWL money default(0), --GG
		ALLBETDraw money default(0), ALLBETTOver money default(0), ALLBETWL money default(0), --ALLBET
		CODraw money default(0), COTOver money default(0), COWL money default(0), --Cash Out
		KLDraw money default(0), KLTOver money default(0), KLWL money default(0), --KENO Lottery
		VS2Draw money default(0), VS2TOver money default(0), VS2WL money default(0), --BetRadar Virtual Sports
		H5Draw money default(0), H5TOver money default(0), H5WL money default(0), --Happy5
		VGDraw money default(0), VGTOver money default(0), VGWL money default(0), --Virtual Games
		TGDraw money default(0), TGTOver money default(0), TGWL money default(0), --Table Game
		AECASINODraw money default(0), AECASINOTOver money default(0), AECASINOWL money default(0), --AE Casino
		SCDraw money default(0), SCTOver money default(0), SCWL money default(0), --SABA Club
		SADraw money default(0), SATOver money default(0), SAWL money default(0), --SA
		H5LDraw money default(0), H5LTOver money default(0), H5LWL money default(0), --Happy 5 Linked Games
		SLDraw money default(0), SLTOver money default(0), SLWL money default(0), --Sports Lottery
		ARCADraw money default(0), ARCATOver money default(0), ARCAWL money default(0), --Arcadia Gaming
		VgamingDraw money default(0), VgamingTOver money default(0), VgamingWL money default(0), --Vgaming
		VS3Draw money default(0), VS3TOver money default(0), VS3WL money default(0), --LG Virtual Sports
		MaxGameDraw money default(0), MaxGameTOver money default(0), MaxGameWL money default(0), --MaxGame
		BTCDraw money default(0), BTCTOver money default(0), BTCWL money default(0), --Bitcoin
		Winloss money default(0), ClosingBalance money default(0), Transfer3rd money default(0), DrawGame money default(0),
		recommend int, mrecommend int, srecommend int, actualrate float, Promotion money)

	--Get Transfer 3rd Winlost data
	DECLARE @WinlostTransfer3rd TABLE(CustId int , winlostdate datetime, Transfer3rd_Opus money, Transfer3rd_HoGaming money, Transfer3rd_AG money, Transfer3rd_GD money, Transfer3rd_VB money ,
		Transfer3rd_CRYSTAL money, Transfer3rd_LBKeno money, Transfer3rd_Opal money, Transfer3rd_BetSoft money, Transfer3rd_iSoftBet money, Transfer3rd_CitiBet money, Transfer3rd_Topaz money,
		Transfer3rd_IMone money, Transfer3rd_BTi money, Transfer3rd_VRLottery money, Transfer3rd_Sapphire money, Transfer3rd_KYGaming money, Transfer3rd_Moonstone money, Transfer3rd_EA money,
		Transfer3rd_N2Live money, Transfer3rd_IDNPoker money, Transfer3rd_BG money, Transfer3rd_AVPMini money, Transfer3rd_AVPSlot money, Transfer3rd_EVO money, Transfer3rd_Betradar money, Transfer3rd_PP money)
		
	IF (@fromDate < @CutDate) OR (@toDate < @CutDate)
	BEGIN
		INSERT INTO @WinlostTmp
		SELECT b.winlostdate, b.custid, b.currency, b.OpeningBalance, b.Deposit, b.Aff2MemTransfer,
			   b.Withdrawal, b.Bonus, b.Adjustment, b.Turnover, b.Outstanding,
			   ISNULL(p1.SBDraw, 0) AS SBDraw, ISNULL(p1.SBTOver, 0) AS SBTOver, ISNULL(p1.SBWL, 0) AS SBWL,
			   ISNULL(p1.HRDraw, 0) AS HRDraw, ISNULL(p1.HRTOver, 0) AS HRTOver, ISNULL(p1.HRWL, 0) AS HRWL,
			   ISNULL(p1.NODraw, 0) AS NODraw, ISNULL(p1.NOTOver, 0) AS NOTOver, ISNULL(p1.NOWL, 0) AS NOWL,
			   ISNULL(p1.CADraw, 0) AS CADraw, ISNULL(p1.CATOver, 0) AS CATOver, ISNULL(p1.CAWL, 0) AS CAWL,
			   ISNULL(p1.VSDraw, 0) AS VSDraw, ISNULL(p1.VSTOver, 0) AS VSTOver, ISNULL(p1.VSWL, 0) AS VSWL,
			   ISNULL(p1.KEDraw, 0) AS KEDraw, ISNULL(p1.KETOver, 0) AS KETOver, ISNULL(p1.KEWL, 0) AS KEWL, --KENO
			   ISNULL(p1.RNDraw, 0) AS RNDraw, ISNULL(p1.RNTOver, 0) AS RNTOver, ISNULL(p1.RNWL, 0) AS RNWL, --RNG
			   ISNULL(p1.MRNDraw, 0) AS MRNDraw, ISNULL(p1.MRNTOver, 0) AS MRNTOver, ISNULL(p1.MRNWL, 0) AS MRNWL, --RNG Mobile
			   ISNULL(p1.VBDraw, 0) AS VBDraw, ISNULL(p1.VBTOver, 0) AS VBOver, ISNULL(p1.VBWL, 0) AS VBWL, --VB
			   ISNULL(p1.MGDraw, 0) AS MGDraw, ISNULL(p1.MGTOver, 0) AS MGTOver, ISNULL(p1.MGWL, 0) AS MGWL, --MG
			   ISNULL(p1.CBDraw, 0) AS CBDraw, ISNULL(p1.CBTOver, 0) AS CBTOver, ISNULL(p1.CBWL, 0) AS CBWL, --CB
			   ISNULL(p1.GGDraw, 0) AS GGDraw, ISNULL(p1.GGTOver, 0) AS GGTOver, ISNULL(p1.GGWL, 0) AS GGWL, --GG
			   ISNULL(p1.ALLBETDraw, 0) AS ALLBETDraw, ISNULL(p1.ALLBETTOver, 0) AS ALLBETTOver, ISNULL(p1.ALLBETWL, 0) AS ALLBETWL, --ALLBET
			   ISNULL(p1.CODraw, 0) AS CODraw, ISNULL(p1.COTOver, 0) AS COTOver, ISNULL(p1.COWL, 0) AS COWL, --Cash Out
			   ISNULL(p1.KLDraw, 0) AS KLDraw, ISNULL(p1.KLTOver, 0) AS KLTOver, ISNULL(p1.KLWL, 0) AS KLWL, --KENO Lottery
			   ISNULL(p1.VS2Draw, 0) AS VS2Draw, ISNULL(p1.VS2TOver, 0) AS VS2TOver, ISNULL(p1.VS2WL, 0) AS VS2WL, --BetRadar Virtual Sports
			   ISNULL(p1.H5Draw, 0) AS H5Draw, ISNULL(p1.H5TOver, 0) AS H5TOver, ISNULL(p1.H5WL, 0) AS H5WL, --Happy5
			   ISNULL(p1.VGDraw, 0) AS VGDraw, ISNULL(p1.VGTOver, 0) AS VGTOver, ISNULL(p1.VGWL, 0) AS VGWL, --Virtual Games
			   ISNULL(p1.TGDraw, 0) AS TGDraw, ISNULL(p1.TGTOver, 0) AS TGTOver, ISNULL(p1.TGWL, 0) AS TGWL, --Table Game
			   ISNULL(p1.AECASINODraw, 0) AS AECASINODraw, ISNULL(p1.AECASINOTOver, 0) AS AECASINOTOver, ISNULL(p1.AECASINOWL, 0) AS AECASINOWL, --AE Casino
			   ISNULL(p1.SCDraw, 0) AS SCDraw, ISNULL(p1.SCTOver, 0) AS SCTOver, ISNULL(p1.SCWL, 0) AS SCWL, --SABA Club
			   ISNULL(p1.SADraw, 0) AS SADraw, ISNULL(p1.SATOver, 0) AS SATOver, ISNULL(p1.SAWL, 0) AS SAWL, --SA
			   ISNULL(p1.H5LDraw, 0) AS H5LDraw, ISNULL(p1.H5LTOver, 0) AS H5LTOver, ISNULL(p1.H5LWL, 0) AS H5LWL, --Happy 5 Linked Games
			   ISNULL(p1.SLDraw, 0) AS SLDraw, ISNULL(p1.SLTOver, 0) AS SLTOver, ISNULL(p1.SLWL, 0) AS SLWL, --Sports Lottery
			   ISNULL(p1.ARCADraw, 0) AS ARCADraw, ISNULL(p1.ARCATOver, 0) AS ARCTOver, ISNULL(p1.ARCAWL, 0) AS ARCAWL, --Arcadia Gaming
			   ISNULL(p1.VgamingDraw, 0) AS VgamingDraw, ISNULL(p1.VgamingTOver, 0) AS VgamingTOver, ISNULL(p1.VgamingWL, 0) AS VgamingWL, --Vgaming
			   ISNULL(p1.VS3Draw, 0) AS VS3Draw, ISNULL(p1.VS3TOver, 0) AS VS3TOver, ISNULL(p1.VS3WL, 0) AS VS3WL, --LG Virtual Sports
			   ISNULL(p1.MaxGameDraw, 0) AS MaxGameDraw, ISNULL(p1.MaxGameTOver, 0) AS MaxGameTOver, ISNULL(p1.MaxGameWL, 0) AS MaxGameWL, --MaxGame
			   ISNULL(p1.BTCDraw, 0) AS BTCDraw, ISNULL(p1.BTCTOver, 0) AS BTCTOver, ISNULL(p1.BTCWL, 0) AS BTCWL, --Bitcoin
			   b.Winloss, b.ClosingBalance, b.Transfer3rd, b.DrawGame,
			   b.recommend, b.mrecommend, b.srecommend, b.actualrate, b.Promotion
		FROM bodb_Report.dbo.rptDepWinlost_bk b WITH(NOLOCK)
			LEFT JOIN (
						SELECT p.winlostdate, p.custid, 
								SUM(CASE WHEN p.sporttype = 0 THEN p.drawTO ELSE 0 END)AS SBDraw,
								SUM(CASE WHEN p.sporttype = 0 THEN p.turnover ELSE 0 END) AS SBTOver,
								SUM(CASE WHEN p.sporttype = 0 THEN p.winlost ELSE 0 END) AS SBWL,
								SUM(CASE WHEN p.sporttype = 151 THEN p.drawTO ELSE 0 END) AS HRDraw,
								SUM(CASE WHEN p.sporttype = 151 THEN p.turnover ELSE 0 END) AS HRTOver,
								SUM(CASE WHEN p.sporttype = 151 THEN p.winlost ELSE 0 END) AS HRWL,
								SUM(CASE WHEN p.sporttype = 161 THEN p.drawTO ELSE 0 END) AS NODraw, 
								SUM(CASE WHEN p.sporttype = 161 THEN p.turnover ELSE 0 END) AS NOTOver,
								SUM(CASE WHEN p.sporttype = 161 THEN p.winlost ELSE 0 END) AS NOWL,
								SUM(CASE WHEN p.sporttype = 162 THEN p.drawTO ELSE 0 END) AS CADraw,
								SUM(CASE WHEN p.sporttype = 162 THEN p.turnover ELSE 0 END) AS CATOver,
								SUM(CASE WHEN p.sporttype = 162 THEN p.winlost ELSE 0 END) AS CAWL,
								SUM(CASE WHEN p.sporttype = 180 THEN p.drawTO ELSE 0 END) AS VSDraw, 
								SUM(CASE WHEN p.sporttype = 180 THEN p.turnover ELSE 0 END) AS VSTOver,
								SUM(CASE WHEN p.sporttype = 180 THEN p.winlost ELSE 0 END) AS VSWL, 
								SUM(CASE WHEN p.sporttype = 202 THEN p.drawTO ELSE 0 END) AS KEDraw, 
								SUM(CASE WHEN p.sporttype = 202 THEN p.turnover ELSE 0 END) AS KETOver,
								SUM(CASE WHEN p.sporttype = 202 THEN p.winlost ELSE 0 END) AS KEWL ,
								SUM(CASE WHEN p.sporttype IN (251,208,209) THEN p.drawTO ELSE 0 END) AS RNDraw ,
								SUM(CASE WHEN p.sporttype IN (251,208,209) THEN p.turnover ELSE 0 END) AS RNTOver ,
								SUM(CASE WHEN p.sporttype IN (251,208,209) THEN p.winlost ELSE 0 END) AS RNWL ,
								SUM(CASE WHEN p.sporttype = 210 THEN p.drawTO ELSE 0 END) AS MRNDraw ,
								SUM(CASE WHEN p.sporttype = 210 THEN p.turnover ELSE 0 END) AS MRNTOver ,
								SUM(CASE WHEN p.sporttype = 210 THEN p.winlost ELSE 0 END) AS MRNWL ,
								SUM(CASE WHEN p.sporttype = 212 THEN p.drawTO ELSE 0 END) AS VBDraw ,
								SUM(CASE WHEN p.sporttype = 212 THEN p.turnover ELSE 0 END) AS VBTOver ,
								SUM(CASE WHEN p.sporttype = 212 THEN p.winlost ELSE 0 END) AS VBWL ,
								SUM(CASE WHEN p.sporttype IN (203,205) THEN p.drawTO ELSE 0 END) AS MGDraw ,
								SUM(CASE WHEN p.sporttype IN (203,205) THEN p.turnover ELSE 0 END) AS MGTOver ,
								SUM(CASE WHEN p.sporttype IN (203,205) THEN p.winlost ELSE 0 END) AS MGWL ,
								SUM(CASE WHEN p.sporttype = 204 THEN p.drawTO ELSE 0 END) AS CBDraw ,
								SUM(CASE WHEN p.sporttype = 204 THEN p.turnover ELSE 0 END) AS CBTOver ,
								SUM(CASE WHEN p.sporttype = 204 THEN p.winlost ELSE 0 END) AS CBWL ,
								SUM(CASE WHEN p.sporttype = 219 THEN p.drawTO ELSE 0 END) AS GGDraw ,
								SUM(CASE WHEN p.sporttype = 219 THEN p.turnover ELSE 0 END) AS GGTOver ,
								SUM(CASE WHEN p.sporttype = 219 THEN p.winlost ELSE 0 END) AS GGWL ,
								SUM(CASE WHEN p.sporttype = 211 THEN p.drawTO ELSE 0 END) AS ALLBETDraw ,
								SUM(CASE WHEN p.sporttype = 211 THEN p.turnover ELSE 0 END) AS ALLBETTOver ,
								SUM(CASE WHEN p.sporttype = 211 THEN p.winlost ELSE 0 END) AS ALLBETWL,
								SUM(CASE WHEN p.sporttype = 220 THEN p.drawTO ELSE 0 END) AS KLDraw, 
								SUM(CASE WHEN p.sporttype = 220 THEN p.turnover ELSE 0 END) AS KLTOver,
								SUM(CASE WHEN p.sporttype = 220 THEN p.winlost ELSE 0 END) AS KLWL ,
								SUM(CASE WHEN p.sporttype IN (190,191,192,193,194,196) THEN p.drawTO ELSE 0 END) AS VS2Draw, 
								SUM(CASE WHEN p.sporttype IN (190,191,192,193,194,196) THEN p.turnover ELSE 0 END) AS VS2TOver,
								SUM(CASE WHEN p.sporttype IN (190,191,192,193,194,196) THEN p.winlost ELSE 0 END) AS VS2WL ,
								SUM(CASE WHEN p.sporttype = -6 THEN p.drawTO ELSE 0 END) AS CODraw,
								SUM(CASE WHEN p.sporttype = -6 THEN p.turnover ELSE 0 END) AS COTOver,
								SUM(CASE WHEN p.sporttype = -6 THEN p.winlost ELSE 0 END) AS COWL,
								SUM(CASE WHEN p.sporttype = 164 THEN p.drawTO ELSE 0 END) AS H5Draw,
								SUM(CASE WHEN p.sporttype = 164 THEN p.turnover ELSE 0 END) AS H5TOver,
								SUM(CASE WHEN p.sporttype = 164 THEN p.winlost ELSE 0 END) AS H5WL,
								SUM(CASE WHEN p.sporttype = 245 THEN p.drawTO ELSE 0 END) AS VGDraw,
								SUM(CASE WHEN p.sporttype = 245 THEN p.turnover ELSE 0 END) AS VGTOver,
								SUM(CASE WHEN p.sporttype = 245 THEN p.winlost ELSE 0 END) AS VGWL,
								SUM(CASE WHEN p.sporttype = 222 THEN p.drawTO ELSE 0 END) AS TGDraw,
								SUM(CASE WHEN p.sporttype = 222 THEN p.turnover ELSE 0 END) AS TGTOver,
								SUM(CASE WHEN p.sporttype = 222 THEN p.winlost ELSE 0 END) AS TGWL,
								SUM(CASE WHEN p.sporttype = 243 THEN p.drawTO ELSE 0 END) AS AECASINODraw,
								SUM(CASE WHEN p.sporttype = 243 THEN p.turnover ELSE 0 END) AS AECASINOTOver,
								SUM(CASE WHEN p.sporttype = 243 THEN p.winlost ELSE 0 END) AS AECASINOWL,
								SUM(CASE WHEN p.sporttype = 200 THEN p.drawTO ELSE 0 END) AS SCDraw,
								SUM(CASE WHEN p.sporttype = 200 THEN p.turnover ELSE 0 END) AS SCTOver,
								SUM(CASE WHEN p.sporttype = 200 THEN p.winlost ELSE 0 END) AS SCWL,
								SUM(CASE WHEN p.sporttype = 244 THEN p.drawTO ELSE 0 END) AS SADraw,
								SUM(CASE WHEN p.sporttype = 244 THEN p.turnover ELSE 0 END) AS SATOver,
								SUM(CASE WHEN p.sporttype = 244 THEN p.winlost ELSE 0 END) AS SAWL,
								SUM(CASE WHEN p.sporttype = 168 THEN p.drawTO ELSE 0 END) AS H5LDraw,
								SUM(CASE WHEN p.sporttype = 168 THEN p.turnover ELSE 0 END) AS H5LTOver,
								SUM(CASE WHEN p.sporttype = 168 THEN p.winlost ELSE 0 END) AS H5LWL,
								SUM(CASE WHEN p.sporttype = 169 THEN p.drawTO ELSE 0 END) AS SLDraw,
								SUM(CASE WHEN p.sporttype = 169 THEN p.turnover ELSE 0 END) AS SLTOver,
								SUM(CASE WHEN p.sporttype = 169 THEN p.winlost ELSE 0 END) AS SLWL,
								SUM(CASE WHEN p.sporttype = 165 THEN p.drawTO ELSE 0 END) AS ARCADraw,
								SUM(CASE WHEN p.sporttype = 165 THEN p.turnover ELSE 0 END) AS ARCATOver,
								SUM(CASE WHEN p.sporttype = 165 THEN p.winlost ELSE 0 END) AS ARCAWL,
								SUM(CASE WHEN p.sporttype = 171 THEN p.drawTO ELSE 0 END) AS VgamingDraw,
								SUM(CASE WHEN p.sporttype = 171 THEN p.turnover ELSE 0 END) AS VgamingTOver,
								SUM(CASE WHEN p.sporttype = 171 THEN p.winlost ELSE 0 END) AS VgamingWL,
								SUM(CASE WHEN p.sporttype = 231 THEN p.drawTO ELSE 0 END) AS VS3Draw,
								SUM(CASE WHEN p.sporttype = 231 THEN p.turnover ELSE 0 END) AS VS3TOver,
								SUM(CASE WHEN p.sporttype = 231 THEN p.winlost ELSE 0 END) AS VS3WL,
								SUM(CASE WHEN p.sporttype = 237 THEN p.drawTO ELSE 0 END) AS MaxGameDraw,
								SUM(CASE WHEN p.sporttype = 237 THEN p.turnover ELSE 0 END) AS MaxGameTOver,
								SUM(CASE WHEN p.sporttype = 237 THEN p.winlost ELSE 0 END) AS MaxGameWL,
								SUM(CASE WHEN p.sporttype = 175 THEN p.drawTO ELSE 0 END) AS BTCDraw,
								SUM(CASE WHEN p.sporttype = 175 THEN p.turnover ELSE 0 END) AS BTCTOver,
								SUM(CASE WHEN p.sporttype = 175 THEN p.winlost ELSE 0 END) AS BTCWL
						FROM bodb_Report.dbo.rptDepWinlostByProduct_BK p WITH(NOLOCK)
						WHERE winlostdate BETWEEN @fromDate AND @toDate 
							AND p.sporttype IN (0,151,161,162,180,190,191,192,193,202,203,204,205,210,211,212,219,220,251,208,209,-6,164,194,196,245,222,243,200,244,168,169,165,171,231,237,175) 
							AND p.custid = @CustId 
						GROUP BY p.winlostdate, p.custid
					) p1 ON b.winlostdate = p1.winlostdate
		WHERE b.winlostdate BETWEEN @fromDate AND @toDate
			AND b.custid = @CustId
			AND b.recommend IN (SELECT value FROM STRING_SPLIT(@agentid,','))

		INSERT INTO @WinlostTransfer3rd (CustId, winlostdate, Transfer3rd_Opus, Transfer3rd_HoGaming, Transfer3rd_AG, Transfer3rd_GD, Transfer3rd_VB ,
			Transfer3rd_CRYSTAL, Transfer3rd_LBKeno, Transfer3rd_Opal, Transfer3rd_BetSoft, Transfer3rd_iSoftBet, Transfer3rd_CitiBet, Transfer3rd_Topaz,
			Transfer3rd_IMone, Transfer3rd_BTi, Transfer3rd_VRLottery, Transfer3rd_Sapphire, Transfer3rd_KYGaming, Transfer3rd_Moonstone, Transfer3rd_EA,
			Transfer3rd_N2Live, Transfer3rd_IDNPoker, Transfer3rd_BG, Transfer3rd_AVPMini, Transfer3rd_AVPSlot, Transfer3rd_EVO, Transfer3rd_Betradar, Transfer3rd_PP)
		SELECT custid, winlostdate, 
			SUM(CASE PartnerId WHEN 2 THEN TransferAmount ELSE 0 END), -- oops
			SUM(CASE PartnerId WHEN 1 THEN TransferAmount ELSE 0 END), -- HoGaming
			SUM(CASE PartnerId WHEN 3 THEN TransferAmount ELSE 0 END), -- AG
			SUM(CASE PartnerId WHEN 4 THEN TransferAmount ELSE 0 END),  -- GD
			SUM(CASE PartnerId WHEN 5 THEN TransferAmount ELSE 0 END),  -- VB
			SUM(CASE PartnerId WHEN 7 THEN TransferAmount ELSE 0 END), -- CRYSTAL
			SUM(CASE PartnerId WHEN 8 THEN TransferAmount ELSE 0 END), -- LBKeno
			SUM(CASE PartnerId WHEN 9 THEN TransferAmount ELSE 0 END), -- Opal
			SUM(CASE PartnerId WHEN 10 THEN TransferAmount ELSE 0 END), -- BetSoft(Amber)
			SUM(CASE PartnerId WHEN 11 THEN TransferAmount ELSE 0 END), -- iSoftBet(Quartz)
			SUM(CASE PartnerId WHEN 12 THEN TransferAmount ELSE 0 END), -- CitiBet(Exchange)
			SUM(CASE WHEN PartnerId IN (13,18) THEN TransferAmount ELSE 0 END), -- Topaz(FG)
			SUM(CASE PartnerId WHEN 14 THEN TransferAmount ELSE 0 END), -- IMone
			SUM(CASE PartnerId WHEN 15 THEN TransferAmount ELSE 0 END), -- BTi
			SUM(CASE PartnerId WHEN 16 THEN TransferAmount ELSE 0 END), -- VRLottery
			SUM(CASE PartnerId WHEN 17 THEN TransferAmount ELSE 0 END), -- Sapphire
			SUM(CASE PartnerId WHEN 19 THEN TransferAmount ELSE 0 END), -- KYGaming
			SUM(CASE PartnerId WHEN 20 THEN TransferAmount ELSE 0 END), -- Moonstone
			SUM(CASE PartnerId WHEN 21 THEN TransferAmount ELSE 0 END), -- EA
			SUM(CASE PartnerId WHEN 22 THEN TransferAmount ELSE 0 END), -- N2Live
			SUM(CASE PartnerId WHEN 23 THEN TransferAmount ELSE 0 END), -- IDNPoker
			SUM(CASE PartnerId WHEN 24 THEN TransferAmount ELSE 0 END), -- BG
			SUM(CASE PartnerId WHEN 25 THEN TransferAmount ELSE 0 END), -- AVPMini
			SUM(CASE PartnerId WHEN 26 THEN TransferAmount ELSE 0 END), -- AVPSlot
			SUM(CASE PartnerId WHEN 27 THEN TransferAmount ELSE 0 END), -- EVO
			SUM(CASE PartnerId WHEN 28 THEN TransferAmount ELSE 0 END), -- Betradar
			SUM(CASE PartnerId WHEN 29 THEN TransferAmount ELSE 0 END)  -- PP
		FROM bodb_Report.dbo.rptDepWinlost_Transfer3rdOthers_bk  WITH (NOLOCK) 
		WHERE  (winlostdate BETWEEN @fromDate AND @toDate) AND custid = @Custid AND recommend IN (SELECT value FROM STRING_SPLIT(@agentid,','))  
		GROUP BY winlostdate,CustId
		
	END

	IF (@fromDate >= @CutDate) OR (@toDate >= @CutDate)
	BEGIN
		INSERT INTO @WinlostTmp
		SELECT b.winlostdate, b.custid, b.currency, b.OpeningBalance, b.Deposit, b.Aff2MemTransfer,
			   b.Withdrawal, b.Bonus, b.Adjustment, b.Turnover, b.Outstanding,
			   ISNULL(p1.SBDraw, 0) AS SBDraw, ISNULL(p1.SBTOver, 0) AS SBTOver, ISNULL(p1.SBWL, 0) AS SBWL,
			   ISNULL(p1.HRDraw, 0) AS HRDraw, ISNULL(p1.HRTOver, 0) AS HRTOver, ISNULL(p1.HRWL, 0) AS HRWL,
			   ISNULL(p1.NODraw, 0) AS NODraw, ISNULL(p1.NOTOver, 0) AS NOTOver, ISNULL(p1.NOWL, 0) AS NOWL,
			   ISNULL(p1.CADraw, 0) AS CADraw, ISNULL(p1.CATOver, 0) AS CATOver, ISNULL(p1.CAWL, 0) AS CAWL,
			   ISNULL(p1.VSDraw, 0) AS VSDraw, ISNULL(p1.VSTOver, 0) AS VSTOver, ISNULL(p1.VSWL, 0) AS VSWL,
			   ISNULL(p1.KEDraw, 0) AS KEDraw, ISNULL(p1.KETOver, 0) AS KETOver, ISNULL(p1.KEWL, 0) AS KEWL, --KENO
			   ISNULL(p1.RNDraw, 0) AS RNDraw, ISNULL(p1.RNTOver, 0) AS RNTOver, ISNULL(p1.RNWL, 0) AS RNWL, --RNG
			   ISNULL(p1.MRNDraw, 0) AS MRNDraw, ISNULL(p1.MRNTOver, 0) AS MRNTOver, ISNULL(p1.MRNWL, 0) AS MRNWL, --RNG Mobile
			   ISNULL(p1.VBDraw, 0) AS VBDraw, ISNULL(p1.VBTOver, 0) AS VBOver, ISNULL(p1.VBWL, 0) AS VBWL, --VB
			   ISNULL(p1.MGDraw, 0) AS MGDraw, ISNULL(p1.MGTOver, 0) AS MGTOver, ISNULL(p1.MGWL, 0) AS MGWL, --MG
			   ISNULL(p1.CBDraw, 0) AS CBDraw, ISNULL(p1.CBTOver, 0) AS CBTOver, ISNULL(p1.CBWL, 0) AS CBWL, --CB
			   ISNULL(p1.GGDraw, 0) AS GGDraw, ISNULL(p1.GGTOver, 0) AS GGTOver, ISNULL(p1.GGWL, 0) AS GGWL, --GG
			   ISNULL(p1.ALLBETDraw, 0) AS ALLBETDraw, ISNULL(p1.ALLBETTOver, 0) AS ALLBETTOver, ISNULL(p1.ALLBETWL, 0) AS ALLBETWL, --ALLBET
			   ISNULL(p1.CODraw, 0) AS CODraw, ISNULL(p1.COTOver, 0) AS COTOver, ISNULL(p1.COWL, 0) AS COWL, --Cash Out
			   ISNULL(p1.KLDraw, 0) AS KLDraw, ISNULL(p1.KLTOver, 0) AS KLTOver, ISNULL(p1.KLWL, 0) AS KLWL, --KENO Lottery
			   ISNULL(p1.VS2Draw, 0) AS VS2Draw, ISNULL(p1.VS2TOver, 0) AS VS2TOver, ISNULL(p1.VS2WL, 0) AS VS2WL, --BetRadar Virtual Sports
			   ISNULL(p1.H5Draw, 0) AS H5Draw, ISNULL(p1.H5TOver, 0) AS H5TOver, ISNULL(p1.H5WL, 0) AS H5WL, --Happy5
			   ISNULL(p1.VGDraw, 0) AS VGDraw, ISNULL(p1.VGTOver, 0) AS VGTOver, ISNULL(p1.VGWL, 0) AS VGWL, --Virtual Games
			   ISNULL(p1.TGDraw, 0) AS TGDraw, ISNULL(p1.TGTOver, 0) AS TGTOver, ISNULL(p1.TGWL, 0) AS TGWL, --Table Game
			   ISNULL(p1.AECASINODraw, 0) AS AECASINODraw, ISNULL(p1.AECASINOTOver, 0) AS AECASINOTOver, ISNULL(p1.AECASINOWL, 0) AS AECASINOWL, --AE Casino
			   ISNULL(p1.SCDraw, 0) AS SCDraw, ISNULL(p1.SCTOver, 0) AS SCTOver, ISNULL(p1.SCWL, 0) AS SCWL, --SABA Club
			   ISNULL(p1.SADraw, 0) AS SADraw, ISNULL(p1.SATOver, 0) AS SATOver, ISNULL(p1.SAWL, 0) AS SAWL, --SA
			   ISNULL(p1.H5LDraw, 0) AS H5LDraw, ISNULL(p1.H5LTOver, 0) AS H5LTOver, ISNULL(p1.H5LWL, 0) AS H5LWL, --Happy 5 Linked Games
			   ISNULL(p1.SLDraw, 0) AS SLDraw, ISNULL(p1.SLTOver, 0) AS SLTOver, ISNULL(p1.SLWL, 0) AS SLWL, --Sports Lottery
			   ISNULL(p1.ARCADraw, 0) AS ARCADraw, ISNULL(p1.ARCATOver, 0) AS ARCTOver, ISNULL(p1.ARCAWL, 0) AS ARCAWL, --Arcadia Gaming
			   ISNULL(p1.VgamingDraw, 0) AS VgamingDraw, ISNULL(p1.VgamingTOver, 0) AS VgamingTOver, ISNULL(p1.VgamingWL, 0) AS VgamingWL, --Vgaming
			   ISNULL(p1.VS3Draw, 0) AS VS3Draw, ISNULL(p1.VS3TOver, 0) AS VS3TOver, ISNULL(p1.VS3WL, 0) AS VS3WL, --LG Virtual Sports
			   ISNULL(p1.MaxGameDraw, 0) AS MaxGameDraw, ISNULL(p1.MaxGameTOver, 0) AS MaxGameTOver, ISNULL(p1.MaxGameWL, 0) AS MaxGameWL, --MaxGame
			   ISNULL(p1.BTCDraw, 0) AS BTCDraw, ISNULL(p1.BTCTOver, 0) AS BTCTOver, ISNULL(p1.BTCWL, 0) AS BTCWL, --Bitcoin
			   b.Winloss, b.ClosingBalance, b.Transfer3rd, b.DrawGame,
			   b.recommend, b.mrecommend, b.srecommend, b.actualrate, b.Promotion
		FROM bodb_Report.dbo.rptDepWinlost b WITH(NOLOCK)
			LEFT JOIN (
						SELECT p.winlostdate, p.custid, 
								SUM(CASE WHEN p.sporttype = 0 THEN p.drawTO ELSE 0 END) AS SBDraw,
								SUM(CASE WHEN p.sporttype = 0 THEN p.turnover ELSE 0 END) AS SBTOver,
								SUM(CASE WHEN p.sporttype = 0 THEN p.winlost ELSE 0 END) AS SBWL,
								SUM(CASE WHEN p.sporttype = 151 THEN p.drawTO ELSE 0 END) AS HRDraw,
								SUM(CASE WHEN p.sporttype = 151 THEN p.turnover ELSE 0 END) AS HRTOver,
								SUM(CASE WHEN p.sporttype = 151 THEN p.winlost ELSE 0 END) AS HRWL,
								SUM(CASE WHEN p.sporttype = 161 THEN p.drawTO ELSE 0 END) AS NODraw, 
								SUM(CASE WHEN p.sporttype = 161 THEN p.turnover ELSE 0 END) AS NOTOver,
								SUM(CASE WHEN p.sporttype = 161 THEN p.winlost ELSE 0 END) AS NOWL,
								SUM(CASE WHEN p.sporttype = 162 THEN p.drawTO ELSE 0 END) AS CADraw,
								SUM(CASE WHEN p.sporttype = 162 THEN p.turnover ELSE 0 END) AS CATOver,
								SUM(CASE WHEN p.sporttype = 162 THEN p.winlost ELSE 0 END) AS CAWL,
								SUM(CASE WHEN p.sporttype = 180 THEN p.drawTO ELSE 0 END) AS VSDraw, 
								SUM(CASE WHEN p.sporttype = 180 THEN p.turnover ELSE 0 END) AS VSTOver,
								SUM(CASE WHEN p.sporttype = 180 THEN p.winlost ELSE 0 END) AS VSWL, 
								SUM(CASE WHEN p.sporttype = 202 THEN p.drawTO ELSE 0 END) AS KEDraw, 
								SUM(CASE WHEN p.sporttype = 202 THEN p.turnover ELSE 0 END) AS KETOver,
								SUM(CASE WHEN p.sporttype = 202 THEN p.winlost ELSE 0 END) AS KEWL ,
								SUM(CASE WHEN p.sporttype IN (251,208,209) THEN p.drawTO ELSE 0 END) AS RNDraw ,
								SUM(CASE WHEN p.sporttype IN (251,208,209) THEN p.turnover ELSE 0 END) AS RNTOver ,
								SUM(CASE WHEN p.sporttype IN (251,208,209) THEN p.winlost ELSE 0 END) AS RNWL ,
								SUM(CASE WHEN p.sporttype = 210 THEN p.drawTO ELSE 0 END) AS MRNDraw ,
								SUM(CASE WHEN p.sporttype = 210 THEN p.turnover ELSE 0 END) AS MRNTOver ,
								SUM(CASE WHEN p.sporttype = 210 THEN p.winlost ELSE 0 END) AS MRNWL ,
								SUM(CASE WHEN p.sporttype = 212 THEN p.drawTO ELSE 0 END) AS VBDraw ,
								SUM(CASE WHEN p.sporttype = 212 THEN p.turnover ELSE 0 END) AS VBTOver ,
								SUM(CASE WHEN p.sporttype = 212 THEN p.winlost ELSE 0 END) AS VBWL ,
								SUM(CASE WHEN p.sporttype IN (203,205) THEN p.drawTO ELSE 0 END) AS MGDraw ,
								SUM(CASE WHEN p.sporttype IN (203,205) THEN p.turnover ELSE 0 END) AS MGTOver ,
								SUM(CASE WHEN p.sporttype IN (203,205) THEN p.winlost ELSE 0 END) AS MGWL  ,
								SUM(CASE WHEN p.sporttype = 204 THEN p.drawTO ELSE 0 END) AS CBDraw ,
								SUM(CASE WHEN p.sporttype = 204 THEN p.turnover ELSE 0 END) AS CBTOver ,
								SUM(CASE WHEN p.sporttype = 204 THEN p.winlost ELSE 0 END) AS CBWL ,
								SUM(CASE WHEN p.sporttype = 219 THEN p.drawTO ELSE 0 END) AS GGDraw ,
								SUM(CASE WHEN p.sporttype = 219 THEN p.turnover ELSE 0 END) AS GGTOver ,
								SUM(CASE WHEN p.sporttype = 219 THEN p.winlost ELSE 0 END) AS GGWL ,
								SUM(CASE WHEN p.sporttype = 211 THEN p.drawTO ELSE 0 END) AS ALLBETDraw ,
								SUM(CASE WHEN p.sporttype = 211 THEN p.turnover ELSE 0 END) AS ALLBETTOver ,
								SUM(CASE WHEN p.sporttype = 211 THEN p.winlost ELSE 0 END) AS ALLBETWL,
								SUM(CASE WHEN p.sporttype = 220 THEN p.drawTO ELSE 0 END) AS KLDraw, 
								SUM(CASE WHEN p.sporttype = 220 THEN p.turnover ELSE 0 END) AS KLTOver,
								SUM(CASE WHEN p.sporttype = 220 THEN p.winlost ELSE 0 END) AS KLWL ,
								SUM(CASE WHEN p.sporttype IN (190,191,192,193,194,196) THEN p.drawTO ELSE 0 END) AS VS2Draw, 
								SUM(CASE WHEN p.sporttype IN (190,191,192,193,194,196) THEN p.turnover ELSE 0 END) AS VS2TOver,
								SUM(CASE WHEN p.sporttype IN (190,191,192,193,194,196) THEN p.winlost ELSE 0 END) AS VS2WL,
								SUM(CASE WHEN p.sporttype = -6 THEN p.drawTO ELSE 0 END) AS CODraw,
								SUM(CASE WHEN p.sporttype = -6 THEN p.turnover ELSE 0 END) AS COTOver,
								SUM(CASE WHEN p.sporttype = -6 THEN p.winlost ELSE 0 END) AS COWL,
								SUM(CASE WHEN p.sporttype = 164 THEN p.drawTO ELSE 0 END) AS H5Draw,
								SUM(CASE WHEN p.sporttype = 164 THEN p.turnover ELSE 0 END) AS H5TOver,
								SUM(CASE WHEN p.sporttype = 164 THEN p.winlost ELSE 0 END) AS H5WL,
								SUM(CASE WHEN p.sporttype = 245 THEN p.drawTO ELSE 0 END) AS VGDraw,
								SUM(CASE WHEN p.sporttype = 245 THEN p.turnover ELSE 0 END) AS VGTOver,
								SUM(CASE WHEN p.sporttype = 245 THEN p.winlost ELSE 0 END) AS VGWL,
								SUM(CASE WHEN p.sporttype = 222 THEN p.drawTO ELSE 0 END) AS TGDraw,
								SUM(CASE WHEN p.sporttype = 222 THEN p.turnover ELSE 0 END) AS TGTOver,
								SUM(CASE WHEN p.sporttype = 222 THEN p.winlost ELSE 0 END) AS TGWL,
								SUM(CASE WHEN p.sporttype = 243 THEN p.drawTO ELSE 0 END) AS AECASINODraw,
								SUM(CASE WHEN p.sporttype = 243 THEN p.turnover ELSE 0 END) AS AECASINOTOver,
								SUM(CASE WHEN p.sporttype = 243 THEN p.winlost ELSE 0 END) AS AECASINOWL,
								SUM(CASE WHEN p.sporttype = 200 THEN p.drawTO ELSE 0 END) AS SCDraw,
								SUM(CASE WHEN p.sporttype = 200 THEN p.turnover ELSE 0 END) AS SCTOver,
								SUM(CASE WHEN p.sporttype = 200 THEN p.winlost ELSE 0 END) AS SCWL,
								SUM(CASE WHEN p.sporttype = 244 THEN p.drawTO ELSE 0 END) AS SADraw,
								SUM(CASE WHEN p.sporttype = 244 THEN p.turnover ELSE 0 END) AS SATOver,
								SUM(CASE WHEN p.sporttype = 244 THEN p.winlost ELSE 0 END) AS SAWL,
								SUM(CASE WHEN p.sporttype = 168 THEN p.drawTO ELSE 0 END) AS H5LDraw,
								SUM(CASE WHEN p.sporttype = 168 THEN p.turnover ELSE 0 END) AS H5LTOver,
								SUM(CASE WHEN p.sporttype = 168 THEN p.winlost ELSE 0 END) AS H5LWL,
								SUM(CASE WHEN p.sporttype = 169 THEN p.drawTO ELSE 0 END) AS SLDraw,
								SUM(CASE WHEN p.sporttype = 169 THEN p.turnover ELSE 0 END) AS SLTOver,
								SUM(CASE WHEN p.sporttype = 169 THEN p.winlost ELSE 0 END) AS SLWL,
								SUM(CASE WHEN p.sporttype = 165 THEN p.drawTO ELSE 0 END) AS ARCADraw,
								SUM(CASE WHEN p.sporttype = 165 THEN p.turnover ELSE 0 END) AS ARCATOver,
								SUM(CASE WHEN p.sporttype = 165 THEN p.winlost ELSE 0 END) AS ARCAWL,
								SUM(CASE WHEN p.sporttype = 171 THEN p.drawTO ELSE 0 END) AS VgamingDraw,
								SUM(CASE WHEN p.sporttype = 171 THEN p.turnover ELSE 0 END) AS VgamingTOver,
								SUM(CASE WHEN p.sporttype = 171 THEN p.winlost ELSE 0 END) AS VgamingWL,
								SUM(CASE WHEN p.sporttype = 231 THEN p.drawTO ELSE 0 END) AS VS3Draw,
								SUM(CASE WHEN p.sporttype = 231 THEN p.turnover ELSE 0 END) AS VS3TOver,
								SUM(CASE WHEN p.sporttype = 231 THEN p.winlost ELSE 0 END) AS VS3WL,
								SUM(CASE WHEN p.sporttype = 237 THEN p.drawTO ELSE 0 END) AS MaxGameDraw,
								SUM(CASE WHEN p.sporttype = 237 THEN p.turnover ELSE 0 END) AS MaxGameTOver,
								SUM(CASE WHEN p.sporttype = 237 THEN p.winlost ELSE 0 END) AS MaxGameWL,
								SUM(CASE WHEN p.sporttype = 175 THEN p.drawTO ELSE 0 END) AS BTCDraw,
								SUM(CASE WHEN p.sporttype = 175 THEN p.turnover ELSE 0 END) AS BTCTOver,
								SUM(CASE WHEN p.sporttype = 175 THEN p.winlost ELSE 0 END) AS BTCWL

						FROM bodb_Report.dbo.rptDepWinlostByProduct p WITH(NOLOCK)
						WHERE winlostdate BETWEEN @fromDate AND @toDate 
							AND p.sporttype IN (0,151,161,162,180,190,191,192,193,202,203,204,205,210,211,212,219,220,251,208,209,-6,164,194,196,245,222,243,200,244,168,169,165,171,231,237,175)
							AND p.custid = @CustId 
						GROUP BY p.winlostdate, p.custid
					) p1 ON b.winlostdate = p1.winlostdate
		WHERE b.winlostdate BETWEEN @fromDate AND @toDate
			AND b.winlostdate <> @dbtodaydate
			AND b.custid = @CustId
			AND b.recommend IN (SELECT value FROM STRING_SPLIT(@agentid,','))

		INSERT INTO @WinlostTransfer3rd (CustId, winlostdate, Transfer3rd_Opus, Transfer3rd_HoGaming, Transfer3rd_AG, Transfer3rd_GD, Transfer3rd_VB,
			Transfer3rd_CRYSTAL, Transfer3rd_LBKeno, Transfer3rd_Opal, Transfer3rd_BetSoft, Transfer3rd_iSoftBet, Transfer3rd_CitiBet, Transfer3rd_Topaz,
			Transfer3rd_IMone, Transfer3rd_BTi, Transfer3rd_VRLottery, Transfer3rd_Sapphire, Transfer3rd_KYGaming, Transfer3rd_Moonstone, Transfer3rd_EA,
			Transfer3rd_N2Live, Transfer3rd_IDNPoker, Transfer3rd_BG, Transfer3rd_AVPMini, Transfer3rd_AVPSlot, Transfer3rd_EVO, Transfer3rd_Betradar, Transfer3rd_PP)
		SELECT custid, winlostdate, 
			SUM(CASE PartnerId WHEN 2 THEN TransferAmount ELSE 0 END), -- oops
			SUM(CASE PartnerId WHEN 1 THEN TransferAmount ELSE 0 END), -- HoGaming
			SUM(CASE PartnerId WHEN 3 THEN TransferAmount ELSE 0 END), -- AG
			SUM(CASE PartnerId WHEN 4 THEN TransferAmount ELSE 0 END), -- GD
			SUM(CASE PartnerId WHEN 5 THEN TransferAmount ELSE 0 END),  -- VB
			SUM(CASE PartnerId WHEN 7 THEN TransferAmount ELSE 0 END), -- CRYSTAL
			SUM(CASE PartnerId WHEN 8 THEN TransferAmount ELSE 0 END), -- LBKeno
			SUM(CASE PartnerId WHEN 9 THEN TransferAmount ELSE 0 END), -- Opal
			SUM(CASE PartnerId WHEN 10 THEN TransferAmount ELSE 0 END), -- BetSoft(Amber)
			SUM(CASE PartnerId WHEN 11 THEN TransferAmount ELSE 0 END), -- iSoftBet(Quartz)
			SUM(CASE PartnerId WHEN 12 THEN TransferAmount ELSE 0 END), -- CitiBet(Exchange)
			SUM(CASE WHEN PartnerId IN (13,18) THEN TransferAmount ELSE 0 END), -- Topaz(FG)
			SUM(CASE PartnerId WHEN 14 THEN TransferAmount ELSE 0 END), -- IMone
			SUM(CASE PartnerId WHEN 15 THEN TransferAmount ELSE 0 END), -- BTi
			SUM(CASE PartnerId WHEN 16 THEN TransferAmount ELSE 0 END), -- VRLottery
			SUM(CASE PartnerId WHEN 17 THEN TransferAmount ELSE 0 END), -- Sapphire
			SUM(CASE PartnerId WHEN 19 THEN TransferAmount ELSE 0 END), -- KYGaming
			SUM(CASE PartnerId WHEN 20 THEN TransferAmount ELSE 0 END), -- Moonstone
			SUM(CASE PartnerId WHEN 21 THEN TransferAmount ELSE 0 END), -- EA
			SUM(CASE PartnerId WHEN 22 THEN TransferAmount ELSE 0 END), -- N2Live
			SUM(CASE PartnerId WHEN 23 THEN TransferAmount ELSE 0 END), -- IDNPoker
			SUM(CASE PartnerId WHEN 24 THEN TransferAmount ELSE 0 END), -- BG
			SUM(CASE PartnerId WHEN 25 THEN TransferAmount ELSE 0 END), -- AVPMini
			SUM(CASE PartnerId WHEN 26 THEN TransferAmount ELSE 0 END), -- AVPSlot
			SUM(CASE PartnerId WHEN 27 THEN TransferAmount ELSE 0 END), -- EVO
			SUM(CASE PartnerId WHEN 28 THEN TransferAmount ELSE 0 END), -- Betradar
			SUM(CASE PartnerId WHEN 29 THEN TransferAmount ELSE 0 END)  -- PP
		FROM bodb_Report.dbo.rptDepWinlost_Transfer3rdOthers  WITH(NOLOCK) 
		WHERE  (winlostdate BETWEEN @fromDate AND @toDate) AND winlostdate <> @dbtodaydate AND custid = @Custid AND recommend IN (SELECT value FROM STRING_SPLIT(@agentid,','))  
		GROUP BY winlostdate,CustId

	END
		
	IF (@toDate >= @dbtodaydate)
	BEGIN 
		DECLARE @TodayOpeningBalance MONEY
		SELECT @TodayOpeningBalance = d.ClosingBalance
		FROM bodb_report.dbo.rptdepwinlost d WITH(NOLOCK)
		WHERE d.custid = @CustId AND d.winlostdate = DATEADD(dd, -1, @dbtodaydate)

		INSERT INTO @TodayData (custid, currency, recommend, mrecommend, srecommend,
					OpeningBalance, Deposit, Aff2MemTransfer, Withdrawal, Bonus, Adjustment,
					Transfer3rd, Turnover, DrawGame, Outstanding, Winloss, Transfer3rd_Opus, 
					Transfer3rd_HoGaing, Transfer3rd_AG, Transfer3rd_GD, Transfer3rd_VB,
					Transfer3rd_CRYSTAL, Transfer3rd_LBKeno, Transfer3rd_Opal, Transfer3rd_BetSoft,
					Transfer3rd_iSoftBet, Transfer3rd_CitiBet, Transfer3rd_Topaz, Transfer3rd_IMone,
					Transfer3rd_BTi, Transfer3rd_VRLottery, Transfer3rd_Sapphire, Transfer3rd_KYGaming,
					Transfer3rd_Moonstone, Transfer3rd_EA, Transfer3rd_N2Live, Transfer3rd_IDNPoker, Transfer3rd_BG, Transfer3rd_AVPMini, Transfer3rd_AVPSlot, Transfer3rd_EVO, Transfer3rd_Betradar, Transfer3rd_PP, Promotion)		
		SELECT 
			ISNULL(B.custid,T.CustId) AS custid,
			ISNULL(B.currency, T.Currency) AS Currency, 
			ISNULL(B.recommend, T.recommend) AS recommend, 
			ISNULL(B.mrecommend, T.mrecommend) AS mrecommend, 
			ISNULL(B.srecommend, T.srecommend) AS srecommend,
			@TodayOpeningBalance AS OpeningBalance, ISNULL(Deposit, 0), ISNULL(Aff2MemTransfer, 0), ISNULL(Withdrawal, 0), ISNULL(Bonus, 0), ISNULL(Adjustment, 0),
			ISNULL(Transfer3rd, 0), ISNULL(Turnover, 0), ISNULL(DrawGame, 0), ISNULL(Outstanding, 0), ISNULL(Winloss, 0), ISNULL(Transfer3rd_Opus, 0), 
			ISNULL(Transfer3rd_HoGaing, 0), ISNULL(Transfer3rd_AG, 0), ISNULL(Transfer3rd_GD, 0), ISNULL(Transfer3rd_VB, 0),
			ISNULL(Transfer3rd_CRYSTAL, 0), ISNULL(Transfer3rd_LBKeno, 0), ISNULL(Transfer3rd_Opal, 0), ISNULL(Transfer3rd_BetSoft, 0),
			ISNULL(Transfer3rd_iSoftBet, 0), ISNULL(Transfer3rd_CitiBet, 0), ISNULL(Transfer3rd_Topaz, 0), ISNULL(Transfer3rd_IMone, 0),
			ISNULL(Transfer3rd_BTi, 0), ISNULL(Transfer3rd_VRLottery, 0), ISNULL(Transfer3rd_Sapphire, 0), ISNULL(Transfer3rd_KYGaming, 0),
			ISNULL(Transfer3rd_Moonstone, 0), ISNULL(Transfer3rd_EA, 0), ISNULL(Transfer3rd_N2Live, 0), ISNULL(Transfer3rd_IDNPoker, 0), 
			ISNULL(Transfer3rd_BG, 0), ISNULL(Transfer3rd_AVPMini, 0), ISNULL(Transfer3rd_AVPSlot, 0), ISNULL(Transfer3rd_EVO, 0), ISNULL(Transfer3rd_Betradar, 0), ISNULL(Transfer3rd_PP, 0), ISNULL(Promotion, 0)
		FROM
		(
			SELECT custid, currency, recommend, mrecommend, srecommend,
				SUM(CASE WHEN winlostdate = @dbtodaydate AND [status] NOT IN ('VOID', 'REJECT', 'Refund') THEN stake ELSE 0 END) AS 'Turnover',
				SUM(CASE WHEN winlostdate = @dbtodaydate AND [status] = 'DRAW' THEN stake ELSE 0 END) AS 'DrawGame',
				SUM(CASE WHEN ruben = 0 THEN actual_stake ELSE 0 END) AS 'Outstanding',
				SUM(CASE WHEN winlostdate = @dbtodaydate AND bettype NOT IN (17000,17003) AND ruben = 1 THEN winlost-actual_stake+playercomm ELSE 0 END) AS 'Winloss',
				SUM(CASE WHEN winlostdate = @dbtodaydate AND bettype IN (17000,17003) THEN winlost-actual_stake ELSE 0 END) AS 'Promotion' -- Promotion, Royalty Program
			FROM bodb02.dbo.bettrans WITH(NOLOCK)
			WHERE custid = @CustId 
				AND recommend IN (SELECT value FROM STRING_SPLIT(@agentid,','))	
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
				SUM(CASE WHEN bettype IN (22010,22011) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_Opus', 
				SUM(CASE WHEN bettype IN (22008,22009) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_HoGaing', 
				SUM(CASE WHEN bettype IN (22014,22015) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_AG', 
				SUM(CASE WHEN bettype IN (22016,22017) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_GD',
				SUM(CASE WHEN bettype IN (22018,22019) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_VB',
				SUM(CASE WHEN bettype IN (22020,22021) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_CRYSTAL',
				SUM(CASE WHEN bettype IN (22022,22023) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_LBKeno',
				SUM(CASE WHEN bettype IN (22024,22025) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_Opal',
				SUM(CASE WHEN bettype IN (22026,22027) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_BetSoft',
				SUM(CASE WHEN bettype IN (22028,22029) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_iSoftBet',
				SUM(CASE WHEN bettype IN (22030,22031) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_CitiBet',
				SUM(CASE WHEN bettype IN (22032,22033,22042,22043) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_Topaz',
				SUM(CASE WHEN bettype IN (22034,22035) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_IMone',
				SUM(CASE WHEN bettype IN (22036,22037) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_BTi',
				SUM(CASE WHEN bettype IN (22038,22039) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_VRLottery',
				SUM(CASE WHEN bettype IN (22040,22041) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_Sapphire',
				SUM(CASE WHEN bettype IN (22044,22045) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_KYGaming',
				SUM(CASE WHEN bettype IN (22046,22047) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_Moonstone',
				SUM(CASE WHEN bettype IN (22048,22049) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_EA',
				SUM(CASE WHEN bettype IN (22050,22051) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_N2Live',
				SUM(CASE WHEN bettype IN (22052,22053) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_IDNPoker',
				SUM(CASE WHEN bettype IN (22054,22055) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_BG',
				SUM(CASE WHEN bettype IN (22056,22057) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_AVPMini',
				SUM(CASE WHEN bettype IN (22058,22059) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_AVPSlot',
				SUM(CASE WHEN bettype IN (22060,22061) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_EVO',
				SUM(CASE WHEN bettype IN (22062,22063) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_Betradar',
				SUM(CASE WHEN bettype IN (22064,22065) THEN winlost-actual_stake ELSE 0 END) AS 'Transfer3rd_PP'
			FROM bodb02.dbo.Transfer WITH(NOLOCK)
			WHERE custid = @CustId 
				AND recommend IN (SELECT value FROM STRING_SPLIT(@agentid,','))
				AND winlostdate = @dbtodaydate
			GROUP BY custid, currency, recommend, mrecommend, srecommend	
		)AS T
		ON B.custid = T.custid
		
		UPDATE d
		SET ClosingBalance = OpeningBalance + Deposit + Aff2MemTransfer - Withdrawal + Bonus + Adjustment - Outstanding + Winloss + 
			Transfer3rd + Transfer3rd_HoGaing + Transfer3rd_Opus + Transfer3rd_AG + Transfer3rd_GD + Transfer3rd_VB + Transfer3rd_CRYSTAL + Transfer3rd_LBKeno + Transfer3rd_Opal + Transfer3rd_BetSoft +
			Transfer3rd_iSoftBet + Transfer3rd_CitiBet + Transfer3rd_Topaz + Transfer3rd_IMone + Transfer3rd_BTi + Transfer3rd_VRLottery + Transfer3rd_Sapphire + Transfer3rd_KYGaming + Transfer3rd_Moonstone +
			Transfer3rd_EA + Transfer3rd_N2Live + Transfer3rd_IDNPoker + Transfer3rd_BG + Transfer3rd_AVPMini + Transfer3rd_AVPSlot + Transfer3rd_EVO + Transfer3rd_Betradar + Transfer3rd_PP + Promotion,
			actualrate = e.ActualRate
		FROM @TodayData d 
			INNER JOIN exchangedailyoanda e WITH(NOLOCK) ON d.currency = e.ExchangeId
		
		UPDATE d
		SET SBDraw = ISNULL(p1.SBDraw,0), SBTOver = ISNULL(p1.SBTOver,0), SBWL = ISNULL(p1.SBWL,0),
			HRDraw = ISNULL(p1.HRDraw,0), HRTOver = ISNULL(p1.HRTOver,0), HRWL = ISNULL(p1.HRWL,0),
			NODraw = ISNULL(p1.NODraw,0), NOTOver = ISNULL(p1.NOTOver,0), NOWL = ISNULL(p1.NOWL,0),
			CADraw = ISNULL(p1.CADraw,0), CATOver = ISNULL(p1.CATOver,0), CAWL = ISNULL(p1.CAWL,0),
			VSDraw = ISNULL(p1.VSDraw,0), VSTOver = ISNULL(p1.VSTOver,0), VSWL = ISNULL(p1.VSWL,0),
			KEDraw = ISNULL(p1.KEDraw,0), KETOver = ISNULL(p1.KETOver,0), KEWL = ISNULL(p1.KEWL,0),  --KENO
			RNDraw = ISNULL(p1.RNDraw,0), RNTOver = ISNULL(p1.RNTOver,0), RNWL = ISNULL(p1.RNWL,0),  --RNG
			MRNDraw = ISNULL(p1.MRNDraw,0), MRNTOver = ISNULL(p1.MRNTOver,0), MRNWL = ISNULL(p1.MRNWL,0),  --MRNG
			VBDraw = ISNULL(p1.VBDraw,0), VBTOver = ISNULL(p1.VBTOver,0), VBWL = ISNULL(p1.VBWL,0),  --VB
			MGDraw = ISNULL(p1.MGDraw,0), MGTOver = ISNULL(p1.MGTOver,0), MGWL = ISNULL(p1.MGWL,0), --MG
			GGDraw = ISNULL(p1.GGDraw,0), GGTOver = ISNULL(p1.GGTOver,0), GGWL = ISNULL(p1.GGWL,0), --GG
			ALLBETDraw = ISNULL(p1.ALLBETDraw,0), ALLBETTOver = ISNULL(p1.ALLBETTOver,0), ALLBETWL = ISNULL(p1.ALLBETWL,0),  --ALLBET
			CODraw = ISNULL(p1.CODraw,0), COTOver = ISNULL(p1.COTOver,0), COWL = ISNULL(p1.COWL,0), --Cash Out
			KLDraw = ISNULL(p1.KLDraw,0), KLTOver = ISNULL(p1.KLTOver,0), KLWL = ISNULL(p1.KLWL,0), --KENO Lottery
			VS2Draw = ISNULL(p1.VS2Draw,0), VS2TOver = ISNULL(p1.VS2TOver,0), VS2WL = ISNULL(p1.VS2WL,0), --BetRadar Virtual Sports
			H5Draw = ISNULL(p1.H5Draw,0), H5TOver = ISNULL(p1.H5TOver,0), H5WL = ISNULL(p1.H5WL,0), --Happy5
			VGDraw = ISNULL(p1.VGDraw,0), VGTOver = ISNULL(p1.VGTOver,0), VGWL = ISNULL(p1.VGWL,0),  --Virtual Games
			TGDraw = ISNULL(p1.TGDraw,0), TGTOver = ISNULL(p1.TGTOver,0), TGWL = ISNULL(p1.TGWL,0),  --Table Game
			AECASINODraw = ISNULL(p1.AECASINODraw,0), AECASINOTOver = ISNULL(p1.AECASINOTOver,0), AECASINOWL = ISNULL(p1.AECASINOWL,0), --AE Casino
			SCDraw = ISNULL(p1.SCDraw,0), SCTOver = ISNULL(p1.SCTOver,0), SCWL = ISNULL(p1.SCWL,0),  --SABA Club
			SADraw = ISNULL(p1.SADraw,0), SATOver = ISNULL(p1.SATOver,0), SAWL = ISNULL(p1.SAWL,0),  --SA
			H5LDraw = ISNULL(p1.H5LDraw,0), H5LTOver = ISNULL(p1.H5LTOver,0), H5LWL = ISNULL(p1.H5LWL,0),  --Happy 5 Linked Games
			SLDraw = ISNULL(p1.SLDraw,0), SLTOver = ISNULL(p1.SLTOver,0), SLWL = ISNULL(p1.SLWL,0),  --Sports Lottery
			ARCADraw = ISNULL(p1.ARCADraw,0), ARCATOver = ISNULL(p1.ARCATOver,0), ARCAWL = ISNULL(p1.ARCAWL,0),  --Arcadia Gaming
			VgamingDraw = ISNULL(p1.VgamingDraw,0), VgamingTOver = ISNULL(p1.VgamingTOver,0), VgamingWL = ISNULL(p1.VgamingWL,0), --Vgaming
			VS3Draw = ISNULL(p1.VS3Draw,0), VS3TOver = ISNULL(p1.VS3TOver,0), VS3WL = ISNULL(p1.VS3WL,0), --LG Virtual Sports  
			MaxGameDraw = ISNULL(p1.MaxGameDraw,0), MaxGameTOver = ISNULL(p1.MaxGameTOver,0), MaxGameWL = ISNULL(p1.MaxGameWL,0),  --MaxGame
			BTCDraw = ISNULL(p1.BTCDraw,0), BTCTOver = ISNULL(p1.BTCTOver,0), BTCWL = ISNULL(p1.BTCWL,0)  --Bitcoin
		FROM @TodayData d
			LEFT JOIN (
						SELECT p.winlostdate, p.custid, 
							   /* Steven Add Draw at 2012/11/5 */
							   SUM(CASE WHEN p.sporttype = 0 THEN p.drawTO ELSE 0 END) AS SBDraw,
							   SUM(CASE WHEN p.sporttype = 0 THEN p.turnover ELSE 0 END) AS SBTOver,
							   SUM(CASE WHEN p.sporttype = 0 THEN p.winlost ELSE 0 END) AS SBWL,
							   SUM(CASE WHEN p.sporttype = 151 THEN p.drawTO ELSE 0 END) AS HRDraw,
							   SUM(CASE WHEN p.sporttype = 151 THEN p.turnover ELSE 0 END) AS HRTOver,
							   SUM(CASE WHEN p.sporttype = 151 THEN p.winlost ELSE 0 END) AS HRWL,
							   SUM(CASE WHEN p.sporttype = 161 THEN p.drawTO ELSE 0 END) AS NODraw, 
							   SUM(CASE WHEN p.sporttype = 161 THEN p.turnover ELSE 0 END) AS NOTOver,
							   SUM(CASE WHEN p.sporttype = 161 THEN p.winlost ELSE 0 END) AS NOWL,
							   SUM(CASE WHEN p.sporttype = 162 THEN p.drawTO ELSE 0 END) AS CADraw,
							   SUM(CASE WHEN p.sporttype = 162 THEN p.turnover ELSE 0 END) AS CATOver,
							   SUM(CASE WHEN p.sporttype = 162 THEN p.winlost ELSE 0 END) AS CAWL,
							   SUM(CASE WHEN p.sporttype = 180 THEN p.drawTO ELSE 0 END) AS VSDraw, 
							   SUM(CASE WHEN p.sporttype = 180 THEN p.turnover ELSE 0 END) AS VSTOver,
							   SUM(CASE WHEN p.sporttype = 180 THEN p.winlost ELSE 0 END) AS VSWL, 
							   SUM(CASE WHEN p.sporttype = 202 THEN p.drawTO ELSE 0 END) AS KEDraw, 
							   SUM(CASE WHEN p.sporttype = 202 THEN p.turnover ELSE 0 END) AS KETOver,
							   SUM(CASE WHEN p.sporttype = 202 THEN p.winlost ELSE 0 END) AS KEWL ,
							   SUM(CASE WHEN p.sporttype IN (251,208,209) THEN p.drawTO ELSE 0 END) AS RNDraw ,
							   SUM(CASE WHEN p.sporttype IN (251,208,209) THEN p.turnover ELSE 0 END) AS RNTOver ,
							   SUM(CASE WHEN p.sporttype IN (251,208,209) THEN p.winlost ELSE 0 END) AS RNWL ,
							   SUM(CASE WHEN p.sporttype = 210 THEN p.drawTO ELSE 0 END) AS MRNDraw ,
							   SUM(CASE WHEN p.sporttype = 210 THEN p.turnover ELSE 0 END) AS MRNTOver ,
							   SUM(CASE WHEN p.sporttype = 210 THEN p.winlost ELSE 0 END) AS MRNWL ,
							   SUM(CASE WHEN p.sporttype = 212 THEN p.drawTO ELSE 0 END) AS VBDraw ,
							   SUM(CASE WHEN p.sporttype = 212 THEN p.turnover ELSE 0 END) AS VBTOver ,
							   SUM(CASE WHEN p.sporttype = 212 THEN p.winlost ELSE 0 END) AS VBWL ,
							   SUM(CASE WHEN p.sporttype IN (203,205) THEN p.drawTO ELSE 0 END) AS MGDraw ,
							   SUM(CASE WHEN p.sporttype IN (203,205) THEN p.turnover ELSE 0 END) AS MGTOver ,
							   SUM(CASE WHEN p.sporttype IN (203,205) THEN p.winlost ELSE 0 END) AS MGWL ,
							   SUM(CASE WHEN p.sporttype = 204 THEN p.drawTO ELSE 0 END) AS CBDraw ,
							   SUM(CASE WHEN p.sporttype = 204 THEN p.turnover ELSE 0 END) AS CBTOver ,
							   SUM(CASE WHEN p.sporttype = 204 THEN p.winlost ELSE 0 END) AS CBWL ,
							   SUM(CASE WHEN p.sporttype = 219 THEN p.drawTO ELSE 0 END) AS GGDraw ,
							   SUM(CASE WHEN p.sporttype = 219 THEN p.turnover ELSE 0 END) AS GGTOver ,
							   SUM(CASE WHEN p.sporttype = 219 THEN p.winlost ELSE 0 END) AS GGWL ,
							   SUM(CASE WHEN p.sporttype = 211 THEN p.drawTO ELSE 0 END) AS ALLBETDraw ,
							   SUM(CASE WHEN p.sporttype = 211 THEN p.turnover ELSE 0 END) AS ALLBETTOver ,
							   SUM(CASE WHEN p.sporttype = 211 THEN p.winlost ELSE 0 END) AS ALLBETWL,
							   SUM(CASE WHEN p.sporttype = 220 THEN p.drawTO ELSE 0 END) AS KLDraw, 
							   SUM(CASE WHEN p.sporttype = 220 THEN p.turnover ELSE 0 END) AS KLTOver,
							   SUM(CASE WHEN p.sporttype = 220 THEN p.winlost ELSE 0 END) AS KLWL ,
							   SUM(CASE WHEN p.sporttype IN (190,191,192,193,194,196) THEN p.drawTO ELSE 0 END) AS VS2Draw, 
							   SUM(CASE WHEN p.sporttype IN (190,191,192,193,194,196) THEN p.turnover ELSE 0 END) AS VS2TOver,
							   SUM(CASE WHEN p.sporttype IN (190,191,192,193,194,196) THEN p.winlost ELSE 0 END) AS VS2WL ,
							   SUM(CASE WHEN p.sporttype = -6 THEN p.drawTO ELSE 0 END) AS CODraw,
							   SUM(CASE WHEN p.sporttype = -6 THEN p.turnover ELSE 0 END) AS COTOver,
							   SUM(CASE WHEN p.sporttype = -6 THEN p.winlost ELSE 0 END) AS COWL,
							   SUM(CASE WHEN p.sporttype = 164 THEN p.drawTO ELSE 0 END) AS H5Draw,
							   SUM(CASE WHEN p.sporttype = 164 THEN p.turnover ELSE 0 END) AS H5TOver,
							   SUM(CASE WHEN p.sporttype = 164 THEN p.winlost ELSE 0 END) AS H5WL,
							   SUM(CASE WHEN p.sporttype = 245 THEN p.drawTO ELSE 0 END) AS VGDraw,
							   SUM(CASE WHEN p.sporttype = 245 THEN p.turnover ELSE 0 END) AS VGTOver,
							   SUM(CASE WHEN p.sporttype = 245 THEN p.winlost ELSE 0 END) AS VGWL,
							   SUM(CASE WHEN p.sporttype = 222 THEN p.drawTO ELSE 0 END) AS TGDraw,
							   SUM(CASE WHEN p.sporttype = 222 THEN p.turnover ELSE 0 END) AS TGTOver,
							   SUM(CASE WHEN p.sporttype = 222 THEN p.winlost ELSE 0 END) AS TGWL,
							   SUM(CASE WHEN p.sporttype = 243 THEN p.drawTO ELSE 0 END) AS AECASINODraw,
							   SUM(CASE WHEN p.sporttype = 243 THEN p.turnover ELSE 0 END) AS AECASINOTOver,
							   SUM(CASE WHEN p.sporttype = 243 THEN p.winlost ELSE 0 END) AS AECASINOWL,
							   SUM(CASE WHEN p.sporttype = 200 THEN p.drawTO ELSE 0 END) AS SCDraw,
							   SUM(CASE WHEN p.sporttype = 200 THEN p.turnover ELSE 0 END) AS SCTOver,
							   SUM(CASE WHEN p.sporttype = 200 THEN p.winlost ELSE 0 END) AS SCWL,
							   SUM(CASE WHEN p.sporttype = 244 THEN p.drawTO ELSE 0 END) AS SADraw,
							   SUM(CASE WHEN p.sporttype = 244 THEN p.turnover ELSE 0 END) AS SATOver,
							   SUM(CASE WHEN p.sporttype = 244 THEN p.winlost ELSE 0 END) AS SAWL,
							   SUM(CASE WHEN p.sporttype = 168 THEN p.drawTO ELSE 0 END) AS H5LDraw,
							   SUM(CASE WHEN p.sporttype = 168 THEN p.turnover ELSE 0 END) AS H5LTOver,
							   SUM(CASE WHEN p.sporttype = 168 THEN p.winlost ELSE 0 END) AS H5LWL,
							   SUM(CASE WHEN p.sporttype = 169 THEN p.drawTO ELSE 0 END) AS SLDraw,
							   SUM(CASE WHEN p.sporttype = 169 THEN p.turnover ELSE 0 END) AS SLTOver,
							   SUM(CASE WHEN p.sporttype = 169 THEN p.winlost ELSE 0 END) AS SLWL,
							   SUM(CASE WHEN p.sporttype = 165 THEN p.drawTO ELSE 0 END) AS ARCADraw,
							   SUM(CASE WHEN p.sporttype = 165 THEN p.turnover ELSE 0 END) AS ARCATOver,
							   SUM(CASE WHEN p.sporttype = 165 THEN p.winlost ELSE 0 END) AS ARCAWL,
							   SUM(CASE WHEN p.sporttype = 171 THEN p.drawTO ELSE 0 END) AS VgamingDraw,
							   SUM(CASE WHEN p.sporttype = 171 THEN p.turnover ELSE 0 END) AS VgamingTOver,
							   SUM(CASE WHEN p.sporttype = 171 THEN p.winlost ELSE 0 END) AS VgamingWL,
							   SUM(CASE WHEN p.sporttype = 231 THEN p.drawTO ELSE 0 END) AS VS3Draw,
							   SUM(CASE WHEN p.sporttype = 231 THEN p.turnover ELSE 0 END) AS VS3TOver,
							   SUM(CASE WHEN p.sporttype = 231 THEN p.winlost ELSE 0 END) AS VS3WL,
							   SUM(CASE WHEN p.sporttype = 237 THEN p.drawTO ELSE 0 END) AS MaxGameDraw,
							   SUM(CASE WHEN p.sporttype = 237 THEN p.turnover ELSE 0 END) AS MaxGameTOver,
							   SUM(CASE WHEN p.sporttype = 237 THEN p.winlost ELSE 0 END) AS MaxGameWL,
							   SUM(CASE WHEN p.sporttype = 175 THEN p.drawTO ELSE 0 END) AS BTCDraw,
							   SUM(CASE WHEN p.sporttype = 175 THEN p.turnover ELSE 0 END) AS BTCTOver,
							   SUM(CASE WHEN p.sporttype = 175 THEN p.winlost ELSE 0 END) AS BTCWL
						FROM bodb_Report.dbo.rptDepWinlostByProduct p WITH(NOLOCK)
						WHERE winlostdate = @dbtodaydate
							AND p.sporttype IN (0,151,161,162,180,190,191,192,193,202,203,204,205,210,211,212,219,220,251,208,209,-6,164,194,196,245,222,243,200,244,168,169,165,171,231,237,175)
							AND p.custid = @CustId 
						GROUP BY p.winlostdate, p.custid
					) p1 ON d.custid = p1.custid
	END

	SELECT b.*,ISNULL(o.Transfer3rd_Opus,0) AS Transfer3rd_Opus,ISNULL(o.Transfer3rd_HoGaming,0) AS Transfer3rd_HoGaming, ISNULL(o.Transfer3rd_AG,0) AS Transfer3rd_AG,
		   ISNULL(o.Transfer3rd_GD, 0) AS Transfer3rd_GD, ISNULL(o.Transfer3rd_VB, 0) AS Transfer3rd_VB, ISNULL(o.Transfer3rd_CRYSTAL, 0) AS Transfer3rd_CRYSTAL,
		   ISNULL(o.Transfer3rd_LBKeno, 0) AS Transfer3rd_LBKeno, ISNULL(o.Transfer3rd_Opal, 0) AS Transfer3rd_Opal, ISNULL(o.Transfer3rd_BetSoft, 0) AS Transfer3rd_BetSoft,
		   ISNULL(o.Transfer3rd_iSoftBet, 0) AS Transfer3rd_iSoftBet,
		   ISNULL(o.Transfer3rd_CitiBet, 0) AS Transfer3rd_CitiBet,
		   ISNULL(o.Transfer3rd_Topaz, 0) AS Transfer3rd_Topaz,
		   ISNULL(o.Transfer3rd_IMone, 0) AS Transfer3rd_IMone,
		   ISNULL(o.Transfer3rd_BTi, 0) AS Transfer3rd_BTi,
		   ISNULL(o.Transfer3rd_VRLottery, 0) AS Transfer3rd_VRLottery,
		   ISNULL(o.Transfer3rd_Sapphire, 0) AS Transfer3rd_Sapphire,
		   ISNULL(o.Transfer3rd_KYGaming, 0) AS Transfer3rd_KYGaming,
		   ISNULL(o.Transfer3rd_Moonstone, 0) AS Transfer3rd_Moonstone,
		   ISNULL(o.Transfer3rd_EA, 0) AS Transfer3rd_EA,
		   ISNULL(o.Transfer3rd_N2Live, 0) AS Transfer3rd_N2Live,
		   ISNULL(o.Transfer3rd_IDNPoker, 0) AS Transfer3rd_IDNPoker,
		   ISNULL(o.Transfer3rd_BG, 0) AS Transfer3rd_BG,
		   ISNULL(o.Transfer3rd_AVPMini, 0) AS Transfer3rd_AVPMini,
		   ISNULL(o.Transfer3rd_AVPSlot, 0) AS Transfer3rd_AVPSlot,
		   ISNULL(o.Transfer3rd_EVO, 0) AS Transfer3rd_EVO,
		   ISNULL(o.Transfer3rd_Betradar, 0) AS Transfer3rd_Betradar,
		   ISNULL(o.Transfer3rd_PP, 0) AS Transfer3rd_PP
	FROM @WinlostTmp b
		LEFT JOIN @WinlostTransfer3rd o ON b.winlostdate = o.winlostdate
	UNION
	SELECT @dbtodaydate, d.* FROM @TodayData d
	ORDER BY b.winlostdate
END


