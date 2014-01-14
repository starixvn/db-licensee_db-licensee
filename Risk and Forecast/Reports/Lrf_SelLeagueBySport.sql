USE [bodb_licensee]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_SelLeagueBySport_8828]    Script Date: 10/01/2014 9:09:43 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [dbo].[Lrf_SelLeagueBySport]
	@LicenseeID int,
	@sportId INT 
	,@Fromdate SMALLDATETIME
	,@Todate SMALLDATETIME
AS 
/*
Created: 20140102@Florent
Task : Get LeagueID from sport type
DB: DBLIC/bodb_Licensee

Revisions:
Param's Explanation:	
*/

SET NOCOUNT ON
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tblLeagueid (leagueid INT)
	CREATE TABLE #tblReturn (leagueid INT, sportid SMALLINT) 
 
	DECLARE @f DATETIME, @t DATETIME,@TempFromDate DATETIME ,@TempToDate DATETIME,@MoveBetsDay DATETIME
	
	SELECT @MoveBetsDay = MAX(eventdate)  
	FROM bodb02.dbo.match14 WITH(NOLOCK) 

	SET @f = @Fromdate
	SET @t = @Todate
	
	IF @t > @MoveBetsDay
		BEGIN
			IF @FromDate <= @MoveBetsDay 
				SET @TempFromDate =  DATEADD(DAY,1,@MoveBetsDay)
			ELSE
				SET @TempFromDate = @f
				
			INSERT INTO #tblLeagueid
			SELECT m.leagueid
			FROM bodb02.dbo.match AS m WITH (NOLOCK)
			WHERE m.eventdate BETWEEN @TempFromDate AND @t 			
		END 
	IF @f <= @MoveBetsDay
		BEGIN
			IF @t >= @MoveBetsDay
				SET @TempToDate = @MoveBetsDay
			ELSE
				SET  @TempToDate = @t				
		INSERT INTO #tblLeagueid		
		SELECT leagueid
		FROM bodb_LicenseeReport.dbo.rptWinlostbyLeague AS rwl WITH (NOLOCK)
		WHERE rwl.winlostdate BETWEEN @f AND @TempToDate
		END 
		
	INSERT INTO #tblReturn
	SELECT DISTINCT l.leagueid,l.sporttype
	FROM #tblLeagueid m
		INNER JOIN bodb02.dbo.League AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
	WHERE ((@sportId = 0) OR (l.sporttype = @sportId) )
		AND l.sporttype < 100

	SELECT leagueid,sportid
	FROM #tblReturn 
	WHERE leagueid>0
		
	DROP TABLE #tblReturn
	DROP TABLE #tblLeagueid
END 

GO
GRANT EXECUTE ON [dbo].[Lrf_SelLeagueBySport] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_SelLeagueBySport] TO [vnteam] AS [dbo]
GO