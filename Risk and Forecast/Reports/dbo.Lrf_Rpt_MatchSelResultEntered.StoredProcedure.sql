/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

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
*/

	SET NOCOUNT ON
	
	DECLARE @ShowNG BIT, @ShowVS BIT, @ShowVS2 BIT
	
    SELECT  @isShowAll = CASE @isShowAll
                           WHEN 1 THEN NULL
                           ELSE 0
                         END

    DECLARE @FromDate DATETIME ,
        @ToDate DATETIME
    SELECT  @ToDate = CONVERT(DATETIME, CONVERT(NVARCHAR(20), GETDATE(), 101))
    SELECT  @FromDate = DATEADD(dd, -1, @ToDate)
    
    DECLARE @Result AS Table(IsToday INT, EventDate SMALLDATETIME, Sporttype INT, Entered INT, NonEntered INT)

	INSERT INTO @Result (IsToday,EventDate,Sporttype,Entered,NonEntered)
    SELECT  datediff(dd,@FromDate,EventDate ) as IsToday,
			EventDate , 
			sporttype,
            SUM(CASE WHEN eventstatus in ('completed','refund') THEN 1 ELSE 0 END) AS Entered ,  
            SUM(CASE WHEN eventstatus NOT in ('completed','refund')  THEN 1 ELSE 0 END) AS NonEntered 
            
            
    FROM    ( 
				SELECT    LeagueID ,
						EventDate ,
						MAX(EventStatus) AS EventStatus
				FROM      Match WITH ( NOLOCK )
				WHERE     Match.EventDate BETWEEN @FromDate AND @ToDate
						AND Match.eventstatus <> 'closed'
				GROUP BY  leagueid ,
						EventDate ,
						matchid--, awayid
				UNION ALL
				SELECT  r.LeagueID
						,o.EventDate
						,MAX(o.EventStatus)
				FROM VSOutright o WITH (NOLOCK)
					INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
					WHERE o.EventDate BETWEEN @FromDate AND @ToDate
							AND o.EventStatus <> 'closed'	
					GROUP BY r.LeagueID
							,o.EventDate
							,EventTime
            ) AS Match
            INNER JOIN League WITH ( NOLOCK ) ON Match.LeagueID = League.LeagueID
                                                 AND League.isTest = ISNULL(@isShowAll,
                                                              League.isTest)
    GROUP BY EventDate, sporttype
 --   ORDER BY EventDate, sporttype


	IF @LicenseeID <> 0
	BEGIN
		SELECT @ShowNG=0, @ShowVS=0, @ShowVS2=0
	
		IF EXISTS(SELECT 1 FROM bodb_licensee.dbo.LicenseeProduct3rd WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND ProductID=2) SET @ShowNG=1
		IF EXISTS(SELECT 1 FROM bodb_licensee.dbo.LicenseeProduct3rd WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND ProductID=5) SET @ShowVS=1
		IF EXISTS(SELECT 1 FROM bodb_licensee.dbo.LicenseeProduct3rd WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND ProductID=27) SET @ShowVS2=1
		
		IF @ShowNG=0 DELETE FROM @Result WHERE Sporttype = 161
		IF @ShowVS=0 DELETE FROM @Result WHERE Sporttype BETWEEN 180 AND 189
		IF @ShowVS2=0 DELETE FROM @Result WHERE Sporttype BETWEEN 190 AND 199
	END
	DELETE @Result WHERE Sporttype = 219
	
	SELECT * FROM @Result
	ORDER BY EventDate, sporttype

 
GO