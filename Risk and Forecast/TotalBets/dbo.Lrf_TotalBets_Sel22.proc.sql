CREATE PROCEDURE [dbo].[Lrf_TotalBets_Sel22]
	@custid INT,
	@PageSize INT=50,
	@PageIndex INT=0,
	@TotalRows INT=0 OUTPUT
	
AS
/*
Created: 20101201@Henry
Task : Total bets for next goal bettype
DB: DB052.bodb02
Original: [Age_TotalBets_Sel22_Ag]

Param's Explanation:
• @CustID: agentID

Revisions:
Not use anymore


*/
SET NOCOUNT ON

DECLARE @RowCount INT, @RowStart INT, @RowEnd INT  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 

DECLARE @Data as TABLE
(
	goalrecord VARCHAR(50),
	showtime nvarchar (50),
	leagueid INT,
	matchid INT,
	homeID INT,
	awayID INT,
	isNeutral BIT,
	livehomescore INT,
	liveawayscore INT,
	home_total MONEY,
	away_total MONEY,
	winlost MONEY
)

INSERT INTO @Data
	SELECT 
		goalrecord, 
		showtime, 
		leagueid,	
		matchid,	
		homeid,
		awayid,
		IsNeutral,
		livehomescore,
		liveawayscore,
		sum(home_total) as home_total,
		sum(away_total) as away_total,
		sum(CASE
				WHEN modds >  0.25	THEN stake * (CASE WHEN odds<0 THEN 1 ELSE odds END) * -apositiontaking
				WHEN modds =  0.25	THEN stake * (CASE WHEN odds<0 THEN 1 ELSE odds END) * -apositiontaking * 0.5
				WHEN modds =  0	THEN 0
				WHEN modds = -0.25	THEN actual_stake * apositiontaking * 0.5
				WHEN modds < -0.25	THEN actual_stake * apositiontaking
			END) as winlost
	FROM
	(
		SELECT
			m.goalrecord,  
			m.showtime, 
			m.leagueid,	
			m.matchid,	
			m.homeid,
			m.awayid,
			b.livehomescore,
			b.liveawayscore,
			b.stake, b.actual_stake, b.apositiontaking, b.odds,b.bettype,
			CASE WHEN betteam = 'h' THEN (b.apositiontaking)* stake * (CASE WHEN abs(odds) <1 THEN 1 ELSE abs(odds) END) ELSE 0 END AS home_total,
			CASE WHEN betteam = 'a' THEN (b.apositiontaking)* stake * (CASE WHEN abs(odds) <1 THEN 1 ELSE abs(odds) END) ELSE 0 END AS away_total,

			CASE SUBSTRING(isnull(GoalRecord,''), b.livehomescore + b.liveawayscore + 1, 1)
				WHEN N'' THEN 0 -- Not have next goal = draw (refund)
				WHEN betteam THEN 1 + CASE betteam 
										WHEN N'h' THEN (hdp2-hdp1) -- collect choose = win
										WHEN N'a' THEN (hdp1-hdp2)
										END 
				ELSE -1 + CASE betteam -- other CASE = lose
							WHEN N'h' THEN (hdp2-hdp1)
							WHEN N'a' THEN (hdp1-hdp2)
							END 
				END as modds,
			isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral
		FROM
			bettrans b WITH(NOLOCK)
			INNER JOIN match m WITH (NOLOCK) ON m.matchid = b.matchid 
		WHERE 
			b.recommend = @custid AND
			m.eventstatus = 'running'  AND
			b.bettype = 22 AND
			b.ruben=0 AND
			b.liveindicator=1
	) a
	GROUP BY
		homeid,
		awayid,
		matchid,		
		leagueid,	
		livehomescore,
		liveawayscore,
		goalrecord,
		showtime,
		isNeutral
	ORDER BY
	matchid,livehomescore + liveawayscore desc

IF @TotalRows = 0  
BEGIN  
	SELECT @TotalRows = count(matchid) FROM @Data
	
END

SELECT c.* FROM
(
	SELECT 
		ROW_NUMBER() over (order by matchid,livehomescore + liveawayscore desc) as RowNum ,
		*
	FROM @Data
) c WHERE c.RowNum between @RowStart AND @RowEnd

GO
GRANT EXECUTE ON [dbo].[Lrf_TotalBets_Sel22] TO [bodbLicenseeNet]

GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_TotalBets_Sel22] TO [vnteam]


