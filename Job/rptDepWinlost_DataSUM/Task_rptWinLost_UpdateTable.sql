USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Task_rptWinLost_UpdateTable]    Script Date: 04/09/2014 21:03:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Task_rptWinLost_UpdateTable]
	@winlostdate smalldatetime
AS
/*
Name : rpt_WinLost_UpdateTable
Creator : Joe
Created : 2007-01-29 01:30
Task : update summary for winlost report
DB: DBACC/bodb02
Revision:
	- 20110516@Lukas: re-arrange bettype
	- 20120420@Hurri: add tickets of member under agent BARM into IBC winlost
	- 20120626@Elodie: exclude outright, HR from sportbook ( in case of matchid = orid)
	- 20130620@Johnson: copy data to rptWinlost2
	- 20130822@Johnson: change to use rptWinlost instead rptWinlost2
	- 20130917@Johnson: correct real turnover of racing formula
	- 20131203@Daniel: exclude UUS tickets to avoid zero data inserted
*/
	
	DECLARE @CommSetting TABLE
	(	MatchID			int,
		IBCFee			bit,
		ToteCommWin		smallmoney,
		ToteCommPlace	smallmoney,
		ToteCommWP		smallmoney,
		ToteFee			smallmoney	
	)
	
	CREATE TABLE #bettransm (
		refno bigint primary key,
		TOIBC	money,
		WLIBC money,
		TOPhum money
	)
	
	SELECT distinct winlostdate FROM bettrans with (nolock) WHERE winlostdate = @winlostdate AND bettype < 19999
	IF @@ROWCOUNT = 1
	BEGIN				
		DELETE FROM bodb_Report.dbo.rptWinlost
		WHERE winlostdate = @winlostdate
		
		--calculate racing winlost
		INSERT INTO @CommSetting (MatchID, IBCFee, ToteCommWin, ToteCommPlace, ToteCommWP, ToteFee)
		SELECT	DISTINCT o.orid as matchid, CASE WHEN r.partnerID IN (2,3,4) THEN 0 ELSE 1 END, p.ToteCommWin, p.ToteCommPlace, (p.ToteCommWin + p.ToteCommPlace)/2 ToteCommWP, p.ToteFee 
		FROM	outright o WITH (NOLOCK)
				INNER JOIN LeagueDetail p WITH (NOLOCK) ON o.leagueID = p.LeagueID AND p.programDate = o.programDate
				INNER JOIN RacingMeeting r WITH(NOLOCK) ON r.meetingID = p.leagueid				
		WHERE	o.eventdate = @winlostdate 
		
		INSERT INTO #bettransm (refno,TOIBC,WLIBC,TOPhum)
		SELECT refno,
			sum(case when bettype = 32 and liveawayscore =0 then 0 else stake*isnull(oddsspread,0) end),
			-sum((winlost - stake)*isnull(oddsspread,0)),
			sum(case when bettype = 32 and liveawayscore = 0 then 0 when bettype = 31 or (bettype = 32 and liveawayscore <> 0) then stake*(1 -tpositiontaking - isnull(oddsspread,0)) else 0 end)
		FROM bettransm WITH(NOLOCK)
		WHERE winlostdate = @winlostdate	
			AND bettype IN (31,32)
		GROUP BY refno
		
		INSERT INTO bodb_Report.dbo.rptWinlost
			(
				[winlostdate]
			   ,[matchid]
			   ,[bettype]
			   ,[liveindicator]
			   ,[Status]
			   ,[IBC]
			   ,[RealTurnover]
			   ,[RealWinLost]
			   ,[RealPosition]
			   ,[RealCommission]
			   ,[RealLineTotal]
			   ,[VirtualTurnover]
			   ,[VirtualLineTotal]
			   ,[SportType]
			   ,[exrisk]
			)			
		SELECT
			winlostdate,
			b.matchid, bettype, liveindicator, Status,
			case when recommend = 52466 then 1 when recommend = 5707545 then 2 else 0 end ibc,
			sum(case when b.bettype = 33 then bm.TOIBC*actualrate ELSE actual_stake*isnull(b.oddsspread,0)*actualrate END) as realturnover,
			sum((winlost-actual_stake)* actualrate)  realwinlost,
			sum((awinlost+mwinlost+swinlost)* actualrate) realpos,
			sum((scomm) * actualrate) realcomm,
			-(sum((case when bettype = 33 then bm.WLIBC else -(b.winlost -b.actual_stake)*isnull(b.oddsspread,0) end)*b.actualrate) 
								- sum( case when cs.IBCFee = 0 then 0 else (case when b.bettype = 33 then bm.TOPhum when bettype in (31,32) then b.actual_stake*(1 -b.tpositiontaking - isnull(b.oddsspread,0)) else 0 end)*b.actualrate*cs.ToteFee end) --FeeDue2 
								+ sum((case bettype when 31 then b.actual_stake*cs.ToteCommWin*(1 - b.tpositiontaking - isnull(oddsspread,0))
													when 32 then b.actual_stake*cs.ToteCommPlace*(1 - b.tpositiontaking - isnull(oddsspread,0))
													when 33 then bm.TOPhum*cs.ToteCommWP  
													else 0 end)*b.actualrate) --commIncomeIBC
								- sum(b.scomm*b.actualrate)) as realLineTotal,
			0 as virtualTurnover,
			0 virtualLineTotal,			
			0, 0
		FROM
			bettrans b with (nolock)
			INNER JOIN @CommSetting as cs ON b.matchid = cs.matchid 
			LEFT JOIN #bettransm bm ON b.transid = bm.refno
		WHERE
			bettype in (31,32,33)
			AND winlostdate = @winlostdate
			AND statusID NOT IN (101,102,103,121)--('VOID','REJECT','DONE','REFUND')
			AND ruben = 1
			AND currency <> 20
		GROUP BY
			winlostdate, b.matchid, bettype, liveindicator, status,
			case when recommend = 52466 then 1 when recommend = 5707545 then 2 else 0 end


		INSERT INTO bodb_Report.dbo.rptWinlost
			(
				[winlostdate]
			   ,[matchid]
			   ,[bettype]
			   ,[liveindicator]
			   ,[Status]
			   ,[IBC]
			   ,[RealTurnover]
			   ,[RealWinLost]
			   ,[RealPosition]
			   ,[RealCommission]
			   ,[RealLineTotal]
			   ,[VirtualTurnover]
			   ,[VirtualLineTotal]
			   ,[SportType]
			   ,[exrisk]
			)	
		SELECT
			winlostdate,
			matchid, bettype, liveindicator, Status,
			case when recommend = 52466 then 1 when recommend = 5707545 then 2 else 0 end as ibc,
			sum(case when bettype IN (71,73,1000) then 0 else (1-tpositiontaking)*abs(stake)*actualrate end) as realturnover,
			sum((winlost-actual_stake)* actualrate)  realWinlost,
			sum((awinlost+mwinlost+swinlost)* actualrate) realPos,
			sum((scomm) * actualrate) realComm,
			sum((case when bettype = 1000 then -1*(odds-scomm) else winlost-actual_stake+awinlost+mwinlost+swinlost+scomm end)*actualrate) realLineTotal,
			sum((1-tpositiontaking)*abs(CASE WHEN bettype IN (71,73,1000) THEN 0 
											WHEN bettype = 29 AND betid > 0 THEN actual_stake 
											ELSE stake END)*virtualrate) as virtualTurnover,
			sum(CASE WHEN bettype IN (71,73,1000) OR bettype between 1101 and 1199 OR bettype between 1201 and 1299 THEN 0 
					ELSE (winlost-actual_stake+awinlost+mwinlost+swinlost+scomm)*virtualrate END ) as virtualLineTotal,
			0, 0
		FROM
			bettrans b with (nolock)
		WHERE
			bettype < 19999 and bettype not in (31,32,33)
			AND winlostdate = @winlostdate
			AND statusID NOT IN (101, 102,103,121) --('VOID','REJECT','DONE','REFUND')
			AND ruben = 1
			AND currency <> 20
		GROUP BY
			winlostdate, matchid, bettype, liveindicator, status,
			case when recommend = 52466 then 1 when recommend = 5707545 then 2 else 0 end

		UPDATE bodb_Report.dbo.rptWinlost
		SET SportType = CASE
			WHEN leaguename LIKE '%NFL%' AND l.sporttype = 2 THEN 3
			WHEN (leaguename LIKE '%NHL%' OR leaguename LIKE '%hockey%') AND l.sporttype = 2 THEN 4
			ELSE l.sporttype END, exrisk = m.exrisk
		FROM match m with (nolock)
			inner join league l with (nolock) ON m.leagueid = l.leagueid
		WHERE bodb_Report.dbo.rptWinlost.matchid = m.matchid
		AND m.eventdate = @winlostdate AND bodb_Report.dbo.rptWinlost.winlostdate = @winlostdate
		AND bodb_Report.dbo.rptWinlost.bettype not in (10,31,32,33) --20120626@Elodie: exclude outright from sportbook

		UPDATE bodb_Report.dbo.rptWinlost
		SET SportType = CASE
			WHEN leaguename LIKE '%NFL%' AND l.sporttype = 2 THEN 3
			WHEN (leaguename LIKE '%NHL%' OR leaguename LIKE '%hockey%') AND l.sporttype = 2 THEN 4
			ELSE l.sporttype END
		FROM outright o with (nolock) INNER JOIN league l with (nolock) ON o.leagueid = l.leagueid
		WHERE bodb_Report.dbo.rptWinlost.matchid = o.orid
		AND bodb_Report.dbo.rptWinlost.winlostdate = @winlostdate
		AND bodb_Report.dbo.rptWinlost.bettype = 10
		
		UPDATE bodb_Report.dbo.rptWinlost
		SET SportType = CASE
			WHEN leaguename LIKE '%NFL%' AND l.sporttype = 2 THEN 3
			WHEN (leaguename LIKE '%NHL%' OR leaguename LIKE '%hockey%') AND l.sporttype = 2 THEN 4
			ELSE l.sporttype END
		FROM outright o with (nolock) INNER JOIN league l with (nolock) ON o.leagueid = l.leagueid
		WHERE bodb_Report.dbo.rptWinlost.matchid = o.orid
		AND bodb_Report.dbo.rptWinlost.winlostdate = @winlostdate
		AND bodb_Report.dbo.rptWinlost.bettype BETWEEN 31 AND 33
		
		--Virtual Racing
		UPDATE bodb_Report.dbo.rptWinlost
		SET SportType = r.sporttype
		FROM VSRaceInfo r with (nolock)
		WHERE bodb_Report.dbo.rptWinlost.matchid = r.EventID
		AND bodb_Report.dbo.rptWinlost.winlostdate = @winlostdate
		AND bodb_Report.dbo.rptWinlost.bettype in (1231, 1232, 1233, 1237, 1238)			
	END
	ELSE
	BEGIN -- check from BetTrans14
		SELECT distinct winlostdate FROM bettrans14 with (nolock) WHERE winlostdate = @winlostdate AND bettype < 19999

		IF @@ROWCOUNT = 1
		BEGIN
			DELETE FROM bodb_Report.dbo.rptWinlost
			WHERE winlostdate = @winlostdate
		
			--calculate racing winlost
			INSERT INTO @CommSetting (MatchID, IBCFee, ToteCommWin, ToteCommPlace, ToteCommWP, ToteFee)
			SELECT	DISTINCT o.orid as matchid, CASE WHEN r.partnerID IN (2,3,4) THEN 0 ELSE 1 END, p.ToteCommWin, p.ToteCommPlace, (p.ToteCommWin + p.ToteCommPlace)/2 ToteCommWP, p.ToteFee 
			FROM	outright14 o WITH (NOLOCK)
					INNER JOIN LeagueDetail p WITH (NOLOCK) ON o.leagueID = p.LeagueID AND p.programDate = o.programDate
					INNER JOIN RacingMeeting r WITH(NOLOCK) ON r.meetingID = p.leagueid				
			WHERE	o.eventdate = @winlostdate 
			
			INSERT INTO #bettransm (refno,TOIBC,WLIBC,TOPhum)
			SELECT refno,
				sum(case when bettype = 32 and liveawayscore =0 then 0 else stake*isnull(oddsspread,0) end),
				-sum((winlost - stake)*isnull(oddsspread,0)),
				sum(case when bettype = 32 and liveawayscore = 0 then 0 when bettype = 31 or (bettype = 32 and liveawayscore <> 0) then stake*(1 -tpositiontaking - isnull(oddsspread,0)) else 0 end)
			FROM bettransm14 WITH(NOLOCK)
			WHERE winlostdate = @winlostdate
				AND bettype IN (31,32)
			GROUP BY refno
			
			INSERT INTO bodb_Report.dbo.rptWinlost
			(
				[winlostdate]
			   ,[matchid]
			   ,[bettype]
			   ,[liveindicator]
			   ,[Status]
			   ,[IBC]
			   ,[RealTurnover]
			   ,[RealWinLost]
			   ,[RealPosition]
			   ,[RealCommission]
			   ,[RealLineTotal]
			   ,[VirtualTurnover]
			   ,[VirtualLineTotal]
			   ,[SportType]
			   ,[exrisk]
			)			
			SELECT
				winlostdate,
				b.matchid, bettype, liveindicator, Status,
				case when recommend = 52466 then 1 when recommend = 5707545 then 2 else 0 end ibc,
				sum(case when b.bettype = 33 then bm.TOIBC*actualrate ELSE actual_stake*isnull(b.oddsspread,0)*actualrate END) as realturnover,
				sum((winlost-actual_stake)* actualrate)  realwinlost,
				sum((awinlost+mwinlost+swinlost)* actualrate) realpos,
				sum((scomm) * actualrate) realcomm,
				-(sum((case when bettype = 33 then bm.WLIBC else -(b.winlost -b.actual_stake)*isnull(b.oddsspread,0) end)*b.actualrate) 
									- sum( case when cs.IBCFee = 0 then 0 else (case when b.bettype = 33 then bm.TOPhum when bettype in (31,32) then b.actual_stake*(1 -b.tpositiontaking - isnull(b.oddsspread,0)) else 0 end)*b.actualrate*cs.ToteFee end) --FeeDue2 
									+ sum((case bettype when 31 then b.actual_stake*cs.ToteCommWin*(1 - b.tpositiontaking - isnull(oddsspread,0))
														when 32 then b.actual_stake*cs.ToteCommPlace*(1 - b.tpositiontaking - isnull(oddsspread,0))
														when 33 then bm.TOPhum*cs.ToteCommWP  
														else 0 end)*b.actualrate) --commIncomeIBC
									- sum(b.scomm*b.actualrate)) as realLineTotal,
				0 as virtualTurnover,
				0 virtualLineTotal,			
				0, 0
			FROM
				bettrans14 b with (nolock)
				INNER JOIN @CommSetting as cs ON b.matchid = cs.matchid 
				LEFT JOIN #bettransm bm ON b.transid = bm.refno
			WHERE
				bettype in (31,32,33)
				AND winlostdate = @winlostdate
				AND statusID NOT IN (101,102,103,121)--('VOID','REJECT','DONE','REFUND')
				AND ruben = 1
				AND currency <> 20
			GROUP BY
				winlostdate, b.matchid, bettype, liveindicator, status,
				case when recommend = 52466 then 1 when recommend = 5707545 then 2 else 0 end


			INSERT INTO bodb_Report.dbo.rptWinlost
				(
					[winlostdate]
				   ,[matchid]
				   ,[bettype]
				   ,[liveindicator]
				   ,[Status]
				   ,[IBC]
				   ,[RealTurnover]
				   ,[RealWinLost]
				   ,[RealPosition]
				   ,[RealCommission]
				   ,[RealLineTotal]
				   ,[VirtualTurnover]
				   ,[VirtualLineTotal]
				   ,[SportType]
				   ,[exrisk]
				)				
			SELECT
				winlostdate,
				matchid, bettype, liveindicator, Status,
				case when recommend = 52466 then 1 when recommend = 5707545 then 2 else 0 end ibc,
				sum(case when bettype IN (71,73,1000) then 0 else (1-tpositiontaking)*abs(stake)*actualrate end) as realturnover,
				sum((winlost-actual_stake)* actualrate)  realWinlost,
				sum((awinlost+mwinlost+swinlost)* actualrate) realPos,
				sum((scomm) * actualrate) realComm,
				sum((case when bettype = 1000 then -1*(odds-scomm) else winlost-actual_stake+awinlost+mwinlost+swinlost+scomm end)*actualrate) realLineTotal,
				sum((1-tpositiontaking)*abs(CASE WHEN bettype IN (71,73,1000) THEN 0 
												WHEN bettype = 29 AND betid > 0 THEN actual_stake 
												ELSE stake END)*virtualrate) as virtualTurnover,
				sum(CASE WHEN bettype IN (71,73,1000) OR bettype between 1101 and 1199 OR bettype between 1201 and 1299 THEN 0 
						ELSE (winlost-actual_stake+awinlost+mwinlost+swinlost+scomm)*virtualrate END ) as virtualLineTotal,
				0, 0
			FROM
				bettrans14 b with (nolock)
			WHERE
				bettype < 19999 and bettype not in (31,32,33)
				AND winlostdate = @winlostdate
				AND statusID NOT IN (101, 102,103,121) ----('VOID','REJECT','DONE','REFUND')
				AND ruben = 1
				AND currency <> 20
			GROUP BY
				winlostdate, matchid, bettype, liveindicator, status,
				case when recommend = 52466 then 1 when recommend = 5707545 then 2 else 0 end

			UPDATE bodb_Report.dbo.rptWinlost
			SET SportType = CASE
				WHEN leaguename LIKE '%NFL%' AND l.sporttype = 2 THEN 3
				WHEN (leaguename LIKE '%NHL%' OR leaguename LIKE '%hockey%') AND l.sporttype = 2 THEN 4
				ELSE l.sporttype END, exrisk = m.exrisk
			FROM match14 m with (nolock)
				inner join league l with (nolock) ON m.leagueid = l.leagueid
			WHERE bodb_Report.dbo.rptWinlost.matchid = m.matchid
			AND m.eventdate = @winlostdate AND bodb_Report.dbo.rptWinlost.winlostdate = @winlostdate
			AND bodb_Report.dbo.rptWinlost.bettype not in (10,31,32,33) --20120626@Elodie: exclude outright from sportbook
			
			UPDATE bodb_Report.dbo.rptWinlost
			SET SportType = CASE
				WHEN leaguename LIKE '%NFL%' AND l.sporttype = 2 THEN 3
				WHEN (leaguename LIKE '%NHL%' OR leaguename LIKE '%hockey%') AND l.sporttype = 2 THEN 4
				ELSE l.sporttype END
			FROM outright14 o with (nolock) INNER JOIN league l with (nolock) ON o.leagueid = l.leagueid
			WHERE bodb_Report.dbo.rptWinlost.matchid = o.orid
			AND bodb_Report.dbo.rptWinlost.winlostdate = @winlostdate
			AND bodb_Report.dbo.rptWinlost.bettype = 10
			
			UPDATE bodb_Report.dbo.rptWinlost
			SET SportType = CASE
				WHEN leaguename LIKE '%NFL%' AND l.sporttype = 2 THEN 3
				WHEN (leaguename LIKE '%NHL%' OR leaguename LIKE '%hockey%') AND l.sporttype = 2 THEN 4
				ELSE l.sporttype END
			FROM outright14 o with (nolock) INNER JOIN league l with (nolock) ON o.leagueid = l.leagueid
			WHERE bodb_Report.dbo.rptWinlost.matchid = o.orid
			AND bodb_Report.dbo.rptWinlost.winlostdate = @winlostdate
			AND bodb_Report.dbo.rptWinlost.bettype BETWEEN 31 AND 33	
			
			--Virtual Racing
			UPDATE bodb_Report.dbo.rptWinlost
			SET SportType = r.sporttype
			FROM VSRaceInfo r with (nolock)
			WHERE bodb_Report.dbo.rptWinlost.matchid = r.EventID
			AND bodb_Report.dbo.rptWinlost.winlostdate = @winlostdate
			AND bodb_Report.dbo.rptWinlost.bettype in (1231, 1232, 1233, 1237, 1238)	
		END
	END
	
	DROP TABLE #bettransm


