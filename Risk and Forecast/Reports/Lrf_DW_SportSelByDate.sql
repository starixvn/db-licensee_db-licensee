ALTER PROCEDURE Lrf_DW_SportSelByDate
	@FromDate SMALLDATETIME,
	@ToDate SMALLDATETIME,
	@BalanceUpDay SMALLDATETIME
	
AS
/*
Created: 20110329@Henry
Task:
DB: DB06.bodb02
Original: 
Revisions:
    Daniel@20110601: Add Number Game
	
*/

SET NOCOUNT ON

DECLARE @TempFromDate DATETIME
DECLARE @TempToDate DATETIME

DECLARE @Temp as Table (sporttype INT, sportname nvarchar(50))

IF @Todate > @BalanceUpDay
BEGIN
	if @FromDate < @BalanceUpDay 
		SET @TempFromDate = @BalanceUpDay
	ELSE
		SET @TempFromDate = @FromDate

	Insert into @Temp (sporttype,sportname)
	SELECT distinct sports.sporttype, sportname from sports with (nolock)
	inner join (
	SELECT matchid, eventdate, eventstatus, sporttype
	from match (nolock)
	UNION ALL
	SELECT matchid, eventdate, eventstatus, sporttype
	from match14 (nolock)
	) match on match.sporttype = sports.sporttype
    WHERE
	    match.eventdate >= @TempFromDate
	    AND match.eventdate <= @ToDate
	    AND match.eventstatus not in ('internal','closed','running')
	    AND (sports.sporttype < 99 or sports.sporttype = 161)
    order by sports.sporttype
END

IF @FromDate < @BalanceUpDay 
BEGIN
	if @ToDate >= DATEADD(dd, -1, @BalanceUpDay)
		SET @TempToDate = DATEADD(dd, -1, @BalanceUpDay)
	ELSE
		SET @TempToDate = @ToDate

	Insert into @Temp (sporttype,sportname)
	SELECT 
		distinct sports.sporttype, sportname 
	from 
		sports with (nolock)
	inner join 
		bodb_archive.dbo.match_BK match (nolock) on match.sporttype = sports.sporttype
	WHERE
		match.eventdate >= @FromDate
		AND match.eventdate <= @TempToDate
		AND match.eventstatus not in ('internal','closed','running')
    	AND (sports.sporttype < 99 or sports.sporttype = 161)
	order by sports.sporttype

END

SELECT distinct sporttype,sportname  from @Temp
order by sporttype, sportname

GO
GRANT EXECUTE ON [dbo].Lrf_DW_SportSelByDate TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].Lrf_DW_SportSelByDate TO [vnteam]
GO



