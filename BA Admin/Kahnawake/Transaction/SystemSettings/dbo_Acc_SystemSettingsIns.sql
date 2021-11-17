ALTER PROCEDURE [dbo].[Acc_SystemSettingsIns]  
	@VName varchar(20) = 'MoveBetsDay',
	@VValue VARCHAR(200)
	
AS  
/*  Created: Henry  
	Date: 2012-02-22
    TASk : Insert data to SystemSettings in Kahnawake server
    DB: bodb_MoveBet
   
    Revisions:  
		
	Param's Explanation:  
*/  
BEGIN  
SET NOCOUNT ON  
	--Delete before insert
	IF EXISTS (SELECT 1 FROM SystemSettings WITH (NOLOCK) WHERE VName = @VName)
	BEGIN
		DELETE FROM SystemSettings WITH (ROWLOCK,UPDLOCK)
		WHERE VName = @VName
	END

	INSERT INTO [dbo].SystemSettings
           (VName
           ,VValue
           
           )
     VALUES	
     (
		@VName,
		@VValue
     )

END   

GO
GRANT EXECUTE ON [dbo].[Acc_SystemSettingsIns] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_SystemSettingsIns] TO [vnteam] 

   