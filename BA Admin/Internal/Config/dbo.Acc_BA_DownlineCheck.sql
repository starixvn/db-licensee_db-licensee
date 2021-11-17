ALTER PROCEDURE [dbo].[Acc_BA_DownlineCheck]
(
	@LicenseeID		INT,
	@BAMemberCount INT = 0 OUTPUT
)
AS
/*
Created: Henry
Date: 20110606
Task : Check running BA members
DB: DB052.bodb_Licensee
Original:


Param's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON
	
	SELECT @BAMemberCount = count(CustID) 
	FROM LicenseeBAHistory WITH (NOLOCK) 
	WHERE LicenseeID = @LicenseeID AND Status = 'Running'
		
	SELECT @BAMemberCount = ISNULL(@BAMemberCount,0)
	
	
END



GO
GRANT EXECUTE ON [dbo].[Acc_BA_DownlineCheck] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_BA_DownlineCheck] TO [vnteam] 