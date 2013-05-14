ALTER PROCEDURE [dbo].[Task_bettransUPD]
AS
/*
	Created: Viet  
	Date: 2012-07-16
	DB   : WW100_DB.bodb_PIH @ kahnawake
*/	
SET NOCOUNT ON  
declare @rn bigint, @bettype smallint, @winlostdate datetime, @custid int

WHILE (1 = 1)
BEGIN
	
	select top 1 @rn = rn
				,@bettype = bettype 
				,@winlostdate = winlostdate
				,@custid = custid
	from dbo.bettransPending with(nolock) 
	order by rn ASC

	IF @@ROWCOUNT = 0
	BEGIN
		WAITFOR DELAY '000:00:00.280'
		RETURN -- no data to be update.
	END
	
	IF @bettype = 20000 -- balance up
	BEGIN
		DELETE bettrans where winlostdate <= @winlostdate and custid = @custid
	END
	
	IF @bettype = 19999 -- movebet
	BEGIN
		DELETE bettrans where winlostdate <= @winlostdate and custid = @CustID and bettype < 19999
	END

	MERGE dbo.bettrans as b
	USING (
			select * from bettransPending with(nolock) where rn = @rn
		) as bp ON (b.transid = bp.transid)
	WHEN MATCHED THEN 
		UPDATE SET b.custid = bp.custid
				,b.transdate = bp.transdate
				,b.oddsid = bp.oddsid
				,b.hdp1 = bp.hdp1
				,b.hdp2 = bp.hdp2
				,b.odds = bp.odds
				,b.stake = bp.stake
				,b.status = bp.status
				,b.winlost = bp.winlost
				,b.awinlost = bp.awinlost
				,b.mwinlost = bp.mwinlost
				,b.playercomm = bp.playercomm
				,b.comm = bp.comm
				,b.acomm = bp.acomm
				,b.apositiontaking = bp.apositiontaking
				,b.mpositiontaking = bp.mpositiontaking
				,b.tpositiontaking = bp.tpositiontaking
				,b.playerdiscount = bp.playerdiscount
				,b.discount = bp.discount
				,b.adiscount = bp.adiscount
				,b.livehomescore = bp.livehomescore
				,b.liveawayscore = bp.liveawayscore
				,b.liveindicator = bp.liveindicator
				,b.betteam = bp.betteam
				,b.creator = bp.creator
				,b.refno = bp.refno
				,b.winlostdate = bp.winlostdate
				,b.betfrom = bp.betfrom
				,b.betcheck = bp.betcheck
				,b.checktime = bp.checktime
				,b.oddsspread = bp.oddsspread
				,b.actualrate = bp.actualrate
				,b.matchid = bp.matchid
				,b.recommend = bp.recommend
				,b.mrecommend = bp.mrecommend
				,b.ruben = bp.ruben
				,b.betid = bp.betid
				,b.statuswinlost = bp.statuswinlost
				,b.modds = bp.modds
				,b.bettype = bp.bettype
				,b.betdaqid = bp.betdaqid
				,b.actual_stake = bp.actual_stake
				,b.currency = bp.currency
				,b.transdesc = bp.transdesc
				,b.sdiscount = bp.sdiscount
				,b.scomm = bp.scomm
				,b.spositiontaking = bp.spositiontaking
				,b.swinlost = bp.swinlost
				,b.srecommend = bp.srecommend
				,b.Username = bp.Username
				,b.CurrencyName = bp.CurrencyName
				,b.oddstype = bp.oddstype
				,b.statusID = bp.statusID
				,b.currency2 = bp.currency2
				,b.transid2 = bp.transid2
				,b.virtualrate = bp.virtualrate
	WHEN NOT MATCHED THEN 
		INSERT (	transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status, winlost, awinlost, mwinlost, playercomm,
					comm, acomm, apositiontaking, mpositiontaking, tpositiontaking, playerdiscount, discount, adiscount, livehomescore, 
					liveawayscore, liveindicator, betteam, creator, refno, winlostdate, betfrom, betcheck, checktime, oddsspread, actualrate, 
					matchid, recommend, mrecommend, ruben, betid, statuswinlost, modds, bettype, betdaqid, actual_stake, currency, transdesc,					
					sdiscount, scomm, spositiontaking, swinlost, srecommend, Username, CurrencyName, oddstype, statusID, currency2, transid2, 
					virtualrate
				)
		VALUES (	bp.transid, bp.custid, bp.transdate, bp.oddsid, bp.hdp1, bp.hdp2, bp.odds, bp.stake, bp.status, bp.winlost, 
					bp.awinlost, bp.mwinlost, bp.playercomm, bp.comm, bp.acomm, bp.apositiontaking, bp.mpositiontaking, 
					bp.tpositiontaking, bp.playerdiscount, bp.discount, bp.adiscount, bp.livehomescore, bp.liveawayscore, 
					bp.liveindicator, bp.betteam, bp.creator, bp.refno, bp.winlostdate, bp.betfrom, bp.betcheck, bp.checktime, 
					bp.oddsspread, bp.actualrate, bp.matchid, bp.recommend, bp.mrecommend, bp.ruben, bp.betid, bp.statuswinlost, 
					bp.modds, bp.bettype, bp.betdaqid, bp.actual_stake, bp.currency, bp.transdesc, bp.sdiscount, bp.scomm, 
					bp.spositiontaking, bp.swinlost, bp.srecommend, bp.Username, bp.CurrencyName, bp.oddstype, bp.statusID, 
					bp.currency2, bp.transid2, bp.virtualrate
				);

	DELETE FROM dbo.bettransPending WHERE rn = @rn
END

GO
GRANT VIEW DEFINITION ON [dbo].[Task_bettransUPD] TO [VNTeam] 