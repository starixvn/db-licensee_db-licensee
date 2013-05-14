CREATE PROCEDURE [dbo].[Task_Licensee_ClearLogin]
	
AS

/*
	Created:  20101209@Henry
	Task: Clear Login
	DB: DB052.bodb_Licensee
	Original SP:
	
	Revisions:
		
*/
SET NOCOUNT ON
DELETE FROM On_User with (updlock)
WHERE        
reload_time < dateadd(minute,-30,CURRENT_TIMESTAMP) AND (ServerID IN (200,201))

GO
GRANT VIEW DEFINITION ON [dbo].[Task_Licensee_ClearLogin] TO [vnteam] 