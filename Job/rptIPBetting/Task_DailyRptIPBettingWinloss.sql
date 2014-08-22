 USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Task_DailyRptIPBettingWinloss]    Script Date: 01/24/2013 02:05:18 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Task_DailyRptIPBettingWinloss]
	@winlostdate DATETIME
AS
/*
Created by:[Henry]
Date: 2012-05-22
Task: daily summary IP betting for Licensee
DB: DB06.BODB02
Revisions:
    - 20130124@Daniel: Change link server alias

   
 */

SET NOCOUNT ON 

DECLARE @BalanceUpDay smalldatetime, @MoveBetsDay smalldatetime

SELECT 
	TOP 1 @BalanceUpDay = winlostdate
FROM Bettrans WITH(NOLOCK)
WHERE bettype = 20000 AND matchid = 0	AND custid = 3

SELECT    
	@MoveBetsDay = MAX(eventdate)  
FROM match14 WITH(NOLOCK)  
	
DECLARE @ABSDate SMALLDATETIME
SET @ABSDate = '2011-09-01'

delete from bodb_Report.dbo.rptIPBetting with(ROWLOCK,UPDLOCK) where winlostdate = @winlostdate	
	
IF @winlostdate > @MoveBetsDay
BEGIN	
	
	INSERT INTO bodb_Report.dbo.rptIPBetting
		(
			[winlostdate]
			,[siteid]
			,[currency]
			,[ip]
			,[turnover]
			,[winlost]
			,[betcount]
			,[statusID]
		)
	SELECT @winlostdate,l.LicenseeID as siteid,bettrans.currency,bettrans.ip,
			SUM(
				case when bettrans.liveawayscore = 0 and bettrans.bettype IN(33,43) then ABS(bettrans.stake/2) else ABS(bettrans.stake) end
				) as TurnOver,
			SUM(winlost-actual_stake)  winlost,
			COUNT(bettrans.transid) BetCount,		
			Bettrans.statusID
		
		FROM
			bettrans bettrans WITH (NOLOCK)
			INNER JOIN bodb02.dbo.customer WITH (NOLOCK) ON bettrans.custid=customer.custid
			INNER JOIN bodb02.dbo.dep_custsuper s WITH (NOLOCK) ON customer.srecommend = s.custid
			INNER JOIN DBLIC.bodb_licensee.dbo.Licensees l WITH (NOLOCK) ON s.site = l.LicenseeName
		WHERE
			bettrans.winlostdate = @winlostdate AND
			bettrans.statusID IN (111,112,113) AND
			bettrans.bettype < 19000 AND
			bettrans.currency IN (2,4,13,15) --MYR,THB,RMB,IDR
		GROUP BY
			l.LicenseeID,
			bettrans.currency,
			bettrans.ip,
			Bettrans.statusID
END
ELSE IF @winlostdate < @MoveBetsDay AND @winlostdate >= @BalanceUpDay
BEGIN
	INSERT INTO bodb_Report.dbo.rptIPBetting
		(
			[winlostdate]
			,[siteid]
			,[currency]
			,[ip]
			,[turnover]
			,[winlost]
			,[betcount]
			,[statusID]
		)
	SELECT @winlostdate,l.LicenseeID as siteid,bettrans.currency,bettrans.ip,
			SUM(
				case when bettrans.liveawayscore = 0 and bettrans.bettype IN(33,43) then ABS(bettrans.stake/2) else ABS(bettrans.stake) end
				) as TurnOver,
			SUM(winlost-actual_stake)  winlost,
			COUNT(bettrans.transid) BetCount,		
			Bettrans.statusID
		FROM
			bettrans14 bettrans WITH (NOLOCK)
			INNER JOIN bodb02.dbo.customer WITH (NOLOCK) ON bettrans.custid=customer.custid
			INNER JOIN bodb02.dbo.dep_custsuper s WITH (NOLOCK) ON customer.srecommend = s.custid
			INNER JOIN DBLIC.bodb_licensee.dbo.Licensees l WITH (NOLOCK) ON s.site = l.LicenseeName
		WHERE
			bettrans.winlostdate = @winlostdate AND
			bettrans.statusID IN (111,112,113) AND
			bettrans.bettype < 19000 AND
			bettrans.currency IN (2,4,13,15) --MYR,THB,RMB,IDR
		GROUP BY
			l.LicenseeID,
			bettrans.currency,
			bettrans.ip,
			Bettrans.statusID
END
ELSE IF @winlostdate < @BalanceUpDay
BEGIN
	INSERT INTO bodb_Report.dbo.rptIPBetting
	(
		[winlostdate]
		,[siteid]
		,[currency]
		,[ip]
		,[turnover]
		,[winlost]
		,[betcount]
		,[statusID]
	)
SELECT @winlostdate,l.LicenseeID as siteid,bettrans.currency,bettrans.ip,
		SUM(
				CASE WHEN bettrans.winlostdate >= @ABSDate 
				THEN case when bettrans.liveawayscore = 0 and bettrans.bettype IN(33,43) then ABS(bettrans.stake/2) else ABS(bettrans.stake) end
				ELSE case when bettrans.liveawayscore = 0 and bettrans.bettype IN(33,43) then bettrans.stake/2 else bettrans.stake end 
				END
			) as TurnOver,
		SUM(winlost-actual_stake)  winlost,
		COUNT(bettrans.transid) BetCount,		
		--114: half win, 115: half lose
		CASE 
			WHEN bettrans.status = 'WON' THEN 112
			WHEN bettrans.status = 'LOSE' THEN 113
			WHEN bettrans.status = 'DRAW' THEN 111
			END AS statusID
	FROM
		bodb_archive.dbo.bettrans_bk bettrans WITH (NOLOCK,INDEX(CIX_winlostdate))
		INNER JOIN bodb02.dbo.customer WITH (NOLOCK) ON bettrans.custid=customer.custid
		INNER JOIN bodb02.dbo.dep_custsuper s WITH (NOLOCK) ON customer.srecommend = s.custid
		INNER JOIN DBLIC.bodb_licensee.dbo.Licensees l WITH (NOLOCK) ON s.site = l.LicenseeName
	WHERE
		bettrans.winlostdate = @winlostdate AND
		bettrans.status IN ('WON','LOSE','DRAW') AND
		bettrans.bettype < 19000 AND
		bettrans.currency IN (2,4,13,15) --MYR,THB,RMB,IDR
	GROUP BY
		l.LicenseeID,
		bettrans.currency,
		bettrans.ip,
		CASE 
			WHEN bettrans.status = 'WON' THEN 112
			WHEN bettrans.status = 'LOSE' THEN 113
			WHEN bettrans.status = 'DRAW' THEN 111
			END 
END

		


GO
GRANT VIEW DEFINITION ON [dbo].[Task_DailyRptIPBettingWinloss] TO [vnteam] AS [dbo]