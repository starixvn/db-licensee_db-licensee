/*<info serverAlias="DBACC-bodb02" executers="ow_12bet" isFunction="0" isNested="0"></info>*/
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
--20221125@Ruby: Remove HR(Racing), MRNG, MG, CB, GG, SC(SABA Club), Live Casino(CA), HoGaming, Opus, GD, VB, LBKeno, iSoftBet(Quartz), IDNPoker Report Data
--20230320@Benson: hotfix add opal data and remove oops data (accidentally deleted opal)
--20230320@Benson: add promotion bettyp(4299,4300,4298,4297,17004,3007,1699,1698,3150,1906,3899,3898,4600,4599,4598,2499,8700)
--20230505@Mark(DB06.bodb02): Add SGWin Report Data
--20230607@KenYang(DB06.bodb02): Add PMSports, PMLive Report Data
--20230727@Ruby(DB06.bodb02): Add BT1 Report Data
--20231225@KenYang(DB06.bodb02): Add JILISlot, PGSoft Report Data
--20240104@Benson: Add Saba Reward Risk free Rebate (bettype: 17007) in the promotion 
--20240207@KenYang(DB06.bodb02): Add Virtual Football League(SportType:178), Virtual Soccer Bundesliga(SportType:195) Report Data
--20240313@MaxCheng(DB06.bodb02): Combine Virtual Sports 2,3 to Virtual Sports ,and remove Cash Out
--20240410@Eddie: Change metadata 'Dot_Admin,Dot_Member' to 'ow_12bet' - [Redmine: #202118]
--20240620@Benson: Add Saba Coins Cash Exchange (bettype: 17008) in the promotion
--20240712@Benson: Add Virtual Cock Fighting (sport: 188)  
--20240905@Edward: Add BG(SportType:239) and Yeebet(SportType:159) Report Data
--20241011@KenYang: 1.Add JILI(SportType:158), PGSoft(SportType:232), HB(SportType:238), CG(SportType: 167), Joker(SportType:234), Seal(SportType: 156), Spribe Report Data. 
                    2.Remove IMone, VRLottery, Moonstone, EA, N2Live, BG, SGWin, PMSports, PMLive transfer columns
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
        NODraw money default(0), NOTOver money default(0), NOWL money default(0),
        VSDraw money default(0), VSTOver money default(0), VSWL money default(0),
        KEDraw money default(0), KETOver money default(0), KEWL money default(0), --KENO
        RNDraw money default(0), RNTOver money default(0), RNWL money default(0), --RNG
        VBDraw money default(0), VBTOver money default(0), VBWL money default(0), --VB
        ALLBETDraw money default(0), ALLBETTOver money default(0), ALLBETWL money default(0), --ALLBET
        KLDraw money default(0), KLTOver money default(0), KLWL money default(0), --KENO Lottery
        H5Draw money default(0), H5TOver money default(0), H5WL money default(0), --Happy5
        VGDraw money default(0), VGTOver money default(0), VGWL money default(0), --Virtual Games
        TGDraw money default(0), TGTOver money default(0), TGWL money default(0), --Table Game
        AECASINODraw money default(0), AECASINOTOver money default(0), AECASINOWL money default(0), --AE Casino
        SADraw money default(0), SATOver money default(0), SAWL money default(0), --SA
        H5LDraw money default(0), H5LTOver money default(0), H5LWL money default(0), --Happy 5 Linked Games
        SLDraw money default(0), SLTOver money default(0), SLWL money default(0), --Sports Lottery
        ARCADraw money default(0), ARCATOver money default(0), ARCAWL money default(0), --Arcadia Gaming
        VgamingDraw money default(0), VgamingTOver money default(0), VgamingWL money default(0), --Vgaming
        MaxGameDraw money default(0), MaxGameTOver money default(0), MaxGameWL money default(0), --MaxGame
        BTCDraw money default(0), BTCTOver money default(0), BTCWL money default(0), --Bitcoin
		BGDraw money default(0), BGTOver money default(0), BGWL money default(0), --BG
		YBDraw money default(0), YBTOver money default(0), YBWL money default(0), --Yeebet
		JILIDraw money default(0), JILITOver money default(0), JILIWL money default(0), --JILI
		PGSoftDraw money default(0), PGSoftTOver money default(0), PGSoftWL money default(0), --PGSoft
		HBDraw money default(0), HBTOver money default(0), HBWL money default(0), --HB
		CGDraw money default(0), CGTOver money default(0), CGWL money default(0), --CG
		JokerDraw money default(0), JokerTOver money default(0), JokerWL money default(0), --Joker
		SealDraw money default(0), SealTOver money default(0), SealWL money default(0), --Seal
        Winloss money default(0), ClosingBalance money default(0), Transfer3rd money default(0), DrawGame money default(0),
        recommend int, mrecommend int, srecommend int, actualrate float, Promotion money,
        Transfer3rd_AG money default(0), Transfer3rd_CRYSTAL money default(0),
        Transfer3rd_Opal money default(0), Transfer3rd_BetSoft money default(0), Transfer3rd_CitiBet money default(0), Transfer3rd_Topaz money default(0),
        Transfer3rd_BTi money default(0), Transfer3rd_Sapphire money default(0), Transfer3rd_KYGaming money default(0),
        Transfer3rd_AVPMini money default(0),Transfer3rd_AVPSlot money default(0),Transfer3rd_EVO money default(0),Transfer3rd_Betradar money default(0), Transfer3rd_PP money default(0),
        Transfer3rd_BT1 money default(0),Transfer3rd_JILISlot money default(0),
        Transfer3rd_PGSoft money default(0),Transfer3rd_Spribe money default(0))
        
    DECLARE @WinlostTmp TABLE (
        winlostdate datetime, custid int, currency int, OpeningBalance money default(0), Deposit money default(0), Aff2MemTransfer money default(0),
        Withdrawal money default(0), Bonus money default(0), Adjustment money default(0), Turnover money default(0), Outstanding money default(0),
        SBDraw money default(0), SBTOver money default(0), SBWL money default(0), 
        NODraw money default(0), NOTOver money default(0), NOWL money default(0),
        VSDraw money default(0), VSTOver money default(0), VSWL money default(0),
        KEDraw money default(0), KETOver money default(0), KEWL money default(0), --KENO
        RNDraw money default(0), RNTOver money default(0), RNWL money default(0), --RNG
        VBDraw money default(0), VBTOver money default(0), VBWL money default(0), --VB
        ALLBETDraw money default(0), ALLBETTOver money default(0), ALLBETWL money default(0), --ALLBET
        KLDraw money default(0), KLTOver money default(0), KLWL money default(0), --KENO Lottery
        H5Draw money default(0), H5TOver money default(0), H5WL money default(0), --Happy5
        VGDraw money default(0), VGTOver money default(0), VGWL money default(0), --Virtual Games
        TGDraw money default(0), TGTOver money default(0), TGWL money default(0), --Table Game
        AECASINODraw money default(0), AECASINOTOver money default(0), AECASINOWL money default(0), --AE Casino
        SADraw money default(0), SATOver money default(0), SAWL money default(0), --SA
        H5LDraw money default(0), H5LTOver money default(0), H5LWL money default(0), --Happy 5 Linked Games
        SLDraw money default(0), SLTOver money default(0), SLWL money default(0), --Sports Lottery
        ARCADraw money default(0), ARCATOver money default(0), ARCAWL money default(0), --Arcadia Gaming
        VgamingDraw money default(0), VgamingTOver money default(0), VgamingWL money default(0), --Vgaming
        MaxGameDraw money default(0), MaxGameTOver money default(0), MaxGameWL money default(0), --MaxGame
        BTCDraw money default(0), BTCTOver money default(0), BTCWL money default(0), --Bitcoin
		BGDraw money default(0), BGTOver money default(0), BGWL money default(0), --BG
		YBDraw money default(0), YBTOver money default(0), YBWL money default(0), --Yeebet
		JILIDraw money default(0), JILITOver money default(0), JILIWL money default(0), --JILI
		PGSoftDraw money default(0), PGSoftTOver money default(0), PGSoftWL money default(0), --PGSoft
		HBDraw money default(0), HBTOver money default(0), HBWL money default(0), --HB
		CGDraw money default(0), CGTOver money default(0), CGWL money default(0), --CG
		JokerDraw money default(0), JokerTOver money default(0), JokerWL money default(0), --Joker
		SealDraw money default(0), SealTOver money default(0), SealWL money default(0), --Seal
        Winloss money default(0), ClosingBalance money default(0), Transfer3rd money default(0), DrawGame money default(0),
        recommend int, mrecommend int, srecommend int, actualrate float, Promotion money)

    --Get Transfer 3rd Winlost data
    DECLARE @WinlostTransfer3rd TABLE(CustId int , winlostdate datetime, Transfer3rd_AG money,
        Transfer3rd_CRYSTAL money, Transfer3rd_Opal money, Transfer3rd_BetSoft money, Transfer3rd_CitiBet money, Transfer3rd_Topaz money,
        Transfer3rd_BTi money, Transfer3rd_Sapphire money, Transfer3rd_KYGaming money,
        Transfer3rd_AVPMini money, Transfer3rd_AVPSlot money, Transfer3rd_EVO money, Transfer3rd_Betradar money, Transfer3rd_PP money,
        Transfer3rd_BT1 money, Transfer3rd_JILISlot money, Transfer3rd_PGSoft money, Transfer3rd_Spribe money)
        
    IF (@fromDate < @CutDate) OR (@toDate < @CutDate)
    BEGIN
        INSERT INTO @WinlostTmp
        SELECT b.winlostdate, b.custid, b.currency, b.OpeningBalance, b.Deposit, b.Aff2MemTransfer,
               b.Withdrawal, b.Bonus, b.Adjustment, b.Turnover, b.Outstanding,
               ISNULL(p1.SBDraw, 0) AS SBDraw, ISNULL(p1.SBTOver, 0) AS SBTOver, ISNULL(p1.SBWL, 0) AS SBWL,
               ISNULL(p1.NODraw, 0) AS NODraw, ISNULL(p1.NOTOver, 0) AS NOTOver, ISNULL(p1.NOWL, 0) AS NOWL,
               ISNULL(p1.VSDraw, 0) AS VSDraw, ISNULL(p1.VSTOver, 0) AS VSTOver, ISNULL(p1.VSWL, 0) AS VSWL,
               ISNULL(p1.KEDraw, 0) AS KEDraw, ISNULL(p1.KETOver, 0) AS KETOver, ISNULL(p1.KEWL, 0) AS KEWL, --KENO
               ISNULL(p1.RNDraw, 0) AS RNDraw, ISNULL(p1.RNTOver, 0) AS RNTOver, ISNULL(p1.RNWL, 0) AS RNWL, --RNG
               ISNULL(p1.VBDraw, 0) AS VBDraw, ISNULL(p1.VBTOver, 0) AS VBOver, ISNULL(p1.VBWL, 0) AS VBWL, --VB
               ISNULL(p1.ALLBETDraw, 0) AS ALLBETDraw, ISNULL(p1.ALLBETTOver, 0) AS ALLBETTOver, ISNULL(p1.ALLBETWL, 0) AS ALLBETWL, --ALLBET
               ISNULL(p1.KLDraw, 0) AS KLDraw, ISNULL(p1.KLTOver, 0) AS KLTOver, ISNULL(p1.KLWL, 0) AS KLWL, --KENO Lottery
               ISNULL(p1.H5Draw, 0) AS H5Draw, ISNULL(p1.H5TOver, 0) AS H5TOver, ISNULL(p1.H5WL, 0) AS H5WL, --Happy5
               ISNULL(p1.VGDraw, 0) AS VGDraw, ISNULL(p1.VGTOver, 0) AS VGTOver, ISNULL(p1.VGWL, 0) AS VGWL, --Virtual Games
               ISNULL(p1.TGDraw, 0) AS TGDraw, ISNULL(p1.TGTOver, 0) AS TGTOver, ISNULL(p1.TGWL, 0) AS TGWL, --Table Game
               ISNULL(p1.AECASINODraw, 0) AS AECASINODraw, ISNULL(p1.AECASINOTOver, 0) AS AECASINOTOver, ISNULL(p1.AECASINOWL, 0) AS AECASINOWL, --AE Casino
               ISNULL(p1.SADraw, 0) AS SADraw, ISNULL(p1.SATOver, 0) AS SATOver, ISNULL(p1.SAWL, 0) AS SAWL, --SA
               ISNULL(p1.H5LDraw, 0) AS H5LDraw, ISNULL(p1.H5LTOver, 0) AS H5LTOver, ISNULL(p1.H5LWL, 0) AS H5LWL, --Happy 5 Linked Games
               ISNULL(p1.SLDraw, 0) AS SLDraw, ISNULL(p1.SLTOver, 0) AS SLTOver, ISNULL(p1.SLWL, 0) AS SLWL, --Sports Lottery
               ISNULL(p1.ARCADraw, 0) AS ARCADraw, ISNULL(p1.ARCATOver, 0) AS ARCTOver, ISNULL(p1.ARCAWL, 0) AS ARCAWL, --Arcadia Gaming
               ISNULL(p1.VgamingDraw, 0) AS VgamingDraw, ISNULL(p1.VgamingTOver, 0) AS VgamingTOver, ISNULL(p1.VgamingWL, 0) AS VgamingWL, --Vgaming
               ISNULL(p1.MaxGameDraw, 0) AS MaxGameDraw, ISNULL(p1.MaxGameTOver, 0) AS MaxGameTOver, ISNULL(p1.MaxGameWL, 0) AS MaxGameWL, --MaxGame
               ISNULL(p1.BTCDraw, 0) AS BTCDraw, ISNULL(p1.BTCTOver, 0) AS BTCTOver, ISNULL(p1.BTCWL, 0) AS BTCWL, --Bitcoin
			   ISNULL(p1.BGDraw, 0) AS BGDraw, ISNULL(p1.BGTOver, 0) AS BGTOver, ISNULL(p1.BGWL, 0) AS BGWL, --BG
			   ISNULL(p1.YBDraw, 0) AS YBDraw, ISNULL(p1.YBTOver, 0) AS YBTOver, ISNULL(p1.YBWL, 0) AS YBWL, --Yeebet
			   ISNULL(p1.JILIDraw, 0) AS JILIDraw, ISNULL(p1.JILITOver, 0) AS JILITOver, ISNULL(p1.JILIWL, 0) AS JILIWL, --JILI
			   ISNULL(p1.PGSoftDraw, 0) AS PGSoftDraw, ISNULL(p1.PGSoftTOver, 0) AS PGSoftTOver, ISNULL(p1.PGSoftWL, 0) AS PGSoftWL, --PGSoft
			   ISNULL(p1.HBDraw, 0) AS HBDraw, ISNULL(p1.HBTOver, 0) AS HBTOver, ISNULL(p1.HBWL, 0) AS HBWL, --HB
			   ISNULL(p1.CGDraw, 0) AS CGDraw, ISNULL(p1.CGTOver, 0) AS CGTOver, ISNULL(p1.CGWL, 0) AS CGWL, --CG
			   ISNULL(p1.JokerDraw, 0) AS JokerDraw, ISNULL(p1.JokerTOver, 0) AS JokerTOver, ISNULL(p1.JokerWL, 0) AS JokerWL, --Joker
			   ISNULL(p1.SealDraw, 0) AS SealDraw, ISNULL(p1.SealTOver, 0) AS SealTOver, ISNULL(p1.SealWL, 0) AS SealWL, --Seal
               b.Winloss, b.ClosingBalance, b.Transfer3rd, b.DrawGame,
               b.recommend, b.mrecommend, b.srecommend, b.actualrate, b.Promotion
        FROM bodb_Report.dbo.rptDepWinlost_bk b WITH(NOLOCK)
            LEFT JOIN (
                        SELECT p.winlostdate, p.custid, 
                                SUM(CASE WHEN p.sporttype = 0 THEN p.drawTO ELSE 0 END)AS SBDraw,
                                SUM(CASE WHEN p.sporttype = 0 THEN p.turnover ELSE 0 END) AS SBTOver,
                                SUM(CASE WHEN p.sporttype = 0 THEN p.winlost ELSE 0 END) AS SBWL,
                                SUM(CASE WHEN p.sporttype = 161 THEN p.drawTO ELSE 0 END) AS NODraw, 
                                SUM(CASE WHEN p.sporttype = 161 THEN p.turnover ELSE 0 END) AS NOTOver,
                                SUM(CASE WHEN p.sporttype = 161 THEN p.winlost ELSE 0 END) AS NOWL,
                                SUM(CASE WHEN p.sporttype IN (180,190,191,192,193,194,195,196,178,231,188) THEN p.drawTO ELSE 0 END) AS VSDraw, 
                                SUM(CASE WHEN p.sporttype IN (180,190,191,192,193,194,195,196,178,231,188) THEN p.turnover ELSE 0 END) AS VSTOver,
                                SUM(CASE WHEN p.sporttype IN (180,190,191,192,193,194,195,196,178,231,188) THEN p.winlost ELSE 0 END) AS VSWL, 
                                SUM(CASE WHEN p.sporttype = 202 THEN p.drawTO ELSE 0 END) AS KEDraw, 
                                SUM(CASE WHEN p.sporttype = 202 THEN p.turnover ELSE 0 END) AS KETOver,
                                SUM(CASE WHEN p.sporttype = 202 THEN p.winlost ELSE 0 END) AS KEWL ,
                                SUM(CASE WHEN p.sporttype IN (251,208,209) THEN p.drawTO ELSE 0 END) AS RNDraw ,
                                SUM(CASE WHEN p.sporttype IN (251,208,209) THEN p.turnover ELSE 0 END) AS RNTOver ,
                                SUM(CASE WHEN p.sporttype IN (251,208,209) THEN p.winlost ELSE 0 END) AS RNWL ,
                                SUM(CASE WHEN p.sporttype = 212 THEN p.drawTO ELSE 0 END) AS VBDraw ,
                                SUM(CASE WHEN p.sporttype = 212 THEN p.turnover ELSE 0 END) AS VBTOver ,
                                SUM(CASE WHEN p.sporttype = 212 THEN p.winlost ELSE 0 END) AS VBWL ,
                                SUM(CASE WHEN p.sporttype = 211 THEN p.drawTO ELSE 0 END) AS ALLBETDraw ,
                                SUM(CASE WHEN p.sporttype = 211 THEN p.turnover ELSE 0 END) AS ALLBETTOver ,
                                SUM(CASE WHEN p.sporttype = 211 THEN p.winlost ELSE 0 END) AS ALLBETWL,
                                SUM(CASE WHEN p.sporttype = 220 THEN p.drawTO ELSE 0 END) AS KLDraw, 
                                SUM(CASE WHEN p.sporttype = 220 THEN p.turnover ELSE 0 END) AS KLTOver,
                                SUM(CASE WHEN p.sporttype = 220 THEN p.winlost ELSE 0 END) AS KLWL ,
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
                                SUM(CASE WHEN p.sporttype = 237 THEN p.drawTO ELSE 0 END) AS MaxGameDraw,
                                SUM(CASE WHEN p.sporttype = 237 THEN p.turnover ELSE 0 END) AS MaxGameTOver,
                                SUM(CASE WHEN p.sporttype = 237 THEN p.winlost ELSE 0 END) AS MaxGameWL,
                                SUM(CASE WHEN p.sporttype = 175 THEN p.drawTO ELSE 0 END) AS BTCDraw,
                                SUM(CASE WHEN p.sporttype = 175 THEN p.turnover ELSE 0 END) AS BTCTOver,
                                SUM(CASE WHEN p.sporttype = 175 THEN p.winlost ELSE 0 END) AS BTCWL,
								SUM(CASE WHEN p.sporttype = 239 THEN p.drawTO ELSE 0 END) AS BGDraw,
                                SUM(CASE WHEN p.sporttype = 239 THEN p.turnover ELSE 0 END) AS BGTOver,
                                SUM(CASE WHEN p.sporttype = 239 THEN p.winlost ELSE 0 END) AS BGWL,
								SUM(CASE WHEN p.sporttype = 159 THEN p.drawTO ELSE 0 END) AS YBDraw,
                                SUM(CASE WHEN p.sporttype = 159 THEN p.turnover ELSE 0 END) AS YBTOver,
                                SUM(CASE WHEN p.sporttype = 159 THEN p.winlost ELSE 0 END) AS YBWL,
								SUM(CASE WHEN p.sporttype = 158 THEN p.drawTO ELSE 0 END) AS JILIDraw,
                                SUM(CASE WHEN p.sporttype = 158 THEN p.turnover ELSE 0 END) AS JILITOver,
                                SUM(CASE WHEN p.sporttype = 158 THEN p.winlost ELSE 0 END) AS JILIWL,
								SUM(CASE WHEN p.sporttype = 232 THEN p.drawTO ELSE 0 END) AS PGSoftDraw,
                                SUM(CASE WHEN p.sporttype = 232 THEN p.turnover ELSE 0 END) AS PGSoftTOver,
                                SUM(CASE WHEN p.sporttype = 232 THEN p.winlost ELSE 0 END) AS PGSoftWL,
								SUM(CASE WHEN p.sporttype = 238 THEN p.drawTO ELSE 0 END) AS HBDraw,
                                SUM(CASE WHEN p.sporttype = 238 THEN p.turnover ELSE 0 END) AS HBTOver,
                                SUM(CASE WHEN p.sporttype = 238 THEN p.winlost ELSE 0 END) AS HBWL,
								SUM(CASE WHEN p.sporttype = 167 THEN p.drawTO ELSE 0 END) AS CGDraw,
                                SUM(CASE WHEN p.sporttype = 167 THEN p.turnover ELSE 0 END) AS CGTOver,
                                SUM(CASE WHEN p.sporttype = 167 THEN p.winlost ELSE 0 END) AS CGWL,
								SUM(CASE WHEN p.sporttype = 234 THEN p.drawTO ELSE 0 END) AS JokerDraw,
                                SUM(CASE WHEN p.sporttype = 234 THEN p.turnover ELSE 0 END) AS JokerTOver,
                                SUM(CASE WHEN p.sporttype = 234 THEN p.winlost ELSE 0 END) AS JokerWL,
								SUM(CASE WHEN p.sporttype = 156 THEN p.drawTO ELSE 0 END) AS SealDraw,
                                SUM(CASE WHEN p.sporttype = 156 THEN p.turnover ELSE 0 END) AS SealTOver,
                                SUM(CASE WHEN p.sporttype = 156 THEN p.winlost ELSE 0 END) AS SealWL
                        FROM bodb_Report.dbo.rptDepWinlostByProduct_BK p WITH(NOLOCK)
                        WHERE winlostdate BETWEEN @fromDate AND @toDate 
                            AND p.sporttype IN (0,161,180,190,191,192,193,202,211,212,220,251,208,209,164,194,196,245,222,243,244,168,169,165,171,231,237,175,195,178,188,239,159,158,232,238,167,234,156)
                            AND p.custid = @CustId 
                        GROUP BY p.winlostdate, p.custid
                    ) p1 ON b.winlostdate = p1.winlostdate
        WHERE b.winlostdate BETWEEN @fromDate AND @toDate
            AND b.custid = @CustId
            AND b.recommend IN (SELECT value FROM STRING_SPLIT(@agentid,','))

        INSERT INTO @WinlostTransfer3rd (CustId, winlostdate, Transfer3rd_AG,
            Transfer3rd_CRYSTAL, Transfer3rd_Opal, Transfer3rd_BetSoft, Transfer3rd_CitiBet, Transfer3rd_Topaz,
            Transfer3rd_BTi, Transfer3rd_Sapphire, Transfer3rd_KYGaming,
            Transfer3rd_AVPMini, Transfer3rd_AVPSlot, Transfer3rd_EVO, Transfer3rd_Betradar, Transfer3rd_PP,
            Transfer3rd_BT1, Transfer3rd_JILISlot, Transfer3rd_PGSoft, Transfer3rd_Spribe)
        SELECT custid, winlostdate,
            SUM(CASE PartnerId WHEN 3 THEN TransferAmount ELSE 0 END), -- AG
            SUM(CASE PartnerId WHEN 7 THEN TransferAmount ELSE 0 END), -- CRYSTAL
            SUM(CASE PartnerId WHEN 9 THEN TransferAmount ELSE 0 END), -- Opal
            SUM(CASE PartnerId WHEN 10 THEN TransferAmount ELSE 0 END), -- BetSoft(Amber)
            SUM(CASE PartnerId WHEN 12 THEN TransferAmount ELSE 0 END), -- CitiBet(Exchange)
            SUM(CASE WHEN PartnerId IN (13,18) THEN TransferAmount ELSE 0 END), -- Topaz(FG)
            SUM(CASE PartnerId WHEN 15 THEN TransferAmount ELSE 0 END), -- BTi
            SUM(CASE PartnerId WHEN 17 THEN TransferAmount ELSE 0 END), -- Sapphire
            SUM(CASE PartnerId WHEN 19 THEN TransferAmount ELSE 0 END), -- KYGaming
            SUM(CASE PartnerId WHEN 25 THEN TransferAmount ELSE 0 END), -- AVPMini
            SUM(CASE PartnerId WHEN 26 THEN TransferAmount ELSE 0 END), -- AVPSlot
            SUM(CASE PartnerId WHEN 27 THEN TransferAmount ELSE 0 END), -- EVO
            SUM(CASE PartnerId WHEN 28 THEN TransferAmount ELSE 0 END), -- Betradar
            SUM(CASE PartnerId WHEN 29 THEN TransferAmount ELSE 0 END), -- PP
            SUM(CASE PartnerId WHEN 33 THEN TransferAmount ELSE 0 END), -- BT1
            SUM(CASE PartnerId WHEN 34 THEN TransferAmount ELSE 0 END), -- JILISlot
            SUM(CASE PartnerId WHEN 35 THEN TransferAmount ELSE 0 END),  -- PGSoft
            SUM(CASE PartnerId WHEN 50 THEN TransferAmount ELSE 0 END)  -- Spribe
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
               ISNULL(p1.NODraw, 0) AS NODraw, ISNULL(p1.NOTOver, 0) AS NOTOver, ISNULL(p1.NOWL, 0) AS NOWL,
               ISNULL(p1.VSDraw, 0) AS VSDraw, ISNULL(p1.VSTOver, 0) AS VSTOver, ISNULL(p1.VSWL, 0) AS VSWL,
               ISNULL(p1.KEDraw, 0) AS KEDraw, ISNULL(p1.KETOver, 0) AS KETOver, ISNULL(p1.KEWL, 0) AS KEWL, --KENO
               ISNULL(p1.RNDraw, 0) AS RNDraw, ISNULL(p1.RNTOver, 0) AS RNTOver, ISNULL(p1.RNWL, 0) AS RNWL, --RNG
               ISNULL(p1.VBDraw, 0) AS VBDraw, ISNULL(p1.VBTOver, 0) AS VBOver, ISNULL(p1.VBWL, 0) AS VBWL, --VB
               ISNULL(p1.ALLBETDraw, 0) AS ALLBETDraw, ISNULL(p1.ALLBETTOver, 0) AS ALLBETTOver, ISNULL(p1.ALLBETWL, 0) AS ALLBETWL, --ALLBET
               ISNULL(p1.KLDraw, 0) AS KLDraw, ISNULL(p1.KLTOver, 0) AS KLTOver, ISNULL(p1.KLWL, 0) AS KLWL, --KENO Lottery
               ISNULL(p1.H5Draw, 0) AS H5Draw, ISNULL(p1.H5TOver, 0) AS H5TOver, ISNULL(p1.H5WL, 0) AS H5WL, --Happy5
               ISNULL(p1.VGDraw, 0) AS VGDraw, ISNULL(p1.VGTOver, 0) AS VGTOver, ISNULL(p1.VGWL, 0) AS VGWL, --Virtual Games
               ISNULL(p1.TGDraw, 0) AS TGDraw, ISNULL(p1.TGTOver, 0) AS TGTOver, ISNULL(p1.TGWL, 0) AS TGWL, --Table Game
               ISNULL(p1.AECASINODraw, 0) AS AECASINODraw, ISNULL(p1.AECASINOTOver, 0) AS AECASINOTOver, ISNULL(p1.AECASINOWL, 0) AS AECASINOWL, --AE Casino
               ISNULL(p1.SADraw, 0) AS SADraw, ISNULL(p1.SATOver, 0) AS SATOver, ISNULL(p1.SAWL, 0) AS SAWL, --SA
               ISNULL(p1.H5LDraw, 0) AS H5LDraw, ISNULL(p1.H5LTOver, 0) AS H5LTOver, ISNULL(p1.H5LWL, 0) AS H5LWL, --Happy 5 Linked Games
               ISNULL(p1.SLDraw, 0) AS SLDraw, ISNULL(p1.SLTOver, 0) AS SLTOver, ISNULL(p1.SLWL, 0) AS SLWL, --Sports Lottery
               ISNULL(p1.ARCADraw, 0) AS ARCADraw, ISNULL(p1.ARCATOver, 0) AS ARCTOver, ISNULL(p1.ARCAWL, 0) AS ARCAWL, --Arcadia Gaming
               ISNULL(p1.VgamingDraw, 0) AS VgamingDraw, ISNULL(p1.VgamingTOver, 0) AS VgamingTOver, ISNULL(p1.VgamingWL, 0) AS VgamingWL, --Vgaming
               ISNULL(p1.MaxGameDraw, 0) AS MaxGameDraw, ISNULL(p1.MaxGameTOver, 0) AS MaxGameTOver, ISNULL(p1.MaxGameWL, 0) AS MaxGameWL, --MaxGame
               ISNULL(p1.BTCDraw, 0) AS BTCDraw, ISNULL(p1.BTCTOver, 0) AS BTCTOver, ISNULL(p1.BTCWL, 0) AS BTCWL, --Bitcoin
			   ISNULL(p1.BGDraw, 0) AS BGDraw, ISNULL(p1.BGTOver, 0) AS BGTOver, ISNULL(p1.BGWL, 0) AS BGWL, --BG
			   ISNULL(p1.YBDraw, 0) AS YBDraw, ISNULL(p1.YBTOver, 0) AS YBTOver, ISNULL(p1.YBWL, 0) AS YBWL, --Yeebet
			   ISNULL(p1.JILIDraw, 0) AS JILIDraw, ISNULL(p1.JILITOver, 0) AS JILITOver, ISNULL(p1.JILIWL, 0) AS JILIWL, --JILI
			   ISNULL(p1.PGSoftDraw, 0) AS PGSoftDraw, ISNULL(p1.PGSoftTOver, 0) AS PGSoftTOver, ISNULL(p1.PGSoftWL, 0) AS PGSoftWL, --PGSoft
			   ISNULL(p1.HBDraw, 0) AS HBDraw, ISNULL(p1.HBTOver, 0) AS HBTOver, ISNULL(p1.HBWL, 0) AS HBWL, --HB
			   ISNULL(p1.CGDraw, 0) AS CGDraw, ISNULL(p1.CGTOver, 0) AS CGTOver, ISNULL(p1.CGWL, 0) AS CGWL, --CG
			   ISNULL(p1.JokerDraw, 0) AS JokerDraw, ISNULL(p1.JokerTOver, 0) AS JokerTOver, ISNULL(p1.JokerWL, 0) AS JokerWL, --Joker
			   ISNULL(p1.SealDraw, 0) AS SealDraw, ISNULL(p1.SealTOver, 0) AS SealTOver, ISNULL(p1.SealWL, 0) AS SealWL, --Seal
               b.Winloss, b.ClosingBalance, b.Transfer3rd, b.DrawGame,
               b.recommend, b.mrecommend, b.srecommend, b.actualrate, b.Promotion
        FROM bodb_Report.dbo.rptDepWinlost b WITH(NOLOCK)
            LEFT JOIN (
                        SELECT p.winlostdate, p.custid, 
                                SUM(CASE WHEN p.sporttype = 0 THEN p.drawTO ELSE 0 END) AS SBDraw,
                                SUM(CASE WHEN p.sporttype = 0 THEN p.turnover ELSE 0 END) AS SBTOver,
                                SUM(CASE WHEN p.sporttype = 0 THEN p.winlost ELSE 0 END) AS SBWL,
                                SUM(CASE WHEN p.sporttype = 161 THEN p.drawTO ELSE 0 END) AS NODraw, 
                                SUM(CASE WHEN p.sporttype = 161 THEN p.turnover ELSE 0 END) AS NOTOver,
                                SUM(CASE WHEN p.sporttype = 161 THEN p.winlost ELSE 0 END) AS NOWL,
                                SUM(CASE WHEN p.sporttype IN (180,190,191,192,193,194,195,196,178,231,188) THEN p.drawTO ELSE 0 END) AS VSDraw, 
                                SUM(CASE WHEN p.sporttype IN (180,190,191,192,193,194,195,196,178,231,188) THEN p.turnover ELSE 0 END) AS VSTOver,
                                SUM(CASE WHEN p.sporttype IN (180,190,191,192,193,194,195,196,178,231,188) THEN p.winlost ELSE 0 END) AS VSWL, 
                                SUM(CASE WHEN p.sporttype = 202 THEN p.drawTO ELSE 0 END) AS KEDraw, 
                                SUM(CASE WHEN p.sporttype = 202 THEN p.turnover ELSE 0 END) AS KETOver,
                                SUM(CASE WHEN p.sporttype = 202 THEN p.winlost ELSE 0 END) AS KEWL ,
                                SUM(CASE WHEN p.sporttype IN (251,208,209) THEN p.drawTO ELSE 0 END) AS RNDraw ,
                                SUM(CASE WHEN p.sporttype IN (251,208,209) THEN p.turnover ELSE 0 END) AS RNTOver ,
                                SUM(CASE WHEN p.sporttype IN (251,208,209) THEN p.winlost ELSE 0 END) AS RNWL ,
                                SUM(CASE WHEN p.sporttype = 212 THEN p.drawTO ELSE 0 END) AS VBDraw ,
                                SUM(CASE WHEN p.sporttype = 212 THEN p.turnover ELSE 0 END) AS VBTOver ,
                                SUM(CASE WHEN p.sporttype = 212 THEN p.winlost ELSE 0 END) AS VBWL ,
                                SUM(CASE WHEN p.sporttype = 211 THEN p.drawTO ELSE 0 END) AS ALLBETDraw ,
                                SUM(CASE WHEN p.sporttype = 211 THEN p.turnover ELSE 0 END) AS ALLBETTOver ,
                                SUM(CASE WHEN p.sporttype = 211 THEN p.winlost ELSE 0 END) AS ALLBETWL,
                                SUM(CASE WHEN p.sporttype = 220 THEN p.drawTO ELSE 0 END) AS KLDraw, 
                                SUM(CASE WHEN p.sporttype = 220 THEN p.turnover ELSE 0 END) AS KLTOver,
                                SUM(CASE WHEN p.sporttype = 220 THEN p.winlost ELSE 0 END) AS KLWL ,
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
                                SUM(CASE WHEN p.sporttype = 237 THEN p.drawTO ELSE 0 END) AS MaxGameDraw,
                                SUM(CASE WHEN p.sporttype = 237 THEN p.turnover ELSE 0 END) AS MaxGameTOver,
                                SUM(CASE WHEN p.sporttype = 237 THEN p.winlost ELSE 0 END) AS MaxGameWL,
                                SUM(CASE WHEN p.sporttype = 175 THEN p.drawTO ELSE 0 END) AS BTCDraw,
                                SUM(CASE WHEN p.sporttype = 175 THEN p.turnover ELSE 0 END) AS BTCTOver,
                                SUM(CASE WHEN p.sporttype = 175 THEN p.winlost ELSE 0 END) AS BTCWL,
								SUM(CASE WHEN p.sporttype = 239 THEN p.drawTO ELSE 0 END) AS BGDraw,
                                SUM(CASE WHEN p.sporttype = 239 THEN p.turnover ELSE 0 END) AS BGTOver,
                                SUM(CASE WHEN p.sporttype = 239 THEN p.winlost ELSE 0 END) AS BGWL,
								SUM(CASE WHEN p.sporttype = 159 THEN p.drawTO ELSE 0 END) AS YBDraw,
                                SUM(CASE WHEN p.sporttype = 159 THEN p.turnover ELSE 0 END) AS YBTOver,
                                SUM(CASE WHEN p.sporttype = 159 THEN p.winlost ELSE 0 END) AS YBWL,
								SUM(CASE WHEN p.sporttype = 158 THEN p.drawTO ELSE 0 END) AS JILIDraw,
                                SUM(CASE WHEN p.sporttype = 158 THEN p.turnover ELSE 0 END) AS JILITOver,
                                SUM(CASE WHEN p.sporttype = 158 THEN p.winlost ELSE 0 END) AS JILIWL,
								SUM(CASE WHEN p.sporttype = 232 THEN p.drawTO ELSE 0 END) AS PGSoftDraw,
                                SUM(CASE WHEN p.sporttype = 232 THEN p.turnover ELSE 0 END) AS PGSoftTOver,
                                SUM(CASE WHEN p.sporttype = 232 THEN p.winlost ELSE 0 END) AS PGSoftWL,
								SUM(CASE WHEN p.sporttype = 238 THEN p.drawTO ELSE 0 END) AS HBDraw,
                                SUM(CASE WHEN p.sporttype = 238 THEN p.turnover ELSE 0 END) AS HBTOver,
                                SUM(CASE WHEN p.sporttype = 238 THEN p.winlost ELSE 0 END) AS HBWL,
								SUM(CASE WHEN p.sporttype = 167 THEN p.drawTO ELSE 0 END) AS CGDraw,
                                SUM(CASE WHEN p.sporttype = 167 THEN p.turnover ELSE 0 END) AS CGTOver,
                                SUM(CASE WHEN p.sporttype = 167 THEN p.winlost ELSE 0 END) AS CGWL,
								SUM(CASE WHEN p.sporttype = 234 THEN p.drawTO ELSE 0 END) AS JokerDraw,
                                SUM(CASE WHEN p.sporttype = 234 THEN p.turnover ELSE 0 END) AS JokerTOver,
                                SUM(CASE WHEN p.sporttype = 234 THEN p.winlost ELSE 0 END) AS JokerWL,
								SUM(CASE WHEN p.sporttype = 156 THEN p.drawTO ELSE 0 END) AS SealDraw,
                                SUM(CASE WHEN p.sporttype = 156 THEN p.turnover ELSE 0 END) AS SealTOver,
                                SUM(CASE WHEN p.sporttype = 156 THEN p.winlost ELSE 0 END) AS SealWL

                        FROM bodb_Report.dbo.rptDepWinlostByProduct p WITH(NOLOCK)
                        WHERE winlostdate BETWEEN @fromDate AND @toDate 
                            AND p.sporttype IN (0,161,180,190,191,192,193,202,211,212,220,251,208,209,164,194,196,245,222,243,244,168,169,165,171,231,237,175,195,178,188,239,159,158,232,238,167,234,156)
                            AND p.custid = @CustId 
                        GROUP BY p.winlostdate, p.custid
                    ) p1 ON b.winlostdate = p1.winlostdate
        WHERE b.winlostdate BETWEEN @fromDate AND @toDate
            AND b.winlostdate <> @dbtodaydate
            AND b.custid = @CustId
            AND b.recommend IN (SELECT value FROM STRING_SPLIT(@agentid,','))

        INSERT INTO @WinlostTransfer3rd (CustId, winlostdate, Transfer3rd_AG,
            Transfer3rd_CRYSTAL, Transfer3rd_Opal, Transfer3rd_BetSoft, Transfer3rd_CitiBet, Transfer3rd_Topaz,
            Transfer3rd_BTi, Transfer3rd_Sapphire, Transfer3rd_KYGaming,
            Transfer3rd_AVPMini, Transfer3rd_AVPSlot, Transfer3rd_EVO, Transfer3rd_Betradar, Transfer3rd_PP,
            Transfer3rd_BT1, Transfer3rd_JILISlot, Transfer3rd_PGSoft, Transfer3rd_Spribe)
        SELECT custid, winlostdate, 
            SUM(CASE PartnerId WHEN 3 THEN TransferAmount ELSE 0 END), -- AG
            SUM(CASE PartnerId WHEN 7 THEN TransferAmount ELSE 0 END), -- CRYSTAL
            SUM(CASE PartnerId WHEN 9 THEN TransferAmount ELSE 0 END), -- Opal
            SUM(CASE PartnerId WHEN 10 THEN TransferAmount ELSE 0 END), -- BetSoft(Amber)
            SUM(CASE PartnerId WHEN 12 THEN TransferAmount ELSE 0 END), -- CitiBet(Exchange)
            SUM(CASE WHEN PartnerId IN (13,18) THEN TransferAmount ELSE 0 END), -- Topaz(FG)
            SUM(CASE PartnerId WHEN 15 THEN TransferAmount ELSE 0 END), -- BTi
            SUM(CASE PartnerId WHEN 17 THEN TransferAmount ELSE 0 END), -- Sapphire
            SUM(CASE PartnerId WHEN 19 THEN TransferAmount ELSE 0 END), -- KYGaming
            SUM(CASE PartnerId WHEN 25 THEN TransferAmount ELSE 0 END), -- AVPMini
            SUM(CASE PartnerId WHEN 26 THEN TransferAmount ELSE 0 END), -- AVPSlot
            SUM(CASE PartnerId WHEN 27 THEN TransferAmount ELSE 0 END), -- EVO
            SUM(CASE PartnerId WHEN 28 THEN TransferAmount ELSE 0 END), -- Betradar
            SUM(CASE PartnerId WHEN 29 THEN TransferAmount ELSE 0 END), -- PP
            SUM(CASE PartnerId WHEN 33 THEN TransferAmount ELSE 0 END), -- BT1
            SUM(CASE PartnerId WHEN 34 THEN TransferAmount ELSE 0 END), -- JILISlot
            SUM(CASE PartnerId WHEN 35 THEN TransferAmount ELSE 0 END), -- PGSoft
            SUM(CASE PartnerId WHEN 50 THEN TransferAmount ELSE 0 END)  -- Spribe
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
                    Transfer3rd, Turnover, DrawGame, Outstanding, Winloss, 
                    Transfer3rd_AG,
                    Transfer3rd_CRYSTAL, Transfer3rd_Opal, Transfer3rd_BetSoft,
                    Transfer3rd_CitiBet, Transfer3rd_Topaz,
                    Transfer3rd_BTi, Transfer3rd_Sapphire, Transfer3rd_KYGaming,
                    Transfer3rd_AVPMini, Transfer3rd_AVPSlot,
                    Transfer3rd_EVO, Transfer3rd_Betradar, Transfer3rd_PP,
                    Transfer3rd_BT1, Transfer3rd_JILISlot, Transfer3rd_PGSoft, Transfer3rd_Spribe, Promotion)
        SELECT 
            ISNULL(B.custid,T.CustId) AS custid,
            ISNULL(B.currency, T.Currency) AS Currency, 
            ISNULL(B.recommend, T.recommend) AS recommend, 
            ISNULL(B.mrecommend, T.mrecommend) AS mrecommend, 
            ISNULL(B.srecommend, T.srecommend) AS srecommend,
            @TodayOpeningBalance AS OpeningBalance, ISNULL(Deposit, 0), ISNULL(Aff2MemTransfer, 0), ISNULL(Withdrawal, 0), ISNULL(Bonus, 0), ISNULL(Adjustment, 0),
            ISNULL(Transfer3rd, 0), ISNULL(Turnover, 0), ISNULL(DrawGame, 0), ISNULL(Outstanding, 0), ISNULL(Winloss, 0),
            ISNULL(Transfer3rd_AG, 0),
            ISNULL(Transfer3rd_CRYSTAL, 0), ISNULL(Transfer3rd_Opal, 0), ISNULL(Transfer3rd_BetSoft, 0),
            ISNULL(Transfer3rd_CitiBet, 0), ISNULL(Transfer3rd_Topaz, 0),
            ISNULL(Transfer3rd_BTi, 0), ISNULL(Transfer3rd_Sapphire, 0), ISNULL(Transfer3rd_KYGaming, 0),
            ISNULL(Transfer3rd_AVPMini, 0), ISNULL(Transfer3rd_AVPSlot, 0), ISNULL(Transfer3rd_EVO, 0),
            ISNULL(Transfer3rd_Betradar, 0), ISNULL(Transfer3rd_PP, 0),
            ISNULL(Transfer3rd_BT1, 0), ISNULL(Transfer3rd_JILISlot, 0), ISNULL(Transfer3rd_PGSoft, 0), ISNULL(Transfer3rd_Spribe, 0), ISNULL(Promotion, 0)
        FROM
        (
            SELECT custid, currency, recommend, mrecommend, srecommend,
                SUM(CASE WHEN winlostdate = @dbtodaydate AND [status] NOT IN ('VOID', 'REJECT', 'Refund') THEN stake ELSE 0 END) AS 'Turnover',
                SUM(CASE WHEN winlostdate = @dbtodaydate AND [status] = 'DRAW' THEN stake ELSE 0 END) AS 'DrawGame',
                SUM(CASE WHEN ruben = 0 THEN actual_stake ELSE 0 END) AS 'Outstanding',
                SUM(CASE WHEN winlostdate = @dbtodaydate AND bettype NOT IN (17000,17003,4299,4300,4298,4297,17004,3007,1699,1698,3150,1906,3899,3898,4600,4599,4598,2499,8700,17007,17008) AND ruben = 1 THEN winlost-actual_stake+playercomm ELSE 0 END) AS 'Winloss',
                SUM(CASE WHEN winlostdate = @dbtodaydate AND bettype IN (17000,17003,4299,4300,4298,4297,17004,3007,1699,1698,3150,1906,3899,3898,4600,4599,4598,2499,8700,17007,17008) THEN winlost-actual_stake ELSE 0 END) AS 'Promotion' -- Promotion, Royalty Program
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
            WHERE custid = @CustId 
                AND recommend IN (SELECT value FROM STRING_SPLIT(@agentid,','))
                AND winlostdate = @dbtodaydate
            GROUP BY custid, currency, recommend, mrecommend, srecommend    
        )AS T
        ON B.custid = T.custid
        
        UPDATE d
        SET ClosingBalance = OpeningBalance + Deposit + Aff2MemTransfer - Withdrawal + Bonus + Adjustment - Outstanding + Winloss + 
            Transfer3rd + Transfer3rd_AG + Transfer3rd_CRYSTAL + Transfer3rd_Opal + Transfer3rd_BetSoft +
            Transfer3rd_CitiBet + Transfer3rd_Topaz + Transfer3rd_BTi + Transfer3rd_Sapphire + Transfer3rd_KYGaming +
            Transfer3rd_AVPMini + Transfer3rd_AVPSlot + Transfer3rd_EVO + Transfer3rd_Betradar + Transfer3rd_PP +
            Transfer3rd_BT1 + Transfer3rd_JILISlot + Transfer3rd_PGSoft + Transfer3rd_Spribe + Promotion,
            actualrate = e.ActualRate
        FROM @TodayData d 
            INNER JOIN exchangedailyoanda e WITH(NOLOCK) ON d.currency = e.ExchangeId
        
        UPDATE d
        SET SBDraw = ISNULL(p1.SBDraw,0), SBTOver = ISNULL(p1.SBTOver,0), SBWL = ISNULL(p1.SBWL,0),
            NODraw = ISNULL(p1.NODraw,0), NOTOver = ISNULL(p1.NOTOver,0), NOWL = ISNULL(p1.NOWL,0),
            VSDraw = ISNULL(p1.VSDraw,0), VSTOver = ISNULL(p1.VSTOver,0), VSWL = ISNULL(p1.VSWL,0),
            KEDraw = ISNULL(p1.KEDraw,0), KETOver = ISNULL(p1.KETOver,0), KEWL = ISNULL(p1.KEWL,0),  --KENO
            RNDraw = ISNULL(p1.RNDraw,0), RNTOver = ISNULL(p1.RNTOver,0), RNWL = ISNULL(p1.RNWL,0),  --RNG
            VBDraw = ISNULL(p1.VBDraw,0), VBTOver = ISNULL(p1.VBTOver,0), VBWL = ISNULL(p1.VBWL,0),  --VB
            ALLBETDraw = ISNULL(p1.ALLBETDraw,0), ALLBETTOver = ISNULL(p1.ALLBETTOver,0), ALLBETWL = ISNULL(p1.ALLBETWL,0),  --ALLBET
            KLDraw = ISNULL(p1.KLDraw,0), KLTOver = ISNULL(p1.KLTOver,0), KLWL = ISNULL(p1.KLWL,0), --KENO Lottery
            H5Draw = ISNULL(p1.H5Draw,0), H5TOver = ISNULL(p1.H5TOver,0), H5WL = ISNULL(p1.H5WL,0), --Happy5
            VGDraw = ISNULL(p1.VGDraw,0), VGTOver = ISNULL(p1.VGTOver,0), VGWL = ISNULL(p1.VGWL,0),  --Virtual Games
            TGDraw = ISNULL(p1.TGDraw,0), TGTOver = ISNULL(p1.TGTOver,0), TGWL = ISNULL(p1.TGWL,0),  --Table Game
            AECASINODraw = ISNULL(p1.AECASINODraw,0), AECASINOTOver = ISNULL(p1.AECASINOTOver,0), AECASINOWL = ISNULL(p1.AECASINOWL,0), --AE Casino
            SADraw = ISNULL(p1.SADraw,0), SATOver = ISNULL(p1.SATOver,0), SAWL = ISNULL(p1.SAWL,0),  --SA
            H5LDraw = ISNULL(p1.H5LDraw,0), H5LTOver = ISNULL(p1.H5LTOver,0), H5LWL = ISNULL(p1.H5LWL,0),  --Happy 5 Linked Games
            SLDraw = ISNULL(p1.SLDraw,0), SLTOver = ISNULL(p1.SLTOver,0), SLWL = ISNULL(p1.SLWL,0),  --Sports Lottery
            ARCADraw = ISNULL(p1.ARCADraw,0), ARCATOver = ISNULL(p1.ARCATOver,0), ARCAWL = ISNULL(p1.ARCAWL,0),  --Arcadia Gaming
            VgamingDraw = ISNULL(p1.VgamingDraw,0), VgamingTOver = ISNULL(p1.VgamingTOver,0), VgamingWL = ISNULL(p1.VgamingWL,0), --Vgaming
            MaxGameDraw = ISNULL(p1.MaxGameDraw,0), MaxGameTOver = ISNULL(p1.MaxGameTOver,0), MaxGameWL = ISNULL(p1.MaxGameWL,0),  --MaxGame
            BTCDraw = ISNULL(p1.BTCDraw,0), BTCTOver = ISNULL(p1.BTCTOver,0), BTCWL = ISNULL(p1.BTCWL,0),  --Bitcoin
			BGDraw = ISNULL(p1.BGDraw,0), BGTOver = ISNULL(p1.BGTOver,0), BGWL = ISNULL(p1.BGWL,0),  --BG
			YBDraw = ISNULL(p1.YBDraw,0), YBTOver = ISNULL(p1.YBTOver,0), YBWL = ISNULL(p1.YBWL,0),  --Yeebet
			JILIDraw = ISNULL(p1.JILIDraw,0), JILITOver = ISNULL(p1.JILITOver,0), JILIWL = ISNULL(p1.JILIWL,0),  --JILI
			PGSoftDraw = ISNULL(p1.PGSoftDraw,0), PGSoftTOver = ISNULL(p1.PGSoftTOver,0), PGSoftWL = ISNULL(p1.PGSoftWL,0),   --PGSoft
			HBDraw = ISNULL(p1.HBDraw,0), HBTOver = ISNULL(p1.HBTOver,0), HBWL = ISNULL(p1.HBWL,0),  --HB
			CGDraw = ISNULL(p1.CGDraw,0), CGTOver = ISNULL(p1.CGTOver,0), CGWL = ISNULL(p1.CGWL,0),  --CG
			JokerDraw = ISNULL(p1.JokerDraw,0), JokerTOver = ISNULL(p1.JokerTOver,0), JokerWL = ISNULL(p1.JokerWL,0),  --Joker
			SealDraw = ISNULL(p1.SealDraw,0), SealTOver = ISNULL(p1.SealTOver,0), SealWL = ISNULL(p1.SealWL,0)   --Seal
        FROM @TodayData d
            LEFT JOIN (
                        SELECT p.winlostdate, p.custid, 
                               /* Steven Add Draw at 2012/11/5 */
                               SUM(CASE WHEN p.sporttype = 0 THEN p.drawTO ELSE 0 END) AS SBDraw,
                               SUM(CASE WHEN p.sporttype = 0 THEN p.turnover ELSE 0 END) AS SBTOver,
                               SUM(CASE WHEN p.sporttype = 0 THEN p.winlost ELSE 0 END) AS SBWL,
                               SUM(CASE WHEN p.sporttype = 161 THEN p.drawTO ELSE 0 END) AS NODraw, 
                               SUM(CASE WHEN p.sporttype = 161 THEN p.turnover ELSE 0 END) AS NOTOver,
                               SUM(CASE WHEN p.sporttype = 161 THEN p.winlost ELSE 0 END) AS NOWL,
                               SUM(CASE WHEN p.sporttype IN (180,190,191,192,193,194,195,196,178,231,188) THEN p.drawTO ELSE 0 END) AS VSDraw, 
                               SUM(CASE WHEN p.sporttype IN (180,190,191,192,193,194,195,196,178,231,188) THEN p.turnover ELSE 0 END) AS VSTOver,
                               SUM(CASE WHEN p.sporttype IN (180,190,191,192,193,194,195,196,178,231,188) THEN p.winlost ELSE 0 END) AS VSWL, 
                               SUM(CASE WHEN p.sporttype = 202 THEN p.drawTO ELSE 0 END) AS KEDraw, 
                               SUM(CASE WHEN p.sporttype = 202 THEN p.turnover ELSE 0 END) AS KETOver,
                               SUM(CASE WHEN p.sporttype = 202 THEN p.winlost ELSE 0 END) AS KEWL ,
                               SUM(CASE WHEN p.sporttype IN (251,208,209) THEN p.drawTO ELSE 0 END) AS RNDraw ,
                               SUM(CASE WHEN p.sporttype IN (251,208,209) THEN p.turnover ELSE 0 END) AS RNTOver ,
                               SUM(CASE WHEN p.sporttype IN (251,208,209) THEN p.winlost ELSE 0 END) AS RNWL ,
                               SUM(CASE WHEN p.sporttype = 212 THEN p.drawTO ELSE 0 END) AS VBDraw ,
                               SUM(CASE WHEN p.sporttype = 212 THEN p.turnover ELSE 0 END) AS VBTOver ,
                               SUM(CASE WHEN p.sporttype = 212 THEN p.winlost ELSE 0 END) AS VBWL ,
                               SUM(CASE WHEN p.sporttype = 211 THEN p.drawTO ELSE 0 END) AS ALLBETDraw ,
                               SUM(CASE WHEN p.sporttype = 211 THEN p.turnover ELSE 0 END) AS ALLBETTOver ,
                               SUM(CASE WHEN p.sporttype = 211 THEN p.winlost ELSE 0 END) AS ALLBETWL,
                               SUM(CASE WHEN p.sporttype = 220 THEN p.drawTO ELSE 0 END) AS KLDraw, 
                               SUM(CASE WHEN p.sporttype = 220 THEN p.turnover ELSE 0 END) AS KLTOver,
                               SUM(CASE WHEN p.sporttype = 220 THEN p.winlost ELSE 0 END) AS KLWL ,
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
                               SUM(CASE WHEN p.sporttype = 237 THEN p.drawTO ELSE 0 END) AS MaxGameDraw,
                               SUM(CASE WHEN p.sporttype = 237 THEN p.turnover ELSE 0 END) AS MaxGameTOver,
                               SUM(CASE WHEN p.sporttype = 237 THEN p.winlost ELSE 0 END) AS MaxGameWL,
                               SUM(CASE WHEN p.sporttype = 175 THEN p.drawTO ELSE 0 END) AS BTCDraw,
                               SUM(CASE WHEN p.sporttype = 175 THEN p.turnover ELSE 0 END) AS BTCTOver,
                               SUM(CASE WHEN p.sporttype = 175 THEN p.winlost ELSE 0 END) AS BTCWL,
							   SUM(CASE WHEN p.sporttype = 239 THEN p.drawTO ELSE 0 END) AS BGDraw,
                               SUM(CASE WHEN p.sporttype = 239 THEN p.turnover ELSE 0 END) AS BGTOver,
                               SUM(CASE WHEN p.sporttype = 239 THEN p.winlost ELSE 0 END) AS BGWL,
							   SUM(CASE WHEN p.sporttype = 159 THEN p.drawTO ELSE 0 END) AS YBDraw,
                               SUM(CASE WHEN p.sporttype = 159 THEN p.turnover ELSE 0 END) AS YBTOver,
                               SUM(CASE WHEN p.sporttype = 159 THEN p.winlost ELSE 0 END) AS YBWL,
							   SUM(CASE WHEN p.sporttype = 158 THEN p.drawTO ELSE 0 END) AS JILIDraw,
                               SUM(CASE WHEN p.sporttype = 158 THEN p.turnover ELSE 0 END) AS JILITOver,
                               SUM(CASE WHEN p.sporttype = 158 THEN p.winlost ELSE 0 END) AS JILIWL,
							   SUM(CASE WHEN p.sporttype = 232 THEN p.drawTO ELSE 0 END) AS PGSoftDraw,
                               SUM(CASE WHEN p.sporttype = 232 THEN p.turnover ELSE 0 END) AS PGSoftTOver,
                               SUM(CASE WHEN p.sporttype = 232 THEN p.winlost ELSE 0 END) AS PGSoftWL,
							   SUM(CASE WHEN p.sporttype = 238 THEN p.drawTO ELSE 0 END) AS HBDraw,
                               SUM(CASE WHEN p.sporttype = 238 THEN p.turnover ELSE 0 END) AS HBTOver,
                               SUM(CASE WHEN p.sporttype = 238 THEN p.winlost ELSE 0 END) AS HBWL,
							   SUM(CASE WHEN p.sporttype = 167 THEN p.drawTO ELSE 0 END) AS CGDraw,
                               SUM(CASE WHEN p.sporttype = 167 THEN p.turnover ELSE 0 END) AS CGTOver,
                               SUM(CASE WHEN p.sporttype = 167 THEN p.winlost ELSE 0 END) AS CGWL,
							   SUM(CASE WHEN p.sporttype = 234 THEN p.drawTO ELSE 0 END) AS JokerDraw,
                               SUM(CASE WHEN p.sporttype = 234 THEN p.turnover ELSE 0 END) AS JokerTOver,
                               SUM(CASE WHEN p.sporttype = 234 THEN p.winlost ELSE 0 END) AS JokerWL,
							   SUM(CASE WHEN p.sporttype = 156 THEN p.drawTO ELSE 0 END) AS SealDraw,
                               SUM(CASE WHEN p.sporttype = 156 THEN p.turnover ELSE 0 END) AS SealTOver,
                               SUM(CASE WHEN p.sporttype = 156 THEN p.winlost ELSE 0 END) AS SealWL
                        FROM bodb_Report.dbo.rptDepWinlostByProduct p WITH(NOLOCK)
                        WHERE winlostdate = @dbtodaydate
                            AND p.sporttype IN (0,161,180,190,191,192,193,202,211,212,220,251,208,209,164,194,196,245,222,243,244,168,169,165,171,231,237,175,195,178,188,239,159,158,232,238,167,234,156)
                            AND p.custid = @CustId 
                        GROUP BY p.winlostdate, p.custid
                    ) p1 ON d.custid = p1.custid
    END

    SELECT b.*,ISNULL(o.Transfer3rd_AG,0) AS Transfer3rd_AG,
           ISNULL(o.Transfer3rd_CRYSTAL, 0) AS Transfer3rd_CRYSTAL,
           ISNULL(o.Transfer3rd_Opal, 0) AS Transfer3rd_Opal, ISNULL(o.Transfer3rd_BetSoft, 0) AS Transfer3rd_BetSoft,
           ISNULL(o.Transfer3rd_CitiBet, 0) AS Transfer3rd_CitiBet,
           ISNULL(o.Transfer3rd_Topaz, 0) AS Transfer3rd_Topaz,
           ISNULL(o.Transfer3rd_BTi, 0) AS Transfer3rd_BTi,
           ISNULL(o.Transfer3rd_Sapphire, 0) AS Transfer3rd_Sapphire,
           ISNULL(o.Transfer3rd_KYGaming, 0) AS Transfer3rd_KYGaming,
           ISNULL(o.Transfer3rd_AVPMini, 0) AS Transfer3rd_AVPMini,
           ISNULL(o.Transfer3rd_AVPSlot, 0) AS Transfer3rd_AVPSlot,
           ISNULL(o.Transfer3rd_EVO, 0) AS Transfer3rd_EVO,
           ISNULL(o.Transfer3rd_Betradar, 0) AS Transfer3rd_Betradar,
           ISNULL(o.Transfer3rd_PP, 0) AS Transfer3rd_PP,
           ISNULL(o.Transfer3rd_BT1, 0) AS Transfer3rd_BT1,
           ISNULL(o.Transfer3rd_JILISlot, 0) AS Transfer3rd_JILISlot,
           ISNULL(o.Transfer3rd_PGSoft, 0) AS Transfer3rd_PGSoft,
           ISNULL(o.Transfer3rd_Spribe, 0) AS Transfer3rd_Spribe
    FROM @WinlostTmp b
        LEFT JOIN @WinlostTransfer3rd o ON b.winlostdate = o.winlostdate
    UNION
    SELECT @dbtodaydate, d.* FROM @TodayData d
    ORDER BY b.winlostdate
END

