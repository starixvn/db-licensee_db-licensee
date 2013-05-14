ALTER PROCEDURE [dbo].[PIH_Users_CheckIn]  
	@CustID   INT,  
	@NetSessionID VARCHAR(30),  
	@On_UserID  INT      OUTPUT,  
	@IP    VARCHAR(15)  = ''  
AS  
  
/*  
 * Created by : [20111512@Kos]  
 * Task  : check in user  
 * DB   : WW100_DB.bodb_PIH @ kahnawake
 * Revisions :  
 *  
 * Param's Explanation:    
 *  - @CustID  : Customer ID  
 *  - @NetSessionID : Net session ID  
 *  - @On_UserID : User ID  
 *  - @IP   : IP address  
 */  
  
SET NOCOUNT ON   
  
UPDATE PIH_OnUser WITH (ROWLOCK, UPDLOCK)   
SET IsKickedout = 1   
WHERE CustID = @CustID  
   
INSERT INTO PIH_OnUser  
 (custid, NetSessionID, IsKickedout, IP)  
VALUES  
 (@custid, @NetSessionid, 0, @IP)  
  
SELECT @On_UserID = SCOPE_IDENTITY()

GO
GRANT VIEW DEFINITION ON [dbo].[PIH_Users_CheckIn] TO [VNTeam] 
GO
GRANT EXECUTE ON [dbo].[PIH_Users_CheckIn] TO [bodbAdminNet] 