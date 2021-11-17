ALTER PROCEDURE [dbo].[Acc_LicenseesIns]  
	@LicenseeId INT,
	@LicenseeName VARCHAR(50)
	
AS  
/*  Created: Henry  
	Date: 2012-02-22
    TASk : Insert data to Licensees in Kahnawake server
    DB: bodb_MoveBet
   
    Revisions:  
		
	Param's Explanation:  
*/  
BEGIN  
SET NOCOUNT ON  
	--Delete before insert
	IF EXISTS (SELECT 1 FROM Licensees WITH (NOLOCK) WHERE LicenseeID = @LicenseeId)
	BEGIN
		DELETE FROM Licensees WITH (ROWLOCK,UPDLOCK)
		WHERE LicenseeID = @LicenseeId
	END

	INSERT INTO [dbo].Licensees
           (LicenseeID
           ,LicenseeName
           
           )
     VALUES	
     (
		@LicenseeId,
		@LicenseeName
     )

END   

GO
GRANT EXECUTE ON [dbo].[Acc_LicenseesIns] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_LicenseesIns] TO [vnteam] 

   