CREATE PROCEDURE [dbo].[Task_Licensee_ClearLogin_Loop]  
AS  
/*
	Created:  20101209@Henry
	Task: Clear Login
	DB: DB052.bodb_Licensee
	Original SP:
	
	Revisions:
		
*/
SET NOCOUNT ON
 DECLARE @start DATETIME  
 SELECT @start = CURRENT_TIMESTAMP  
  
 WHILE (1=1) AND (DATEDIFF(minute,@start, CURRENT_TIMESTAMP) < 20)  
 BEGIN  
  EXEC Task_Licensee_ClearLogin  
  WAITFOR DELAY '00:00:30'  
 END  
 
 GO
GRANT VIEW DEFINITION ON [dbo].[Task_Licensee_ClearLogin_Loop] TO [vnteam] 