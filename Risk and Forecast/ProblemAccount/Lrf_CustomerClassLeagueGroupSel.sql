/*<info serverAlias="DBACC-bodb02" executers="wsv_lap" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE Lrf_CustomerClassLeagueGroupSel
	@SportType SMALLINT = 0,
	@LeagueGroupID VARCHAR(MAX) = ''

AS
	/*
		Created: 20241017@Winfred
		Task: Risk Level Bet Setting - Show league group info 
		DB: DBACC-bodb02
		
		Revisions:
			- 20241017@Winfred: LAP - Risk Level Bet Setting - Show league group info [redmine:#211952]
	*/
BEGIN
	SET NOCOUNT ON

	SELECT  lg.GroupID AS LeagueGroupID, kq.leagueid, kq.leaguename
	FROM LeagueGroup AS lg WITH(NOLOCK) 
		CROSS APPLY (
			SELECT VALUE AS LeagueGroupID 
			FROM STRING_SPLIT(@LeagueGroupID,',') WHERE lg.GroupID = CAST(VALUE AS SMALLINT) AND  
			VALUE <> ''
		) a
		CROSS APPLY (
			SELECT l.leagueid, l.leaguename
			FROM league l WITH(NOLOCK)
			WHERE lg.GroupID = l.LeagueGroupID AND l.IsActive = 1 AND l.isTest =0 
					AND l.sporttype = CASE WHEN @SportType = 9901 THEN 1 
										   WHEN @SportType = 9902 THEN 2 ELSE  @SportType END
		) kq
	
	WHERE 1 = CASE WHEN @SportType NOT IN (9901, 9902, 1, 2) AND lg.SportType IN (0, @SportType) THEN 1
				 WHEN @SportType = 1 AND lg.GroupID NOT IN (42, 74, 108) AND lg.SportType IN (0, @SportType) THEN 1
				 WHEN @SportType = 2 AND lg.GroupID NOT IN (42) AND lg.SportType IN (0, @SportType) THEN 1
				 WHEN @SportType = 9901 AND lg.GroupID IN (42, 74, 108) THEN 1
				 WHEN @SportType = 9902 AND lg.GroupID IN (42) THEN 1
			ELSE 0 END
END
