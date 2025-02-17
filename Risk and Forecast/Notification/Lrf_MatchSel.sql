/*<info serverAlias="DBACC-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_MatchSel]
	@MatchId		INT,
	@EventDate		DATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME
AS

/*
	Created by: Kai
	Date: 2025-02-10
	Task: OIC - Move Result Amendment to DBOIC.bodb_OIC db054/db055
	DB: DBACC.bodb02

	Revisions:
		- 20250210@Kai: Move Result Amendment to DBOIC.bodb_OIC db054/db055 - [RedmineId: #217146]
*/

BEGIN
	SET NOCOUNT ON

    DECLARE @tblMatch TABLE (
		MatchId		INT,
		IsNeutral	BIT,
		MatchCode	NVARCHAR(50),
		SportType	SMALLINT,
		AwayId		INT,
		HomeId		INT)

    -- Match Info
	IF(@EventDate > @MoveBetsDay) 
	BEGIN
        INSERT INTO @tblMatch
		SELECT 
            m.matchid,
            m.IsNeutral,
            m.matchcode,
            m.sporttype,
            m.awayid,
            m.homeid
		FROM dbo.match m WITH(NOLOCK) 
        WHERE m.matchid = @MatchId 
	END
	ELSE IF(@EventDate >= @BalanceUpDay)
	BEGIN
        INSERT INTO @tblMatch
		SELECT 
            m.matchid,
            m.IsNeutral,
            m.matchcode,
            m.sporttype,
            m.awayid,
            m.homeid
		FROM dbo.match14 m WITH(NOLOCK) 
        WHERE m.matchid = @MatchId
		END
	ELSE 
	BEGIN
        INSERT INTO @tblMatch
		SELECT 
            m.matchid,
            m.IsNeutral,
            m.matchcode,
            m.sporttype,
            m.awayid,
            m.homeid 
		FROM bodb_Archive.dbo.match_bk m WITH(NOLOCK) 
        WHERE m.matchid = @MatchId
	END

    SELECT DISTINCT
		m.MatchId,
		m.IsNeutral,
		m.MatchCode,
        m.SportType,
        m.AwayId,
        m.HomeId,
		sbm.ProductId
	FROM @tblMatch AS m 
    INNER JOIN dbo.SportBettypeMatrix AS sbm WITH (NOLOCK) ON sbm.SportType = m.sporttype
	WHERE sbm.ProductID IN (1, 3)

END