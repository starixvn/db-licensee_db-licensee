ALTER PROCEDURE [dbo].[Acc_LicenseeCurrencyBAGroupIns]  
	@LicenseeId INT,
	@Currency INT,
	@ugroup varchar(3)
	
AS  
/*  Created: Henry  
	Date: 2012-02-22
    TASk : Insert data to LicenseeCurrencyBAGroup in Kahnawake server
    DB: bodb_MoveBet
   
    Revisions:  
		
	Param's Explanation:  
*/  
BEGIN  
SET NOCOUNT ON  
	--Delete before insert
	IF EXISTS (SELECT 1 FROM LicenseeCurrencyBAGroup WITH (NOLOCK) WHERE LicenseeID = @LicenseeId AND Currency = @Currency)
	BEGIN
		DELETE FROM LicenseeCurrencyBAGroup WITH (ROWLOCK,UPDLOCK)
		WHERE LicenseeID = @LicenseeId AND Currency = @Currency
	END

	INSERT INTO [dbo].LicenseeCurrencyBAGroup
           (LicenseeID
           ,Currency
           ,ugroup
           )
     VALUES	
     (
		@LicenseeId,
		@Currency,
		@ugroup
     )

END   

GO
GRANT EXECUTE ON [dbo].[Acc_LicenseeCurrencyBAGroupIns] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_LicenseeCurrencyBAGroupIns] TO [vnteam] 

     