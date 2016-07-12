USE [bodb02]
 
SET QUOTED_IDENTIFIER ON
GO


CREATE VIEW [dbo].[view_LiveMatch_LeagueEx]
AS
/*
	Created: Jim
	Date: 2016-03-03
	Task : LRF - Weekly live matches [Redmine #52886]
	DB: DBEXT/bodb02
	Revisions: 20160518@Jim: use view instead of table league to filter test leaguage
			   20160602@Jim: change formula to calculate total match of E-sport and set monday is the first day of week	
			   20160621@Jim: modify sp to adapt new specs	
*/

SELECT leagueid 
	   ,leaguename	
	   ,sporttype
	   
FROM dbo.League l WITH (NOLOCK)
WHERE  	leaguename  	NOT LIKE '%SPECIFIC 15 MINS%'   
		AND  leaguename NOT LIKE '%No.of Corners%'    
		AND  leaguename NOT LIKE '%Total Bookings'     
		AND  leaguename NOT LIKE '%Booking'       
		AND  leaguename NOT LIKE '%Corner%'        
		AND  leaguename NOT LIKE '%SPECIFIC 15 MINS TOTAL BOOKINGS%'  
		AND  leaguename NOT LIKE '%SPECIFIC 15 MINS%'   
		AND  leaguename NOT LIKE '%SPECIFIC 10 MINS%'  
		AND  leaguename NOT LIKE '%SINGLE TEAM OVER/UNDER%'    
		AND  leaguename NOT LIKE '%:00%'	
		AND  leaguename NOT LIKE '%Winner%'	
		AND  leaguename NOT LIKE '%shoot out%'
		AND  leagueName NOT LIKE '%PENALTY SHOOT-OUT%'
		AND  leaguename NOT LIKE '%FANTASY MATCH%'
		AND 
		(
			l.sporttype=1
			OR  (l.sporttype = 2
			AND l.leaguename NOT LIKE '%no use%'
			AND l.leaguename NOT LIKE '%wrong%'
			AND l.leaguename NOT LIKE '%betting prohibited area%'
			AND l.leaguename NOT LIKE '%testing%'
			AND l.leaguename NOT LIKE '%specials%'
			AND l.leaguename NOT LIKE '%1st quarter%'
			AND l.leaguename NOT LIKE '%2nd quarter%'
			AND l.leaguename NOT LIKE '%3rd quarter%'
			AND l.leaguename NOT LIKE '%4th quarter%'
			AND l.leaguename NOT LIKE '%2nd half%'
			AND l.leaguename NOT LIKE '%first%'
			AND l.leaguename NOT LIKE '%last%'
			AND l.leaguename NOT LIKE '%total points%'
			AND l.leaguename NOT LIKE '%total rebounds%'
			AND l.leaguename NOT LIKE '%series winner%'
			AND l.leaguename NOT LIKE '%running ball%'
			AND l.leaguename NOT LIKE '%fantasy match%')
			OR 
			( l.sporttype = 3
			AND l.leaguename NOT LIKE '%no use%'
			AND l.leaguename NOT LIKE '%wrong%'
			AND l.leaguename NOT LIKE '%betting prohibited area%'
			AND l.leaguename NOT LIKE '%testing%'
			AND l.leaguename NOT LIKE '%specials%'
			AND l.leaguename NOT LIKE '%1st quarter%'
			AND l.leaguename NOT LIKE '%2nd quarter%'
			AND l.leaguename NOT LIKE '%3rd quarter%'
			AND l.leaguename NOT LIKE '%4th quarter%'
			AND l.leaguename NOT LIKE '%2nd half%'
			AND l.leaguename NOT LIKE '%first%'
			AND l.leaguename NOT LIKE '%last%'
			AND l.leaguename NOT LIKE '%longest%'
			AND l.leaguename NOT LIKE '%highest scoring%'
			AND l.leaguename NOT LIKE '%which team%'
			AND l.leaguename NOT LIKE '%(total%'
			AND l.leaguename NOT LIKE '%most valuable player%'
			AND l.leaguename NOT LIKE '%winning margin%')
			OR 
			( l.sporttype = 4
			AND l.leaguename NOT LIKE '%no use%'
			AND l.leaguename NOT LIKE '%wrong%'
			AND l.leaguename NOT LIKE '%betting prohibited area%'
			AND l.leaguename NOT LIKE '%testing%'
			AND l.leaguename NOT LIKE '%specials%'
			AND l.leaguename NOT LIKE '%Including OT and Penalty Shootouts%'
			AND l.leaguename NOT LIKE '%OT not included%'
			AND l.leaguename NOT LIKE '%1st period%'
			AND l.leaguename NOT LIKE '%2nd period%'
			AND l.leaguename NOT LIKE '%1st-period%'
			AND l.leaguename NOT LIKE '%2nd-period%'
			AND l.leaguename NOT LIKE '%3rd period%'
			AND l.leaguename NOT LIKE '%overtime%'
			AND l.leaguename NOT LIKE '%penalty%'
			AND l.leaguename NOT LIKE '%extra time%')
			OR 
			( l.sporttype = 5
			AND l.leaguename NOT LIKE '%no use%'
			AND l.leaguename NOT LIKE '%wrong%'
			AND l.leaguename NOT LIKE '%betting prohibited area%'
			AND l.leaguename NOT LIKE '%testing%'
			AND l.leaguename NOT LIKE '%specials%'
			AND l.leaguename NOT LIKE '%first ace%'
			AND l.leaguename NOT LIKE '%first double fault%'
			AND l.leaguename NOT LIKE '%most aces%'
			AND l.leaguename NOT LIKE '%most double fault%'
			AND l.leaguename NOT LIKE '%game winner%'
			AND l.leaguename NOT LIKE '%set winner%'
			AND l.leaguename NOT LIKE '%game handicap%'
			AND l.leaguename NOT LIKE '%correct score%')
			OR 
			( l.sporttype = 6
			AND l.leaguename NOT LIKE '%no use%'
			AND l.leaguename NOT LIKE '%wrong%'
			AND l.leaguename NOT LIKE '%betting prohibited area%'
			AND l.leaguename NOT LIKE '%testing%'
			AND l.leaguename NOT LIKE '%specials%'
			AND l.leaguename NOT LIKE '%point handicap%'
			AND l.leaguename NOT LIKE '%points handicap%'
			AND l.leaguename NOT LIKE '%set winner%')
			OR 
			( l.sporttype = 7
			AND l.leaguename NOT LIKE '%no use%'
			AND l.leaguename NOT LIKE '%wrong%'
			AND l.leaguename NOT LIKE '%betting prohibited area%'
			AND l.leaguename NOT LIKE '%testing%'
			AND l.leaguename NOT LIKE '%specials%'
			AND l.leaguename NOT LIKE '%(frame winner)%'
			AND l.leaguename NOT LIKE '%(1st frame)%')
			OR 
			( l.sporttype = 8
			AND l.leaguename NOT LIKE '%no use%'
			AND l.leaguename NOT LIKE '%wrong%'
			AND l.leaguename NOT LIKE '%betting prohibited area%'
			AND l.leaguename NOT LIKE '%testing%'
			AND l.leaguename NOT LIKE '%specials%'
			AND l.leaguename NOT LIKE '%inning%')
			OR 
			( l.sporttype = 9
			AND (l.leaguename LIKE '%winner' 
					OR l.leaguename LIKE '%set handicap%')
					)
			OR 
			( l.sporttype = 10
			AND l.leaguename NOT LIKE '%no use%'
			AND l.leaguename NOT LIKE '%wrong%'
			AND l.leaguename NOT LIKE '%betting prohibited area%'
			AND l.leaguename NOT LIKE '%testing%'
			AND l.leaguename NOT LIKE '%specials%'
			AND l.leaguename NOT LIKE '%round%')
			OR 
			( l.sporttype = 11
			AND l.leaguename NOT LIKE '%no use%'
			AND l.leaguename NOT LIKE '%wrong%'
			AND l.leaguename NOT LIKE '%betting prohibited area%'
			AND l.leaguename NOT LIKE '%testing%'
			AND l.leaguename NOT LIKE '%specials%')
			OR 
			( l.sporttype = 12
			AND l.leaguename NOT LIKE '%no use%'
			AND l.leaguename NOT LIKE '%wrong%'
			AND l.leaguename NOT LIKE '%betting prohibited area%'
			AND l.leaguename NOT LIKE '%testing%'
			AND l.leaguename NOT LIKE '%specials%')
			OR 
			( l.sporttype = 13
			AND l.leaguename NOT LIKE '%no use%'
			AND l.leaguename NOT LIKE '%wrong%'
			AND l.leaguename NOT LIKE '%betting prohibited area%'
			AND l.leaguename NOT LIKE '%testing%'
			AND l.leaguename NOT LIKE '%specials%')

			OR ( l.sporttype = 14
			AND l.leaguename NOT LIKE '%no use%'
			AND l.leaguename NOT LIKE '%wrong%'
			AND l.leaguename NOT LIKE '%betting prohibited area%'
			AND l.leaguename NOT LIKE '%testing%'
			AND l.leaguename NOT LIKE '%specials%')
			OR 
			( l.sporttype = 15
			AND l.leaguename NOT LIKE '%no use%'
			AND l.leaguename NOT LIKE '%wrong%'
			AND l.leaguename NOT LIKE '%betting prohibited area%'
			AND l.leaguename NOT LIKE '%testing%'
			AND l.leaguename NOT LIKE '%specials%')
			OR 
			( l.sporttype = 16
			AND l.leaguename NOT LIKE '%no use%'
			AND l.leaguename NOT LIKE '%wrong%'
			AND l.leaguename NOT LIKE '%betting prohibited area%'
			AND l.leaguename NOT LIKE '%testing%'
			AND l.leaguename NOT LIKE '%specials%'
			AND l.leaguename NOT LIKE '%method of victory%'
			AND l.leaguename NOT LIKE '%total rounds%')
			OR 
			( l.sporttype = 17
			AND l.leaguename NOT LIKE '%no use%'
			AND l.leaguename NOT LIKE '%wrong%'
			AND l.leaguename NOT LIKE '%betting prohibited area%'
			AND l.leaguename NOT LIKE '%testing%'
			AND l.leaguename NOT LIKE '%specials%')
			OR 
			( l.sporttype = 18
			AND l.leaguename NOT LIKE '%no use%'
			AND l.leaguename NOT LIKE '%wrong%'
			AND l.leaguename NOT LIKE '%betting prohibited area%'
			AND l.leaguename NOT LIKE '%testing%'
			AND l.leaguename NOT LIKE '%specials%'
			AND l.leaguename NOT LIKE '%set winner)%')
			OR 
			( l.sporttype = 19
			AND l.leaguename NOT LIKE '%no use%'
			AND l.leaguename NOT LIKE '%wrong%'
			AND l.leaguename NOT LIKE '%betting prohibited area%'
			AND l.leaguename NOT LIKE '%testing%'
			AND l.leaguename NOT LIKE '%specials%')
			OR 
			( l.sporttype = 20
			AND l.leaguename NOT LIKE '%no use%'
			AND l.leaguename NOT LIKE '%wrong%'
			AND l.leaguename NOT LIKE '%betting prohibited area%'
			AND l.leaguename NOT LIKE '%testing%'
			AND l.leaguename NOT LIKE '%specials%')
			OR 
			( l.sporttype = 21
			AND l.leaguename NOT LIKE '%no use%'
			AND l.leaguename NOT LIKE '%wrong%'
			AND l.leaguename NOT LIKE '%betting prohibited area%'
			AND l.leaguename NOT LIKE '%testing%'
			AND l.leaguename NOT LIKE '%specials%')
			OR 
			( l.sporttype = 22
			AND l.leaguename NOT LIKE '%no use%'
			AND l.leaguename NOT LIKE '%wrong%'
			AND l.leaguename NOT LIKE '%betting prohibited area%'
			AND l.leaguename NOT LIKE '%testing%'
			AND l.leaguename NOT LIKE '%specials%')
			OR
			( l.sporttype = 23
			AND l.leaguename NOT LIKE '%no use%'
			AND l.leaguename NOT LIKE '%wrong%'
			AND l.leaguename NOT LIKE '%betting prohibited area%'
			AND l.leaguename NOT LIKE '%testing%'
			AND l.leaguename NOT LIKE '%specials%')
			OR
			( l.sporttype = 24
			AND l.leaguename NOT LIKE '%no use%'
			AND l.leaguename NOT LIKE '%wrong%'
			AND l.leaguename NOT LIKE '%betting prohibited area%'
			AND l.leaguename NOT LIKE '%testing%'
			AND l.leaguename NOT LIKE '%specials%')
			OR 
			( l.sporttype = 25
			 
			AND l.leaguename LIKE '%best of%')
			OR 
			( l.sporttype = 26
			AND l.leaguename NOT LIKE '%no use%'
			AND l.leaguename NOT LIKE '%wrong%'
			AND l.leaguename NOT LIKE '%betting prohibited area%'
			AND l.leaguename NOT LIKE '%testing%'
			AND l.leaguename NOT LIKE '%specials%'
			AND l.leaguename NOT LIKE '%which team%')
			OR
			( l.sporttype in (27,50)
			AND l.leaguename NOT LIKE '%no use%'
			AND l.leaguename NOT LIKE '%wrong%'
			AND l.leaguename NOT LIKE '%betting prohibited area%'
			AND l.leaguename NOT LIKE '%testing%'
			AND l.leaguename NOT LIKE '%specials%'
			AND l.leaguename NOT LIKE '%inning%'
			AND l.leaguename NOT LIKE '%total runs%'
			AND l.leaguename NOT LIKE '%most runs%'
			AND l.leaguename NOT LIKE '%most sixes%'
			AND l.leaguename NOT LIKE '%highest%')
			OR
			( l.sporttype = 28
			AND l.leaguename NOT LIKE '%no use%'
			AND l.leaguename NOT LIKE '%wrong%'
			AND l.leaguename NOT LIKE '%betting prohibited area%'
			AND l.leaguename NOT LIKE '%testing%'
			AND l.leaguename NOT LIKE '%specials%'
			AND l.leaguename NOT LIKE '%1st half%'
			AND l.leaguename NOT LIKE '%extra time%'
			AND l.leaguename NOT LIKE '%penalty%')
			OR 
			( l.sporttype = 29
			AND l.leaguename NOT LIKE '%no use%'
			AND l.leaguename NOT LIKE '%wrong%'
			AND l.leaguename NOT LIKE '%betting prohibited area%'
			AND l.leaguename NOT LIKE '%testing%'
			AND l.leaguename NOT LIKE '%specials%')
			OR 
			( l.sporttype = 30
			AND l.leaguename NOT LIKE '%no use%'
			AND l.leaguename NOT LIKE '%wrong%'
			AND l.leaguename NOT LIKE '%betting prohibited area%'
			AND l.leaguename NOT LIKE '%testing%'
			AND l.leaguename NOT LIKE '%specials%')
			OR 
			( l.sporttype = 31
			AND l.leaguename NOT LIKE '%no use%'
			AND l.leaguename NOT LIKE '%wrong%'
			AND l.leaguename NOT LIKE '%betting prohibited area%'
			AND l.leaguename NOT LIKE '%testing%'
			AND l.leaguename NOT LIKE '%specials%')
			OR
			( l.sporttype = 32
			AND l.leaguename NOT LIKE '%no use%'
			AND l.leaguename NOT LIKE '%wrong%'
			AND l.leaguename NOT LIKE '%betting prohibited area%'
			AND l.leaguename NOT LIKE '%testing%'
			AND l.leaguename NOT LIKE '%specials%'
			AND l.leaguename NOT LIKE '%quarter)%')
			OR
			( l.sporttype = 33
			AND l.leaguename NOT LIKE '%no use%'
			AND l.leaguename NOT LIKE '%wrong%'
			AND l.leaguename NOT LIKE '%betting prohibited area%'
			AND l.leaguename NOT LIKE '%testing%'
			AND l.leaguename NOT LIKE '%specials%'
			AND l.leaguename NOT LIKE '%quarter)%')
			OR
			( l.sporttype = 34
			AND l.leaguename NOT LIKE '%no use%'
			AND l.leaguename NOT LIKE '%wrong%'
			AND l.leaguename NOT LIKE '%betting prohibited area%'
			AND l.leaguename NOT LIKE '%testing%'
			AND l.leaguename NOT LIKE '%specials%')
			OR 
			( l.sporttype = 35
			AND l.leaguename NOT LIKE '%no use%'
			AND l.leaguename NOT LIKE '%wrong%'
			AND l.leaguename NOT LIKE '%betting prohibited area%'
			AND l.leaguename NOT LIKE '%testing%'
			AND l.leaguename NOT LIKE '%specials%')
			OR 
			( l.sporttype = 36
			AND l.leaguename NOT LIKE '%no use%'
			AND l.leaguename NOT LIKE '%wrong%'
			AND l.leaguename NOT LIKE '%betting prohibited area%'
			AND l.leaguename NOT LIKE '%testing%'
			AND l.leaguename NOT LIKE '%specials%')
			OR 
			( l.sporttype = 37
			AND l.leaguename NOT LIKE '%no use%'
			AND l.leaguename NOT LIKE '%wrong%'
			AND l.leaguename NOT LIKE '%betting prohibited area%'
			AND l.leaguename NOT LIKE '%testing%'
			AND l.leaguename NOT LIKE '%specials%')
			OR 
			( l.sporttype = 38
			AND l.leaguename NOT LIKE '%no use%'
			AND l.leaguename NOT LIKE '%wrong%'
			AND l.leaguename NOT LIKE '%betting prohibited area%'
			AND l.leaguename NOT LIKE '%testing%'
			AND l.leaguename NOT LIKE '%specials%')
			OR 
			( l.sporttype = 39
			AND l.leaguename NOT LIKE '%no use%'
			AND l.leaguename NOT LIKE '%wrong%'
			AND l.leaguename NOT LIKE '%betting prohibited area%'
			AND l.leaguename NOT LIKE '%testing%'
			AND l.leaguename NOT LIKE '%specials%')
			OR 
			( l.sporttype = 40
			AND l.leaguename NOT LIKE '%no use%'
			AND l.leaguename NOT LIKE '%wrong%'
			AND l.leaguename NOT LIKE '%betting prohibited area%'
			AND l.leaguename NOT LIKE '%testing%'
			AND l.leaguename NOT LIKE '%specials%')
			OR 
			( l.sporttype = 41
			AND l.leaguename NOT LIKE '%no use%'
			AND l.leaguename NOT LIKE '%wrong%'
			AND l.leaguename NOT LIKE '%betting prohibited area%'
			AND l.leaguename NOT LIKE '%testing%'
			AND l.leaguename NOT LIKE '%specials%')
			OR 
			( l.sporttype = 42
			AND l.leaguename NOT LIKE '%no use%'
			AND l.leaguename NOT LIKE '%wrong%'
			AND l.leaguename NOT LIKE '%betting prohibited area%'
			AND l.leaguename NOT LIKE '%testing%'
			AND l.leaguename NOT LIKE '%specials%')
			OR 
			(l.sporttype = 43
			AND l.leaguename NOT LIKE '%no use%'
			AND l.leaguename NOT LIKE '%wrong%'
			AND l.leaguename NOT LIKE '%betting prohibited area%'
			AND l.leaguename NOT LIKE '%testing%'
			AND l.leaguename NOT LIKE '%specials%'
			AND l.leaguename NOT LIKE '%pistol round)%'
			AND l.leaguename NOT LIKE '%(First%'
			AND l.leaguename NOT LIKE '%(Which%'
			AND l.leaguename NOT LIKE '%head to head%'
			AND l.leaguename NOT LIKE '%game duration%'
			AND l.leaguename NOT LIKE '%total kills%')
			OR 
			( l.sporttype = 44
			AND l.leaguename NOT LIKE '%no use%'
			AND l.leaguename NOT LIKE '%wrong%'
			AND l.leaguename NOT LIKE '%betting prohibited area%'
			AND l.leaguename NOT LIKE '%testing%'
			AND l.leaguename NOT LIKE '%specials%'
			AND l.leaguename NOT LIKE '%total rounds%')
			OR 
			( l.sporttype = 99
			AND l.leaguename NOT LIKE '%no use%'
			AND l.leaguename NOT LIKE '%wrong%'
			AND l.leaguename NOT LIKE '%betting prohibited area%'
			AND l.leaguename NOT LIKE '%testing%'
			AND l.leaguename NOT LIKE '%specials%'
			AND l.leaguename NOT LIKE '%period%'
			AND l.leaguename NOT LIKE '%point handicap%'
			)
		)

 --select * from [view_LiveMatch_LeagueEx]
 

GO


GO 
 GRANT VIEW DEFINITION ON [dbo].[view_LiveMatch_LeagueEx] TO [vnteam]
GO 
 GRANT SELECT ON [dbo].[view_LiveMatch_LeagueEx] TO [bodbLicenseeNet]
GO 