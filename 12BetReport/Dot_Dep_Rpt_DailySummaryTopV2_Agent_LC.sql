/*<info serverAlias="DBACC-bodb02" executers="Dot_Member" viewers="" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO
ALTER PROCEDURE [dbo].[Dot_Dep_Rpt_DailySummaryTopV2_Agent_LC]
	@currency int,
	@fromDate smalldatetime,
	@toDate smalldatetime,
	@orderItem tinyint = 1, -- 1-Deposit/2-Withdrawal/3-Turnover/4-Winloss desc/5-Winloss asc
	@agentid NVARCHAR(3500),
	@topcnt int = 100	-- default 100, 0 is SELECT all
AS
/*
DB: DB06.bodb02
Revisions:    
20121106@Steven: Turnover Report
20130227@Benson: hotfix Request (SB/LV/NO) Query Date error greater than 2 days
20140804@Michael: Add field (RNG) RNTOver, RNDraw, RNWL, (KENO) KETOver, KEDraw, KEWL
20140819@Howard: Add Playtech, Opps, and AG
20150327@Hugo: Add GD Report Data
20150327@Angus: Add VB Report Data
20150922@Edward(DB06.bodb02): Add @WinlostTransfer3rd PK 
20151001@Angus(DB06.bodb02): Add Crystal Report Data
20160203@Benson: fix OneRNG issue add sporttpye:208
20160721@Matthew(DB06.bodb02): Add LBKeno Report Data
20160802@Matthew(DB06.bodb02): Add VB/MG Tover/Draw/WL
20161013@Matthew(DB06.bodb02): Fix VB/MG sporttype
20161109@Matthew(DB06.bodb02): Add CB Tover/Draw/WL
20161205@Matthew(DB06.bodb02): Add GG and Allbet Tover/Draw/WL
20170306@Matthew(DB06.bodb02): Add Opal Report Data
20170518@Paul: Enhance performance - [Redmine: #76206]
20170605@Simon(DB06.bodb02): Add BetSoft Report Data
20170811@Benson(DB06.bodb02): Add Cash Out(CO) information
20170814@ZiYang(DB06.bodb02): Add iSoftBet(Quartz) Report Data 
20170926@AngusHung(DB06.bodb02): Add KenoLottery Report Data
20170927@AngusHung(DB06.bodb02): Add BetRadar Virtual Sports Report Data
20171127@Angus(DB06.bodb02): Add CitiBet(Exchange) Report Data 
20180515@Benson(DB06.bodb02): Add BetRadar Virtual Sports(192,193) Report Data
20180806@James(DB06.bodb02): Add FG Report Data 
20180905@Benson(DB06.bodb02): Add mini game(SportType:209) in RNG relate column
20190111@Angus(DB06.bodb02): Add Happy5(SportType:164) Report Data
*/
BEGIN
	CREATE TABLE #SumWinlost(
		custid int PRIMARY KEY,
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
		DrawGame money
		/* 20121116@Steven: Turnover Report Top 100 For Izhar Request (SB/LV/NO) */
		,SBDraw money null,
		CADraw money null,
		NODraw money null,
		HRDraw money null,
		VSDraw money null,
		KEDraw money null,
		RNDraw money null,
		MRNDraw money null,
		VBDraw money null,
		MGDraw money null,
		CBDraw money null,
		GGDraw money null,
		ALLBETDraw money null,
		CODraw money null,
		KLDraw money null,
		VS2Draw money null,
		H5Draw money null,
		SBTOver money null,
		CATOver money null,
		NOTOver money null,
		HRTOver money null,
		VSTOver money null,
		KETOver money null,
		RNTOver money null,
		MRNTOver money null,
		VBTOver money null,
		MGTOver money null,
		CBTOver money null,
		GGTOver money null,
		ALLBETTOver money null,
		COTOver money null,
		KLTOver money null,
		VS2TOver money null,
		H5TOver money null,
		SBWL money null,
		CAWL money null,
		NOWL money null,
		HRWL money null,
		VSWL money null,
		KEWL money null,
		RNWL money null,
		MRNWL money null,
		VBWL money null,
		MGWL money null,
		CBWL money null,
		GGWL money null,
		ALLBETWL money null,
		COWL money null,
		KLWL money null,
		VS2WL money null,
		H5WL money null,
		Transfer3rd money
	)

	CREATE TABLE #SumWinlost_FromCutDate(
		custid int PRIMARY KEY,
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
		SBDraw money null,
		CADraw money null,
		NODraw money null,
		HRDraw money null,
		VSDraw money null,
		KEDraw money null,
		RNDraw money null,
		MRNDraw money null,
		VBDraw money null,
		MGDraw money null,
		CBDraw money null,
		GGDraw money null,
		ALLBETDraw money null,
		CODraw money null,
		KLDraw money null,
		VS2Draw money null,
		H5Draw money null,
		SBTOver money null,
		CATOver money null,
		NOTOver money null,
		HRTOver money null,
		VSTOver money null,
		KETOver money null,
		RNTOver money null,
		MRNTOver money null,
		VBTOver money null,
		MGTOver money null,
		CBTOver money null,
		GGTOver money null,
		ALLBETTOver money null,
		COTOver money null,
		KLTOver money null,
		VS2TOver money null,
		H5TOver money null,
		SBWL money null,
		CAWL money null,
		NOWL money null,
		HRWL money null,
		VSWL money null,
		KEWL money null,
		RNWL money null,
		MRNWL money null,
		VBWL money null,
		MGWL money null,
		CBWL money null,
		GGWL money null,
		ALLBETWL money null,
		COWL money null,
		KLWL money null,
		VS2WL money null,
		H5WL money null,
		Transfer3rd money
	)

	CREATE TABLE #SumWinlost_BeforeCutDate(
		custid int PRIMARY KEY,
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
		SBDraw money null,
		CADraw money null,
		NODraw money null,
		HRDraw money null,
		VSDraw money null,
		KEDraw money null,
		RNDraw money null,
		MRNDraw money null,
		VBDraw money null,
		MGDraw money null,
		CBDraw money null,
		GGDraw money null,
		ALLBETDraw money null,
		CODraw money null,
		KLDraw money null,
		VS2Draw money null,
		H5Draw money null,
		SBTOver money null,
		CATOver money null,
		NOTOver money null,
		HRTOver money null,
		VSTOver money null,
		KETOver money null,
		RNTOver money null,
		MRNTOver money null,
		VBTOver money null,
		MGTOver money null,
		CBTOver money null,
		GGTOver money null,
		ALLBETTOver money null,
		COTOver money null,
		KLTOver money null,
		VS2TOver money null,
		H5TOver money null,
		SBWL money null,
		CAWL money null,
		NOWL money null,
		HRWL money null,
		VSWL money null,
		KEWL money null,
		RNWL money null,
		MRNWL money null,
		VBWL money null,
		MGWL money null,
		CBWL money null,
		GGWL money null,
		ALLBETWL money null,
		COWL money null,
		KLWL money null,
		VS2WL money null,
		H5WL money null,
		Transfer3rd money
	)

	--Get Transfer 3rd Winlost data
	DECLARE @WinlostTransfer3rd TABLE(CustId int PRIMARY KEY, Transfer3rd_Opus money, Transfer3rd_AG money, Transfer3rd_GD money, Transfer3rd_VB money, Transfer3rd_Crystal money, Transfer3rd_LBKeno money, Transfer3rd_Opal money, Transfer3rd_BetSoft money, Transfer3rd_iSoftBet money, Transfer3rd_CitiBet money, Transfer3rd_Topaz money)

	DECLARE @WinlostTransfer3rd_BeforeCutDate TABLE(CustId int PRIMARY KEY, Transfer3rd_Opus money, Transfer3rd_AG money, Transfer3rd_GD money, Transfer3rd_VB money, Transfer3rd_Crystal money, Transfer3rd_LBKeno money, Transfer3rd_Opal money, Transfer3rd_BetSoft money, Transfer3rd_iSoftBet money, Transfer3rd_CitiBet money, Transfer3rd_Topaz money)

	DECLARE @WinlostTransfer3rd_FromCutDate TABLE(CustId int PRIMARY KEY, Transfer3rd_Opus money, Transfer3rd_AG money, Transfer3rd_GD money, Transfer3rd_VB money, Transfer3rd_Crystal money, Transfer3rd_LBKeno money, Transfer3rd_Opal money, Transfer3rd_BetSoft money, Transfer3rd_iSoftBet money, Transfer3rd_CitiBet money, Transfer3rd_Topaz money)

	CREATE TABLE #AgentList (AgentID INT)

	CREATE CLUSTERED INDEX ix_AgentList_cl ON #AgentList(AgentID)

	DECLARE @XMLString XML

	SET @XMLString = CAST(('<r>' + REPLACE(@agentid, ',', '</r><r>') + '</r>') AS XML)

	INSERT INTO #AgentList(AgentID)
	SELECT x.v.value('(./text())[1]','INT') AS AgentID
	FROM @XMLString.nodes('./r') AS x(v)
	OPTION (OPTIMIZE FOR (@XMLString = NULL)) 

	CREATE TABLE #tblcust (custid int)

	CREATE CLUSTERED INDEX ix_tblcust_cl ON #tblcust(custid)

	INSERT INTO #tblcust(custid)
	SELECT custid 
	FROM customer c WITH (NOLOCK) 
	WHERE EXISTS (SELECT 1 FROM #AgentList a WHERE a.AgentID = c.recommend)
		AND RoleID = 1 

	DECLARE @CutDate SMALLDATETIME
	SELECT @CutDate =  MIN(winlostdate) FROM bodb_report.dbo.rptdepwinlost WITH(NOLOCK) 
 
	DECLARE @FromDate_BK SMALLDATETIME,
			@ToDate_BK SMALLDATETIME

	IF @FromDate < @CutDate
	BEGIN
		IF @ToDate >= @CutDate
		BEGIN
			SET @ToDate_BK = DATEADD(DD, -1, @CutDate )
		END
		ELSE
		BEGIN
			SET @ToDate_BK = @toDate
		END
			
		INSERT INTO #SumWinlost_BeforeCutDate
		(
			custid , Deposit , Aff2MemTransfer , Withdrawal ,  Turnover ,
			Winloss ,  Bonus ,  Adjustment , Outstanding , OpeningBalance ,
			ClosingBalance , DrawGame , Transfer3rd,
			SBDraw, CADraw, NODraw, HRDraw, VSDraw, KEDraw, RNDraw, MRNDraw,
			VBDraw, MGDraw, CBDraw, GGDraw, ALLBETDraw, CODraw, KLDraw, VS2Draw, H5Draw,
			SBTOver, CATOver, NOTOver, HRTOver, VSTOver, KETOver, RNTOver, MRNTOver,
			VBTOver, MGTOver, CBTOver, GGTOver, ALLBETTOver, COTOver, KLTOver, VS2TOver, H5TOver,
			SBWL, CAWL, NOWL, HRWL, VSWL, KEWL, RNWL, MRNWL,
			VBWL, MGWL, CBWL, GGWL, ALLBETWL, COWL, KLWL, VS2WL, H5WL
		)
		SELECT	d.custid, d.Deposit, d.Aff2MemTransfer, d.Withdrawal, d.Turnover,
				d.Winloss, d.Bonus, d.Adjustment, d.Outstanding, d.OpeningBalance,
				d.ClosingBalance, d.DrawGame, d.Transfer3rd,
				ISNULL(p1.SBDraw,0), ISNULL(p1.CADraw,0), ISNULL(p1.NODraw,0), ISNULL(p1.HRDraw,0), ISNULL(p1.VSDraw,0),
				ISNULL(p1.KEDraw,0), ISNULL(p1.RNDraw,0), ISNULL(p1.MRNDraw,0), ISNULL(p1.VBDraw,0), ISNULL(p1.MGDraw,0),
				ISNULL(p1.CBDraw,0), ISNULL(p1.GGDraw,0), ISNULL(p1.ALLBETDraw,0), ISNULL(p1.CODraw,0), ISNULL(p1.KLDraw,0), ISNULL(p1.VS2Draw,0), ISNULL(p1.H5Draw,0),
				ISNULL(p1.SBTOver,0), ISNULL(p1.CATOver,0), ISNULL(p1.NOTOver,0), ISNULL(p1.HRTOver,0), ISNULL(p1.VSTOver,0),
				ISNULL(p1.KETOver,0), ISNULL(p1.RNTOver,0), ISNULL(p1.MRNTOver,0), ISNULL(p1.VBTOver,0), ISNULL(p1.MGTOver,0),
				ISNULL(p1.CBTOver,0), ISNULL(p1.GGTOver,0), ISNULL(p1.ALLBETTOver,0), ISNULL(p1.COTOver,0), ISNULL(p1.KLTOver,0), ISNULL(p1.VS2TOver,0), ISNULL(p1.H5TOver,0),
				ISNULL(p1.SBWL,0), ISNULL(p1.CAWL,0), ISNULL(p1.NOWL,0), ISNULL(p1.HRWL,0), ISNULL(p1.VSWL,0),
				ISNULL(p1.KEWL,0), ISNULL(p1.RNWL,0), ISNULL(p1.MRNWL,0), ISNULL(p1.VBWL,0), ISNULL(p1.MGWL,0),
				ISNULL(p1.CBWL,0), ISNULL(p1.GGWL,0), ISNULL(p1.ALLBETWL,0), ISNULL(p1.COWL,0), ISNULL(p1.KLWL,0), ISNULL(p1.VS2WL,0), ISNULL(p1.H5WL,0)
		FROM (
				SELECT b.custid, SUM(Deposit) AS Deposit, 
						SUM(Aff2MemTransfer) AS Aff2MemTransfer, 
						SUM(Withdrawal) AS Withdrawal, 
						SUM(Turnover) AS Turnover, 
						SUM(Winloss) AS Winloss, 
						SUM(Bonus) AS Bonus, 
						SUM(Adjustment) AS Adjustment, 
						SUM(Outstanding) AS Outstanding,
						SUM(CASE  winlostdate WHEN @fromDate THEN OpeningBalance ELSE 0 END) OpeningBalance,
						SUM(CASE  winlostdate WHEN @ToDate THEN ClosingBalance ELSE 0 END) ClosingBalance,
						SUM(DrawGame) AS DrawGame,
						SUM(Transfer3rd) AS Transfer3rd
				FROM   bodb_Report.dbo.rptDepWinlost_bk  b with (nolock)
				WHERE  winlostdate >= @fromDate AND winlostdate <= @ToDate_BK
	 				AND EXISTS (SELECT 1 FROM #tblcust c WHERE c.CustID = b.custid)	
					AND currency = @currency
				GROUP BY b.custid
			) d
			LEFT JOIN (
				SELECT  p.custid , 
						ISNULL (SUM (CASE  WHEN p.sporttype = 0 THEN p.drawTO ELSE 0 END) , 0 ) AS SBDraw ,
						ISNULL (SUM (CASE  WHEN p.sporttype = 162 THEN p.drawTO ELSE 0 END) , 0 ) AS CADraw ,
						ISNULL (SUM (CASE  WHEN p.sporttype = 161 THEN p.drawTO ELSE 0 END) , 0 ) AS NODraw , 
						ISNULL (SUM (CASE  WHEN p.sporttype = 151 THEN p.drawTO ELSE 0 END) , 0 ) AS HRDraw ,
						ISNULL (SUM (CASE  WHEN p.sporttype = 180 THEN p.drawTO ELSE 0 END) , 0 ) AS VSDraw , 
						ISNULL (SUM (CASE  WHEN p.sporttype = 202 THEN p.drawTO ELSE 0 END) , 0 ) AS KEDraw , 
						ISNULL (SUM (CASE  WHEN p.sporttype IN (251,208,209) THEN p.drawTO ELSE 0 END) , 0 ) AS RNDraw , 
						ISNULL (SUM (CASE  WHEN p.sporttype = 210 THEN p.drawTO ELSE 0 END) , 0 ) AS MRNDraw,
						ISNULL (SUM (CASE  WHEN p.sporttype = 212 THEN p.drawTO ELSE 0 END) , 0 ) AS VBDraw,
						ISNULL (SUM (CASE  WHEN p.sporttype IN (203,205) THEN p.drawTO ELSE 0 END) , 0 ) AS MGDraw,
						ISNULL (SUM (CASE  WHEN p.sporttype = 204 THEN p.drawTO ELSE 0 END) , 0 ) AS CBDraw,
						ISNULL (SUM (CASE  WHEN p.sporttype = 219 THEN p.drawTO ELSE 0 END) , 0 ) AS GGDraw,
						ISNULL (SUM (CASE  WHEN p.sporttype = 211 THEN p.drawTO ELSE 0 END) , 0 ) AS ALLBETDraw,
						ISNULL (SUM (CASE  WHEN p.sporttype = 220 THEN p.drawTO ELSE 0 END) , 0 ) AS KLDraw,
						ISNULL (SUM (CASE  WHEN p.sporttype IN (190,191,192,193) THEN p.drawTO ELSE 0 END) , 0 ) AS VS2Draw,
						ISNULL (SUM (CASE  WHEN p.sporttype = -6 THEN p.drawTO ELSE 0 END) , 0 ) AS CODraw,
						ISNULL (SUM (CASE  WHEN p.sporttype = 164 THEN p.drawTO ELSE 0 END) , 0 ) AS H5Draw,
						ISNULL (SUM (CASE  WHEN p.sporttype = 0 THEN p.turnover ELSE 0 END) , 0 ) AS SBTOver ,
						ISNULL (SUM (CASE  WHEN p.sporttype = 162 THEN p.turnover ELSE 0 END) , 0 ) AS CATOver ,
						ISNULL (SUM (CASE  WHEN p.sporttype = 161 THEN p.turnover ELSE 0 END) , 0 ) AS NOTOver ,
						ISNULL (SUM (CASE  WHEN p.sporttype = 151 THEN p.turnover ELSE 0 END) , 0 ) AS HRTOver ,
						ISNULL (SUM (CASE  WHEN p.sporttype = 180 THEN p.turnover ELSE 0 END) , 0 ) AS VSTOver ,
						ISNULL (SUM (CASE  WHEN p.sporttype = 202 THEN p.turnover ELSE 0 END) , 0 ) AS KETOver ,
						ISNULL (SUM (CASE  WHEN p.sporttype IN (251,208,209) THEN p.turnover ELSE 0 END) , 0 ) AS RNTOver ,
						ISNULL (SUM (CASE  WHEN p.sporttype = 210 THEN p.turnover ELSE 0 END) , 0 ) AS MRNTOver ,
						ISNULL (SUM (CASE  WHEN p.sporttype = 212 THEN p.turnover ELSE 0 END) , 0 ) AS VBTOver ,
						ISNULL (SUM (CASE  WHEN p.sporttype  IN (203,205)then p.turnover ELSE 0 END) , 0 ) AS MGTOver ,
						ISNULL (SUM (CASE  WHEN p.sporttype  = 204 THEN p.turnover ELSE 0 END) , 0 ) AS CBTOver ,
						ISNULL (SUM (CASE  WHEN p.sporttype  = 219 THEN p.turnover ELSE 0 END) , 0 ) AS GGTOver ,
						ISNULL (SUM (CASE  WHEN p.sporttype  = 211 THEN p.turnover ELSE 0 END) , 0 ) AS ALLBETTOver ,
						ISNULL (SUM (CASE  WHEN p.sporttype  = 220 THEN p.turnover ELSE 0 END) , 0 ) AS KLTOver ,
						ISNULL (SUM (CASE  WHEN p.sporttype IN (190,191,192,193) THEN p.turnover ELSE 0 END) , 0 ) AS VS2TOver,
						ISNULL (SUM (CASE  WHEN p.sporttype  = -6 THEN p.turnover ELSE 0 END) , 0 ) AS COTOver ,
						ISNULL (SUM (CASE  WHEN p.sporttype  = 164 THEN p.turnover ELSE 0 END) , 0 ) AS H5TOver ,
						ISNULL (SUM (CASE  WHEN p.sporttype = 0 THEN p.winlost ELSE 0 END) , 0 ) AS SBWL ,
						ISNULL (SUM (CASE  WHEN p.sporttype = 162 THEN p.winlost ELSE 0 END) , 0 ) AS CAWL ,
						ISNULL (SUM (CASE  WHEN p.sporttype = 161 THEN p.winlost ELSE 0 END) , 0 ) AS NOWL ,
						ISNULL (SUM (CASE  WHEN p.sporttype = 151 THEN p.winlost ELSE 0 END) , 0 ) AS HRWL ,
						ISNULL (SUM (CASE  WHEN p.sporttype = 180 THEN p.winlost ELSE 0 END) , 0 ) AS VSWL ,
						ISNULL (SUM (CASE  WHEN p.sporttype = 202 THEN p.winlost ELSE 0 END) , 0 ) AS KEWL ,
						ISNULL (SUM (CASE  WHEN p.sporttype IN (251,208,209) THEN p.winlost ELSE 0 END) , 0 ) AS RNWL, 
						ISNULL (SUM (CASE  WHEN p.sporttype = 210 THEN p.winlost ELSE 0 END) , 0 ) AS MRNWL, 
						ISNULL (SUM (CASE  WHEN p.sporttype = 212 THEN p.winlost ELSE 0 END) , 0 ) AS VBWL, 
						ISNULL (SUM (CASE  WHEN p.sporttype IN (203,205) THEN p.winlost ELSE 0 END) , 0 ) AS MGWL,
						ISNULL (SUM (CASE  WHEN p.sporttype = 204 THEN p.winlost ELSE 0 END) , 0 ) AS CBWL,
						ISNULL (SUM (CASE  WHEN p.sporttype = 219 THEN p.winlost ELSE 0 END) , 0 ) AS GGWL,
						ISNULL (SUM (CASE  WHEN p.sporttype = 211 THEN p.winlost ELSE 0 END) , 0 ) AS ALLBETWL,
						ISNULL (SUM (CASE  WHEN p.sporttype = 220 THEN p.winlost ELSE 0 END) , 0 ) AS KLWL,
						ISNULL (SUM (CASE  WHEN p.sporttype IN (190,191,192,193) THEN p.winlost ELSE 0 END) , 0 ) AS VS2WL,
						ISNULL (SUM (CASE  WHEN p.sporttype = -6 THEN p.winlost ELSE 0 END) , 0 ) AS COWL,
						ISNULL (SUM (CASE  WHEN p.sporttype = 164 THEN p.winlost ELSE 0 END) , 0 ) AS H5WL
				FROM bodb_Report.dbo.rptDepWinlostByProduct_BK p WITH (NOLOCK)
				Where winlostdate >= @fromDate AND winlostdate <= @ToDate_BK 
					AND p.sporttype in (0,151,161,162,180,190,191,192,193,202,203,204,205,210,211,212,219,220,251,208,209,-6,164) 
					AND EXISTS (SELECT 1 FROM #tblcust c WHERE c.custid = p.custid)	
				GROUP BY  p.custid
			) p1 ON d.custid = p1.custid
			   
					   
		INSERT INTO @WinlostTransfer3rd_BeforeCutDate (CustId, Transfer3rd_Opus, Transfer3rd_AG, Transfer3rd_GD, Transfer3rd_VB, Transfer3rd_Crystal, Transfer3rd_LBKeno, Transfer3rd_Opal, Transfer3rd_BetSoft, Transfer3rd_iSoftBet, Transfer3rd_CitiBet, Transfer3rd_Topaz)
		SELECT custid,  
			SUM(CASE PartnerId WHEN 2 THEN TransferAmount ELSE 0 END), -- oops
			SUM(CASE PartnerId WHEN 3 THEN TransferAmount ELSE 0 END), -- AG
			SUM(CASE PartnerId WHEN 4 THEN TransferAmount ELSE 0 END),  -- GD
			SUM(CASE PartnerId WHEN 5 THEN TransferAmount ELSE 0 END),  -- VB
			SUM(CASE PartnerId WHEN 7 THEN TransferAmount ELSE 0 END), -- Crystal
			SUM(CASE PartnerId WHEN 8 THEN TransferAmount ELSE 0 END), -- LBKeno
			SUM(CASE PartnerId WHEN 9 THEN TransferAmount ELSE 0 END),  -- Opal
			SUM(CASE PartnerId WHEN 10 THEN TransferAmount ELSE 0 END), -- BetSoft
			SUM(CASE PartnerId WHEN 11 THEN TransferAmount ELSE 0 END), -- iSoftBet
			SUM(CASE PartnerId WHEN 12 THEN TransferAmount ELSE 0 END), -- CitiBet
			SUM(CASE PartnerId WHEN 13 THEN TransferAmount ELSE 0 END) -- FG
		FROM bodb_Report.dbo.rptDepWinlost_Transfer3rdOthers_bk b WITH (NOLOCK) 
		WHERE  (winlostdate >= @fromDate AND winlostdate <= @ToDate_BK) 
			AND EXISTS (SELECT 1 FROM #tblcust c WHERE c.custid = b.CustId)	 
			AND currency = @currency
		GROUP BY custid
	END

	IF @toDate >= @CutDate
	BEGIN
		IF @fromDate < @CutDate
		BEGIN
			SET @FromDate_BK = @CutDate
		END
		ELSE
		BEGIN
			SET @FromDate_BK = @fromDate
		END

		INSERT INTO #SumWinlost_FromCutDate
		( 
			custid , Deposit , Aff2MemTransfer , Withdrawal ,  Turnover ,
			Winloss ,  Bonus ,  Adjustment , Outstanding , OpeningBalance ,
			ClosingBalance , DrawGame , Transfer3rd,
			SBDraw, CADraw, NODraw, HRDraw, VSDraw, KEDraw, RNDraw, MRNDraw,
			VBDraw, MGDraw, CBDraw, GGDraw, ALLBETDraw, CODraw, KLDraw, VS2Draw, H5Draw,
			SBTOver, CATOver, NOTOver, HRTOver, VSTOver, KETOver, RNTOver, MRNTOver,
			VBTOver, MGTOver, CBTOver, GGTOver, ALLBETTOver, COTOver, KLTOver, VS2TOver, H5TOver,
			SBWL, CAWL, NOWL, HRWL, VSWL, KEWL, RNWL, MRNWL,
			VBWL, MGWL, CBWL, GGWL, ALLBETWL, COWL, KLWL, VS2WL, H5WL
		)	
		SELECT	d.custid, d.Deposit, d.Aff2MemTransfer, d.Withdrawal, d.Turnover,
				d.Winloss, d.Bonus, d.Adjustment, d.Outstanding, d.OpeningBalance,
				d.ClosingBalance, d.DrawGame, d.Transfer3rd,
				ISNULL(p1.SBDraw,0), ISNULL(p1.CADraw,0), ISNULL(p1.NODraw,0), ISNULL(p1.HRDraw,0), ISNULL(p1.VSDraw,0),
				ISNULL(p1.KEDraw,0), ISNULL(p1.RNDraw,0), ISNULL(p1.MRNDraw,0), ISNULL(p1.VBDraw,0), ISNULL(p1.MGDraw,0),
				ISNULL(p1.CBDraw,0), ISNULL(p1.GGDraw,0), ISNULL(p1.ALLBETDraw,0), ISNULL(p1.CODraw,0), ISNULL(p1.KLDraw,0), ISNULL(p1.VS2Draw,0), ISNULL(p1.H5Draw,0),
				ISNULL(p1.SBTOver,0), ISNULL(p1.CATOver,0), ISNULL(p1.NOTOver,0), ISNULL(p1.HRTOver,0), ISNULL(p1.VSTOver,0),
				ISNULL(p1.KETOver,0), ISNULL(p1.RNTOver,0), ISNULL(p1.MRNTOver,0), ISNULL(p1.VBTOver,0), ISNULL(p1.MGTOver,0),
				ISNULL(p1.CBTOver,0), ISNULL(p1.GGTOver,0), ISNULL(p1.ALLBETTOver,0), ISNULL(p1.COTOver,0), ISNULL(p1.KLTOver,0), ISNULL(p1.VS2TOver,0), ISNULL(p1.H5TOver,0),
				ISNULL(p1.SBWL,0), ISNULL(p1.CAWL,0), ISNULL(p1.NOWL,0), ISNULL(p1.HRWL,0), ISNULL(p1.VSWL,0),
				ISNULL(p1.KEWL,0), ISNULL(p1.RNWL,0), ISNULL(p1.MRNWL,0), ISNULL(p1.VBWL,0), ISNULL(p1.MGWL,0),
				ISNULL(p1.CBWL,0), ISNULL(p1.GGWL,0), ISNULL(p1.ALLBETWL,0), ISNULL(p1.COWL,0), ISNULL(p1.KLWL,0), ISNULL(p1.VS2WL,0), ISNULL(p1.H5WL,0)
		FROM (
				SELECT custid, SUM(Deposit) AS Deposit, 
							SUM(Aff2MemTransfer) AS Aff2MemTransfer, 
							SUM(Withdrawal) AS Withdrawal, 
							SUM(Turnover) AS Turnover, 
							SUM(Winloss) AS Winloss, 
							SUM(Bonus) AS Bonus, 
							SUM(Adjustment) AS Adjustment, 
							SUM(Outstanding) AS Outstanding,
							SUM(CASE  winlostdate WHEN @fromDate THEN OpeningBalance ELSE 0 END) OpeningBalance,
							SUM(CASE  winlostdate WHEN @ToDate THEN ClosingBalance ELSE 0 END) ClosingBalance,
							SUM(DrawGame) AS DrawGame,
							SUM(Transfer3rd) AS Transfer3rd
				FROM   bodb_Report.dbo.rptDepWinlost b WITH (NOLOCK)
				WHERE  winlostdate >= @FromDate_BK AND winlostdate <= @toDate
						AND EXISTS (SELECT 1 FROM #tblcust c WHERE c.custid = b.CustID)
						AND currency = @currency
				GROUP BY custid
			) d
			LEFT JOIN (
				SELECT  p.custid , 
						ISNULL (SUM (CASE  WHEN p.sporttype = 0 THEN p.drawTO ELSE 0 END) , 0 ) AS SBDraw ,
						ISNULL (SUM (CASE  WHEN p.sporttype = 162 THEN p.drawTO ELSE 0 END) , 0 ) AS CADraw ,
						ISNULL (SUM (CASE  WHEN p.sporttype = 161 THEN p.drawTO ELSE 0 END) , 0 ) AS NODraw , 
						ISNULL (SUM (CASE  WHEN p.sporttype = 151 THEN p.drawTO ELSE 0 END) , 0 ) AS HRDraw ,
						ISNULL (SUM (CASE  WHEN p.sporttype = 180 THEN p.drawTO ELSE 0 END) , 0 ) AS VSDraw , 
						ISNULL (SUM (CASE  WHEN p.sporttype IN (190,191,192,193) THEN p.drawTO ELSE 0 END) , 0 ) AS VS2Draw,
						ISNULL (SUM (CASE  WHEN p.sporttype = 202 THEN p.drawTO ELSE 0 END) , 0 ) AS KEDraw , 
						ISNULL (SUM (CASE  WHEN p.sporttype IN (251,208,209) THEN p.drawTO ELSE 0 END) , 0 ) AS RNDraw ,
						ISNULL (SUM (CASE  WHEN p.sporttype = 210 THEN p.drawTO ELSE 0 END) , 0 ) AS MRNDraw,
						ISNULL (SUM (CASE  WHEN p.sporttype = 212 THEN p.drawTO ELSE 0 END) , 0 ) AS VBDraw,
						ISNULL (SUM (CASE  WHEN p.sporttype IN (203,205) THEN p.drawTO ELSE 0 END) , 0 ) AS MGDraw,
						ISNULL (SUM (CASE  WHEN p.sporttype = 204 THEN p.drawTO ELSE 0 END) , 0 ) AS CBDraw,
						ISNULL (SUM (CASE  WHEN p.sporttype = 219 THEN drawTO ELSE 0 END) , 0 ) AS GGDraw,
						ISNULL (SUM (CASE  WHEN p.sporttype = 211 THEN drawTO ELSE 0 END) , 0 ) AS ALLBETDraw,
						ISNULL (SUM (CASE  WHEN p.sporttype = 220 THEN drawTO ELSE 0 END) , 0 ) AS KLDraw,
						ISNULL (SUM (CASE  WHEN p.sporttype = -6 THEN drawTO ELSE 0 END) , 0 ) AS CODraw,
						ISNULL (SUM (CASE  WHEN p.sporttype = 164 THEN drawTO ELSE 0 END) , 0 ) AS H5Draw,
						ISNULL (SUM (CASE  WHEN p.sporttype = 0 THEN p.turnover ELSE 0 END) , 0 ) AS SBTOver ,
						ISNULL (SUM (CASE  WHEN p.sporttype = 162 THEN p.turnover ELSE 0 END) , 0 ) AS CATOver ,
						ISNULL (SUM (CASE  WHEN p.sporttype = 161 THEN p.turnover ELSE 0 END) , 0 ) AS NOTOver ,
						ISNULL (SUM (CASE  WHEN p.sporttype = 151 THEN p.turnover ELSE 0 END) , 0 ) AS HRTOver ,
						ISNULL (SUM (CASE  WHEN p.sporttype = 180 THEN p.turnover ELSE 0 END) , 0 ) AS VSTOver ,
						ISNULL (SUM (CASE  WHEN p.sporttype IN (190,191,192,193) THEN p.turnover ELSE 0 END) , 0 ) AS VS2TOver,
						ISNULL (SUM (CASE  WHEN p.sporttype = 202 THEN p.turnover ELSE 0 END) , 0 ) AS KETOver ,
						ISNULL (SUM (CASE  WHEN p.sporttype IN (251,208,209) THEN p.turnover ELSE 0 END) , 0 ) AS RNTOver ,
						ISNULL (SUM (CASE  WHEN p.sporttype = 210 THEN p.turnover ELSE 0 END) , 0 ) AS MRNTOver ,
						ISNULL (SUM (CASE  WHEN p.sporttype = 212 THEN p.turnover ELSE 0 END) , 0 ) AS VBTOver ,
						ISNULL (SUM (CASE  WHEN p.sporttype IN (203,205) THEN p.turnover ELSE 0 END) , 0 ) AS MGTOver ,
						ISNULL (SUM (CASE  WHEN p.sporttype = 204 THEN p.turnover ELSE 0 END) , 0 ) AS CBTOver ,
						ISNULL (SUM (CASE  WHEN p.sporttype = 219 THEN turnover ELSE 0 END) , 0 ) AS GGTOver ,
						ISNULL (SUM (CASE  WHEN p.sporttype = 211 THEN turnover ELSE 0 END) , 0 ) AS ALLBETTOver ,
						ISNULL (SUM (CASE  WHEN p.sporttype = 220 THEN turnover ELSE 0 END) , 0 ) AS KLTOver ,
						ISNULL (SUM (CASE  WHEN p.sporttype = -6 THEN turnover ELSE 0 END) , 0 ) AS COTOver ,
						ISNULL (SUM (CASE  WHEN p.sporttype = 164 THEN turnover ELSE 0 END) , 0 ) AS H5TOver ,
						ISNULL (SUM (CASE  WHEN p.sporttype = 0 THEN p.winlost ELSE 0 END) , 0 ) AS SBWL ,
						ISNULL (SUM (CASE  WHEN p.sporttype = 162 THEN p.winlost ELSE 0 END) , 0 ) AS CAWL ,
						ISNULL (SUM (CASE  WHEN p.sporttype = 161 THEN p.winlost ELSE 0 END) , 0 ) AS NOWL ,
						ISNULL (SUM (CASE  WHEN p.sporttype = 151 THEN p.winlost ELSE 0 END) , 0 ) AS HRWL ,
						ISNULL (SUM (CASE  WHEN p.sporttype = 180 THEN p.winlost ELSE 0 END) , 0 ) AS VSWL ,
						ISNULL (SUM (CASE  WHEN p.sporttype IN (190,191,192,193) THEN p.winlost ELSE 0 END) , 0 ) AS VS2WL,
						ISNULL (SUM (CASE  WHEN p.sporttype = 202 THEN p.winlost ELSE 0 END) , 0 ) AS KEWL ,
						ISNULL (SUM (CASE  WHEN p.sporttype IN (251,208,209) THEN p.winlost ELSE 0 END) , 0 ) AS RNWL ,
						ISNULL (SUM (CASE  WHEN p.sporttype = 210 THEN p.winlost ELSE 0 END) , 0 ) AS MRNWL, 
						ISNULL (SUM (CASE  WHEN p.sporttype = 212 THEN p.winlost ELSE 0 END) , 0 ) AS VBWL, 
						ISNULL (SUM (CASE  WHEN p.sporttype IN (203,205) THEN p.winlost ELSE 0 END) , 0 ) AS MGWL, 
						ISNULL (SUM (CASE  WHEN p.sporttype = 204 THEN p.winlost ELSE 0 END) , 0 ) AS CBWL,
						ISNULL (SUM (CASE  WHEN p.sporttype = 219 THEN winlost ELSE 0 END) , 0 ) AS GGWL ,
						ISNULL (SUM (CASE  WHEN p.sporttype = 211 THEN winlost ELSE 0 END) , 0 ) AS ALLBETWL, 
						ISNULL (SUM (CASE  WHEN p.sporttype = 220 THEN winlost ELSE 0 END) , 0 ) AS KLWL,
						ISNULL (SUM (CASE  WHEN sporttype = -6 THEN winlost ELSE 0 END) , 0 ) AS COWL,
						ISNULL (SUM (CASE  WHEN sporttype = 164 THEN winlost ELSE 0 END) , 0 ) AS H5WL
				FROM bodb_Report.dbo.rptDepWinlostByProduct p WITH (NOLOCK)
				WHERE winlostdate >= @FromDate_BK AND winlostdate <= @toDate 
					AND p.sporttype IN (0,151,161,162,180,190,191,192,193,202,203,204,205,210,211,212,219,220,251,208,209,-6,164) 
					AND EXISTS (SELECT 1 FROM #tblcust c WHERE c.custid = p.CustID)	
				GROUP BY  p.custid
			) p1 ON d.custid = p1.custid	

		INSERT INTO @WinlostTransfer3rd_FromCutDate (CustId, Transfer3rd_Opus, Transfer3rd_AG, Transfer3rd_GD, Transfer3rd_VB, Transfer3rd_Crystal, Transfer3rd_LBKeno, Transfer3rd_Opal, Transfer3rd_BetSoft, Transfer3rd_iSoftBet, Transfer3rd_CitiBet, Transfer3rd_Topaz)
		SELECT custid,  
			SUM(CASE PartnerId WHEN 2 THEN TransferAmount ELSE 0 END),  -- oops
			SUM(CASE PartnerId WHEN 3 THEN TransferAmount ELSE 0 END),  -- AG
			SUM(CASE PartnerId WHEN 4 THEN TransferAmount ELSE 0 END),   -- GD
			SUM(CASE PartnerId WHEN 5 THEN TransferAmount ELSE 0 END),   -- VB
			SUM(CASE PartnerId WHEN 7 THEN TransferAmount ELSE 0 END),  -- Crystal
			SUM(CASE PartnerId WHEN 8 THEN TransferAmount ELSE 0 END),  -- LBKeno
			SUM(CASE PartnerId WHEN 9 THEN TransferAmount ELSE 0 END),   -- Opal
			SUM(CASE PartnerId WHEN 10 THEN TransferAmount ELSE 0 END), -- BetSoft
			SUM(CASE PartnerId WHEN 11 THEN TransferAmount ELSE 0 END),  -- iSoftBet(Quartz)
			SUM(CASE PartnerId WHEN 12 THEN TransferAmount ELSE 0 END),  -- CitiBet(Exchange)
			SUM(CASE PartnerId WHEN 13 THEN TransferAmount ELSE 0 END)  -- FG
		FROM bodb_Report.dbo.rptDepWinlost_Transfer3rdOthers b WITH (NOLOCK) 
		WHERE  (winlostdate >= @FromDate_BK AND winlostdate <= @toDate) 
			AND EXISTS (SELECT 1 FROM #tblcust c WHERE c.custid = b.CustId)
			AND currency = @currency
		GROUP BY custid
	END

	INSERT INTO #SumWinlost
	( 
		custid , Deposit , Aff2MemTransfer , Withdrawal ,  Turnover ,
		Winloss ,  Bonus ,  Adjustment , Outstanding , OpeningBalance ,
		ClosingBalance , DrawGame , Transfer3rd,
		SBDraw, CADraw, NODraw, HRDraw, VSDraw, KEDraw, RNDraw, MRNDraw,
		VBDraw, MGDraw, CBDraw, GGDraw, ALLBETDraw, CODraw, KLDraw, VS2Draw, H5Draw,
		SBTOver, CATOver, NOTOver, HRTOver, VSTOver, KETOver, RNTOver, MRNTOver,
		VBTOver, MGTOver, CBTOver, GGTOver, ALLBETTOver, COTOver, KLTOver, VS2TOver, H5TOver,
		SBWL, CAWL, NOWL, HRWL, VSWL, KEWL, RNWL, MRNWL,
		VBWL, MGWL, CBWL, GGWL, ALLBETWL, COWL, KLWL, VS2WL, H5WL
	)
	SELECT	custid, SUM(Deposit) AS Deposit, SUM(Aff2MemTransfer) AS Aff2MemTransfer, 
			SUM(Withdrawal) AS Withdrawal, SUM(Turnover) AS Turnover, SUM(Winloss) AS Winloss, 
			SUM(Bonus) AS Bonus, SUM(Adjustment) AS Adjustment, SUM(Outstanding) AS Outstanding,
			SUM(OpeningBalance) AS OpeningBalance, SUM(ClosingBalance) AS ClosingBalance, SUM(DrawGame) AS DrawGame,
			SUM(Transfer3rd) AS Transfer3rd,
			ISNULL (SUM (SBDraw),0) AS SBDraw ,
			ISNULL (SUM (CADraw),0) AS CADraw ,
			ISNULL (SUM (NODraw),0) AS NODraw , 
			ISNULL (SUM (HRDraw),0) AS HRDraw ,
			ISNULL (SUM (VSDraw),0) AS VSDraw , 
			ISNULL (SUM (KEDraw),0) AS KEDraw , 
			ISNULL (SUM (RNDraw),0) AS RNDraw , 
			ISNULL (SUM (MRNDraw),0) AS MRNDraw , 
			ISNULL (SUM (VBDraw),0) AS VBDraw , 
			ISNULL (SUM (MGDraw),0) AS MGDraw , 
			ISNULL (SUM (CBDraw),0) AS CBDraw , 
			ISNULL (SUM (GGDraw),0) AS GGDraw , 
			ISNULL (SUM (ALLBETDraw),0) AS ALLBETDraw , 
			ISNULL (SUM (CODraw),0) AS CODraw , 
			ISNULL (SUM (KLDraw),0) AS KLDraw , 
			ISNULL (SUM (VS2Draw),0) AS VS2Draw , 
			ISNULL (SUM (H5Draw),0) AS H5Draw , 
			ISNULL (SUM (SBTOver),0) AS SBTOver ,
			ISNULL (SUM (CATOver),0) AS CATOver ,
			ISNULL (SUM (NOTOver),0) AS NOTOver ,
			ISNULL (SUM (HRTOver),0) AS HRTOver ,
			ISNULL (SUM (VSTOver),0) AS VSTOver ,
			ISNULL (SUM (KETOver),0) AS KETOver ,
			ISNULL (SUM (RNTOver),0) AS RNTOver ,
			ISNULL (SUM (MRNTOver),0) AS MRNTOver ,
			ISNULL (SUM (VBTOver),0) AS VBTOver ,
			ISNULL (SUM (MGTOver),0) AS MGTOver ,
			ISNULL (SUM (CBTOver),0) AS CBTOver ,
			ISNULL (SUM (GGTOver),0) AS GGTOver ,
			ISNULL (SUM (ALLBETTOver),0) AS ALLBETTOver ,
			ISNULL (SUM (COTOver),0) AS COTOver ,
			ISNULL (SUM (KLTOver),0) AS KLTOver ,
			ISNULL (SUM (VS2TOver),0) AS VS2TOver ,
			ISNULL (SUM (H5TOver),0) AS H5TOver ,
			ISNULL (SUM (SBWL),0) AS SBWL ,
			ISNULL (SUM (CAWL),0) AS CAWL ,
			ISNULL (SUM (NOWL),0) AS NOWL ,
			ISNULL (SUM (HRWL),0) AS HRWL ,
			ISNULL (SUM (VSWL),0) AS VSWL ,
			ISNULL (SUM (KEWL),0) AS KEWL ,
			ISNULL (SUM (RNWL),0) AS RNWL ,
			ISNULL (SUM (MRNWL),0) AS MRNWL ,
			ISNULL (SUM (VBWL),0) AS VBWL ,
			ISNULL (SUM (MGWL),0) AS MGWL ,
			ISNULL (SUM (CBWL),0) AS CBWL ,
			ISNULL (SUM (GGWL),0) AS GGWL ,
			ISNULL (SUM (ALLBETWL),0) AS ALLBETWL,
			ISNULL (SUM (COWL),0) AS COWL ,
			ISNULL (SUM (KLWL),0) AS KLWL ,
			ISNULL (SUM (VS2WL),0) AS VS2WL,
			ISNULL (SUM (H5WL),0) AS H5WL
	FROM (
			SELECT  custid , Deposit , Aff2MemTransfer , Withdrawal ,  Turnover ,
					Winloss ,  Bonus ,  Adjustment , Outstanding , OpeningBalance ,
					ClosingBalance , DrawGame , Transfer3rd,
					SBDraw, CADraw, NODraw, HRDraw, VSDraw, KEDraw, RNDraw, MRNDraw,
					VBDraw, MGDraw, CBDraw, GGDraw, ALLBETDraw, CODraw, KLDraw, VS2Draw, H5Draw,
					SBTOver, CATOver, NOTOver, HRTOver, VSTOver, KETOver, RNTOver, MRNTOver,
					VBTOver, MGTOver, CBTOver, GGTOver, ALLBETTOver, COTOver, KLTOver, VS2TOver, H5TOver,
					SBWL, CAWL, NOWL, HRWL, VSWL, KEWL, RNWL, MRNWL,
					VBWL, MGWL, CBWL, GGWL, ALLBETWL, COWL, KLWL, VS2WL, H5WL
			FROM #SumWinlost_BeforeCutDate

			UNION ALL
			
			SELECT  custid , Deposit , Aff2MemTransfer , Withdrawal ,  Turnover ,
					Winloss ,  Bonus ,  Adjustment , Outstanding , OpeningBalance ,
					ClosingBalance , DrawGame , Transfer3rd,
					SBDraw, CADraw, NODraw, HRDraw, VSDraw, KEDraw, RNDraw, MRNDraw,
					VBDraw, MGDraw, CBDraw, GGDraw, ALLBETDraw, CODraw, KLDraw, VS2Draw, H5Draw,
					SBTOver, CATOver, NOTOver, HRTOver, VSTOver, KETOver, RNTOver, MRNTOver,
					VBTOver, MGTOver, CBTOver, GGTOver, ALLBETTOver, COTOver, KLTOver, VS2TOver, H5TOver,
					SBWL, CAWL, NOWL, HRWL, VSWL, KEWL, RNWL, MRNWL,
					VBWL, MGWL, CBWL, GGWL, ALLBETWL, COWL, KLWL, VS2WL, H5WL
			FROM #SumWinlost_FromCutDate
		) d
	GROUP BY custid

	INSERT INTO @WinlostTransfer3rd (CustId, Transfer3rd_Opus, Transfer3rd_AG, Transfer3rd_GD, Transfer3rd_VB, Transfer3rd_Crystal, Transfer3rd_LBKeno, Transfer3rd_Opal, Transfer3rd_BetSoft, Transfer3rd_iSoftBet, Transfer3rd_CitiBet, Transfer3rd_Topaz)
	SELECT	custid, SUM(Transfer3rd_Opus), SUM(Transfer3rd_AG), SUM(Transfer3rd_GD), SUM(Transfer3rd_VB),
			SUM(Transfer3rd_Crystal), SUM(Transfer3rd_LBKeno), SUM(Transfer3rd_Opal), SUM(Transfer3rd_BetSoft), SUM(Transfer3rd_iSoftBet), SUM(Transfer3rd_CitiBet), SUM(Transfer3rd_Topaz)
	FROM (
			SELECT	CustId, Transfer3rd_Opus, Transfer3rd_AG, Transfer3rd_GD, Transfer3rd_VB,
					Transfer3rd_Crystal, Transfer3rd_LBKeno, Transfer3rd_Opal, Transfer3rd_BetSoft, Transfer3rd_iSoftBet, Transfer3rd_CitiBet, Transfer3rd_Topaz
			FROM @WinlostTransfer3rd_BeforeCutDate

			UNION ALL

			SELECT	CustId, Transfer3rd_Opus, Transfer3rd_AG, Transfer3rd_GD, Transfer3rd_VB,
					Transfer3rd_Crystal, Transfer3rd_LBKeno, Transfer3rd_Opal, Transfer3rd_BetSoft, Transfer3rd_iSoftBet, Transfer3rd_CitiBet, Transfer3rd_Topaz
			FROM @WinlostTransfer3rd_FromCutDate
		) AS Transfer3rd
	GROUP BY custid

	IF @orderItem=5
	BEGIN
		IF @topcnt=0
		BEGIN
			SELECT c.username,c.username2, toptbl.*,ISNULL(o.Transfer3rd_Opus,0) AS Transfer3rd_Opus, ISNULL(o.Transfer3rd_AG,0) AS Transfer3rd_AG,
				   ISNULL(o.Transfer3rd_GD, 0) AS Transfer3rd_GD, ISNULL(o.Transfer3rd_VB, 0) AS Transfer3rd_VB, ISNULL(o.Transfer3rd_Crystal, 0) AS Transfer3rd_Crystal,
				   ISNULL(o.Transfer3rd_LBKeno, 0) AS Transfer3rd_LBKeno, ISNULL(o.Transfer3rd_Opal, 0) AS Transfer3rd_Opal, ISNULL(o.Transfer3rd_BetSoft, 0) AS Transfer3rd_BetSoft, ISNULL(o.Transfer3rd_iSoftBet, 0) AS Transfer3rd_iSoftBet, ISNULL(o.Transfer3rd_CitiBet, 0) AS Transfer3rd_CitiBet, ISNULL(o.Transfer3rd_Topaz, 0) AS Transfer3rd_Topaz
			FROM 
			(
				SELECT rpt.*
				FROM #SumWinlost rpt
			
				WHERE rpt.Winloss <> 0
			) AS toptbl
			INNER JOIN dbo.Customer c WITH(NOLOCK) ON toptbl.custid = c.custid
			LEFT JOIN @WinlostTransfer3rd o ON toptbl.custid = o.custid
			ORDER BY  toptbl.Winloss
		END
		ELSE
		BEGIN
			SELECT c.username,c.username2, toptbl.*,ISNULL(o.Transfer3rd_Opus,0) AS Transfer3rd_Opus, ISNULL(o.Transfer3rd_AG,0) AS Transfer3rd_AG,
				   ISNULL(o.Transfer3rd_GD, 0) AS Transfer3rd_GD, ISNULL(o.Transfer3rd_VB, 0) AS Transfer3rd_VB, ISNULL(o.Transfer3rd_Crystal, 0) AS Transfer3rd_Crystal,
				   ISNULL(o.Transfer3rd_LBKeno, 0) AS Transfer3rd_LBKeno,ISNULL(o.Transfer3rd_Opal, 0) AS Transfer3rd_Opal, ISNULL(o.Transfer3rd_BetSoft, 0) AS Transfer3rd_BetSoft, ISNULL(o.Transfer3rd_iSoftBet, 0) AS Transfer3rd_iSoftBet, ISNULL(o.Transfer3rd_CitiBet, 0) AS Transfer3rd_CitiBet, ISNULL(o.Transfer3rd_Topaz, 0) AS Transfer3rd_Topaz
			FROM 
			(
				SELECT TOP(@topcnt) rpt.*
				FROM #SumWinlost rpt
				WHERE rpt.Winloss <> 0
				ORDER BY rpt.Winloss
			) AS toptbl
			INNER JOIN dbo.Customer c WITH(NOLOCK) ON toptbl.custid = c.custid
			LEFT JOIN @WinlostTransfer3rd o ON toptbl.custid = o.custid
		
		END
	END
	ELSE
	BEGIN
		IF @topcnt=0
		BEGIN
			SELECT c.username,c.username2, toptbl.*,ISNULL(o.Transfer3rd_Opus,0) AS Transfer3rd_Opus, ISNULL(o.Transfer3rd_AG,0) AS Transfer3rd_AG,
					ISNULL(o.Transfer3rd_GD, 0) AS Transfer3rd_GD, ISNULL(o.Transfer3rd_VB, 0) AS Transfer3rd_VB, ISNULL(o.Transfer3rd_Crystal, 0) AS Transfer3rd_Crystal,
					ISNULL(o.Transfer3rd_LBKeno, 0) AS Transfer3rd_LBKeno, ISNULL(o.Transfer3rd_Opal, 0) AS Transfer3rd_Opal, ISNULL(o.Transfer3rd_BetSoft, 0) AS Transfer3rd_BetSoft, ISNULL(o.Transfer3rd_iSoftBet, 0) AS Transfer3rd_iSoftBet, ISNULL(o.Transfer3rd_CitiBet, 0) AS Transfer3rd_CitiBet, ISNULL(o.Transfer3rd_Topaz, 0) AS Transfer3rd_Topaz
			FROM 
			(
				SELECT rpt.*
				FROM #SumWinlost rpt
				WHERE 
					CASE  
						WHEN @orderItem=1 AND rpt.Deposit > 0 THEN 1
						WHEN @orderItem=2 AND rpt.Withdrawal > 0 THEN 1
						WHEN @orderItem=3 AND rpt.Turnover > 0 THEN 1
						WHEN @orderItem=4 AND rpt.Winloss <> 0 THEN 1
						END = 1
			) AS toptbl
				INNER JOIN dbo.Customer c WITH(NOLOCK) ON toptbl.custid = c.custid
				LEFT JOIN @WinlostTransfer3rd o ON toptbl.custid = o.custid
			  ORDER BY 
					CASE  @orderItem
						WHEN 1 THEN toptbl.Deposit
						WHEN 2 THEN toptbl.Withdrawal
						WHEN 3 THEN toptbl.Turnover
						WHEN 4 THEN toptbl.Winloss
					END DESC 
		END 
		ELSE
		BEGIN
			SELECT c.username,c.username2, toptbl.*,ISNULL(o.Transfer3rd_Opus,0) AS Transfer3rd_Opus, ISNULL(o.Transfer3rd_AG,0) AS Transfer3rd_AG,
					ISNULL(o.Transfer3rd_GD, 0) AS Transfer3rd_GD, ISNULL(o.Transfer3rd_VB, 0) AS Transfer3rd_VB, ISNULL(o.Transfer3rd_Crystal, 0) AS Transfer3rd_Crystal,
					ISNULL(o.Transfer3rd_LBKeno, 0) AS Transfer3rd_LBKeno,ISNULL(o.Transfer3rd_Opal, 0) AS Transfer3rd_Opal, ISNULL(o.Transfer3rd_BetSoft, 0) AS Transfer3rd_BetSoft, ISNULL(o.Transfer3rd_iSoftBet, 0) AS Transfer3rd_iSoftBet, ISNULL(o.Transfer3rd_CitiBet, 0) AS Transfer3rd_CitiBet, ISNULL(o.Transfer3rd_Topaz, 0) AS Transfer3rd_Topaz
			FROM 
			(
				SELECT TOP(@topcnt) rpt.*
				FROM #SumWinlost rpt
				WHERE
					CASE  
						WHEN @orderItem=1 AND rpt.Deposit >0 THEN 1
						WHEN @orderItem=2 AND rpt.Withdrawal >0 THEN 1
						WHEN @orderItem=3 AND rpt.Turnover >0 THEN 1
						WHEN @orderItem=4 AND rpt.Winloss <>0 THEN 1
						END = 1
				ORDER BY 
					CASE  @orderItem
						WHEN 1 THEN rpt.Deposit
						WHEN 2 THEN rpt.Withdrawal
						WHEN 3 THEN rpt.Turnover
						WHEN 4 THEN rpt.Winloss
					END DESC
			) AS toptbl
			INNER JOIN dbo.Customer c WITH(NOLOCK) ON toptbl.custid = c.custid
			LEFT JOIN @WinlostTransfer3rd o ON toptbl.custid = o.custid
		END
	END

	DROP TABLE #SumWinlost
	DROP TABLE #AgentList
	DROP TABLE #tblcust
END


