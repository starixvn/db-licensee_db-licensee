/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_MatchSelResultEntered] 
	@isShowAll BIT = 1, -- 1: Show All; 0: is NOT show Test
	@LicenseeID INT=0
AS /*
Created: 20101201@Jacob
Task : 
DB: DB052.bodb02
Original:Age_Rpt_MatchSelResultEntered
Revisions:
    - 20101201@Jacob: Copy source code from Age_Rpt_MatchSelResultEntered
    - 20110308@Henry: add more sporttype Greyhound Racing(152), Harness Racing (153) 
    - 20110427@Lukas: add Netball game (sporttype = 32)  
    - 20110525@Henry: Change the way to get data
    - 20120906@Henry: fix bug
    - 20121220@Henry: only show Sports by Licensee
	- 20130809@Jim: offer Virtual Horse Racing
	- 20161115@Jim: LRF - Integrate new product Fishing World [RedmineID : #66737]
	- 20170627@Harper: LRF - Integrate new product Betradar Virtual Sports [RedmineID: #78241]
	- 20180129@Harper: Remove LC from product list [RedmineID: #85965]
	- 20180807@Amanda: Remove Racing [RedmineID: #99378]
	- 20181210@Joseph: Integrate Happy 5 for NumberGame [RedmineID: #103698]
	- 20230928@Evan: Integrate Virtual Sports 3 (Leap Gaming New) [RedmineID: #190908]
	- 20231206@Evan: Integrate VS3 Sport 179 [RedmineID: #190908]
	- 20241701@Evan: Merge VS, VS2, VS3 as VS only [RedmineID: #199523]
	- 20242901@Evan: Integrate VS4 (add missing sportid VS3) [RedmineID: #199347]
	- 20241001@Kelvin: LAP - Integrate BetRadar Virtual Horses & Dogs Racing [RedmineID: #210808]
	- 20241024@Kelvin: LAP - Integrate Betby (VS6) [RedmineID: #212446]
*/

BEGIN
	SET NOCOUNT ON

	SELECT @isShowAll =
					   CASE @isShowAll
						   WHEN 1 THEN NULL
						   ELSE 0
					   END

	DECLARE @FromDate DATETIME
		  , @ToDate DATETIME
	SELECT @ToDate = CONVERT(DATETIME, CONVERT(NVARCHAR(20), GETDATE(), 101))
	SELECT @FromDate = DATEADD(dd, -1, @ToDate)

	DECLARE @Result AS TABLE (
		  IsToday INT
		, EventDate SMALLDATETIME
		, Sporttype INT
		, Entered INT
		, NonEntered INT
	)

	DECLARE @ExcludedBetType AS TABLE (SportType smallint)

	IF @LicenseeID <> 0
	BEGIN	
		--Exclude NG-Number Game
		IF NOT EXISTS (SELECT 1 FROM bodb_licensee.dbo.LicenseeProduct3rd WITH (NOLOCK) WHERE LicenseeID = @LicenseeID AND ProductID = 2)
		BEGIN
			INSERT INTO @ExcludedBetType (SportType)
			SELECT distinct SportType FROM dbo.SportBettypeMatrix WITH(NOLOCK) WHERE ProductID = 3
		END

		--Exclude VS-Virtual Sports
		IF NOT EXISTS (SELECT 1 FROM bodb_licensee.dbo.LicenseeProduct3rd WITH (NOLOCK) WHERE LicenseeID = @LicenseeID AND ProductID = 5)
		BEGIN
			INSERT INTO @ExcludedBetType (SportType)
			SELECT distinct b.SportType
			FROM dbo.SportBettypeMatrix b WITH(NOLOCK) 
				JOIN dbo.Lrf_f_GroupProduct() f ON f.GroupProductId = 5 AND f.ProductId = b.ProductID
		END
	END
			
	--Match
	INSERT INTO @Result (IsToday, EventDate, Sporttype, Entered, NonEntered)
	SELECT DATEDIFF(dd, @FromDate, m.eventdate) AS IsToday
		 , m.eventdate
		 , l.sporttype
		 , SUM(CASE WHEN m.eventstatus IN ('completed', 'refund') THEN 1 ELSE 0 END) AS Entered
		 , SUM(CASE WHEN m.eventstatus NOT IN ('completed', 'refund') THEN 1 ELSE 0 END) AS NonEntered
	FROM dbo.Match m 
		INNER JOIN dbo.League l WITH(NOLOCK) 
			ON m.leagueid = l.leagueid AND l.isTest = ISNULL(@isShowAll, l.isTest)
	WHERE m.eventdate BETWEEN @FromDate AND @ToDate
		AND m.eventstatus <> 'closed'		
		AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType b WHERE b.SportType = l.sporttype)
	GROUP BY m.eventdate, l.sporttype

	--VSRaceInfo/VSOutright
	INSERT INTO @Result (IsToday, EventDate, Sporttype, Entered, NonEntered)
	SELECT DATEDIFF(dd, @FromDate, EventDate) AS IsToday
		 , m.EventDate
		 , m.SportType
		 , SUM(CASE WHEN m.EventStatus = 'completed' AND m.BetStatus <> 'refund' THEN 1 ELSE 0 END) AS Entered
		 , SUM(CASE WHEN m.EventStatus <> 'completed' THEN 1 ELSE 0 END) AS NonEntered
	FROM 
	( 
		SELECT o.EventDate, r.SportType, MAX(r.EventStatus) AS EventStatus, MAX(r.BetStatus) AS BetStatus  
		FROM dbo.VSRaceInfo r WITH (NOLOCK)
			INNER JOIN dbo.VSOutright o WITH (NOLOCK) 
				ON r.EventID = o.EventID
			INNER JOIN dbo.League3rd l WITH(NOLOCK) 
				ON r.LeagueID = l.League3rdId AND l.IsTest = ISNULL(@isShowAll, l.IsTest)
		WHERE o.EventDate BETWEEN @FromDate AND @ToDate
			AND r.EventStatus <> 'closed'
			AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType b WHERE b.SportType = r.SportType)
		GROUP BY r.EventID, o.EventDate, r.SportType
	) m
	GROUP BY m.EventDate, m.SportType

	--Match3rd
	INSERT INTO @Result (IsToday, EventDate, Sporttype, Entered, NonEntered)
	SELECT DATEDIFF(dd, @FromDate, EventDate) AS IsToday
		 , EventDate
		 , m.SportType
		 , SUM(CASE WHEN EventStatus IN ('completed') THEN 1 ELSE 0 END) AS Entered
		 , SUM(CASE WHEN EventStatus NOT IN ('completed') THEN 1 ELSE 0 END) AS NonEntered
	FROM dbo.Match3rd m WITH (NOLOCK)
	WHERE m.EventDate BETWEEN @FromDate AND @ToDate
		AND m.EventStatus <> 'closed'
		AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType b WHERE b.SportType = m.SportType)
	GROUP BY EventDate, m.SportType

	SELECT IsToday, EventDate, Sporttype, Entered, NonEntered
	FROM @Result
	ORDER BY EventDate, Sporttype

END
 
GO