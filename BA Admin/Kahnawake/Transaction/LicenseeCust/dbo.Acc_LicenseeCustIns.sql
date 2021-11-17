ALTER PROCEDURE [dbo].[Acc_LicenseeCustIns]  
	@LicenseeId INT,
	@CustId INT,
	@RoleID INT,
	@Currency INT
AS  
/*  Created: Henry  
	Date: 2012-02-22
    TASk : Insert data to LicenseeCust in Kahnawake server
    DB: bodb_MoveBet
   
    Revisions:  
		
	Param's Explanation:  
*/  
BEGIN  
SET NOCOUNT ON  
	--Delete before insert
	IF EXISTS (SELECT 1 FROM LicenseeCust WITH (NOLOCK) WHERE CustID = @CustId)
	BEGIN
		DELETE FROM LicenseeCust WITH (ROWLOCK,UPDLOCK)
		WHERE CustID = @CustId
	END

	INSERT INTO [dbo].LicenseeCust
           (LicenseeID
           ,CustID
           ,RoleID
           ,Currency
           )
     VALUES	
     (
		@LicenseeID
        ,@CustID
        ,@RoleID
        ,@Currency
     )

END   

GO
GRANT EXECUTE ON [dbo].[Acc_LicenseeCustIns] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_LicenseeCustIns] TO [vnteam] 

   