ALTER  PROCEDURE [dbo].[Acc_BA_TeamSel]
@tstamp timestamp = NULL
/*
	Created by: [20120220@Henry]
	Task: Get List of all team 
	DB: DB052.bodb02
	Revisions:
	
*/ 
AS
SET NOCOUNT ON

SELECT 
	Teamid,TeamName,Sporttype
FROM Team WITH (NOLOCK)
WHERE @tstamp IS NULL OR (@tstamp IS NOT NULL AND tstamp > @tstamp)
ORDER BY Teamid ASC

GO
GRANT EXECUTE ON [dbo].[Acc_BA_TeamSel] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_BA_TeamSel] TO [vnteam]

   