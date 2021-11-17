ALTER  PROCEDURE [dbo].[Acc_BA_MatchSel]
	@tstamp timestamp = NULL
/*
	Created by: [20120220@Henry]
	Task: Get List of all match 
	DB: DB052.bodb02
	Revisions:
*/
AS
SET NOCOUNT ON

SELECT 
	matchid,leagueid,homeid,awayid,eventdate,eventstatus,livehomescore,liveawayscore,finalhomescore,finalawayscore,kickofftime,closedtime,hthomescore,htawayscore,sporttype,
	tstamp
FROM match WITH (NOLOCK)
WHERE @tstamp IS NULL OR (@tstamp IS NOT NULL AND tstamp > @tstamp)
	

GO
GRANT EXECUTE ON [dbo].[Acc_BA_MatchSel] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_BA_MatchSel] TO [vnteam]

 