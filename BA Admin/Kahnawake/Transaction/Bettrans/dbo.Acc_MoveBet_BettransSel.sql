ALTER PROCEDURE [dbo].[Acc_MoveBet_BettransSel]  
	@tstamp timestamp
AS  
/*  Created: Henry  
	Date: 2012-02-21
    TASk : Get data to insert to bettrans in Kahnawake server
    DB: DB052.bodb02
   
    Revisions:  
		20121115@viet: revise SP
		
	Param's Explanation:  
*/  
BEGIN  
SET NOCOUNT ON  
--return
----Delay for 1 seconds
--WAITFOR DELAY '000:00:6'

	declare @tstamp1 binary(8), @tstamp2 binary(8)
	-- scan each transid twice to prevent missing by locking
	SELECT @tstamp1 = cast(cast(isnull(vvalue,0) as bigint)+1 as binary(8))
	FROM dbo.systemsettings2 with(rowlock) 
	WHERE vname = 'Acc_MoveBet_BettransSel'	

	SELECT @tstamp2 = max(tstamp) FROM bodb02.dbo.bettrans with(nolock) 
	
	IF SYSTEM_USER = 'bodbAdminNet' -- not update new value for dba testing case vnteam/thien
	BEGIN
		UPDATE dbo.systemsettings2 with(rowlock, updlock)
		SET vvalue = vvalue2
			,vvalue2 = cast(cast(@tstamp2 as bigint) as varchar(200))
		WHERE vname = 'Acc_MoveBet_BettransSel'
	END

	declare @IDs as table (transid bigint, tstamp binary(8))
	
	INSERT INTO @IDs(transid, tstamp)
	SELECT b.transid, tstamp
	FROM bettrans b WITH(NOLOCK, index=IX_tstamp_transid)		
	WHERE tstamp between @tstamp1 and @tstamp2	
		and transid in (
			select transid from bodb_licensee.dbo.LicenseeBATransaction_active with(nolock)
		)
 	
 	IF @@ROWCOUNT = 0 
 	BEGIN
 		TRUNCATE TABLE dbo.MovebetTrans_lastbatch
 		RETURN 	
	END 		
 	 	
	DELETE  d
	FROM @IDs d 	 	
		INNER JOIN dbo.MovebetTrans_lastbatch s with(nolock) on d.transid = s.transid
	WHERE d.tstamp = s.tstamp
	
	TRUNCATE TABLE dbo.MovebetTrans_lastbatch
		
	SELECT
		b.[transid]
		,[custid]
		,b.[transdate]
		,[oddsid]
		,[hdp1]
		,[hdp2]
		,[odds]
		,[stake]
		,[status]
		,[winlost]
		,[awinlost]
		,[mwinlost]
		,[playercomm]
		,[comm]
		,[acomm]
		,[apositiontaking]
		,[mpositiontaking]
		,[tpositiontaking]
		,[playerdiscount]
		,[discount]
		,[adiscount]
		,[livehomescore]
		,[liveawayscore]
		,[liveindicator]
		,[betteam]
		,[creator]
		,[refno]
		,[winlostdate]
		,[betfrom]
		,[betcheck]
		,[checktime]
		,[oddsspread]
		,[actualrate]
		,[matchid]
		,[recommend]
		,[mrecommend]
		,[ruben]
		,[betid]
		,[statuswinlost]
		,[modds]
		,[bettype]
		,[betdaqid]
		,[actual_stake]
		,[currency]
		,[ip]
		,[transdesc]
		,[sdiscount]
		,[scomm]
		,[spositiontaking]
		,[swinlost]
		,[srecommend]
		,[username]
		,[virtualrate]
		,[oddstype]
		,[statusid]
		,[currency2]
		,[tstamp]		
	FROM bettrans b WITH (NOLOCK)
	WHERE transid in (select transid from @IDs)
	ORDER BY tstamp ASC
	FOR XML PATH('bettrans'), ROOT ('root')
	
	INSERT INTO dbo.MovebetTrans_lastbatch(transid, tstamp)
	SELECT transid, tstamp
	FROM @IDs
END

GO
GRANT EXECUTE ON [dbo].[Acc_MoveBet_BettransSel] TO [bodbAdminNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Acc_MoveBet_BettransSel] TO [vnteam] AS [dbo]
GO
