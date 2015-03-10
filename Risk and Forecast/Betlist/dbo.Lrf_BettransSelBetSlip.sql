USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_BettransSelBetSlip]    Script Date: 02/21/2014 00:14:12 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.Lrf_BettransSelBetSlip    Script Date: 5/8/2013 3:14:43 AM ******/
/****** Object:  Stored Procedure dbo.Lrf_BettransSelBetSlip    Script Date: 4/29/2013 9:54:25 AM ******/

ALTER PROCEDURE [dbo].[Lrf_BettransSelBetSlip]
	@transid bigint,
	@Langkey VARCHAR(10) = 'en-US'
AS

/*
Created: 20101210@Henry
Task : 
DB: DB052.bodb02
Original: [Age_BettransSelBetSlip]

Revisions:
    -- 20110222@Jacob: Add more column "nickname"
    -- 20110303@Henry: suppport based currency
    -- 20110408@Amy: Change function to get Odds value AND odds type
    -- 20111124@Henry: Add Checktime and SecAcceptFlag to show status waiting or running
    -- 20111229@Jim: Remove function : f_ShowOddsByBettype,f_GetOddsByBettype,f_GetChoice
	-- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
    -- 20150130@Winnie: Add base currency GBP
*/
SET NOCOUNT ON

DECLARE @Today smalldatetime 
SET @Today = convert(VARCHAR(10), CURRENT_TIMESTAMP, 120) 
DECLARE @Fromdate DATETIME
DECLARE @Todate  DATETIME

IF exists(SELECT 1 from bettrans WITH (NOLOCK) WHERE transid = @transid)	
BEGIN
		SELECT	@FromDate=CASE WHEN MAX(m.eventdate) <= @Today THEN MAX(m.eventdate)  ELSE @Today END,
				@ToDate=@Today
		FROM dbo.match14 m (NOLOCK) 
		GROUP BY  m.eventdate  
	
	SELECT 
		b.username,
		substring(c.username2,  CHARINDEX('$',c.username2)+1, len(c.username2)-CHARINDEX('$',c.username2)) as nickname,
		b.bettype,
		b.transid,
		m.matchcode,
		m.matchid,
		m.homeID,
		m.awayID,		
		b.hdp1,
		b.hdp2,
		b.betid,
		b.OddsType,
		--dbo.Lrf_f_ShowOddsByBettype(b.bettype,b.oddstype) as OddsType ,
		b.odds,
		--dbo.Lrf_f_GetOddsByBettype(b.odds,b.bettype,b.oddstype) as odds,
		b.winlostdate,
		CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
		ELSE b.status   
		END as status, 
		b.stake,
		b.stake*e.USD stakeUSD,
		b.stake*e.EUR stakeEUR,
		b.stake*e.GBP stakeGBP,
		b.transdate,
		b.betteam,
		--dbo.Lrf_f_GetChoice(b.betteam, b.bettype,@Language) betteam,
		b.livehomescore,
		b.liveawayscore,
		m.finalhomescore, 
		m.finalawayscore,
		m.hthomescore, 
		m.htawayscore, 
		(b.winlost-actual_stake) as winlost,
		(b.winlost-actual_stake)*e.USD as winlostUSD,
		(b.winlost-actual_stake)*e.EUR as winlostEUR,
		(b.winlost-actual_stake)*e.GBP as winlostGBP,
		b.liveindicator, 
		IP as IP,
		isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral
	from 	
		bettrans b with (nolock)
		LEFT OUTER JOIN match m with (nolock) ON b.matchid=m.matchid
		INNER JOIN customer c with(nolock) ON b.custid=c.custid	
		INNER JOIN  (SELECT * FROM Lrf_f_GetExchangeDaily(@FromDate,@ToDate))e 
		--ON e.ExchangeDate = b.winlostdate   
		ON e.ExchangeDate = (CASE WHEN b.winlostdate <= @Today THEN b.winlostdate ELSE @Today  END)
		AND e.exchangeid = b.currency	
	WHERE
		b.transid= @transid
	RETURN
END
IF exists(SELECT 1 from bettrans14 WITH (NOLOCK) WHERE transid = @transid)	
BEGIN
	SELECT @Fromdate=max( m.eventdate),@Todate=CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)
	FROM dbo.match14 m (NOLOCK)
	GROUP BY  m.eventdate 
	
	SELECT 
		b.username,
		substring(c.username2,  CHARINDEX('$',c.username2)+1, len(c.username2)-CHARINDEX('$',c.username2)) as nickname,
		b.bettype,
		b.transid,
		m.matchcode, 
		m.matchid,
		m.homeID,
		m.awayID,		
		b.hdp1,
		b.hdp2,
		b.betid,
		b.OddsType,
		--dbo.Lrf_f_ShowOddsByBettype(b.bettype,b.oddstype) as OddsType ,
		b.odds,
		--dbo.Lrf_f_GetOddsByBettype(b.odds,b.bettype,b.oddstype) as odds,
		b.winlostdate,
		b.status as Status,
		b.stake,
		b.stake*e.USD stakeUSD,
		b.stake*e.EUR stakeEUR,
		b.stake*e.GBP stakeGBP,
		b.transdate,
		b.betteam,
		--dbo.Lrf_f_GetChoice(b.betteam, b.bettype,@Language) betteam,
		b.livehomescore,
		b.liveawayscore,
		m.finalhomescore, 
		m.finalawayscore,
		m.hthomescore, 
		m.htawayscore, 
		(b.winlost-actual_stake) as winlost,
		(b.winlost-actual_stake)*e.USD as winlostUSD,
		(b.winlost-actual_stake)*e.EUR as winlostEUR,
		(b.winlost-actual_stake)*e.GBP as winlostGBP,
		b.liveindicator, 
		IP as IP,
		isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral
	FROM
		bettrans14 b with (nolock)
		LEFT OUTER JOIN match14 m with (nolock) ON b.matchid=m.matchid		
		INNER JOIN customer c with(nolock) ON b.custid=c.custid		
		INNER JOIN (SELECT *  FROM Lrf_f_GetExchangeDaily(@Fromdate,@Todate))e 
		ON e.ExchangeDate = b.winlostdate   AND e.exchangeid = b.currency	
	WHERE
		b.transid= @transid
	RETURN
END
GO
GRANT EXECUTE ON [dbo].[Lrf_BettransSelBetSlip] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BettransSelBetSlip] TO [VNTeam]
GO