USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Task_DepWinlost_SyncData]    Script Date: 04/09/2014 21:19:26 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Task_DepWinlost_SyncData]	
AS
/*   
 Task : arrange bettransDEP data
 DB: DB054.bodb02  
 Revisions:   
  - 20121001@viet: create SP   
*/  
SET NOCOUNT ON
	declare @_tstamp binary(8)
	-- scan each transaction twice to prevent missing by locking

	SELECT @_tstamp = cast(cast(isnull(vvalue,0) as bigint) as binary(8))
	FROM dbo.systemsettings2 with(rowlock) 
	WHERE vname = 'Task_DepWinlost'	
	
	declare @today smalldatetime
	SET @today = DATEADD(dd, DATEDIFF(d, 0, CURRENT_TIMESTAMP), 0)			
	
	IF @_tstamp = 0x0000000000000000 -- 0: renew all data
	BEGIN
		SELECT @_tstamp = max(tstamp) FROM bodb02.dbo.bettrans with(nolock) 
		
		UPDATE dbo.systemsettings2 with(rowlock, updlock)
		SET vvalue = vvalue2
			,vvalue2 = cast(cast(@_tstamp as bigint) as varchar(200))
		WHERE vname = 'Task_DepWinlost'		
		
		RETURN
	END					
			
	select b.transid, b.tstamp, b.matchid, b.srecommend
	INTO #TempData
	from dbo.bettrans b with(nolock)
	where tstamp > @_tstamp
		and winlostdate >= DATEADD(dd, DATEDIFF(d, 0, CURRENT_TIMESTAMP)-1, 0) --yesterday onwards
	
	SELECT @_tstamp = max(tstamp) FROM #TempData with(nolock) 		
	UPDATE dbo.systemsettings2 with(rowlock, updlock)
	SET vvalue = vvalue2
		,vvalue2 = cast(cast(@_tstamp as bigint) as varchar(200))
	WHERE vname = 'Task_DepWinlost'	
	
	DELETE #TempData
	FROM dbo.Task_DepWinlost_tstamp s with(nolock)
	WHERE #TempData.tstamp = s.tstamp	
		
	TRUNCATE TABLE dbo.Task_DepWinlost_tstamp
	
	INSERT INTO dbo.Task_DepWinlost_tstamp (tstamp)
	SELECT tstamp
	FROM #TempData
	
	IF @@ROWCOUNT = 0 RETURN -- no new row		
	
	-- sync for bettransParlay
	MERGE dbo.bettransParlay as d
		USING (
			SELECT b.transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status, winlost, awinlost, mwinlost, playercomm, comm, acomm, 
				apositiontaking, mpositiontaking, tpositiontaking, playerdiscount, discount, adiscount, livehomescore, liveawayscore, 
				liveindicator, betteam, creator, refno, comstatus, winlostdate, betfrom, betcheck, checktime, oddsspread, actualrate, b.matchid, 
				recommend, mrecommend, ruben, betid, statuswinlost, modds, bettype, betdaqid, actual_stake, currency, ip, transdesc, sdiscount, 
				scomm, spositiontaking, swinlost, b.srecommend, Username, CurrencyName, virtualrate, oddstype, statusID, currency2, balance, 
				SecAcceptFlag, transid2 
			from dbo.bettrans b with(nolock)
				INNER JOIN #TempData s on b.transid = s.transid
			WHERE s.matchid in (9,29)
		) s on d.transid = s.transid	
		WHEN MATCHED THEN 
			UPDATE SET 
				custid = s.custid
				,transdate = s.transdate
				,oddsid = s.oddsid
				,hdp1 = s.hdp1
				,hdp2 = s.hdp2
				,odds = s.odds
				,stake = s.stake
				,status = s.status
				,winlost = s.winlost
				,awinlost = s.awinlost
				,mwinlost = s.mwinlost
				,playercomm = s.playercomm
				,comm = s.comm
				,acomm = s.acomm
				,apositiontaking = s.apositiontaking
				,mpositiontaking = s.mpositiontaking
				,tpositiontaking = s.tpositiontaking
				,playerdiscount = s.playerdiscount
				,discount = s.discount
				,adiscount = s.adiscount
				,livehomescore = s.livehomescore
				,liveawayscore = s.liveawayscore
				,liveindicator = s.liveindicator
				,betteam = s.betteam
				,creator = s.creator
				,refno = s.refno
				,comstatus = s.comstatus
				,winlostdate = s.winlostdate
				,betfrom = s.betfrom
				,betcheck = s.betcheck
				,checktime = s.checktime
				,oddsspread = s.oddsspread
				,actualrate = s.actualrate
				,matchid = s.matchid
				,recommend = s.recommend
				,mrecommend = s.mrecommend
				,ruben = s.ruben
				,betid = s.betid
				,statuswinlost = s.statuswinlost
				,modds = s.modds
				,bettype = s.bettype
				,betdaqid = s.betdaqid
				,actual_stake = s.actual_stake
				,currency = s.currency
				,ip = s.ip
				,transdesc = s.transdesc
				,sdiscount = s.sdiscount
				,scomm = s.scomm
				,spositiontaking = s.spositiontaking
				,swinlost = s.swinlost
				,srecommend = s.srecommend
				,Username = s.Username
				,CurrencyName = s.CurrencyName
				,virtualrate = s.virtualrate
				,oddstype = s.oddstype
				,statusID = s.statusID
				,currency2 = s.currency2
				,balance = s.balance
				,SecAcceptFlag = s.SecAcceptFlag
				,transid2 = s.transid2
		WHEN NOT MATCHED THEN 
		INSERT (transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status, winlost, awinlost, mwinlost, playercomm, comm, acomm, 
			apositiontaking, mpositiontaking, tpositiontaking, playerdiscount, discount, adiscount, livehomescore, liveawayscore, 
			liveindicator, betteam, creator, refno, comstatus, winlostdate, betfrom, betcheck, checktime, oddsspread, actualrate, matchid, 
			recommend, mrecommend, ruben, betid, statuswinlost, modds, bettype, betdaqid, actual_stake, currency, ip, transdesc, sdiscount, 
			scomm, spositiontaking, swinlost, srecommend, Username, CurrencyName, virtualrate, oddstype, statusID, currency2, balance, 
			SecAcceptFlag, transid2
			)
		VALUES (
			transid, s.custid, s.transdate, s.oddsid, s.hdp1, s.hdp2, s.odds, s.stake, s.status, s.winlost, s.awinlost, s.mwinlost, s.playercomm, 
			s.comm, s.acomm, s.apositiontaking, s.mpositiontaking, s.tpositiontaking, s.playerdiscount, s.discount, s.adiscount, s.livehomescore, 
			s.liveawayscore, s.liveindicator, s.betteam, s.creator, s.refno, s.comstatus, s.winlostdate, s.betfrom, s.betcheck, s.checktime, 
			s.oddsspread, s.actualrate, s.matchid, s.recommend, s.mrecommend, s.ruben, s.betid, s.statuswinlost, s.modds, s.bettype, s.betdaqid, 
			s.actual_stake, s.currency, s.ip, s.transdesc, s.sdiscount, s.scomm, s.spositiontaking, s.swinlost, s.srecommend, s.Username, 
			s.CurrencyName, s.virtualrate, s.oddstype, s.statusID, s.currency2, s.balance, s.SecAcceptFlag, s.transid2
			)
	;--end MERGE
	
	DECLARE @temptrans TABLE(transid bigint primary key, isBA bit)
	
	;WITH S AS (
		SELECT transid 
		FROM #TempData t
			INNER JOIN Dep_CustSuper c on t.srecommend = c.custid		
	)
	INSERT INTO @temptrans(transid, isBA)
	SELECT transid, 0
		FROM #TempData t
			INNER JOIN Dep_CustSuper c on t.srecommend = c.custid	
			
	UPDATE D
		SET isBA = 1
	FROM @temptrans D		
		INNER JOIN DB052.bodb_licensee.dbo.LicenseeBATransaction_active s with(nolock)
			ON s.transid = d.transid
	
	DELETE dbo.bettransDEP 
	FROM @temptrans s
	WHERE bettransDEP.transid = s.transid
	
	DECLARE @tempCustPending TABLE (custid int, winlostdate smalldatetime)
	
	INSERT INTO dbo.bettransDEP (
		transid, custid, transdate, stake, status, winlost, awinlost, mwinlost, playercomm, comm, 
		acomm, livehomescore, liveawayscore, liveindicator, refno, winlostdate, actualrate, matchid, 
		recommend, mrecommend, ruben, bettype, actual_stake, currency, scomm, swinlost, srecommend, 
		Username, statusID, isBA
	)
	OUTPUT inserted.custid, inserted.winlostdate INTO @tempCustPending(custid, winlostdate)
	SELECT t.transid, custid, transdate, stake, status, winlost, awinlost, mwinlost, playercomm, comm, 
		acomm, livehomescore, liveawayscore, liveindicator, refno, winlostdate, actualrate, matchid, 
		recommend, mrecommend, ruben, bettype, actual_stake, currency, scomm, swinlost, srecommend, 
		Username, statusID, isBA
	FROM dbo.bettrans b with(nolock)	
		INNER JOIN @temptrans t on b.transid = t.transid	

	MERGE dbo.Dep_CustomerPendingCalculate WITH(ROWLOCK, UPDLOCK) as d
		USING (	SELECT distinct custid, case when winlostdate > @Today then @Today else winlostdate end as winlostdate
				FROM @tempCustPending
			)s on d.custid = s.custid and d.winlostdate = s.winlostdate				
		WHEN NOT MATCHED THEN 
		INSERT (custid, winlostdate)
		VALUES (s.custid, s.winlostdate)
	;--end MERGE	
	DROP TABLE #TempData
SET NOCOUNT OFF
