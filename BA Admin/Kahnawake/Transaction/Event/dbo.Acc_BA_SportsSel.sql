ALTER  PROCEDURE [dbo].[Acc_BA_SportsSel]
/*
	Created by: [20120220@Henry]
	Task: Get List of all sports 
	DB: DB052.bodb02
	Revisions:
	
*/
AS
SET NOCOUNT ON

SELECT 
	Sporttype, SportName
FROM Sports WITH (NOLOCK)

GO
GRANT EXECUTE ON [dbo].[Acc_BA_SportsSel] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_BA_SportsSel] TO [vnteam]

  